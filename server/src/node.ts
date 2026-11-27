/**
 * Plain Node entry for self-hosting (Docker) and local development:
 * `npm run dev` (reads .env) or `npm run build && npm start`.
 */
import { serve } from '@hono/node-server';

import { createApp } from './api.js';
import { configFromEnv } from './config.js';
import { Database } from './db/client.js';
import { log } from './log.js';
import { NoopScheduler, sendDuePushes } from './push/due.js';
import { WebPushSender } from './push/web_push_sender.js';
import { appFromConfig } from './wiring.js';

const config = configFromEnv();
const database = Database.fromUrl(config.databaseUrl, config.databaseAuthToken);
const deps = appFromConfig(config, database, new NoopScheduler());
const app = createApp(deps);

const port = Number(process.env['PORT'] ?? 8787);

const server = serve({ fetch: app.fetch, port }, (info) => {
  log('info', 'listening', { port: info.port });
});

// No queue here: every 30 seconds, send the reminders that have come due.
const tickMs = 30_000;
let timer: NodeJS.Timeout | undefined;
if (deps.push) {
  const sender = new WebPushSender(config.vapid!);
  let running = false;
  timer = setInterval(() => {
    if (running) return;
    running = true;
    database
      .client()
      .then((db) => sendDuePushes(db, sender, Date.now()))
      .catch(() => log('error', 'push_tick_failed'))
      .finally(() => {
        running = false;
      });
  }, tickMs);
  log('info', 'push_timer_started', { everySeconds: tickMs / 1000 });
}

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.on(signal, () => {
    if (timer) clearInterval(timer);
    server.close();
    process.exit(0);
  });
}
