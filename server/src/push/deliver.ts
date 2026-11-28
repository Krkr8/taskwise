import type { Client } from '@libsql/client';

import { log } from '../log.js';
import type { PushMessage } from './schedule.js';
import {
  claimItem,
  deleteGoneSubscription,
  releaseItem,
  subscriptionsOf,
  type PushSubscriptionRow,
} from './store.js';

/** Sends one Web Push. `'gone'`: the push service dropped the subscription. */
export interface PushSender {
  send(sub: PushSubscriptionRow, payload: string): Promise<'ok' | 'gone'>;
}

/** A message this late sends nothing: a stale reminder is worse than none. */
export const staleAfterMs = 60 * 60 * 1000;

// Web Push payloads are limited to about 4 KB; these keep one well inside.
const maxPayloadTitle = 200;
const maxPayloadBody = 400;

function shorten(text: string, max: number): string {
  const chars = Array.from(text);
  return chars.length <= max ? text : `${chars.slice(0, max - 1).join('')}…`;
}

/**
 * Handles one queued message. The item is claimed first (marked sent only if
 * it is still unsent with this fire time), so an edited, deleted or already
 * sent item sends nothing (`'skipped'`), and a message delivered twice sends
 * once. If every subscription fails, the claim is undone and this throws, so
 * the queue tries again.
 *
 * Claim before send, on purpose: if the function dies between the claim and
 * the push (a crash or a timeout), that reminder is lost, never sent twice.
 * The queue's retry finds it claimed and skips it.
 */
export async function deliverPushItem(
  db: Client,
  sender: PushSender,
  msg: PushMessage,
  now: number,
): Promise<'sent' | 'stale' | 'skipped'> {
  const item = await claimItem(db, msg, now);
  if (!item) return 'skipped';

  const lateMs = now - msg.fireAt;
  if (lateMs > staleAfterMs) {
    log('warn', 'push_stale', {
      device: msg.deviceId,
      lateMinutes: Math.round(lateMs / 60000),
    });
    return 'stale';
  }

  const subs = await subscriptionsOf(db, msg.deviceId);
  if (subs.length === 0) {
    log('info', 'push_no_subscription', { device: msg.deviceId });
    return 'skipped';
  }
  const payload = JSON.stringify({
    title: shorten(item.title, maxPayloadTitle),
    body: shorten(item.body, maxPayloadBody),
    taskId: item.taskId,
    key: msg.key,
  });
  const results = await Promise.allSettled(
    subs.map((sub) => sender.send(sub, payload)),
  );
  let ok = 0;
  let gone = 0;
  let failed = 0;
  for (const [i, result] of results.entries()) {
    if (result.status === 'rejected') {
      failed++;
    } else if (result.value === 'gone') {
      gone++;
      await deleteGoneSubscription(db, subs[i]!.endpoint);
    } else {
      ok++;
    }
  }
  if (ok === 0 && failed > 0) {
    await releaseItem(db, msg, now);
    log('error', 'push_failed', { device: msg.deviceId, gone, failed });
    throw new Error('Web Push failed for every subscription.');
  }
  log('info', 'push_sent', { device: msg.deviceId, ok, gone, failed });
  return ok > 0 ? 'sent' : 'skipped';
}
