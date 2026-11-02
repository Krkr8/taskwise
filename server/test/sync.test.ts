import { describe, expect, it } from 'vitest';

import { maxBodyBytes } from '../src/api.js';
import { record, testApp } from './helpers.js';

async function ready() {
  const t = await testApp();
  await t.setup();
  const laptop = await t.login('laptop', 'linux');
  const phone = await t.login('phone', 'ios');
  const push = (token: string, changes: unknown[]) =>
    t.request('POST', '/sync', { token, body: { changes } });
  const pull = (token: string, query = 'since=0') =>
    t.request('GET', `/sync?${query}`, { token });
  return { ...t, laptop, phone, push, pull };
}

describe('push', () => {
  it('last write wins by updatedAt', async () => {
    const { laptop, phone, push, pull } = await ready();
    await push(laptop, [
      { type: 'task', record: record('t1', '2026-10-31T10:00:00.000Z', { title: 'a' }) },
    ]);
    const older = await push(phone, [
      { type: 'task', record: record('t1', '2026-10-31T09:59:59.999Z', { title: 'b' }) },
    ]);
    expect(older.body.results[0].status).toBe('stale');
    const newer = await push(phone, [
      { type: 'task', record: record('t1', '2026-10-31T10:00:00.001Z', { title: 'c' }) },
    ]);
    expect(newer.body.results[0].status).toBe('applied');
    const pulled = await pull(laptop);
    expect(pulled.body.changes).toHaveLength(1);
    expect(pulled.body.changes[0].record.title).toBe('c');
  });

  it('breaks updatedAt ties by device id, and a repeated push is stale', async () => {
    const { laptop, phone, push } = await ready();
    const at = '2026-10-31T10:00:00.000Z';
    // 'phone' > 'laptop', so the phone wins a tie but the laptop does not.
    expect(
      (await push(laptop, [{ type: 'tag', record: record('g', at) }])).body
        .results[0].status,
    ).toBe('applied');
    expect(
      (await push(phone, [{ type: 'tag', record: record('g', at) }])).body
        .results[0].status,
    ).toBe('applied');
    expect(
      (await push(laptop, [{ type: 'tag', record: record('g', at) }])).body
        .results[0].status,
    ).toBe('stale');
    expect(
      (await push(phone, [{ type: 'tag', record: record('g', at) }])).body
        .results[0].status,
    ).toBe('stale');
  });

  it('sets updatedByDevice from the token, ignoring the client value', async () => {
    const { laptop, push, pull } = await ready();
    await push(laptop, [
      {
        type: 'tag',
        record: record('g', '2026-10-31T10:00:00.000Z', { updatedByDevice: 'spoofed' }),
      },
    ]);
    expect((await pull(laptop)).body.changes[0].record.updatedByDevice).toBe(
      'laptop',
    );
  });

  it('keeps the same id apart across types', async () => {
    const { laptop, push, pull } = await ready();
    const at = '2026-10-31T10:00:00.000Z';
    await push(laptop, [
      { type: 'tag', record: record('same', at) },
      { type: 'category', record: record('same', at) },
    ]);
    expect((await pull(laptop)).body.changes).toHaveLength(2);
  });

  it('syncs tombstones', async () => {
    const { laptop, phone, push, pull } = await ready();
    await push(laptop, [{ type: 'task', record: record('t', '2026-10-31T10:00:00.000Z') }]);
    await push(laptop, [
      { type: 'task', record: { ...record('t', '2026-10-31T11:00:00.000Z'), deleted: true } },
    ]);
    const pulled = await pull(phone);
    expect(pulled.body.changes).toEqual([
      expect.objectContaining({ type: 'task', record: expect.objectContaining({ deleted: true }) }),
    ]);
  });

  it.each([
    [{ changes: [{ type: 'device', record: record('x', '2026-10-31T10:00:00.000Z') }] }, 'unknown type'],
    [{ changes: [{ type: 'task', record: { id: 'x', deleted: false } }] }, 'updatedAt'],
    [{ changes: [{ type: 'task', record: record('x', '2026-10-31 10:00') }] }, 'updatedAt'],
    [{ changes: [{ type: 'task', record: record('x', '2026-10-31T10:00:00+03:00') }] }, 'updatedAt'],
    [{ changes: [{ type: 'task', record: { id: 'x', updatedAt: '2026-10-31T10:00:00Z' } }] }, 'deleted'],
    [{ changes: [{ type: 'task', record: record('', '2026-10-31T10:00:00Z') }] }, 'id'],
    [{ changes: [{ type: 'task', record: record('x'.repeat(129), '2026-10-31T10:00:00Z') }] }, 'id'],
    [{ changes: [{ type: 'task', record: [] }] }, 'record'],
    [{ changes: 'nope' }, 'changes'],
    [[], 'changes'],
  ])('rejects an invalid push (%#: %s)', async (body, mention) => {
    const { laptop, request, pull } = await ready();
    const response = await request('POST', '/sync', { token: laptop, body });
    expect(response.status).toBe(400);
    expect(response.body.error.message).toContain(mention);
    expect((await pull(laptop)).body.changes).toHaveLength(0);
  });

  it('rejects the whole push if one change is invalid', async () => {
    const { laptop, push, pull } = await ready();
    const response = await push(laptop, [
      { type: 'task', record: record('ok', '2026-10-31T10:00:00.000Z') },
      { type: 'nope', record: record('bad', '2026-10-31T10:00:00.000Z') },
    ]);
    expect(response.status).toBe(400);
    expect(response.body.error.message).toContain('changes[1]');
    expect((await pull(laptop)).body.changes).toHaveLength(0);
  });

  it('accepts 500 changes and refuses 501', async () => {
    const { laptop, push } = await ready();
    const changes = (n: number) =>
      Array.from({ length: n }, (_, i) => ({
        type: 'tag',
        record: record(`tag-${i}`, '2026-10-31T10:00:00.000Z'),
      }));
    const ok = await push(laptop, changes(500));
    expect(ok.status).toBe(200);
    expect(ok.body.seq).toBe(500);
    expect((await push(laptop, changes(501))).status).toBe(400);
  });

  it('refuses a body over 1 MB', async () => {
    const { laptop, push } = await ready();
    const response = await push(laptop, [
      {
        type: 'task',
        record: record('big', '2026-10-31T10:00:00.000Z', {
          notes: 'x'.repeat(maxBodyBytes),
        }),
      },
    ]);
    expect(response.status).toBe(413);
    expect(response.body.error.code).toBe('payload_too_large');
  });

  it('needs a token', async () => {
    const { request } = await ready();
    expect((await request('POST', '/sync', { body: { changes: [] } })).status).toBe(401);
    expect((await request('GET', '/sync', { token: 'tw_wrong' })).status).toBe(401);
  });
});

describe('pull', () => {
  it('pages through changes in sequence order', async () => {
    const { laptop, push, pull } = await ready();
    await push(laptop, [
      ...['a', 'b', 'c', 'd', 'e'].map((id) => ({
        type: 'tag',
        record: record(id, '2026-10-31T10:00:00.000Z'),
      })),
    ]);
    // Editing 'a' moves it to the end.
    await push(laptop, [{ type: 'tag', record: record('a', '2026-10-31T11:00:00.000Z') }]);
    const seen: string[] = [];
    let since = 0;
    for (;;) {
      const page = await pull(laptop, `since=${since}&limit=2`);
      seen.push(...page.body.changes.map((c: { record: { id: string } }) => c.record.id));
      since = page.body.nextSince;
      if (!page.body.hasMore) break;
    }
    expect(seen).toEqual(['b', 'c', 'd', 'e', 'a']);
    expect(since).toBe(6);
  });

  it.each(['since=-1', 'since=abc', 'limit=0', 'limit=1001', 'since=1.5'])(
    'rejects %s',
    async (query) => {
      const { laptop, pull } = await ready();
      expect((await pull(laptop, query)).status).toBe(400);
    },
  );
});
