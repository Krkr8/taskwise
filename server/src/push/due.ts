import type { Client } from '@libsql/client';

import { log } from '../log.js';
import { deliverPushItem, type PushSender } from './deliver.js';
import type { PushMessage, PushScheduler } from './schedule.js';

/** Plain Node has no queue: the timer finds due items itself. */
export class NoopScheduler implements PushScheduler {
  async enqueue(_msg: PushMessage, _delaySeconds: number): Promise<void> {}
}

export interface DueResult {
  sent: number;
  stale: number;
  skipped: number;
  failed: number;
}

/** Items handled per tick; the rest wait for the next one. */
const batchSize = 200;

/**
 * Delivers the unsent items that are due ([now] or earlier). A failed one is
 * released, so the next tick tries again (until it is an hour late).
 */
export async function sendDuePushes(
  db: Client,
  sender: PushSender,
  now: number,
): Promise<DueResult> {
  const due = await db.execute({
    sql: `SELECT device_id, key, fire_at FROM push_items
          WHERE sent_at IS NULL AND fire_at <= ?
          ORDER BY fire_at LIMIT ?`,
    args: [now, batchSize],
  });
  const result: DueResult = { sent: 0, stale: 0, skipped: 0, failed: 0 };
  for (const row of due.rows) {
    const msg = {
      deviceId: String(row['device_id']),
      key: String(row['key']),
      fireAt: Number(row['fire_at']),
    };
    try {
      result[await deliverPushItem(db, sender, msg, now)]++;
    } catch {
      result.failed++; // deliverPushItem already logged it
    }
  }
  if (due.rows.length > 0) log('info', 'push_due', { ...result });
  return result;
}
