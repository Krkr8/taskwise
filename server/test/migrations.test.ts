import { createClient } from '@libsql/client';
import { describe, expect, it } from 'vitest';

import { configFromEnv } from '../src/config.js';
import { migrate, migrations } from '../src/db/migrations.js';

describe('migrations', () => {
  it('apply once, and running them again changes nothing', async () => {
    const db = createClient({ url: ':memory:' });
    await migrate(db);
    await migrate(db);
    const versions = await db.execute('SELECT version FROM schema_migrations');
    expect(versions.rows.map((r) => Number(r['version']))).toEqual(
      migrations.map((_, i) => i + 1),
    );
  });

  it('survive two instances migrating at once', async () => {
    const dir = await import('node:fs/promises').then((fs) =>
      fs.mkdtemp(`${(process.env['TMPDIR'] ?? '/tmp')}/taskwise-`),
    );
    const url = `file:${dir}/race.db`;
    await Promise.all([
      migrate(createClient({ url })),
      migrate(createClient({ url })),
    ]);
    const db = createClient({ url });
    const versions = await db.execute('SELECT COUNT(*) AS n FROM schema_migrations');
    expect(Number(versions.rows[0]?.['n'])).toBe(migrations.length);
  });

  it('upgrade a version 2 database: devices gain a time zone, push tables appear', async () => {
    const db = createClient({ url: ':memory:' });
    await db.execute(
      'CREATE TABLE schema_migrations (version INTEGER PRIMARY KEY, applied_at INTEGER NOT NULL)',
    );
    await db.batch(
      [...migrations[0]!, ...migrations[1]!, 'INSERT INTO schema_migrations VALUES (1, 0), (2, 0)'],
      'write',
    );
    await db.execute(`INSERT INTO devices (id, name, type, token_hash, created_at, updated_at, is_main)
      VALUES ('phone', 'iPhone', 'ios', 'h1', 1, 1, 1)`);
    await migrate(db);
    const device = await db.execute('SELECT id, time_zone, is_main FROM devices');
    expect(device.rows.map((r) => ({ ...r }))).toEqual([
      { id: 'phone', time_zone: null, is_main: 1 },
    ]);
    await db.execute(`INSERT INTO push_subscriptions (endpoint, device_id, p256dh, auth, created_at)
      VALUES ('https://push.example.com/x', 'phone', 'k', 'a', 1)`);
    await db.execute(`INSERT INTO push_items (device_id, key, fire_at, task_id, title, body)
      VALUES ('phone', '1', 2, 't', 'x', 'y')`);
    const item = await db.execute('SELECT queued_at, sent_at FROM push_items');
    expect(item.rows.map((r) => ({ ...r }))).toEqual([{ queued_at: null, sent_at: null }]);
  });
});

describe('config', () => {
  it('reads the environment, treating blank values as unset', () => {
    expect(
      configFromEnv({
        DATABASE_URL: 'libsql://db.turso.io',
        DATABASE_AUTH_TOKEN: ' ',
        SETUP_SECRET: 'abc',
      }),
    ).toEqual({
      databaseUrl: 'libsql://db.turso.io',
      databaseAuthToken: undefined,
      setupSecret: 'abc',
      cronSecret: undefined,
    });
  });
});
