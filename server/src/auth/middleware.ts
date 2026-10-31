import { createMiddleware } from 'hono/factory';

import type { AppDeps, AppEnv } from '../context.js';
import { DeviceStore } from '../devices.js';
import { ApiError } from '../errors.js';
import { bearerToken, hashToken } from './tokens.js';

/** Requires a valid, unrevoked device token; sets `device` on the context. */
export function requireDevice(deps: AppDeps) {
  return createMiddleware<AppEnv>(async (c, next) => {
    const token = bearerToken(c.req.header('authorization'));
    const devices = new DeviceStore(c.get('db'), deps.now);
    const device = token
      ? await devices.findByTokenHash(hashToken(token))
      : undefined;
    if (!device) {
      throw new ApiError(
        401,
        'unauthorized',
        'Missing, invalid or revoked device token. Log in again.',
        { 'WWW-Authenticate': 'Bearer' },
      );
    }
    await devices.touch(device);
    c.set('device', device);
    await next();
  });
}
