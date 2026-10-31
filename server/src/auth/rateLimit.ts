import type { Client } from '@libsql/client';

/** Login failures allowed per key within one window. */
export const maxLoginFailures = 5;
export const loginWindowMs = 15 * 60 * 1000;

/**
 * Login rate limiting. Counters live in the database because serverless
 * functions keep no memory between requests (SPEC.md §3.4). Keys are
 * `ip:<address>` and `user:<username>`.
 */
export class LoginRateLimit {
  constructor(
    private readonly db: Client,
    private readonly now: () => number,
  ) {}

  /** Milliseconds until a login may be tried again, or 0 if allowed now. */
  async retryAfterMs(keys: readonly string[]): Promise<number> {
    const now = this.now();
    const result = await this.db.execute({
      sql: `SELECT window_start, count FROM login_attempts
            WHERE key IN (${keys.map(() => '?').join(', ')})`,
      args: [...keys],
    });
    let wait = 0;
    for (const row of result.rows) {
      const windowEnd = Number(row['window_start']) + loginWindowMs;
      if (Number(row['count']) >= maxLoginFailures && windowEnd > now) {
        wait = Math.max(wait, windowEnd - now);
      }
    }
    return wait;
  }

  /** Counts a failed login; an expired window starts again at 1. */
  async recordFailure(keys: readonly string[]): Promise<void> {
    const now = this.now();
    await this.db.batch(
      keys.map((key) => ({
        sql: `INSERT INTO login_attempts (key, window_start, count) VALUES (?, ?, 1)
              ON CONFLICT (key) DO UPDATE SET
                count = CASE WHEN window_start <= ? THEN 1 ELSE count + 1 END,
                window_start = CASE WHEN window_start <= ? THEN excluded.window_start
                                    ELSE window_start END`,
        args: [key, now, now - loginWindowMs, now - loginWindowMs],
      })),
      'write',
    );
  }

  async reset(keys: readonly string[]): Promise<void> {
    await this.db.execute({
      sql: `DELETE FROM login_attempts WHERE key IN (${keys.map(() => '?').join(', ')})`,
      args: [...keys],
    });
  }
}
