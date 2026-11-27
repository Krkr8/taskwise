import type { Client, Row } from '@libsql/client';

/**
 * Push data: the Web Push subscriptions of devices and each web device's
 * push plan. It lives in its own tables, outside the synced `records`.
 */

/** A browser's Web Push subscription, owned by one device. */
export interface PushSubscriptionRow {
  readonly endpoint: string;
  readonly deviceId: string;
  readonly p256dh: string;
  readonly auth: string;
  readonly createdAt: number;
}

/** One planned push (`PushPlanItem` in shared); `fireAt` is UTC ms. */
export interface PushPlanItem {
  readonly key: string;
  readonly fireAt: number;
  readonly taskId: string;
  readonly title: string;
  readonly body: string;
}

/** Identifies one occurrence of an item: a message is for exactly this. */
export interface PushItemRef {
  readonly deviceId: string;
  readonly key: string;
  readonly fireAt: number;
}

/** What a delivery needs from a claimed item. */
export interface ClaimedPushItem {
  readonly taskId: string;
  readonly title: string;
  readonly body: string;
}

/** Items whose time is this long past are removed by the daily cron. */
export const pushItemMaxAgeMs = 2 * 24 * 60 * 60 * 1000;

function subscriptionFromRow(row: Row): PushSubscriptionRow {
  return {
    endpoint: String(row['endpoint']),
    deviceId: String(row['device_id']),
    p256dh: String(row['p256dh']),
    auth: String(row['auth']),
    createdAt: Number(row['created_at']),
  };
}

/**
 * Saves a subscription for [deviceId]. The same endpoint again (a renewed
 * subscription, or the browser now signed in as another device) replaces it.
 */
export async function putSubscription(
  db: Client,
  deviceId: string,
  sub: { endpoint: string; p256dh: string; auth: string },
  now: number,
): Promise<void> {
  await db.execute({
    sql: `INSERT INTO push_subscriptions (endpoint, device_id, p256dh, auth, created_at)
          VALUES (?, ?, ?, ?, ?)
          ON CONFLICT (endpoint) DO UPDATE SET
            device_id = excluded.device_id, p256dh = excluded.p256dh,
            auth = excluded.auth`,
    args: [sub.endpoint, deviceId, sub.p256dh, sub.auth, now],
  });
}

/** Removes [endpoint] if [deviceId] owns it. */
export async function deleteSubscription(
  db: Client,
  deviceId: string,
  endpoint: string,
): Promise<void> {
  await db.execute({
    sql: 'DELETE FROM push_subscriptions WHERE endpoint = ? AND device_id = ?',
    args: [endpoint, deviceId],
  });
}

/** Removes a subscription the push service reported gone. */
export async function deleteGoneSubscription(
  db: Client,
  endpoint: string,
): Promise<void> {
  await db.execute({
    sql: 'DELETE FROM push_subscriptions WHERE endpoint = ?',
    args: [endpoint],
  });
}

export async function subscriptionsOf(
  db: Client,
  deviceId: string,
): Promise<PushSubscriptionRow[]> {
  const result = await db.execute({
    sql: `SELECT endpoint, device_id, p256dh, auth, created_at
          FROM push_subscriptions WHERE device_id = ? ORDER BY created_at, endpoint`,
    args: [deviceId],
  });
  return result.rows.map(subscriptionFromRow);
}

/**
 * Replaces [deviceId]'s plan with [items] in one write transaction, so two
 * uploads at once leave one of the two lists, never a mix.
 *
 * - Unsent items not in the list are deleted, so their queued messages
 *   find nothing to send.
 * - A new key, or a changed fire time, has `queued_at` (and `sent_at`) reset,
 *   so it gets one new message. A changed title or body only updates the
 *   text: the message already queued for that fire time sends the new text.
 * - Sent items stay until the cron removes them, so uploading them again
 *   doesn't send them twice.
 *
 * Does nothing unless [deviceId] is an active web device.
 */
export async function replacePlan(
  db: Client,
  deviceId: string,
  items: readonly PushPlanItem[],
): Promise<void> {
  const json = JSON.stringify(items);
  const isActiveWeb = `EXISTS (SELECT 1 FROM devices
      WHERE id = ? AND type = 'web' AND revoked_at IS NULL)`;
  await db.batch(
    [
      {
        sql: `DELETE FROM push_items
              WHERE device_id = ? AND sent_at IS NULL
                AND key NOT IN (SELECT json_extract(value, '$.key') FROM json_each(?))`,
        args: [deviceId, json],
      },
      {
        // `WHERE` before `ON CONFLICT` is required by SQLite's parser here.
        sql: `INSERT INTO push_items (device_id, key, fire_at, task_id, title, body)
              SELECT ?, json_extract(value, '$.key'), json_extract(value, '$.fireAt'),
                     json_extract(value, '$.taskId'), json_extract(value, '$.title'),
                     json_extract(value, '$.body')
              FROM json_each(?) WHERE ${isActiveWeb}
              ON CONFLICT (device_id, key) DO UPDATE SET
                queued_at = CASE WHEN push_items.fire_at = excluded.fire_at
                                 THEN push_items.queued_at END,
                sent_at = CASE WHEN push_items.fire_at = excluded.fire_at
                               THEN push_items.sent_at END,
                fire_at = excluded.fire_at, task_id = excluded.task_id,
                title = excluded.title, body = excluded.body`,
        args: [deviceId, json, deviceId],
      },
    ],
    'write',
  );
}

/**
 * Marks the item sent if it is still unsent with exactly this fire time,
 * and returns it; undefined if it was changed, deleted or already sent.
 * One statement, so of two deliveries of one message only one gets it.
 */
export async function claimItem(
  db: Client,
  ref: PushItemRef,
  now: number,
): Promise<ClaimedPushItem | undefined> {
  // No RETURNING: local libSQL reports rowsAffected 0 for it.
  const claim = await db.execute({
    sql: `UPDATE push_items SET sent_at = ?
          WHERE device_id = ? AND key = ? AND fire_at = ? AND sent_at IS NULL`,
    args: [now, ref.deviceId, ref.key, ref.fireAt],
  });
  if (claim.rowsAffected !== 1) return undefined;
  const result = await db.execute({
    sql: `SELECT task_id, title, body FROM push_items
          WHERE device_id = ? AND key = ? AND fire_at = ?`,
    args: [ref.deviceId, ref.key, ref.fireAt],
  });
  const row = result.rows[0];
  if (!row) return undefined;
  return {
    taskId: String(row['task_id']),
    title: String(row['title']),
    body: String(row['body']),
  };
}

/** Undoes [claimItem] (made at [claimedAt]) after a failed send. */
export async function releaseItem(
  db: Client,
  ref: PushItemRef,
  claimedAt: number,
): Promise<void> {
  await db.execute({
    sql: `UPDATE push_items SET sent_at = NULL
          WHERE device_id = ? AND key = ? AND fire_at = ? AND sent_at = ?`,
    args: [ref.deviceId, ref.key, ref.fireAt, claimedAt],
  });
}

/** Removes items whose time is more than [pushItemMaxAgeMs] past. */
export async function purgePushItems(db: Client, now: number): Promise<number> {
  const result = await db.execute({
    sql: 'DELETE FROM push_items WHERE fire_at < ?',
    args: [now - pushItemMaxAgeMs],
  });
  return result.rowsAffected;
}
