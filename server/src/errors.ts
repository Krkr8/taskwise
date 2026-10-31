import type { ContentfulStatusCode } from 'hono/utils/http-status';

/** Machine-readable error codes; documented in docs/sync-api.md. */
export type ErrorCode =
  | 'bad_request'
  | 'unauthorized'
  | 'forbidden'
  | 'not_found'
  | 'conflict'
  | 'payload_too_large'
  | 'rate_limited'
  | 'resync_required'
  | 'setup_disabled'
  | 'not_configured'
  | 'internal';

/** An error that becomes a JSON response `{error: {code, message}}`. */
export class ApiError extends Error {
  constructor(
    readonly status: ContentfulStatusCode,
    readonly code: ErrorCode,
    message: string,
    readonly headers: Record<string, string> = {},
  ) {
    super(message);
  }
}

export const badRequest = (message: string): ApiError =>
  new ApiError(400, 'bad_request', message);
