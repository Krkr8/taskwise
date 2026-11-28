import { createClient } from '@libsql/client';
import { describe, expect, it } from 'vitest';

import { migrate } from '../src/db/migrations.js';
import { vercelPath } from '../src/vercel_path.js';
import { vercelApp } from '../src/wiring.js';

describe('vercelPath', () => {
  it('drops one leading /_hono', () => {
    expect(vercelPath('/_hono/api/v1/health')).toBe('/api/v1/health');
    expect(vercelPath('/api/v1/health')).toBe('/api/v1/health');
    expect(vercelPath('/_honox/a')).toBe('/_honox/a');
    expect(vercelPath('/_hono/_hono/a')).toBe('/_hono/a');
  });
});

describe('vercelApp', () => {
  async function app() {
    const db = createClient({ url: ':memory:' });
    await migrate(db);
    return vercelApp({
      db: async () => db,
      setupSecret: 'test-setup-secret-0123456789',
      cronSecret: 'test-cron-secret-0123456789',
      now: () => 0,
    });
  }

  it('serves health with and without the prefix', async () => {
    const a = await app();
    for (const path of ['/_hono/api/v1/health', '/api/v1/health']) {
      const response = await a.request(path);
      expect(response.status).toBe(200);
      expect(await response.json()).toMatchObject({ status: 'ok' });
    }
  });

  it('answers unknown paths with the JSON 404', async () => {
    const response = await (await app()).request('/_hono/nope');
    expect(response.status).toBe(404);
    expect(await response.json()).toEqual({
      error: { code: 'not_found', message: 'No such endpoint.' },
    });
  });
});
