import { describe, expect, it } from 'vitest';

import { testApp } from './helpers.js';

const origin = 'https://taskwise-app.vercel.app';

describe('CORS', () => {
  it('answers the preflight for a browser', async () => {
    const t = await testApp();
    const res = await t.app.request('/api/v1/sync', {
      method: 'OPTIONS',
      headers: {
        Origin: origin,
        'Access-Control-Request-Method': 'POST',
        'Access-Control-Request-Headers': 'authorization,content-type',
      },
    });
    expect(res.status).toBe(204);
    expect(res.headers.get('access-control-allow-origin')).toBe('*');
    expect(res.headers.get('access-control-allow-headers')).toContain(
      'Authorization',
    );
    expect(res.headers.get('access-control-max-age')).toBe('86400');
    expect(res.headers.get('access-control-allow-credentials')).toBeNull();
  });

  it('adds the header to normal responses', async () => {
    const t = await testApp();
    const res = await t.app.request('/api/v1/health', {
      headers: { Origin: origin },
    });
    expect(res.headers.get('access-control-allow-origin')).toBe('*');
  });

  it('adds the header to a 401 so the browser shows our error', async () => {
    const t = await testApp();
    const res = await t.app.request('/api/v1/sync', {
      headers: { Origin: origin },
    });
    expect(res.status).toBe(401);
    expect(res.headers.get('access-control-allow-origin')).toBe('*');
  });

  it('adds the header to a 404', async () => {
    const t = await testApp();
    const res = await t.app.request('/nope', { headers: { Origin: origin } });
    expect(res.status).toBe(404);
    expect(res.headers.get('access-control-allow-origin')).toBe('*');
  });
});
