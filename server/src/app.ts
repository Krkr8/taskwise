import { Hono } from 'hono';
import { bodyLimit } from 'hono/body-limit';
import { createMiddleware } from 'hono/factory';

import { requireDevice } from './auth/middleware.js';
import type { AppDeps, AppEnv } from './context.js';
import { ApiError } from './errors.js';
import { log } from './log.js';
import { authRoutes } from './routes/auth.js';
import { cronRoutes } from './routes/cron.js';
import { deviceRoutes } from './routes/devices.js';
import { healthRoutes } from './routes/health.js';
import { syncRoutes } from './routes/sync.js';
import { apiBasePath } from './version.js';

export type { AppDeps } from './context.js';

/** Largest request body accepted (a full push of 500 changes fits easily). */
export const maxBodyBytes = 1024 * 1024;

/**
 * The Taskwise sync server. It reads no environment variables itself, so
 * the Vercel entry (index.ts), the Node entry (node.ts) and tests can each
 * pass their own [AppDeps]. API reference: docs/sync-api.md.
 */
export function createApp(deps: AppDeps): Hono<AppEnv> {
  const withDb = createMiddleware<AppEnv>(async (c, next) => {
    c.set('db', await deps.db());
    await next();
  });

  const api = new Hono<AppEnv>()
    .use(
      bodyLimit({
        maxSize: maxBodyBytes,
        onError: () => {
          throw new ApiError(
            413,
            'payload_too_large',
            `Request body is larger than ${maxBodyBytes} bytes.`,
          );
        },
      }),
    )
    .route('/', healthRoutes(deps))
    .use(withDb)
    .route('/', authRoutes(deps))
    .route('/', cronRoutes(deps))
    .use(requireDevice(deps))
    .route('/', deviceRoutes(deps))
    .route('/', syncRoutes());

  return new Hono<AppEnv>()
    .route(apiBasePath, api)
    .notFound((c) =>
      c.json({ error: { code: 'not_found', message: 'No such endpoint.' } }, 404),
    )
    .onError((error, c) => {
      if (error instanceof ApiError) {
        return c.json(
          { error: { code: error.code, message: error.message } },
          error.status,
          error.headers,
        );
      }
      log('error', 'unhandled', {
        method: c.req.method,
        path: c.req.path,
        message: error.message,
      });
      return c.json(
        { error: { code: 'internal', message: 'Internal server error.' } },
        500,
      );
    });
}
