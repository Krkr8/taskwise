/**
 * Vercel entry. Vercel serves the default export of the first Hono file it
 * finds among app.ts, index.ts, server.ts, src/app.ts, src/index.ts... so
 * don't add a file with one of those names before this one. Configure it with the environment
 * variables listed in .env.example.
 */
import { createApp } from './api.js';
import { configFromEnv } from './config.js';
import { Database } from './db/client.js';

const config = configFromEnv();
const database = Database.fromUrl(config.databaseUrl, config.databaseAuthToken);

export default createApp({
  db: () => database.client(),
  setupSecret: config.setupSecret,
  cronSecret: config.cronSecret,
  now: Date.now,
});
