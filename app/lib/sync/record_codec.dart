import 'package:drift/drift.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/db/app_database.dart';
import '../data/db/tables.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/reminder_repository.dart';
import '../data/repositories/task_repository.dart';

/// A record as the sync API sends it: `{type, record}` (docs/sync-api.md).
typedef SyncChange = ({String type, Map<String, Object?> record});

/// Who wrote a stored row last, for last-write-wins.
typedef SyncStamp = ({DateTime updatedAt, String? updatedByDevice});

/// True when a change stamped [incoming] beats the stored [current] one:
/// a later `updatedAt` wins, and a tie goes to the greater device id (the
/// same rule as the server, so every device ends up with the same winner).
bool winsOver(SyncStamp incoming, SyncStamp? current) {
  if (current == null) return true;
  final byTime = incoming.updatedAt.compareTo(current.updatedAt);
  if (byTime != 0) return byTime > 0;
  return (incoming.updatedByDevice ?? '').compareTo(
        current.updatedByDevice ?? '',
      ) >
      0;
}

/// Converts local rows to sync records and back, per record type. The JSON
/// shapes are the shared models' `toJson` (checked against the fixtures in
/// shared/test/fixtures/sync).
class RecordCodec {
  RecordCodec(this.db);

  final AppDatabase db;

  late final Map<String, _Adapter<SyncColumns, DataClass>> _adapters = {
    'task': _Adapter<$TasksTable, TaskRow>(
      db.tasks,
      (row) => TaskRepository.toTask(row).toJson(),
      (json) => TaskRepository.toCompanion(Task.fromJson(json)),
    ),
    'subtask': _Adapter<$SubtasksTable, SubtaskRow>(
      db.subtasks,
      (row) => TaskRepository.toSubtask(row).toJson(),
      (json) => TaskRepository.toSubtaskCompanion(Subtask.fromJson(json)),
    ),
    'category': _Adapter<$CategoriesTable, CategoryRow>(
      db.categories,
      (row) => CategoryRepository.toCategory(row).toJson(),
      (json) {
        final c = Category.fromJson(json);
        return CategoriesCompanion.insert(
          id: c.id,
          name: c.name,
          colorValue: c.colorValue,
          updatedAt: c.updatedAt,
          deleted: Value(c.deleted),
          updatedByDevice: Value(c.updatedByDevice),
        );
      },
    ),
    'tag': _Adapter<$TagsTable, TagRow>(
      db.tags,
      (row) => TaskRepository.toTag(row).toJson(),
      (json) {
        final t = Tag.fromJson(json);
        return TagsCompanion.insert(
          id: t.id,
          name: t.name,
          updatedAt: t.updatedAt,
          deleted: Value(t.deleted),
          updatedByDevice: Value(t.updatedByDevice),
        );
      },
    ),
    'taskTag': _Adapter<$TaskTagsTable, TaskTagRow>(
      db.taskTags,
      (row) => TaskTag(
        id: row.id,
        taskId: row.taskId,
        tagId: row.tagId,
        updatedAt: row.updatedAt,
        deleted: row.deleted,
        updatedByDevice: row.updatedByDevice,
      ).toJson(),
      (json) {
        final l = TaskTag.fromJson(json);
        return TaskTagsCompanion.insert(
          id: l.id,
          taskId: l.taskId,
          tagId: l.tagId,
          updatedAt: l.updatedAt,
          deleted: Value(l.deleted),
          updatedByDevice: Value(l.updatedByDevice),
        );
      },
    ),
    'reminder': _Adapter<$RemindersTable, ReminderRow>(
      db.reminders,
      (row) => ReminderRepository.toReminder(row).toJson(),
      (json) => ReminderRepository.toCompanion(Reminder.fromJson(json)),
    ),
    'place': _Adapter<$PlacesTable, PlaceRow>(
      db.places,
      (row) => Place(
        id: row.id,
        name: row.name,
        latitude: row.latitude,
        longitude: row.longitude,
        address: row.address,
        radiusMeters: row.radiusMeters,
        updatedAt: row.updatedAt,
        deleted: row.deleted,
        updatedByDevice: row.updatedByDevice,
      ).toJson(),
      (json) {
        final p = Place.fromJson(json);
        return PlacesCompanion.insert(
          id: p.id,
          name: p.name,
          latitude: p.latitude,
          longitude: p.longitude,
          address: Value(p.address),
          radiusMeters: Value(p.radiusMeters),
          updatedAt: p.updatedAt,
          deleted: Value(p.deleted),
          updatedByDevice: Value(p.updatedByDevice),
        );
      },
    ),
    'taskTargetDevice': _Adapter<$TaskTargetDevicesTable, TaskTargetDeviceRow>(
      db.taskTargetDevices,
      (row) => TaskTargetDevice(
        id: row.id,
        taskId: row.taskId,
        deviceId: row.deviceId,
        updatedAt: row.updatedAt,
        deleted: row.deleted,
        updatedByDevice: row.updatedByDevice,
      ).toJson(),
      (json) {
        final t = TaskTargetDevice.fromJson(json);
        return TaskTargetDevicesCompanion.insert(
          id: t.id,
          taskId: t.taskId,
          deviceId: t.deviceId,
          updatedAt: t.updatedAt,
          deleted: Value(t.deleted),
          updatedByDevice: Value(t.updatedByDevice),
        );
      },
    ),
    // Settings have no shared model: `{id: key, value, updatedAt, ...}`.
    // Only synced keys are ever pushed, so pulled ones are synced too.
    'setting': _Adapter<$SettingsTable, SettingRow>(
      db.settings,
      (row) => {
        'id': row.id,
        'value': row.value,
        'updatedAt': JsonFields.dateTime(row.updatedAt),
        'deleted': row.deleted,
        'updatedByDevice': row.updatedByDevice,
      },
      (json) => SettingsCompanion.insert(
        id: json['id']! as String,
        value: json['value']! as String,
        synced: const Value(true),
        updatedAt: JsonFields.parseRequiredDateTime(json['updatedAt']),
        deleted: Value(json['deleted'] as bool? ?? false),
        updatedByDevice: Value(json['updatedByDevice'] as String?),
      ),
    ),
  };

  /// Record types this app knows; others are ignored on pull.
  Iterable<String> get types => _adapters.keys;

  bool knows(String type) => _adapters.containsKey(type);

  /// The stored row as a sync record, or null if it doesn't exist.
  Future<Map<String, Object?>?> read(String type, String id) async {
    final adapter = _adapter(type);
    final row = await (db.select(
      adapter.table,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : adapter.toJson(row);
  }

  /// Who last wrote the stored row, or null if it doesn't exist.
  Future<SyncStamp?> stamp(String type, String id) async {
    final row = await db
        .customSelect(
          'SELECT updated_at, updated_by_device FROM '
          '${_adapter(type).table.actualTableName} WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return (
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('updated_at'),
        isUtc: true,
      ),
      updatedByDevice: row.readNullable<String>('updated_by_device'),
    );
  }

  /// Stores a record, replacing the row with the same id.
  Future<void> write(String type, Map<String, Object?> record) {
    final adapter = _adapter(type);
    return db
        .into(adapter.table)
        .insertOnConflictUpdate(adapter.fromJson(record));
  }

  /// Ids of all stored rows of [type] (for a full resync).
  Future<Set<String>> ids(String type) async {
    final adapter = _adapter(type);
    final filter = type == 'setting' ? ' WHERE synced = 1' : '';
    final rows = await db
        .customSelect('SELECT id FROM ${adapter.table.actualTableName}$filter')
        .get();
    return {for (final row in rows) row.read<String>('id')};
  }

  /// Removes a row for good (a full resync found it gone from the server).
  Future<void> delete(String type, String id) => db.customStatement(
    'DELETE FROM ${_adapter(type).table.actualTableName} WHERE id = ?',
    [id],
  );

  _Adapter<SyncColumns, DataClass> _adapter(String type) =>
      _adapters[type] ?? (throw ArgumentError.value(type, 'type'));
}

final class _Adapter<T extends SyncColumns, R extends DataClass> {
  _Adapter(this.table, this._toJson, this._fromJson);

  final TableInfo<T, R> table;
  final Map<String, Object?> Function(R row) _toJson;
  final Insertable<R> Function(Map<String, Object?> json) _fromJson;

  Map<String, Object?> toJson(DataClass row) => _toJson(row as R);

  Insertable<R> fromJson(Map<String, Object?> json) => _fromJson(json);
}
