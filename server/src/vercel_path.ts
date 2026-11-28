/**
 * The request path without one leading `/_hono`. vercel.json rewrites
 * `/api/v1/*` to `/_hono/api/v1/*` (see src/index.ts), so the Hono app sees
 * the prefix and has to drop it. Direct paths are left alone.
 */
export function vercelPath(path: string): string {
  return path === '/_hono' || path.startsWith('/_hono/')
    ? path.slice('/_hono'.length) || '/'
    : path;
}
