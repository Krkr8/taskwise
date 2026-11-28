/**
 * Vercel entry. Vercel serves the default export of the first file among
 * app.ts, index.ts, server.ts, src/app.ts, src/index.ts... that imports
 * `hono` itself, so this file must import it, and no file with one of
 * those names may come before it. Configure it with the environment
 * variables listed in .env.example.
 *
 * Routing: server/api/push-delivery.ts (the queue consumer) makes Vercel send
 * every /api/* request to the functions in api/, so vercel.json rewrites
 * /api/v1/* to /_hono/api/v1/* (outside /api/), which reaches this app. The
 * function sees the rewritten path, so [vercelApp] drops the /_hono prefix
 * again.
 */
// A value import on purpose: Vercel looks for it (see above).
import { Hono } from 'hono';

import { configFromEnv } from './config.js';
import type { AppEnv } from './context.js';
import { Database } from './db/client.js';
import { QueuePushScheduler } from './push/vercel_queue.js';
import { appFromConfig, vercelApp } from './wiring.js';

const config = configFromEnv();
const database = Database.fromUrl(config.databaseUrl, config.databaseAuthToken);

const app: Hono<AppEnv> = vercelApp(
  appFromConfig(config, database, new QueuePushScheduler()),
);

export default app;
