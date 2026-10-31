import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { describe, expect, it } from 'vitest';

import { setupSecret, testApp } from './helpers.js';

// The shared contract with the Dart app: shared/test/fixtures/sync/.
const fixtures = new URL('../../shared/test/fixtures/sync/', import.meta.url);
const flow = JSON.parse(
  readFileSync(fileURLToPath(new URL('flow.json', fixtures)), 'utf8'),
) as {
  now: string;
  steps: {
    name: string;
    request: { method: string; path: string; auth?: string; body?: unknown };
    response: { status: number; body: unknown };
    saveTokenAs?: string;
  }[];
};

/** Replaces placeholders in an expected response with matchers. */
function expected(value: unknown): unknown {
  if (value === '$token') return expect.stringMatching(/^tw_[\w-]{43}$/);
  if (value === '$string') return expect.any(String);
  if (Array.isArray(value)) return value.map(expected);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, expected(item)]),
    );
  }
  return value;
}

function withSecret(value: unknown): unknown {
  return JSON.parse(
    JSON.stringify(value ?? null).replaceAll('$setupSecret', setupSecret),
  );
}

describe('sync API contract (flow.json)', async () => {
  const { app } = await testApp(Date.parse(flow.now));
  const tokens = new Map<string, string>();

  // Steps build on each other, so they run in order in one test each.
  for (const step of flow.steps) {
    it(step.name, async () => {
      const { method, path, auth, body } = step.request;
      const token = auth ? tokens.get(auth) : undefined;
      const response = await app.request(path, {
        method,
        headers: {
          'content-type': 'application/json',
          ...(token ? { authorization: `Bearer ${token}` } : {}),
        },
        ...(body === undefined ? {} : { body: JSON.stringify(withSecret(body)) }),
      });
      const json = (await response.json()) as Record<string, unknown>;
      expect({ status: response.status, body: json }).toEqual({
        status: step.response.status,
        body: expected(step.response.body),
      });
      if (step.saveTokenAs) tokens.set(step.saveTokenAs, json['token'] as string);
    });
  }
});
