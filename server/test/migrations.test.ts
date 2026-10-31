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
