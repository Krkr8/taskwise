import { describe, expect, it } from 'vitest';

import { createApp } from '../src/api.js';
import { tombstoneMaxAgeMs } from '../src/sync/purge.js';
import { cronSecret, record, testApp } from './helpers.js';

const day = 24 * 60 * 60 * 1000;

async function ready() {
  const t = await testApp();
  await t.setup();
  const token = await t.login();
  const push = (changes: unknown[]) =>
    t.request('POST', '/sync', { token, body: { changes } });
  const cron = (secret = cronSecret) =>
    t.request('GET', '/cron/daily', { token: secret });
  const ids = async () =>
    (await t.db.execute('SELECT type, id FROM records ORDER BY type, id')).rows.map(
      (row) => `${String(row['type'])}:${String(row['id'])}`,
    );
  return { ...t, token, push, cron, ids };
}

const iso = (ms: number) => new Date(ms).toISOString();

describe('daily cron', () => {
  it('needs the cron secret', async () => {
    const { cron, request } = await ready();
    expect((await cron('wrong')).status).toBe(401);
    expect((await request('GET', '/cron/daily')).status).toBe(401);
  });

  it('is off without CRON_SECRET', async () => {
    const { db } = await ready();
    const app = createApp({
      db: async () => db,
      setupSecret: undefined,
      cronSecret: undefined,
      now: Date.now,
    });
    const response = await app.request('/api/v1/cron/daily', {
      headers: { authorization: 'Bearer anything' },
    });
    expect(response.status).toBe(503);
  });

  it('purges old tombstones with their tasks\' children, and nothing else', async () => {
    const { push, cron, ids, clock, token, request } = await ready();
    const old = iso(clock.now - tombstoneMaxAgeMs - day);
    const recent = iso(clock.now - day);
    await push([
      { type: 'task', record: { ...record('old-task', old), deleted: true } },
      { type: 'subtask', record: record('s1', recent, { taskId: 'old-task' }) },
      { type: 'reminder', record: record('r1', recent, { taskId: 'old-task' }) },
      { type: 'taskTag', record: record('tt1', recent, { taskId: 'old-task', tagId: 'g' }) },
      { type: 'taskTargetDevice', record: record('td1', recent, { taskId: 'old-task', deviceId: 'd' }) },
      { type: 'tag', record: { ...record('old-tag', old), deleted: true } },
      { type: 'task', record: { ...record('recent-task', recent), deleted: true } },
      { type: 'subtask', record: record('s2', old, { taskId: 'recent-task' }) },
      { type: 'task', record: record('live-task', old) },
      { type: 'tag', record: record('g', old) },
    ]);
    const response = await cron();
    expect(response.status).toBe(200);
    expect(response.body.purgedRecords).toBe(6);
    expect(await ids()).toEqual([
      'subtask:s2',
      'tag:g',
      'task:live-task',
      'task:recent-task',
    ]);

    // A device that last synced before the purged tombstones must start over.
    expect(
      (await request('GET', '/sync?since=1', { token })).body.error.code,
    ).toBe('resync_required');
    expect((await request('GET', '/sync?since=1', { token })).status).toBe(410);
    expect((await request('GET', '/sync?since=0', { token })).status).toBe(200);
    expect((await request('GET', '/sync?since=10', { token })).status).toBe(200);
  });

  it('clears expired login counters', async () => {
    const { request, cron, clock, db } = await ready();
    await request('POST', '/auth/login', {
      body: { username: 'x', password: 'y', device: { id: 'd', name: 'd', type: 'linux' } },
    });
    expect((await cron()).body.purgedLoginAttempts).toBe(0);
    clock.now += 16 * 60 * 1000;
    expect((await cron()).body.purgedLoginAttempts).toBe(2);
    expect((await db.execute('SELECT * FROM login_attempts')).rows).toHaveLength(0);
  });

  it('saves a backup of all records and keeps the newest 7', async () => {
    const { push, cron, db, clock } = await ready();
    await push([
      { type: 'tag', record: record('a', '2026-10-31T10:00:00.000Z') },
      { type: 'task', record: record('b', '2026-10-31T10:00:00.000Z', { title: 'x' }) },
    ]);
    for (let i = 0; i < 9; i++) {
      expect((await cron()).body.backupRecords).toBe(2);
      clock.now += day;
    }
    const rows = (await db.execute('SELECT created_at, data FROM backups ORDER BY id')).rows;
    expect(rows).toHaveLength(7);
    const latest = JSON.parse(String(rows.at(-1)?.['data']));
    expect(latest).toMatchObject({
      createdAt: iso(clock.now - day),
      seq: 2,
      records: [
        { type: 'tag', seq: 1, record: { id: 'a' } },
        { type: 'task', seq: 2, record: { id: 'b', title: 'x' } },
      ],
    });
    expect(JSON.stringify(latest)).not.toContain('token');
  });
});
