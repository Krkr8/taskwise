import type { Client } from '@libsql/client';

import type { Change, RecordType, SyncRecord } from './records.js';

export type PushStatus = 'applied' | 'stale';

export interface PushResult {
  readonly results: { type: RecordType; id: string; status: PushStatus }[];
  /** The server's latest change sequence number after this push. */
  readonly seq: number;
}

export interface PullResult {
  readonly changes: { type: RecordType; seq: number; record: SyncRecord }[];
  readonly nextSince: number;
  readonly hasMore: boolean;
}

export const defaultPullLimit = 500;
export const maxPullLimit = 1000;

/**
 * Stores pushed changes, last write wins per record (SPEC.md §4).
 *
 * A change replaces the stored record only if its `updatedAt` is newer, or
 * equal with a greater device id (a stable tie-break). Every applied change
 * takes the next sequence number. The whole push is one write transaction,
 * and the winner is decided inside SQL, so concurrent pushes can't lose
 * updates. Since writes are serialized, sequence numbers commit in order and
 * a pull never skips a change. Stale changes still use up a number; gaps are
 * harmless.
 */
export async function push(
  db: Client,
  deviceId: string,
  changes: readonly Change[],
): Promise<PushResult> {
  const statements = changes.flatMap((change) => {
    const record = { ...change.record, updatedByDevice: deviceId };
    return [
      'UPDATE meta SET value = value + 1 WHERE key = \'seq\'',
      {
        sql: `INSERT INTO records
                (type, id, seq, updated_at, deleted, updated_by_device, data)
              VALUES (?, ?, (SELECT value FROM meta WHERE key = 'seq'), ?, ?, ?, ?)
              ON CONFLICT (type, id) DO UPDATE SET
                seq = excluded.seq,
                updated_at = excluded.updated_at,
                deleted = excluded.deleted,
                updated_by_device = excluded.updated_by_device,
                data = excluded.data
              WHERE excluded.updated_at > records.updated_at
                 OR (excluded.updated_at = records.updated_at
                     AND excluded.updated_by_device > COALESCE(records.updated_by_device, ''))`,
        args: [
          change.type,
          record.id,
          change.updatedAtMs,
          record.deleted ? 1 : 0,
          deviceId,
          JSON.stringify(record),
        ],
      },
    ];
  });
  const results = await db.batch(
    [...statements, "SELECT value FROM meta WHERE key = 'seq'"],
    'write',
  );
  return {
    results: changes.map((change, index) => ({
      type: change.type,
      id: change.record.id,
      status: results[index * 2 + 1]!.rowsAffected > 0 ? 'applied' : 'stale',
    })),
    seq: Number(results.at(-1)!.rows[0]!['value']),
  };
}

/** Changes with a sequence number above [since], oldest first. */
export async function pull(
  db: Client,
  since: number,
  limit: number,
): Promise<PullResult> {
  const result = await db.execute({
    sql: 'SELECT type, seq, data FROM records WHERE seq > ? ORDER BY seq LIMIT ?',
    args: [since, limit + 1],
  });
  const rows = result.rows.slice(0, limit);
  const changes = rows.map((row) => ({
    type: String(row['type']) as RecordType,
    seq: Number(row['seq']),
    record: JSON.parse(String(row['data'])) as SyncRecord,
  }));
  return {
    changes,
    nextSince: changes.at(-1)?.seq ?? since,
    hasMore: result.rows.length > limit,
  };
}

/**
 * The highest sequence number among purged tombstones. A client whose
 * `since` is below it may have missed deletions and must sync from 0.
 */
export async function purgedSeq(db: Client): Promise<number> {
  const result = await db.execute(
    "SELECT value FROM meta WHERE key = 'purged_seq'",
  );
  return Number(result.rows[0]?.['value'] ?? 0);
}
