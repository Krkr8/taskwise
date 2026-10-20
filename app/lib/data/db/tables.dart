import 'package:drift/drift.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import 'converters.dart';

// Every table carries the sync columns from SPEC.md section 4. There are no
// foreign-key constraints on purpose: sync can deliver records in any order,
// and tombstones (deleted = true) stand in for cascading deletes.

/// Columns shared by every synced table.
mixin SyncColumns on Table {
  TextColumn get id => text()();
  IntColumn get updatedAt => integer().map(const UtcMillisConverter())();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  TextColumn get updatedByDevice => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TaskRow')
@TableIndex(name: 'tasks_deleted_done', columns: {#deleted, #done})
class Tasks extends Table with SyncColumns {
  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get dueDate => text().map(const LocalDateConverter()).nullable()();
  IntColumn get dueTimeMinutes => integer().nullable()();
  TextColumn get priority =>
      textEnum<Priority>().withDefault(Constant(Priority.none.name))();
  TextColumn get categoryId => text().nullable()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get completedAt =>
      integer().map(const UtcMillisConverter()).nullable()();
  TextColumn get recurrenceRule => text().nullable()();
  BoolColumn get notifyAllDevices =>
      boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer().map(const UtcMillisConverter())();
}

@DataClassName('SubtaskRow')
@TableIndex(name: 'subtasks_task', columns: {#taskId})
class Subtasks extends Table with SyncColumns {
  TextColumn get taskId => text()();
  TextColumn get title => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer()();
}

@DataClassName('CategoryRow')
class Categories extends Table with SyncColumns {
  TextColumn get name => text()();
  IntColumn get colorValue => integer()();
}

@DataClassName('TagRow')
class Tags extends Table with SyncColumns {
  TextColumn get name => text()();
}

@DataClassName('TaskTagRow')
@TableIndex(name: 'task_tags_task', columns: {#taskId})
@TableIndex(name: 'task_tags_tag', columns: {#tagId})
class TaskTags extends Table with SyncColumns {
  TextColumn get taskId => text()();
  TextColumn get tagId => text()();
}

/// Schema only in M1; UI arrives in M4 (time) and M7 (location).
@DataClassName('ReminderRow')
@TableIndex(name: 'reminders_task', columns: {#taskId})
class Reminders extends Table with SyncColumns {
  TextColumn get taskId => text()();
  TextColumn get kind => textEnum<ReminderKind>()();
  IntColumn get absoluteAt =>
      integer().map(const UtcMillisConverter()).nullable()();
  IntColumn get minutesBeforeDue => integer().nullable()();
  TextColumn get placeId => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  IntColumn get radiusMeters => integer().nullable()();
  TextColumn get trigger => textEnum<LocationTrigger>().nullable()();
}

/// Saved places (UI in M7).
@DataClassName('PlaceRow')
class Places extends Table with SyncColumns {
  TextColumn get name => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get address => text().nullable()();
  IntColumn get radiusMeters =>
      integer().withDefault(const Constant(Place.defaultRadiusMeters))();
}

@DataClassName('DeviceRow')
class Devices extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get type => textEnum<DeviceType>()();
  IntColumn get lastSeenAt =>
      integer().map(const UtcMillisConverter()).nullable()();
}

/// Explicit notify-on-device targets, used when a task's notifyAllDevices
/// flag is false (from M6).
@DataClassName('TaskTargetDeviceRow')
@TableIndex(name: 'task_target_devices_task', columns: {#taskId})
class TaskTargetDevices extends Table with SyncColumns {
  TextColumn get taskId => text()();
  TextColumn get deviceId => text()();
}

/// Key/value settings. The `id` column is the setting key. Rows with
/// [synced] = false stay on this device (theme, language...); synced rows
/// are shared across devices (week start...).
@DataClassName('SettingRow')
class Settings extends Table with SyncColumns {
  TextColumn get value => text()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}
