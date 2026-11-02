import { createClient } from '@libsql/client';
import { describe, expect, it } from 'vitest';

import { migrate, migrations } from '../src/db/migrations.js';
import { testApp } from './helpers.js';

const main = async (t: Awaited<ReturnType<typeof testApp>>, token: string) =>
  (await t.request('GET', '/devices', { token })).body.devices
    .filter((d: { main: boolean; deleted: boolean }) => d.main && !d.deleted)
    .map((d: { id: string }) => d.id);

describe('main device', () => {
  it('passes to the most recently seen device when the main one signs out', async () => {
    const t = await testApp();
    await t.setup();
    const a = await t.login('a');
    t.clock.now += 1000;
    const b = await t.login('b');
    t.clock.now += 120_000;
    const c = await t.login('c'); // seen last
    expect(await main(t, a)).toEqual(['a']);

    await t.request('DELETE', '/devices/a', { token: a }); // sign out
    expect(await main(t, c)).toEqual(['c']);
    expect(await main(t, b)).toEqual(['c']);
  });

  it('a removed main device logging in again is not main any more', async () => {
    const t = await testApp();
    await t.setup();
    const a = await t.login('a');
    const b = await t.login('b');
    await t.request('PATCH', '/devices/b', { token: a, body: { main: true } });
    const again = await t.login('a');
    expect(await main(t, again)).toEqual(['b']);
    expect(b).toBeTruthy();
  });

  it('the first device after all were removed becomes main', async () => {
    const t = await testApp();
    await t.setup();
    const a = await t.login('a');
    await t.request('DELETE', '/devices/a', { token: a });
    const b = await t.login('b');
    expect(await main(t, b)).toEqual(['b']);
  });

  it('upgrading an existing database makes the oldest active device main', async () => {
    const db = createClient({ url: ':memory:' });
    // Schema as it was before the main device existed.
    await db.execute(
      'CREATE TABLE schema_migrations (version INTEGER PRIMARY KEY, applied_at INTEGER NOT NULL)',
    );
    await db.batch([...migrations[0]!, 'INSERT INTO schema_migrations VALUES (1, 0)'], 'write');
    await db.execute(`INSERT INTO devices (id, name, type, token_hash, created_at, updated_at, revoked_at)
      VALUES ('old-revoked', 'x', 'linux', 'h1', 1, 1, 5),
             ('first', 'Fedora', 'linux', 'h2', 2, 2, NULL),
             ('second', 'iPhone', 'ios', 'h3', 3, 3, NULL)`);
    await migrate(db);
    const rows = await db.execute('SELECT id FROM devices WHERE is_main = 1');
    expect(rows.rows.map((r) => r['id'])).toEqual(['first']);
  });
});
