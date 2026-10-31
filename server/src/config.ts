/** Server configuration. It comes only from environment variables (SPEC.md §0 rule 8). */
export interface Config {
  /** libSQL URL: `libsql://…turso.io` on Turso, `file:taskwise.db` locally. */
  readonly databaseUrl: string | undefined;
  readonly databaseAuthToken: string | undefined;
  /** Needed once to create the account; setup is disabled without it. */
  readonly setupSecret: string | undefined;
  /** Vercel Cron sends it as `Authorization: Bearer <secret>`. */
  readonly cronSecret: string | undefined;
}

/** Reads [Config] from [env], treating empty values as unset. */
export function configFromEnv(
  env: Record<string, string | undefined> = process.env,
): Config {
  const value = (name: string): string | undefined => {
    const raw = env[name]?.trim();
    return raw ? raw : undefined;
  };
  return {
    databaseUrl: value('DATABASE_URL'),
    databaseAuthToken: value('DATABASE_AUTH_TOKEN'),
    setupSecret: value('SETUP_SECRET'),
    cronSecret: value('CRON_SECRET'),
  };
}
