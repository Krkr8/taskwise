import { badRequest } from '../errors.js';

/**
 * Record types clients may sync. Devices are not in the list: they are
 * managed through /devices only.
 */
export const recordTypes = [
  'task',
  'subtask',
  'category',
  'tag',
  'taskTag',
  'reminder',
  'place',
  'setting',
  'taskTargetDevice',
] as const;
export type RecordType = (typeof recordTypes)[number];

/** Types whose records belong to a task (`taskId`); purged with it. */
export const taskChildTypes: readonly RecordType[] = [
  'subtask',
  'reminder',
  'taskTag',
  'taskTargetDevice',
];

export const maxChangesPerPush = 500;
export const maxIdLength = 128;

export type SyncRecord = Record<string, unknown> & {
  id: string;
  updatedAt: string;
  deleted: boolean;
};

/** A validated change from a push. */
export interface Change {
  readonly type: RecordType;
  readonly record: SyncRecord;
  /** `record.updatedAt` in UTC milliseconds. */
  readonly updatedAtMs: number;
}

// UTC ISO 8601 as written by Dart's toIso8601String() and JS toISOString().
const isoUtc = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$/;

const isObject = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

/** Validates a push body. Throws a 400 [ApiError] naming the bad change. */
export function parsePush(body: unknown): Change[] {
  if (!isObject(body) || !Array.isArray(body['changes'])) {
    throw badRequest('Body must be {"changes": [...]}.');
  }
  const changes: unknown[] = body['changes'];
  if (changes.length > maxChangesPerPush) {
    throw badRequest(
      `At most ${maxChangesPerPush} changes per push; send the rest in another request.`,
    );
  }
  return changes.map((change, index) => {
    const fail = (reason: string) => badRequest(`changes[${index}]: ${reason}`);
    if (!isObject(change)) throw fail('must be an object.');
    const { type, record } = change;
    if (
      typeof type !== 'string' ||
      !(recordTypes as readonly string[]).includes(type)
    ) {
      throw fail(`unknown type ${JSON.stringify(type)}.`);
    }
    if (!isObject(record)) throw fail('record must be an object.');
    const { id, updatedAt, deleted } = record;
    if (typeof id !== 'string' || id.length === 0 || id.length > maxIdLength) {
      throw fail(`record.id must be a string of 1–${maxIdLength} characters.`);
    }
    if (typeof updatedAt !== 'string' || !isoUtc.test(updatedAt)) {
      throw fail('record.updatedAt must be a UTC ISO 8601 date ending in Z.');
    }
    const updatedAtMs = Date.parse(updatedAt);
    if (Number.isNaN(updatedAtMs)) throw fail('record.updatedAt is invalid.');
    if (typeof deleted !== 'boolean') {
      throw fail('record.deleted must be true or false.');
    }
    return {
      type: type as RecordType,
      record: record as SyncRecord,
      updatedAtMs,
    };
  });
}
