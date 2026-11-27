import { send } from '@vercel/queue';

import type { PushMessage, PushScheduler } from './schedule.js';

export const pushTopic = 'taskwise-push';

const maxRetentionSeconds = 604800;
const maxIdempotencyKeyLength = 256;

/** The queue's `send`; tests pass a fake. */
export type QueueSend = (
  topic: string,
  payload: PushMessage,
  options: ReturnType<typeof queueSendOptions>,
) => Promise<unknown>;

/** The options for one message: kept past its delay, deduplicated per item and time. */
export function queueSendOptions(msg: PushMessage, delaySeconds: number) {
  let idempotencyKey = `${msg.deviceId}:${msg.key}:${msg.fireAt}`;
  if (idempotencyKey.length > maxIdempotencyKeyLength) {
    // Too long for the queue: keep the tail (the time) and shorten the rest.
    const tail = `:${msg.fireAt}`;
    idempotencyKey = `${idempotencyKey.slice(0, maxIdempotencyKeyLength - tail.length)}${tail}`;
  }
  return {
    delaySeconds,
    retentionSeconds: Math.min(delaySeconds + 3600, maxRetentionSeconds),
    idempotencyKey,
  };
}

/** Queues each push on Vercel Queues, to arrive at `api/push-delivery.ts` on time. */
export class QueuePushScheduler implements PushScheduler {
  constructor(private readonly sendMessage: QueueSend = send) {}

  async enqueue(msg: PushMessage, delaySeconds: number): Promise<void> {
    await this.sendMessage(pushTopic, msg, queueSendOptions(msg, delaySeconds));
  }
}
