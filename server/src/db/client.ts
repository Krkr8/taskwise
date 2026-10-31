import { createClient, type Client } from '@libsql/client';

import { ApiError } from '../errors.js';
import { migrate } from './migrations.js';

/**
 * Lazily opens the database and runs migrations once per server instance
 * (a Vercel function instance, or the Node process).
 */
export class Database {
  #ready: Promise<Client> | undefined;

  constructor(private readonly open: () => Client) {}

  /** Opens a libSQL database from a URL (`libsql://…`, `file:…`, `:memory:`). */
  static fromUrl(url: string | undefined, authToken?: string): Database {
    return new Database(() => {
      if (!url) {
        throw new ApiError(
          500,
          'not_configured',
          'DATABASE_URL is not set on the server.',
        );
      }
      return createClient(authToken ? { url, authToken } : { url });
    });
  }

  /** The migrated client. A failed open is retried on the next call. */
  client(): Promise<Client> {
    this.#ready ??= (async () => {
      const client = this.open();
      await migrate(client);
      return client;
    })().catch((error: unknown) => {
      this.#ready = undefined;
      throw error;
    });
    return this.#ready;
  }
}
