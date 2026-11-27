import type { Client } from '@libsql/client';

import { log } from '../log.js';
import { deliverPushItem, type PushSender } from './deliver.js';
import type { PushMessage } from './schedule.js';

/** Reads a queue message; undefined if it isn't a [PushMessage]. */
export function parsePushMessage(value: unknown): PushMessage | undefined {
  let data = value;
  if (typeof value === 'string') {
    try {
      data = JSON.parse(value);
    } catch {
      return undefined;
    }
  }
  if (typeof data !== 'object' || data === null) return undefined;
  const { deviceId, key, fireAt } = data as Record<string, unknown>;
  if (
    typeof deviceId !== 'string' ||
    typeof key !== 'string' ||
    typeof fireAt !== 'number' ||
    !Number.isSafeInteger(fireAt)
  ) {
    return undefined;
  }
  return { deviceId, key, fireAt };
}

export interface PushDeliveryDeps {
  db: () => Promise<Client>;
  /** Undefined when the server has no VAPID keys. */
  sender: PushSender | undefined;
  now: () => number;
}

/**
 * The queue consumer's handler. Returning acknowledges the message; throwing
 * (every subscription failed) makes the queue deliver it again. Logs never
 * hold titles or endpoints.
 */
export function pushDeliveryHandler(deps: PushDeliveryDeps) {
  return async (
    message: unknown,
    metadata: { deliveryCount: number },
  ): Promise<void> => {
    const msg = parsePushMessage(message);
    if (!msg) {
      log('warn', 'push_bad_message', { deliveryCount: metadata.deliveryCount });
      return;
    }
    if (!deps.sender) {
      log('warn', 'push_not_configured', {});
      return;
    }
    const result = await deliverPushItem(await deps.db(), deps.sender, msg, deps.now());
    log('info', 'push_delivery', {
      device: msg.deviceId,
      result,
      deliveryCount: metadata.deliveryCount,
    });
  };
}
