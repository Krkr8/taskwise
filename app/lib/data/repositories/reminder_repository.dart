import 'package:drift/drift.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../db/app_database.dart';
import 'repository_base.dart';

/// Reads and writes reminders. Time reminders only for now; location
/// reminders arrive in M7 and use the same table.
class ReminderRepository extends RepositoryBase {
  ReminderRepository(super.db, {required super.deviceId, super.clock});

  /// All non-deleted time reminders (the scheduler's input).
  Stream<List<Reminder>> watchTimeReminders() =>
      (db.select(db.reminders)..where(
            (r) => r.deleted.not() & r.kind.equalsValue(ReminderKind.time),
          ))
          .watch()
          .map((rows) => rows.map(toReminder).toList());

  /// A task's non-deleted time reminders: relative ones first (soonest to
  /// the due time last), then absolute ones by time.
  Stream<List<Reminder>> watchForTask(String taskId) =>
      (db.select(db.reminders)..where(
            (r) =>
                r.taskId.equals(taskId) &
                r.deleted.not() &
                r.kind.equalsValue(ReminderKind.time),
          ))
          .watch()
          .map((rows) => rows.map(toReminder).toList()..sort(_compare));

  /// Adds "[minutes] before the due time" (0 = at the due time), unless the
  /// task already has that exact reminder.
  Future<void> addRelative(String taskId, int minutes) =>
      db.transaction(() async {
        final existing =
            await (db.select(db.reminders)..where(
                  (r) =>
                      r.taskId.equals(taskId) &
                      r.deleted.not() &
                      r.minutesBeforeDue.equals(minutes),
                ))
                .get();
        if (existing.isNotEmpty) return;
        await _insert(
          Reminder(
            id: newId(),
            taskId: taskId,
            kind: ReminderKind.time,
            minutesBeforeDue: minutes,
            updatedAt: now(),
            updatedByDevice: deviceId,
          ),
        );
      });

  /// Adds a reminder at a fixed moment.
  Future<void> addAbsolute(String taskId, DateTime at) => _insert(
    Reminder(
      id: newId(),
      taskId: taskId,
      kind: ReminderKind.time,
      absoluteAt: at.toUtc(),
      updatedAt: now(),
      updatedByDevice: deviceId,
    ),
  );

  /// Tombstones a reminder.
  Future<void> delete(String id) =>
      (db.update(db.reminders)..where((r) => r.id.equals(id))).write(
        RemindersCompanion(
          deleted: const Value(true),
          updatedAt: Value(now()),
          updatedByDevice: Value(deviceId),
        ),
      );

  /// Whether a task has any live reminder.
  Future<bool> hasReminders(String taskId) async =>
      (await (db.select(db.reminders)
                ..where((r) => r.taskId.equals(taskId) & r.deleted.not())
                ..limit(1))
              .get())
          .isNotEmpty;

  Future<void> _insert(Reminder r) =>
      db.into(db.reminders).insert(toCompanion(r));

  static int _compare(Reminder a, Reminder b) {
    final ar = a.minutesBeforeDue;
    final br = b.minutesBeforeDue;
    if (ar != null && br != null) return br.compareTo(ar);
    if (ar != null) return -1;
    if (br != null) return 1;
    return a.absoluteAt!.compareTo(b.absoluteAt!);
  }

  static Reminder toReminder(ReminderRow row) => Reminder(
    id: row.id,
    taskId: row.taskId,
    kind: row.kind,
    absoluteAt: row.absoluteAt,
    minutesBeforeDue: row.minutesBeforeDue,
    placeId: row.placeId,
    latitude: row.latitude,
    longitude: row.longitude,
    radiusMeters: row.radiusMeters,
    trigger: row.trigger,
    updatedAt: row.updatedAt,
    deleted: row.deleted,
    updatedByDevice: row.updatedByDevice,
  );

  static RemindersCompanion toCompanion(Reminder r) =>
      RemindersCompanion.insert(
        id: r.id,
        taskId: r.taskId,
        kind: r.kind,
        absoluteAt: Value(r.absoluteAt),
        minutesBeforeDue: Value(r.minutesBeforeDue),
        placeId: Value(r.placeId),
        latitude: Value(r.latitude),
        longitude: Value(r.longitude),
        radiusMeters: Value(r.radiusMeters),
        trigger: Value(r.trigger),
        updatedAt: r.updatedAt,
        deleted: Value(r.deleted),
        updatedByDevice: Value(r.updatedByDevice),
      );
}
