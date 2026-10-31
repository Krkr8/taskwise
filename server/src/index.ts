/**
 * Vercel entry. Vercel detects a Hono app in src/index.ts and serves its
 * default export as a function. Configure it with the environment
 * variables listed in .env.example.
 */
import { createApp } from './app.js';
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
