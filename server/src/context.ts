import type { Client } from '@libsql/client';
import type { Context } from 'hono';

import type { DeviceRow } from './devices.js';
import { badRequest } from './errors.js';

/** Everything [createApp] needs; tests pass their own. */
export interface AppDeps {
  /** Returns the migrated database client. */
  readonly db: () => Promise<Client>;
  readonly setupSecret: string | undefined;
  readonly cronSecret: string | undefined;
  /** Current time in UTC milliseconds (tests use a fake clock). */
  readonly now: () => number;
}

export interface AppEnv {
  Variables: {
    db: Client;
    /** The authenticated device (routes behind requireDevice). */
    device: DeviceRow;
  };
}

/** Parses the JSON request body, turning bad JSON into a 400. */
export async function readJson(c: Context<AppEnv>): Promise<unknown> {
  try {
    return await c.req.json<unknown>();
  } catch {
    throw badRequest('Request body must be valid JSON.');
  }
}

/** Reads a required string field, trimmed, within the given length. */
export function stringField(
  body: unknown,
  name: string,
  { min = 1, max = 200, trim = true } = {},
): string {
  const value =
    typeof body === 'object' && body !== null
      ? (body as Record<string, unknown>)[name]
      : undefined;
  const text = typeof value === 'string' && trim ? value.trim() : value;
  if (typeof text !== 'string' || text.length < min || text.length > max) {
    throw badRequest(`"${name}" must be a string of ${min}–${max} characters.`);
  }
  return text;
}

/**
 * The client address. Vercel (and most proxies) put the real client first
 * in X-Forwarded-For. A self-hosted server without a proxy in front can't
 * trust this header; the per-username login limit still applies there.
 */
export function clientIp(c: Context<AppEnv>): string {
  const forwarded = c.req.header('x-forwarded-for')?.split(',')[0]?.trim();
  return forwarded || c.req.header('x-real-ip') || 'unknown';
}
