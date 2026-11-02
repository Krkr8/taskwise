import 'package:drift/drift.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import 'repository_base.dart';

/// Reads the device list. The server owns devices: the sync engine copies
/// its list here, and renaming or removing goes through the server
/// (`SyncController`).
class DeviceRepository extends RepositoryBase {
  DeviceRepository(super.db, {required super.deviceId, super.clock});

  /// Active devices, this one first, then by name.
  Stream<List<Device>> watchDevices() =>
      (db.select(db.devices)..where((d) => d.deleted.not())).watch().map(
        (rows) =>
            [
              for (final row in rows)
                Device(
                  id: row.id,
                  name: row.name,
                  type: row.type,
                  lastSeenAt: row.lastSeenAt,
                  updatedAt: row.updatedAt,
                  deleted: row.deleted,
                  updatedByDevice: row.updatedByDevice,
                  isMain: row.isMain,
                ),
            ]..sort((a, b) {
              if (a.id == deviceId) return -1;
              if (b.id == deviceId) return 1;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            }),
      );
}
