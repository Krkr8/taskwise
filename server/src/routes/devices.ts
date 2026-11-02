import type { Client } from '@libsql/client';
import { Hono } from 'hono';

import { verifyDummy, verifyPassword } from '../auth/password.js';
import { LoginRateLimit } from '../auth/rateLimit.js';
import {
  clientIp,
  readJson,
  stringField,
  type AppDeps,
  type AppEnv,
} from '../context.js';
import { DeviceStore, deviceToJson } from '../devices.js';
import { ApiError, badRequest } from '../errors.js';
import { log } from '../log.js';

const notFound = () => new ApiError(404, 'not_found', 'No such device.');
const mainOnly = (what: string) =>
  new ApiError(403, 'forbidden', `Only the main device can ${what}.`);

/**
 * GET /devices, PATCH /devices/:id, DELETE /devices/:id and
 * POST /devices/claim-main.
 *
 * The main device (the first to sign in) manages the others: only it can
 * remove or rename other devices and hand the role on. Any device can
 * rename itself and sign itself out, and can become the main device by
 * entering the account password again (for when the main one is lost).
 */
export function deviceRoutes(deps: AppDeps) {
  const store = (db: Client) => new DeviceStore(db, deps.now);
  return new Hono<AppEnv>()
    .get('/devices', async (c) => {
      const devices = await store(c.get('db')).list();
      return c.json({ devices: devices.map(deviceToJson) });
    })
    .patch('/devices/:id', async (c) => {
      const body = (await readJson(c)) as Record<string, unknown> | null;
      const id = c.req.param('id');
      const me = c.get('device');
      const devices = store(c.get('db'));
      if (!(await devices.find(id))) throw notFound();

      const makeMain = body?.['main'];
      if (makeMain !== undefined && makeMain !== true) {
        throw badRequest('"main" can only be set to true.');
      }
      const hasName = body?.['name'] !== undefined;
      if (!hasName && makeMain === undefined) {
        throw badRequest('Send "name" and/or "main": true.');
      }
      if (hasName && id !== me.id && !me.isMain) {
        throw mainOnly('rename other devices');
      }
      if (makeMain && !me.isMain) throw mainOnly('choose the main device');

      let device = hasName
        ? await devices.rename(id, stringField(body, 'name', { max: 100 }))
        : await devices.find(id);
      if (makeMain) {
        device = await devices.makeMain(id);
        if (!device) throw new ApiError(409, 'conflict', 'That device was removed.');
        log('info', 'main_device_changed', { device: id, by: me.id });
      }
      return c.json(deviceToJson(device!));
    })
    .delete('/devices/:id', async (c) => {
      const id = c.req.param('id');
      const me = c.get('device');
      if (id !== me.id && !me.isMain) throw mainOnly('remove other devices');
      const devices = store(c.get('db'));
      if (!(await devices.revoke(id))) throw notFound();
      log('info', 'device_revoked', { device: id, by: me.id });
      return c.json(deviceToJson((await devices.find(id))!));
    })
    .post('/devices/claim-main', async (c) => {
      const password = stringField(await readJson(c), 'password', {
        max: 1024,
        trim: false,
      });
      const db = c.get('db');
      const account = (
        await db.execute('SELECT username, password_hash FROM account')
      ).rows[0];
      const limit = new LoginRateLimit(db, deps.now);
      const keys = [
        `ip:${clientIp(c)}`,
        `user:${String(account?.['username'] ?? '').toLowerCase()}`,
      ];
      const waitMs = await limit.retryAfterMs(keys);
      if (waitMs > 0) {
        const seconds = Math.ceil(waitMs / 1000);
        throw new ApiError(
          429,
          'rate_limited',
          `Too many failed tries. Try again in ${Math.ceil(seconds / 60)} min.`,
          { 'Retry-After': String(seconds) },
        );
      }
      const ok = account
        ? await verifyPassword(String(account['password_hash']), password)
        : (await verifyDummy(password), false);
      if (!ok) {
        await limit.recordFailure(keys);
        throw new ApiError(403, 'wrong_password', 'Wrong password.');
      }
      await limit.reset(keys);
      const me = c.get('device');
      const device = await store(db).makeMain(me.id);
      log('info', 'main_device_claimed', { device: me.id });
      return c.json(deviceToJson(device!));
    });
}
