import type { Client } from '@libsql/client';

import { loginWindowMs } from '../auth/rateLimit.js';
import { taskChildTypes } from './records.js';

export const tombstoneMaxAgeMs = 90 * 24 * 60 * 60 * 1000;

export interface PurgeResult {
  readonly records: number;
  readonly loginAttempts: number;
}

/**
 * Deletes tombstones older than 90 days, the records of purged tasks
 * (subtasks, reminders, tag links, device targets; tombstoned tasks keep
 * them for undo), and expired login counters. Records `purged_seq` so
 * clients that missed the tombstones know to sync from scratch.
 */
export async function purge(db: Client, now: number): Promise<PurgeResult> {
  const cutoff = now - tombstoneMaxAgeMs;
  const childTypes = taskChildTypes.map((type) => `'${type}'`).join(', ');
  const purgedTasks = `SELECT id FROM records
                       WHERE type = 'task' AND deleted = 1 AND updated_at < ?`;
  const results = await db.batch(
    [
      {
        sql: `UPDATE meta SET value = MAX(value, COALESCE((
                SELECT MAX(seq) FROM records
                WHERE (deleted = 1 AND updated_at < ?)
                   OR (type IN (${childTypes})
                       AND json_extract(data, '$.taskId') IN (${purgedTasks}))
              ), 0))
              WHERE key = 'purged_seq'`,
        args: [cutoff, cutoff],
      },
      {
        sql: `DELETE FROM records
              WHERE type IN (${childTypes})
                AND json_extract(data, '$.taskId') IN (${purgedTasks})`,
        args: [cutoff],
      },
      {
        sql: 'DELETE FROM records WHERE deleted = 1 AND updated_at < ?',
        args: [cutoff],
      },
      {
        sql: 'DELETE FROM login_attempts WHERE window_start <= ?',
        args: [now - loginWindowMs],
      },
    ],
    'write',
  );
  return {
    records: results[1]!.rowsAffected + results[2]!.rowsAffected,
    loginAttempts: results[3]!.rowsAffected,
  };
}
