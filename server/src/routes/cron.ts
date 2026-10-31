import { Hono } from 'hono';

import { bearerToken, secretsEqual } from '../auth/tokens.js';
import type { AppDeps, AppEnv } from '../context.js';
import { ApiError } from '../errors.js';
import { log } from '../log.js';
import { backup } from '../sync/backup.js';
import { purge } from '../sync/purge.js';

/**
 * GET /cron/daily: run by Vercel Cron once a day (see vercel.json), which
 * sends `Authorization: Bearer $CRON_SECRET`. Safe to run more than once.
 */
export function cronRoutes(deps: AppDeps) {
  return new Hono<AppEnv>().get('/cron/daily', async (c) => {
    if (!deps.cronSecret) {
      throw new ApiError(
        503,
        'not_configured',
        'CRON_SECRET is not set on the server.',
      );
    }
    const token = bearerToken(c.req.header('authorization'));
    if (!token || !secretsEqual(token, deps.cronSecret)) {
      throw new ApiError(401, 'unauthorized', 'Wrong cron secret.');
    }
    const db = c.get('db');
    const now = deps.now();
    const purged = await purge(db, now);
    const saved = await backup(db, now);
    const result = {
      purgedRecords: purged.records,
      purgedLoginAttempts: purged.loginAttempts,
      backupRecords: saved.records,
    };
    log('info', 'cron_daily', result);
    return c.json(result);
  });
}
