import { Hono } from 'hono';

import { createApp } from './api.js';
import type { Config } from './config.js';
import type { AppDeps, AppEnv } from './context.js';
import type { Database } from './db/client.js';
import type { PushScheduler } from './push/schedule.js';
import { vercelPath } from './vercel_path.js';
import { WebPushSender } from './push/web_push_sender.js';

/**
 * The dependencies of the app, from the configuration. [scheduler] differs by
 * host: Vercel Queues on Vercel, a timer on plain Node. Push is on only when
 * the VAPID keys are set.
 */
export function appFromConfig(
  config: Config,
  database: Database,
  scheduler: PushScheduler,
): AppDeps {
  return {
    db: () => database.client(),
    setupSecret: config.setupSecret,
    cronSecret: config.cronSecret,
    now: Date.now,
    ...(config.vapid
      ? {
          push: {
            publicKey: config.vapid.publicKey,
            scheduler,
            sender: new WebPushSender(config.vapid),
          },
        }
      : {}),
  };
}

/**
 * The app Vercel serves: [createApp] behind a `getPath` that drops the
 * `/_hono` prefix of the rewrite in vercel.json.
 */
export function vercelApp(deps: AppDeps): Hono<AppEnv> {
  return new Hono<AppEnv>({
    getPath: (request) => vercelPath(new URL(request.url).pathname),
  })
    .route('/', createApp(deps))
    .notFound((c) =>
      c.json({ error: { code: 'not_found', message: 'No such endpoint.' } }, 404),
    );
}
