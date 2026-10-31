import type { Client, Row } from '@libsql/client';

/** Device types; matches `DeviceType` in shared/lib/src/models/enums.dart. */
export const deviceTypes = ['windows', 'linux', 'ios', 'other'] as const;
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
}

const columns =
  'id, name, type, created_at, updated_at, last_seen_at, revoked_at';

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
   */
  async register(
    device: { id: string; name: string; type: DeviceType },
    tokenHash: string,
  ): Promise<DeviceRow> {
    const now = this.now();
    await this.db.execute({
      sql: `INSERT INTO devices
              (id, name, type, token_hash, created_at, updated_at, last_seen_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (id) DO UPDATE SET
              name = excluded.name, type = excluded.type,
              token_hash = excluded.token_hash, updated_at = excluded.updated_at,
              last_seen_at = excluded.last_seen_at, revoked_at = NULL`,
      args: [device.id, device.name, device.type, tokenHash, now, now, now],
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

  /** Revokes the device's token. Returns false if the id is unknown. */
  async revoke(id: string): Promise<boolean> {
    const now = this.now();
    const result = await this.db.execute({
      sql: `UPDATE devices SET revoked_at = COALESCE(revoked_at, ?), updated_at = ?
            WHERE id = ?`,
      args: [now, now, id],
    });
    return result.rowsAffected > 0;
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
