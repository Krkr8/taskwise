import { createClient, type Client } from '@libsql/client';

import { createApp } from '../src/api.js';
import { migrate } from '../src/db/migrations.js';

export const setupSecret = 'test-setup-secret-0123456789';
export const cronSecret = 'test-cron-secret-0123456789';
export const password = 'a long password';

/** A fresh app on an in-memory database with a controllable clock. */
export async function testApp(start = Date.parse('2026-10-31T12:00:00.000Z')) {
  const db: Client = createClient({ url: ':memory:' });
  await migrate(db);
  const clock = { now: start };
  const app = createApp({
    db: async () => db,
    setupSecret,
    cronSecret,
    now: () => clock.now,
  });

  const request = async (
    method: string,
    path: string,
    { body, token, headers = {} }: {
      body?: unknown;
      token?: string;
      headers?: Record<string, string>;
    } = {},
  ) => {
    const response = await app.request(`/api/v1${path}`, {
      method,
      headers: {
        ...(body === undefined ? {} : { 'content-type': 'application/json' }),
        ...(token ? { authorization: `Bearer ${token}` } : {}),
        ...headers,
      },
      ...(body === undefined
        ? {}
        : { body: typeof body === 'string' ? body : JSON.stringify(body) }),
    });
    const text = await response.text();
    return {
      status: response.status,
      headers: response.headers,
      body: text ? (JSON.parse(text) as any) : undefined,
    };
  };

  const setup = () =>
    request('POST', '/auth/setup', {
      body: { setupSecret, username: 'owner', password },
    });

  const login = async (deviceId = 'device-1', type = 'linux') => {
    const response = await request('POST', '/auth/login', {
      body: {
        username: 'owner',
        password,
        device: { id: deviceId, name: `Device ${deviceId}`, type },
      },
    });
    return response.body.token as string;
  };

  return { app, db, clock, request, setup, login };
}

/** A minimal valid record. */
export function record(id: string, updatedAt: string, extra: object = {}) {
  return { id, updatedAt, deleted: false, ...extra };
}
