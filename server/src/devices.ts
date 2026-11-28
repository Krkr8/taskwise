import type { Client, Row } from '@libsql/client';

import { badRequest } from './errors.js';

/** Device types; matches `DeviceType` in shared/lib/src/models/enums.dart. */
export const deviceTypes = ['windows', 'linux', 'ios', 'android', 'other', 'web'] as const;
export type DeviceType = (typeof deviceTypes)[number];

/** A registered app install, as stored on the server. */
export interface DeviceRow {
  readonly id: string;
  readonly name: string;
  readonly type: DeviceType;
  readonly createdAt: number;
  readonly updatedAt: number;
  readonly lastSeenAt: number | null;
  readonly revokedAt: number | null;
  /** The main device manages the others (removes them, renames them). */
  readonly isMain: boolean;
  /** IANA time zone the device reported (since 1.4.0), or null. */
  readonly timeZone: string | null;
  /** True when the device has at least one Web Push subscription. */
  readonly pushEnabled: boolean;
  /**
   * When the device reminds of all-day tasks, in minutes after midnight
   * (web devices since 1.4.0 report it, for the apps that plan for them),
   * or null.
   */
  readonly allDayMinutes: number | null;
}

/** JSON shape of a device; matches `Device.toJson` in shared. */
export interface DeviceJson {
  id: string;
  name: string;
  type: DeviceType;
  lastSeenAt: string | null;
  updatedAt: string;
  deleted: boolean;
  updatedByDevice: null;
  main: boolean;
  /** Only present when set, like `Device.toJson` in shared. */
  timeZone?: string;
  /** Only present when true, like `Device.toJson` in shared. */
  pushEnabled?: true;
  /** Only present when set, like `Device.toJson` in shared. */
  allDayMinutes?: number;
}

/** Longest time zone name accepted (IANA names are far shorter). */
export const maxTimeZoneLength = 64;

/**
 * Reads an optional `timeZone` field: undefined when absent, null when
 * explicitly null (clears it), else a non-empty string. The server only
 * compares it, so any IANA name the device knows is fine.
 */
export function timeZoneField(body: unknown): string | null | undefined {
  const value =
    typeof body === 'object' && body !== null
      ? (body as Record<string, unknown>)['timeZone']
      : undefined;
  if (value === undefined || value === null) return value;
  const text = typeof value === 'string' ? value.trim() : '';
  if (text.length < 1 || text.length > maxTimeZoneLength) {
    throw badRequest(
      `"timeZone" must be null or a string of 1–${maxTimeZoneLength} characters.`,
    );
  }
  return text;
}

/**
 * Reads an optional `allDayMinutes` field: undefined when absent, null when
 * explicitly null (clears it), else an integer from 0 to 1439.
 */
export function allDayMinutesField(body: unknown): number | null | undefined {
  const value =
    typeof body === 'object' && body !== null
      ? (body as Record<string, unknown>)['allDayMinutes']
      : undefined;
  if (value === undefined || value === null) return value;
  if (
    typeof value !== 'number' ||
    !Number.isInteger(value) ||
    value < 0 ||
    value >= 24 * 60
  ) {
    throw badRequest('"allDayMinutes" must be null or a whole number from 0 to 1439.');
  }
  return value;
}

const columns = `id, name, type, created_at, updated_at, last_seen_at,
  revoked_at, is_main, time_zone, all_day_minutes,
  EXISTS (SELECT 1 FROM push_subscriptions s WHERE s.device_id = devices.id)
    AS push_enabled`;

function fromRow(row: Row): DeviceRow {
  const nullable = (value: unknown): number | null =>
    value === null || value === undefined ? null : Number(value);
  const type = String(row['type']);
  return {
    id: String(row['id']),
    name: String(row['name']),
    type: (deviceTypes as readonly string[]).includes(type)
      ? (type as DeviceType)
      : 'other',
    createdAt: Number(row['created_at']),
    updatedAt: Number(row['updated_at']),
    lastSeenAt: nullable(row['last_seen_at']),
    revokedAt: nullable(row['revoked_at']),
    isMain: Number(row['is_main']) === 1,
    timeZone:
      row['time_zone'] === null || row['time_zone'] === undefined
        ? null
        : String(row['time_zone']),
    pushEnabled: Number(row['push_enabled']) === 1,
    allDayMinutes: nullable(row['all_day_minutes']),
  };
}

/** A revoked device is reported as a tombstone (`deleted: true`). */
export function deviceToJson(device: DeviceRow): DeviceJson {
  return {
    id: device.id,
    name: device.name,
    type: device.type,
    lastSeenAt:
      device.lastSeenAt === null
        ? null
        : new Date(device.lastSeenAt).toISOString(),
    updatedAt: new Date(device.updatedAt).toISOString(),
    deleted: device.revokedAt !== null,
    updatedByDevice: null,
    main: device.isMain,
    ...(device.timeZone === null ? {} : { timeZone: device.timeZone }),
    ...(device.pushEnabled ? { pushEnabled: true as const } : {}),
    ...(device.allDayMinutes === null ? {} : { allDayMinutes: device.allDayMinutes }),
  };
}

/** Only refresh `last_seen_at` once a minute, to save database writes. */
const lastSeenResolutionMs = 60 * 1000;

export class DeviceStore {
  constructor(
    private readonly db: Client,
    private readonly now: () => number,
  ) {}

  async list(): Promise<DeviceRow[]> {
    const result = await this.db.execute(
      `SELECT ${columns} FROM devices ORDER BY created_at`,
    );
    return result.rows.map(fromRow);
  }

  async find(id: string): Promise<DeviceRow | undefined> {
    const result = await this.db.execute({
      sql: `SELECT ${columns} FROM devices WHERE id = ?`,
      args: [id],
    });
    const row = result.rows[0];
    return row ? fromRow(row) : undefined;
  }

  /** The active (not revoked) device that owns this token hash. */
  async findByTokenHash(tokenHash: string): Promise<DeviceRow | undefined> {
    const result = await this.db.execute({
      sql: `SELECT ${columns} FROM devices
            WHERE token_hash = ? AND revoked_at IS NULL`,
      args: [tokenHash],
    });
    const row = result.rows[0];
    return row ? fromRow(row) : undefined;
  }

  /**
   * Registers a device, or gives an existing device id a new token (which
   * also un-revokes it: the user has just logged in with the password).
   * Without a [timeZone] or [allDayMinutes] (apps before 1.4.0) the stored
   * one is kept.
   */
  async register(
    device: {
      id: string;
      name: string;
      type: DeviceType;
      timeZone?: string;
      allDayMinutes?: number;
    },
    tokenHash: string,
  ): Promise<DeviceRow> {
    const now = this.now();
    await this.db.execute({
      sql: `INSERT INTO devices
              (id, name, type, token_hash, created_at, updated_at, last_seen_at,
               time_zone, all_day_minutes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (id) DO UPDATE SET
              name = excluded.name, type = excluded.type,
              token_hash = excluded.token_hash, updated_at = excluded.updated_at,
              last_seen_at = excluded.last_seen_at, revoked_at = NULL,
              time_zone = COALESCE(excluded.time_zone, devices.time_zone),
              all_day_minutes =
                COALESCE(excluded.all_day_minutes, devices.all_day_minutes)`,
      args: [
        device.id,
        device.name,
        device.type,
        tokenHash,
        now,
        now,
        now,
        device.timeZone ?? null,
        device.allDayMinutes ?? null,
      ],
    });
    // The first device (or the first after the main one was removed)
    // becomes the main device.
    await this.db.execute({
      sql: `UPDATE devices SET is_main = 1 WHERE id = ? AND NOT EXISTS (
              SELECT 1 FROM devices WHERE is_main = 1 AND revoked_at IS NULL)`,
      args: [device.id],
    });
    return (await this.find(device.id))!;
  }

  async rename(id: string, name: string): Promise<DeviceRow | undefined> {
    await this.db.execute({
      sql: 'UPDATE devices SET name = ?, updated_at = ? WHERE id = ?',
      args: [name, this.now(), id],
    });
    return this.find(id);
  }

  /** Sets (or with null clears) the device's time zone. */
  async setTimeZone(
    id: string,
    timeZone: string | null,
  ): Promise<DeviceRow | undefined> {
    await this.db.execute({
      sql: 'UPDATE devices SET time_zone = ?, updated_at = ? WHERE id = ?',
      args: [timeZone, this.now(), id],
    });
    return this.find(id);
  }

  /** Sets (or with null clears) the device's all-day reminder minutes. */
  async setAllDayMinutes(
    id: string,
    minutes: number | null,
  ): Promise<DeviceRow | undefined> {
    await this.db.execute({
      sql: 'UPDATE devices SET all_day_minutes = ?, updated_at = ? WHERE id = ?',
      args: [minutes, this.now(), id],
    });
    return this.find(id);
  }

  /**
   * Revokes the device's token. Returns false if the id is unknown. If it
   * was the main device, the most recently seen other device takes over.
   * Its push subscriptions and unsent push items go with it.
   */
  async revoke(id: string): Promise<boolean> {
    const now = this.now();
    const results = await this.db.batch(
      [
        {
          sql: `UPDATE devices SET revoked_at = COALESCE(revoked_at, ?),
                  updated_at = ?, is_main = 0
                WHERE id = ?`,
          args: [now, now, id],
        },
        {
          sql: `UPDATE devices SET is_main = 1, updated_at = ? WHERE id = (
                  SELECT id FROM devices WHERE revoked_at IS NULL
                  ORDER BY last_seen_at DESC, created_at LIMIT 1)
                AND NOT EXISTS (
                  SELECT 1 FROM devices WHERE is_main = 1 AND revoked_at IS NULL)`,
          args: [now],
        },
        {
          sql: 'DELETE FROM push_subscriptions WHERE device_id = ?',
          args: [id],
        },
        {
          sql: 'DELETE FROM push_items WHERE device_id = ? AND sent_at IS NULL',
          args: [id],
        },
      ],
      'write',
    );
    return results[0]!.rowsAffected > 0;
  }

  /** Makes [id] (an active device) the main device. */
  async makeMain(id: string): Promise<DeviceRow | undefined> {
    const now = this.now();
    const target = await this.find(id);
    if (!target || target.revokedAt !== null) return undefined;
    await this.db.batch(
      [
        {
          sql: 'UPDATE devices SET is_main = 0, updated_at = ? WHERE is_main = 1 AND id <> ?',
          args: [now, id],
        },
        {
          sql: 'UPDATE devices SET is_main = 1, updated_at = ? WHERE id = ?',
          args: [now, id],
        },
      ],
      'write',
    );
    return this.find(id);
  }

  async touch(device: DeviceRow): Promise<void> {
    const now = this.now();
    if (
      device.lastSeenAt !== null &&
      now - device.lastSeenAt < lastSeenResolutionMs
    ) {
      return;
    }
    await this.db.execute({
      sql: 'UPDATE devices SET last_seen_at = ? WHERE id = ?',
      args: [now, device.id],
    });
  }
}
