import { describe, expect, it } from 'vitest';

import { createApp } from '../src/app.js';
import { Database } from '../src/db/client.js';
import { password, setupSecret, testApp } from './helpers.js';

describe('setup', () => {
  it('is disabled without SETUP_SECRET', async () => {
    const { db } = await testApp();
    const app = createApp({
      db: async () => db,
      setupSecret: undefined,
      cronSecret: undefined,
      now: Date.now,
    });
    const response = await app.request('/api/v1/auth/setup', {
      method: 'POST',
      body: JSON.stringify({ setupSecret: '', username: 'owner', password }),
    });
    expect(response.status).toBe(503);
    expect(await response.json()).toMatchObject({
      error: { code: 'setup_disabled' },
    });
  });

  it('refuses a short password', async () => {
    const { request } = await testApp();
    const response = await request('POST', '/auth/setup', {
      body: { setupSecret, username: 'owner', password: 'short' },
    });
    expect(response.status).toBe(400);
  });

  it('refuses bad JSON', async () => {
    const { request } = await testApp();
    const response = await request('POST', '/auth/setup', { body: '{nope' });
    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('bad_request');
  });

  it('stores an argon2id hash, not the password', async () => {
    const { setup, db } = await testApp();
    await setup();
    const row = (await db.execute('SELECT password_hash FROM account')).rows[0];
    expect(String(row?.['password_hash'])).toMatch(/^\$argon2id\$/);
  });
});

describe('login', () => {
  const loginBody = (pw: string, user = 'owner') => ({
    username: user,
    password: pw,
    device: { id: 'device-1', name: 'Laptop', type: 'linux' },
  });

  it('fails before setup', async () => {
    const { request } = await testApp();
    const response = await request('POST', '/auth/login', {
      body: loginBody(password),
    });
    expect(response.status).toBe(401);
  });

  it('refuses an unknown device type', async () => {
    const { request, setup } = await testApp();
    await setup();
    const response = await request('POST', '/auth/login', {
      body: { ...loginBody(password), device: { id: 'd', name: 'x', type: 'mac' } },
    });
    expect(response.status).toBe(400);
  });

  it('is rate limited after 5 failures per username, until the window ends', async () => {
    const { request, setup, clock } = await testApp();
    await setup();
    for (let i = 0; i < 5; i++) {
      const response = await request('POST', '/auth/login', {
        body: loginBody('wrong'),
        headers: { 'x-forwarded-for': `10.0.0.${i}` },
      });
      expect(response.status).toBe(401);
    }
    // Even the right password is refused now, from any address.
    const limited = await request('POST', '/auth/login', {
      body: loginBody(password),
      headers: { 'x-forwarded-for': '10.0.0.99' },
    });
    expect(limited.status).toBe(429);
    expect(limited.body.error.code).toBe('rate_limited');
    expect(Number(limited.headers.get('retry-after'))).toBe(15 * 60);

    clock.now += 15 * 60 * 1000;
    const later = await request('POST', '/auth/login', {
      body: loginBody(password),
      headers: { 'x-forwarded-for': '10.0.0.99' },
    });
    expect(later.status).toBe(200);
  });

  it('is rate limited per IP across usernames', async () => {
    const { request, setup } = await testApp();
    await setup();
    for (let i = 0; i < 5; i++) {
      await request('POST', '/auth/login', {
        body: loginBody('wrong', `user${i}`),
        headers: { 'x-forwarded-for': '203.0.113.7, 10.0.0.1' },
      });
    }
    const response = await request('POST', '/auth/login', {
      body: loginBody(password),
      headers: { 'x-forwarded-for': '203.0.113.7' },
    });
    expect(response.status).toBe(429);
  });

  it('a success resets the failure count', async () => {
    const { request, setup } = await testApp();
    await setup();
    for (let i = 0; i < 4; i++) {
      await request('POST', '/auth/login', { body: loginBody('wrong') });
    }
    expect(
      (await request('POST', '/auth/login', { body: loginBody(password) }))
        .status,
    ).toBe(200);
    for (let i = 0; i < 4; i++) {
      await request('POST', '/auth/login', { body: loginBody('wrong') });
    }
    expect(
      (await request('POST', '/auth/login', { body: loginBody(password) }))
        .status,
    ).toBe(200);
  });

  it('logging in again replaces the device token', async () => {
    const { login, request, setup } = await testApp();
    await setup();
    const first = await login('device-1');
    const second = await login('device-1');
    expect(second).not.toBe(first);
    expect((await request('GET', '/devices', { token: first })).status).toBe(
      401,
    );
    expect((await request('GET', '/devices', { token: second })).status).toBe(
      200,
    );
  });

  it('a revoked device can log in again', async () => {
    const { login, request, setup } = await testApp();
    await setup();
    const token = await login('device-1');
    await request('DELETE', '/devices/device-1', { token });
    expect((await request('GET', '/devices', { token })).status).toBe(401);
    const again = await login('device-1');
    const devices = await request('GET', '/devices', { token: again });
    expect(devices.body.devices[0].deleted).toBe(false);
  });

  it('only stores a hash of the token', async () => {
    const { login, setup, db } = await testApp();
    await setup();
    const token = await login();
    const rows = (await db.execute('SELECT token_hash FROM devices')).rows;
    expect(String(rows[0]?.['token_hash'])).toMatch(/^[0-9a-f]{64}$/);
    expect(String(rows[0]?.['token_hash'])).not.toContain(token);
  });
});

describe('devices', () => {
  it('updates last seen at most once a minute', async () => {
    const { login, request, setup, clock } = await testApp();
    await setup();
    const token = await login();
    const start = clock.now;
    clock.now += 30 * 1000;
    let devices = await request('GET', '/devices', { token });
    expect(devices.body.devices[0].lastSeenAt).toBe(new Date(start).toISOString());
    clock.now += 60 * 1000;
    await request('GET', '/devices', { token });
    devices = await request('GET', '/devices', { token });
    expect(devices.body.devices[0].lastSeenAt).toBe(
      new Date(clock.now).toISOString(),
    );
  });

  it('refuses an empty name', async () => {
    const { login, request, setup } = await testApp();
    await setup();
    const token = await login();
    const response = await request('PATCH', '/devices/device-1', {
      token,
      body: { name: '   ' },
    });
    expect(response.status).toBe(400);
  });
});

describe('health', () => {
  it('reports 503 when the database is not configured', async () => {
    const database = Database.fromUrl(undefined);
    const app = createApp({
      db: () => database.client(),
      setupSecret: undefined,
      cronSecret: undefined,
      now: Date.now,
    });
    const response = await app.request('/api/v1/health');
    expect(response.status).toBe(503);
    const other = await app.request('/api/v1/devices');
    expect(other.status).toBe(500);
    expect(await other.json()).toMatchObject({
      error: { code: 'not_configured' },
    });
  });
});

describe('routing', () => {
  it('answers unknown paths outside the API with 404 JSON', async () => {
    const { app } = await testApp();
    const response = await app.request('/nope');
    expect(response.status).toBe(404);
    expect(await response.json()).toMatchObject({ error: { code: 'not_found' } });
  });
});
