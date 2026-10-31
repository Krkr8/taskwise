import type { Client } from '@libsql/client';

export const backupsKept = 7;

/**
 * Saves a JSON copy of all synced records in the `backups` table and keeps
 * the newest [backupsKept]. Account and device rows (password and token
 * hashes) are not included.
 */
export async function backup(
  db: Client,
  now: number,
): Promise<{ records: number }> {
  const result = await db.execute(
    'SELECT type, seq, data FROM records ORDER BY seq',
  );
  const seq = await db.execute("SELECT value FROM meta WHERE key = 'seq'");
  const data = JSON.stringify({
    createdAt: new Date(now).toISOString(),
    seq: Number(seq.rows[0]?.['value'] ?? 0),
    records: result.rows.map((row) => ({
      type: String(row['type']),
      seq: Number(row['seq']),
      record: JSON.parse(String(row['data'])) as unknown,
    })),
  });
  await db.batch(
    [
      {
        sql: 'INSERT INTO backups (created_at, data) VALUES (?, ?)',
        args: [now, data],
      },
      {
        sql: `DELETE FROM backups WHERE id NOT IN
                (SELECT id FROM backups ORDER BY id DESC LIMIT ?)`,
        args: [backupsKept],
      },
    ],
    'write',
  );
  return { records: result.rows.length };
}
