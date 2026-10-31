import type { Client } from '@libsql/client';

/**
 * Schema migrations, applied in order. Never edit a released migration;
 * append a new one instead.
 *
 * `records` is a generic store: the server only keeps and serves synced
 * records (as JSON), it doesn't interpret them (SPEC.md §2).
 */
export const migrations: readonly (readonly string[])[] = [
  [
    `CREATE TABLE account (
       id INTEGER PRIMARY KEY CHECK (id = 1),
       username TEXT NOT NULL,
       password_hash TEXT NOT NULL,
       created_at INTEGER NOT NULL
     )`,
    `CREATE TABLE devices (
       id TEXT PRIMARY KEY,
       name TEXT NOT NULL,
       type TEXT NOT NULL,
       token_hash TEXT NOT NULL UNIQUE,
       created_at INTEGER NOT NULL,
       updated_at INTEGER NOT NULL,
       last_seen_at INTEGER,
       revoked_at INTEGER
     )`,
    `CREATE TABLE records (
       type TEXT NOT NULL,
       id TEXT NOT NULL,
       seq INTEGER NOT NULL,
       updated_at INTEGER NOT NULL,
       deleted INTEGER NOT NULL,
       updated_by_device TEXT,
       data TEXT NOT NULL,
       PRIMARY KEY (type, id)
     )`,
    'CREATE INDEX records_seq ON records (seq)',
    'CREATE INDEX records_tombstones ON records (deleted, updated_at)',
    `CREATE TABLE meta (
       key TEXT PRIMARY KEY,
       value INTEGER NOT NULL
     )`,
    `INSERT INTO meta (key, value) VALUES ('seq', 0), ('purged_seq', 0)`,
    `CREATE TABLE login_attempts (
       key TEXT PRIMARY KEY,
       window_start INTEGER NOT NULL,
       count INTEGER NOT NULL
     )`,
    `CREATE TABLE backups (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       created_at INTEGER NOT NULL,
       data TEXT NOT NULL
     )`,
  ],
];

/** Brings the database schema up to date. Safe to run concurrently. */
export async function migrate(client: Client): Promise<void> {
  await client.execute(
    `CREATE TABLE IF NOT EXISTS schema_migrations (
       version INTEGER PRIMARY KEY,
       applied_at INTEGER NOT NULL
     )`,
  );
  const result = await client.execute(
    'SELECT COALESCE(MAX(version), 0) AS version FROM schema_migrations',
  );
  const current = Number(result.rows[0]?.['version'] ?? 0);

  for (let version = current + 1; version <= migrations.length; version++) {
    const statements = migrations[version - 1] ?? [];
    // The version row is inserted in the same transaction, so a second
    // instance migrating at the same time fails on the primary key and
    // rolls back instead of applying the migration twice.
    try {
      await client.batch(
        [
          ...statements,
          {
            sql: 'INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?)',
            args: [version, Date.now()],
          },
        ],
        'write',
      );
    } catch (error) {
      const again = await client.execute(
        'SELECT 1 FROM schema_migrations WHERE version = ?',
        [version],
      );
      if (again.rows.length === 0) throw error;
    }
  }
}
