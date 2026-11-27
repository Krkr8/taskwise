import { Hono } from 'hono';

import {
  readJson,
  stringField,
  type AppDeps,
  type AppEnv,
  type PushDeps,
} from '../context.js';
import { DeviceStore } from '../devices.js';
import { ApiError, badRequest } from '../errors.js';
import { log } from '../log.js';
import { queueDueItems } from '../push/schedule.js';
import {
  deleteSubscription,
  putSubscription,
  replacePlan,
  type PushPlanItem,
} from '../push/store.js';
import { maxIdLength } from '../sync/records.js';

/** Items per web device (60 days of reminders, capped). */
export const maxPushPlanItems = 500;
const maxEndpointLength = 2048;
const maxTextLength = 1000;

/**
 * GET /push/key, PUT and DELETE /push/subscription, PUT /push/plan/:deviceId.
 * Without push set up (no VAPID keys) every one answers
 * 404 `push_not_configured`.
 */
export function pushRoutes(deps: AppDeps) {
  const push = (): PushDeps => {
    if (!deps.push) {
      throw new ApiError(
        404,
        'push_not_configured',
        'This server is not set up for reminders (Web Push) yet.',
      );
    }
    return deps.push;
  };

  return new Hono<AppEnv>()
    .get('/push/key', (c) => c.json({ publicKey: push().publicKey }))
    .put('/push/subscription', async (c) => {
      push();
      const body = await readJson(c);
      const endpoint = endpointField(body);
      const keys = (body as Record<string, unknown>)['keys'];
      const p256dh = stringField(keys, 'p256dh', { max: 256 });
      const auth = stringField(keys, 'auth', { max: 256 });
      const me = c.get('device');
      await putSubscription(c.get('db'), me.id, { endpoint, p256dh, auth }, deps.now());
      log('info', 'push_subscribed', { device: me.id });
      return c.body(null, 204);
    })
    .delete('/push/subscription', async (c) => {
      push();
      const endpoint = endpointField(await readJson(c));
      const me = c.get('device');
      await deleteSubscription(c.get('db'), me.id, endpoint);
      log('info', 'push_unsubscribed', { device: me.id });
      return c.body(null, 204);
    })
    .put('/push/plan/:deviceId', async (c) => {
      const { scheduler } = push();
      const items = parsePlan(await readJson(c));
      const deviceId = c.req.param('deviceId');
      const db = c.get('db');
      const target = await new DeviceStore(db, deps.now).find(deviceId);
      if (!target || target.type !== 'web' || target.revokedAt !== null) {
        throw new ApiError(404, 'not_found', 'No such web device.');
      }
      await replacePlan(db, deviceId, items);
      const queued = await queueDueItems(db, scheduler, deps.now(), deviceId);
      log('info', 'push_plan', {
        device: deviceId,
        by: c.get('device').id,
        items: items.length,
        queued,
      });
      return c.body(null, 204);
    });
}

function endpointField(body: unknown): string {
  const endpoint = stringField(body, 'endpoint', { max: maxEndpointLength });
  let url: URL | undefined;
  try {
    url = new URL(endpoint);
  } catch {
    url = undefined;
  }
  if (url?.protocol !== 'https:') {
    throw badRequest('"endpoint" must be an https URL.');
  }
  return endpoint;
}

function parsePlan(body: unknown): PushPlanItem[] {
  const items =
    typeof body === 'object' && body !== null
      ? (body as Record<string, unknown>)['items']
      : undefined;
  if (!Array.isArray(items)) throw badRequest('"items" must be a list.');
  if (items.length > maxPushPlanItems) {
    throw badRequest(`At most ${maxPushPlanItems} items per plan.`);
  }
  const keys = new Set<string>();
  return items.map((value: unknown, i) => {
    const where = (message: string) => badRequest(`items[${i}]: ${message}`);
    const field = (name: string, max: number, min = 1) => {
      try {
        return stringField(value, name, { min, max, trim: false });
      } catch (error) {
        throw error instanceof ApiError ? where(error.message) : error;
      }
    };
    const key = field('key', 200);
    const taskId = field('taskId', maxIdLength);
    const title = field('title', maxTextLength, 0);
    const text = field('body', maxTextLength, 0);
    const fireAt = (value as Record<string, unknown>)['fireAt'];
    if (typeof fireAt !== 'number' || !Number.isSafeInteger(fireAt) || fireAt <= 0) {
      throw where('"fireAt" must be a time in UTC milliseconds.');
    }
    if (keys.has(key)) throw where(`the key "${key}" appears twice.`);
    keys.add(key);
    return { key, fireAt, taskId, title, body: text };
  });
}
