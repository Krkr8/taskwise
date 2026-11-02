/**
 * Vercel entry. Vercel serves the default export of the first file among
 * app.ts, index.ts, server.ts, src/app.ts, src/index.ts... that imports
 * `hono` itself, so this file must import it, and no file with one of
 * those names may come before it. Configure it with the environment
 * variables listed in .env.example.
 */
// A value import on purpose: Vercel looks for it (see above).
import { Hono } from 'hono';

import { createApp } from './api.js';
import { configFromEnv } from './config.js';
import type { AppEnv } from './context.js';
import { Database } from './db/client.js';

const config = configFromEnv();
const database = Database.fromUrl(config.databaseUrl, config.databaseAuthToken);

const app: Hono<AppEnv> = createApp({
  db: () => database.client(),
  setupSecret: config.setupSecret,
  cronSecret: config.cronSecret,
  now: Date.now,
});

export default app;
