/** Server configuration. It comes only from environment variables (SPEC.md §0 rule 8). */
export interface Config {
  /** libSQL URL: `libsql://…turso.io` on Turso, `file:taskwise.db` locally. */
  readonly databaseUrl: string | undefined;
  readonly databaseAuthToken: string | undefined;
  /** Needed once to create the account; setup is disabled without it. */
  readonly setupSecret: string | undefined;
  /** Vercel Cron sends it as `Authorization: Bearer <secret>`. */
  readonly cronSecret: string | undefined;
  /** Web Push (VAPID) keys; set only when all three variables are. */
  readonly vapid: VapidConfig | undefined;
}

export interface VapidConfig {
  readonly publicKey: string;
  readonly privateKey: string;
  /** `mailto:` an email address, or the site's https URL. */
  readonly subject: string;
}

/** Reads [Config] from [env], treating empty values as unset. */
export function configFromEnv(
  env: Record<string, string | undefined> = process.env,
): Config {
  const value = (name: string): string | undefined => {
    const raw = env[name]?.trim();
    return raw ? raw : undefined;
  };
  const publicKey = value('VAPID_PUBLIC_KEY');
  const privateKey = value('VAPID_PRIVATE_KEY');
  const subject = value('VAPID_SUBJECT');
  return {
    vapid:
      publicKey && privateKey && subject
        ? { publicKey, privateKey, subject }
        : undefined,
    databaseUrl: value('DATABASE_URL'),
    databaseAuthToken: value('DATABASE_AUTH_TOKEN'),
    setupSecret: value('SETUP_SECRET'),
    cronSecret: value('CRON_SECRET'),
  };
}
