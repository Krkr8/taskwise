import { Hono } from 'hono';

import { apiVersion } from '../version.js';
import type { AppDeps, AppEnv } from '../context.js';
import { log } from '../log.js';

/** GET /health: no auth; also checks the database answers. */
export function healthRoutes(deps: AppDeps) {
  return new Hono<AppEnv>().get('/health', async (c) => {
    const time = new Date(deps.now()).toISOString();
    try {
      const db = await deps.db();
      await db.execute('SELECT 1');
      return c.json({ status: 'ok', apiVersion, time });
    } catch (error) {
      log('error', 'health_db_failed', { message: String(error) });
      return c.json({ status: 'error', apiVersion, time }, 503);
    }
  });
}
