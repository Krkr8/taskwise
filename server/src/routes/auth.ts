import { Hono } from 'hono';

import {
  hashPassword,
  minPasswordLength,
  verifyDummy,
  verifyPassword,
} from '../auth/password.js';
import { LoginRateLimit } from '../auth/rateLimit.js';
import { hashToken, newToken, secretsEqual } from '../auth/tokens.js';
import {
  clientIp,
  readJson,
  stringField,
  type AppDeps,
  type AppEnv,
} from '../context.js';
import {
  DeviceStore,
  deviceToJson,
  deviceTypes,
  type DeviceType,
} from '../devices.js';
import { ApiError, badRequest } from '../errors.js';
import { log } from '../log.js';
import { maxIdLength } from '../sync/records.js';

const passwordField = { min: minPasswordLength, max: 1024, trim: false };

/** POST /auth/setup and POST /auth/login. */
export function authRoutes(deps: AppDeps) {
  return new Hono<AppEnv>()
    .post('/auth/setup', async (c) => {
      if (!deps.setupSecret) {
        throw new ApiError(
          503,
          'setup_disabled',
          'Account setup is disabled: SETUP_SECRET is not set on the server.',
        );
      }
      const body = await readJson(c);
      const secret = stringField(body, 'setupSecret', { max: 1024 });
      const username = stringField(body, 'username', { max: 100 });
      const password = stringField(body, 'password', passwordField);
      if (!secretsEqual(secret, deps.setupSecret)) {
        log('warn', 'setup_wrong_secret', { ip: clientIp(c) });
        throw new ApiError(403, 'forbidden', 'Wrong setup secret.');
      }
      const db = c.get('db');
      // `id = 1` is the only allowed account id, so a second setup fails
      // even if two requests race.
      const result = await db.execute({
        sql: `INSERT INTO account (id, username, password_hash, created_at)
              VALUES (1, ?, ?, ?) ON CONFLICT (id) DO NOTHING`,
        args: [username, await hashPassword(password), deps.now()],
      });
      if (result.rowsAffected === 0) {
        throw new ApiError(409, 'conflict', 'The account already exists.');
      }
      log('info', 'account_created');
      return c.json({ username }, 201);
    })
    .post('/auth/login', async (c) => {
      const body = await readJson(c);
      const username = stringField(body, 'username', { max: 100 });
      const password = stringField(body, 'password', {
        ...passwordField,
        min: 1,
      });
      const device = parseDevice((body as Record<string, unknown>)['device']);

      const db = c.get('db');
      const limit = new LoginRateLimit(db, deps.now);
      const keys = [`ip:${clientIp(c)}`, `user:${username.toLowerCase()}`];
      const waitMs = await limit.retryAfterMs(keys);
      if (waitMs > 0) {
        const seconds = Math.ceil(waitMs / 1000);
        throw new ApiError(
          429,
          'rate_limited',
          `Too many failed logins. Try again in ${Math.ceil(seconds / 60)} min.`,
          { 'Retry-After': String(seconds) },
        );
      }

      const account = (
        await db.execute('SELECT username, password_hash FROM account')
      ).rows[0];
      let ok = false;
      if (account) {
        ok =
          (await verifyPassword(String(account['password_hash']), password)) &&
          String(account['username']) === username;
      } else {
        await verifyDummy(password);
      }
      if (!ok) {
        await limit.recordFailure(keys);
        log('warn', 'login_failed', { ip: clientIp(c) });
        throw new ApiError(401, 'unauthorized', 'Wrong username or password.');
      }
      await limit.reset(keys);

      const token = newToken();
      const row = await new DeviceStore(db, deps.now).register(
        device,
        hashToken(token),
      );
      log('info', 'login', { device: row.id, type: row.type });
      return c.json({ token, device: deviceToJson(row) });
    });
}

function parseDevice(value: unknown): {
  id: string;
  name: string;
  type: DeviceType;
} {
  const id = stringField(value, 'id', { max: maxIdLength });
  const name = stringField(value, 'name', { max: 100 });
  const type = stringField(value, 'type', { max: 20 });
  if (!(deviceTypes as readonly string[]).includes(type)) {
    throw badRequest(`"type" must be one of: ${deviceTypes.join(', ')}.`);
  }
  return { id, name, type: type as DeviceType };
}
