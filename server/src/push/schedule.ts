import type { Client } from '@libsql/client';

import type { PushItemRef } from './store.js';

/** A queued delivery of one item at one fire time. */
export interface PushMessage {
  deviceId: string;
  key: string;
  fireAt: number;
}

/**
 * Delivers a message to `deliverPushItem` after [delaySeconds]. Messages
 * can't be cancelled: every delivery re-checks the item.
 */
export interface PushScheduler {
  enqueue(msg: PushMessage, delaySeconds: number): Promise<void>;
}

/**
 * How far ahead messages are queued: 7 days (the Vercel Queues maximum for
 * retention) minus an hour, so retention (delay + 1 hour) always fits.
 */
export const queueHorizonMs = 7 * 24 * 3600 * 1000 - 3600 * 1000;

/** Enqueue calls made at once. */
const enqueueBatch = 25;

/**
 * Queues every unsent, not yet queued item with a fire time in
 * (now, now + queueHorizonMs] (7 days minus an hour), of [deviceId] or of all devices, and returns how many
 * were queued. Items are marked queued first, in one statement, so two calls
 * at once queue each item only once. Items whose enqueue fails are unmarked
 * (the next upload or the daily cron tries again) and the call throws.
 */
export async function queueDueItems(
  db: Client,
  scheduler: PushScheduler,
  now: number,
  deviceId?: string,
): Promise<number> {
  const result = await db.execute({
    sql: `UPDATE push_items SET queued_at = ?
          WHERE queued_at IS NULL AND sent_at IS NULL
            AND fire_at > ? AND fire_at <= ?
            ${deviceId === undefined ? '' : 'AND device_id = ?'}
          RETURNING device_id, key, fire_at`,
    args: [
      now,
      now,
      now + queueHorizonMs,
      ...(deviceId === undefined ? [] : [deviceId]),
    ],
  });
  const claimed: PushMessage[] = result.rows
    .map((row) => ({
      deviceId: String(row['device_id']),
      key: String(row['key']),
      fireAt: Number(row['fire_at']),
    }))
    .sort((a, b) => a.fireAt - b.fireAt || a.key.localeCompare(b.key));

  const failed: PushItemRef[] = [];
  for (let i = 0; i < claimed.length; i += enqueueBatch) {
    const batch = claimed.slice(i, i + enqueueBatch);
    const results = await Promise.allSettled(
      batch.map((msg) =>
        scheduler.enqueue(msg, Math.ceil((msg.fireAt - now) / 1000)),
      ),
    );
    results.forEach((r, j) => {
      if (r.status === 'rejected') failed.push(batch[j]!);
    });
  }
  if (failed.length > 0) {
    await db.batch(
      failed.map((ref) => ({
        sql: `UPDATE push_items SET queued_at = NULL
              WHERE device_id = ? AND key = ? AND fire_at = ? AND queued_at = ?`,
        args: [ref.deviceId, ref.key, ref.fireAt, now],
      })),
      'write',
    );
    throw new Error(`Could not queue ${failed.length} of ${claimed.length} pushes.`);
  }
  return claimed.length;
}
