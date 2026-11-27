import type { Agent } from 'node:https';

import { sendNotification } from 'web-push';

import type { VapidConfig } from '../config.js';
import type { PushSender } from './deliver.js';
import type { PushSubscriptionRow } from './store.js';

/** How long the push service keeps an undeliverable push (seconds). */
const ttlSeconds = 3600;

/** A failed send. The message never holds the endpoint or the payload. */
export class WebPushError extends Error {
  constructor(readonly statusCode: number | undefined) {
    super(
      statusCode === undefined
        ? 'Web Push request failed.'
        : `Web Push request failed with status ${statusCode}.`,
    );
    this.name = 'WebPushError';
  }
}

/** Sends Web Push messages signed with the server's VAPID keys. */
export class WebPushSender implements PushSender {
  /** [agent] is for tests (a local push service with a self-signed certificate). */
  constructor(
    private readonly vapid: VapidConfig,
    private readonly agent?: Agent,
  ) {}

  async send(sub: PushSubscriptionRow, payload: string): Promise<'ok' | 'gone'> {
    try {
      await sendNotification(
        { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
        payload,
        {
          TTL: ttlSeconds,
          urgency: 'high',
          ...(this.agent ? { agent: this.agent } : {}),
          vapidDetails: {
            subject: this.vapid.subject,
            publicKey: this.vapid.publicKey,
            privateKey: this.vapid.privateKey,
          },
        },
      );
      return 'ok';
    } catch (error) {
      const status = (error as { statusCode?: unknown }).statusCode;
      if (status === 404 || status === 410) return 'gone';
      throw new WebPushError(typeof status === 'number' ? status : undefined);
    }
  }
}
