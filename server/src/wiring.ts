import type { Config } from './config.js';
import type { AppDeps } from './context.js';
import type { Database } from './db/client.js';
import type { PushScheduler } from './push/schedule.js';
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
