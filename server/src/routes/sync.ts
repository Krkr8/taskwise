import { Hono } from 'hono';

import { readJson, type AppEnv } from '../context.js';
import { ApiError, badRequest } from '../errors.js';
import { log } from '../log.js';
import { parsePush } from '../sync/records.js';
import {
  defaultPullLimit,
  maxPullLimit,
  pull,
  purgedSeq,
  push,
} from '../sync/store.js';

/** GET /sync (pull) and POST /sync (push). */
export function syncRoutes() {
  return new Hono<AppEnv>()
    .get('/sync', async (c) => {
      const since = intParam(c.req.query('since'), 'since', 0, 0);
      const limit = intParam(
        c.req.query('limit'),
        'limit',
        defaultPullLimit,
        1,
        maxPullLimit,
      );
      const db = c.get('db');
      if (since > 0 && since < (await purgedSeq(db))) {
        throw new ApiError(
          410,
          'resync_required',
          'Deleted records this device has not seen were purged. Sync again from since=0.',
        );
      }
      return c.json(await pull(db, since, limit));
    })
    .post('/sync', async (c) => {
      const changes = parsePush(await readJson(c));
      const device = c.get('device');
      const result = await push(c.get('db'), device.id, changes);
      const applied = result.results.filter((r) => r.status === 'applied');
      log('info', 'push', {
        device: device.id,
        changes: changes.length,
        applied: applied.length,
        seq: result.seq,
      });
      return c.json(result);
    });
}

function intParam(
  raw: string | undefined,
  name: string,
  fallback: number,
  min: number,
  max = Number.MAX_SAFE_INTEGER,
): number {
  if (raw === undefined || raw === '') return fallback;
  if (!/^\d+$/.test(raw)) throw badRequest(`"${name}" must be a whole number.`);
  const value = Number(raw);
  if (value < min || value > max) {
    throw badRequest(`"${name}" must be between ${min} and ${max}.`);
  }
  return value;
}
