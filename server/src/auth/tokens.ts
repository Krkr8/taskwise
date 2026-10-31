import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';

/** A new device token: 32 random bytes, base64url, with a `tw_` prefix. */
export function newToken(): string {
  return `tw_${randomBytes(32).toString('base64url')}`;
}

/** Tokens are stored only as SHA-256 hashes. */
export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

/** Constant-time string comparison (for secrets from the environment). */
export function secretsEqual(a: string, b: string): boolean {
  const left = createHash('sha256').update(a).digest();
  const right = createHash('sha256').update(b).digest();
  return timingSafeEqual(left, right);
}

/** The token from an `Authorization: Bearer <token>` header, if any. */
export function bearerToken(header: string | undefined): string | undefined {
  const match = /^Bearer\s+(\S+)\s*$/i.exec(header ?? '');
  return match?.[1];
}
