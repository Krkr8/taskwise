/**
 * Vercel Queues consumer for topic `taskwise-push` (wired in vercel.json).
 * Each message says which push item is due; `deliverPushItem` re-checks it.
 */
import { handleCallback } from '@vercel/queue';

import { configFromEnv } from '../src/config.js';
import { Database } from '../src/db/client.js';
import { pushDeliveryHandler } from '../src/push/consumer.js';
import { WebPushSender } from '../src/push/web_push_sender.js';

const config = configFromEnv();
const database = Database.fromUrl(config.databaseUrl, config.databaseAuthToken);

export const POST = handleCallback(
  pushDeliveryHandler({
    db: () => database.client(),
    sender: config.vapid ? new WebPushSender(config.vapid) : undefined,
    now: Date.now,
  }),
);
