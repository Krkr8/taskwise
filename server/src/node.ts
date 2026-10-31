/**
 * Plain Node entry for self-hosting (Docker) and local development:
 * `npm run dev` (reads .env) or `npm run build && npm start`.
 */
import { serve } from '@hono/node-server';

import { log } from './log.js';
import app from './index.js';

const port = Number(process.env['PORT'] ?? 8787);

const server = serve({ fetch: app.fetch, port }, (info) => {
  log('info', 'listening', { port: info.port });
});

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.on(signal, () => {
    server.close();
    process.exit(0);
  });
}
