/**
 * JSON-line logging (Vercel shows these in the project's Logs tab).
 * Never pass tokens, passwords or record contents here.
 */
type Level = 'info' | 'warn' | 'error';

export function log(
  level: Level,
  event: string,
  fields: Record<string, unknown> = {},
): void {
  const line = JSON.stringify({
    time: new Date().toISOString(),
    level,
    event,
    ...fields,
  });
  if (level === 'error') {
    console.error(line);
  } else {
    console.log(line);
  }
}
