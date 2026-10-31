import type { Client } from '@libsql/client';
import { Hono } from 'hono';

import { readJson, stringField, type AppDeps, type AppEnv } from '../context.js';
import { DeviceStore, deviceToJson } from '../devices.js';
import { ApiError } from '../errors.js';
import { log } from '../log.js';

const notFound = () => new ApiError(404, 'not_found', 'No such device.');

/** GET /devices, PATCH /devices/:id, DELETE /devices/:id. */
export function deviceRoutes(deps: AppDeps) {
  const store = (db: Client) => new DeviceStore(db, deps.now);
  return new Hono<AppEnv>()
    .get('/devices', async (c) => {
      const devices = await store(c.get('db')).list();
      return c.json({ devices: devices.map(deviceToJson) });
    })
    .patch('/devices/:id', async (c) => {
      const name = stringField(await readJson(c), 'name', { max: 100 });
      const device = await store(c.get('db')).rename(c.req.param('id'), name);
      if (!device) throw notFound();
      return c.json(deviceToJson(device));
    })
    .delete('/devices/:id', async (c) => {
      const id = c.req.param('id');
      const devices = store(c.get('db'));
      if (!(await devices.revoke(id))) throw notFound();
      log('info', 'device_revoked', { device: id, by: c.get('device').id });
      return c.json(deviceToJson((await devices.find(id))!));
    });
}
