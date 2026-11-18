import 'package:drift/drift.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../db/app_database.dart';
import '../db/tables.dart' show SyncColumns;
import 'reminder_repository.dart';
import 'repository_base.dart';

/// What [TaskRepository.setDone] changed, for [TaskRepository.undoCompletion].
final class Completion {
  const Completion({this.rule, this.nextTaskId});

  /// The repeat rule the completed task had (it's moved to the next copy).
  final String? rule;

  /// The occurrence created for a repeating task, if any.
  final String? nextTaskId;
}

/// Reads and writes tasks, their subtasks and their tags.
class TaskRepository extends RepositoryBase {
  TaskRepository(super.db, {required super.deviceId, super.clock});

  // ---------------------------------------------------------------- tasks

  /// All non-deleted tasks with their tag ids and subtask counts.
  Stream<List<TaskEntry>> watchEntries() {
    final query = db.customSelect(
      '''
      SELECT t.*,
        (SELECT COUNT(*) FROM subtasks s
          WHERE s.task_id = t.id AND s.deleted = 0) AS subtask_count,
        (SELECT COUNT(*) FROM subtasks s
          WHERE s.task_id = t.id AND s.deleted = 0 AND s.done = 1)
          AS subtasks_done,
        (SELECT group_concat(tt.tag_id, ',') FROM task_tags tt
          JOIN tags g ON g.id = tt.tag_id
          WHERE tt.task_id = t.id AND tt.deleted = 0 AND g.deleted = 0)
          AS tag_ids
      FROM tasks t
      WHERE t.deleted = 0
      ''',
      readsFrom: {db.tasks, db.subtasks, db.taskTags, db.tags},
    );
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          TaskEntry(
            task: toTask(db.tasks.map(row.data)),
            subtaskCount: row.read<int>('subtask_count'),
            subtasksDone: row.read<int>('subtasks_done'),
            tagIds: switch (row.readNullable<String>('tag_ids')) {
              final String ids => ids.split(',').toSet(),
              null => const <String>{},
            },
          ),
      ],
    );
  }

  /// One task, or null if it doesn't exist or is deleted.
  Stream<Task?> watchTask(String id) =>
      (db.select(db.tasks)..where((t) => t.id.equals(id) & t.deleted.not()))
          .watchSingleOrNull()
          .map((row) => row == null ? null : toTask(row));

  Future<Task?> getTask(String id) async {
    final row = await (db.select(
      db.tasks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : toTask(row);
  }

  /// Creates a task. Throws [ArgumentError] if [title] is blank. [id] is
  /// for tasks made elsewhere first (Siri's inbox); new ids are UUID v7.
  Future<Task> createTask({
    required String title,
    String notes = '',
    LocalDate? dueDate,
    int? dueTimeMinutes,
    Priority priority = Priority.none,
    String? categoryId,
    String? id,
  }) async {
    final at = now();
    final task = Task(
      id: id ?? newId(),
      title: Task.validateTitle(title),
      notes: notes,
      dueDate: dueDate,
      dueTimeMinutes: dueDate == null ? null : dueTimeMinutes,
      priority: priority,
      categoryId: categoryId,
      createdAt: at,
      updatedAt: at,
      updatedByDevice: deviceId,
    );
    await db.into(db.tasks).insert(toCompanion(task));
    return task;
  }

  /// Saves the editable content of an existing task (title, notes, due
  /// date/time, priority, category, recurrence, device targeting), stamping
  /// updatedAt and updatedByDevice. A due time without a due date is dropped.
  ///
  /// Completion, deletion and creation time are deliberately not written:
  /// they change only through [setDone], [deleteTask] and [restoreTask], so a
  /// stale snapshot (e.g. an editor flushing typed text after the task was
  /// deleted) can never undo them. Returns the stored task, or null if it
  /// doesn't exist.
  Future<Task?> saveTask(Task task) async {
    await (db.update(db.tasks)..where((t) => t.id.equals(task.id))).write(
      TasksCompanion(
        title: Value(Task.validateTitle(task.title)),
        notes: Value(task.notes),
        dueDate: Value(task.dueDate),
        dueTimeMinutes: Value(
          task.dueDate == null ? null : task.dueTimeMinutes,
        ),
        priority: Value(task.priority),
        categoryId: Value(task.categoryId),
        recurrenceRule: Value(task.recurrenceRule),
        notifyAllDevices: Value(task.notifyAllDevices),
        updatedAt: Value(now()),
        updatedByDevice: Value(deviceId),
      ),
    );
    return getTask(task.id);
  }

  /// Marks a task done (recording when) or not done. With [skipped], the
  /// task is finished as skipped rather than done; reopening clears that.
  ///
  /// Completing (or skipping) a repeating task keeps it as a done copy
  /// without the rule and creates the next occurrence (see [_spawnNext]).
  /// The returned [Completion] lets [undoCompletion] reverse exactly that.
  Future<Completion> setDone(
    String id, {
    required bool done,
    bool skipped = false,
  }) => db.transaction(() async {
    final at = now();
    final task = await getTask(id);
    final rule = done ? RecurrenceRule.tryParse(task?.recurrenceRule) : null;
    await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        done: Value(done),
        skipped: Value(done && skipped),
        completedAt: Value(done ? at : null),
        recurrenceRule: rule == null ? const Value.absent() : const Value(null),
        updatedAt: Value(at),
        updatedByDevice: Value(deviceId),
      ),
    );
    if (task == null || rule == null) return const Completion();
    return Completion(
      rule: task.recurrenceRule,
      nextTaskId: await _spawnNext(task, rule),
    );
  });

  /// Undoes [setDone] (`done: true`): the task is open again with its rule,
  /// and the occurrence created for it is deleted.
  Future<void> undoCompletion(String id, Completion completion) =>
      db.transaction(() async {
        await setDone(id, done: false);
        if (completion.rule case final rule?) {
          await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
            TasksCompanion(recurrenceRule: Value(rule)),
          );
        }
        if (completion.nextTaskId case final next?) await deleteTask(next);
      });

  /// Gives every repeating task that wasn't done in time its next copy
  /// (see [missedRepeatDate]): the old task stays where it is, open and
  /// without the rule, and the copy takes the rule. Returns how many copies
  /// were made; running it again makes none.
  ///
  /// Only the first missed one stays in Overdue: when the task rolling over
  /// is itself a missed copy of an earlier missed one (the app was opened
  /// every day while the task was ignored), it's removed, as if the days in
  /// between had never been created.
  ///
  /// Every write is stamped just after the task's own `updatedAt` rather
  /// than now, so a real change made on another device that this one hasn't
  /// pulled yet (ticking the task, say) wins last-write-wins over this
  /// automatic one.
  Future<int> rollOverMissedRepeats(LocalDate today) =>
      db.transaction(() async {
        final rows = await (db.select(
          db.tasks,
        )..where((t) => t.dueDate.isNotNull())).get();
        final dated = [for (final row in rows) toTask(row)];
        var made = 0;
        for (final task in dated) {
          if (task.deleted || task.done || task.recurrenceRule == null) {
            continue;
          }
          final date = missedRepeatDate(task, today);
          if (date == null) continue;
          final stamp = task.updatedAt.add(const Duration(milliseconds: 1));
          await (db.update(db.tasks)..where((t) => t.id.equals(task.id))).write(
            TasksCompanion(
              recurrenceRule: const Value(null),
              deleted: Value(_followsAMissedOne(task, dated)),
              updatedAt: Value(stamp),
              updatedByDevice: Value(deviceId),
            ),
          );
          await _spawnNext(
            task,
            RecurrenceRule.parse(task.recurrenceRule!),
            on: date,
            stamp: stamp,
          );
          made++;
        }
        return made;
      });

  /// Whether an earlier occurrence of [task]'s series is still open in
  /// Overdue: follows the chain of copies back ([derivedId] links each copy
  /// to the task it was made from), through removed in-between copies, and
  /// stops at a done one.
  bool _followsAMissedOne(Task task, List<Task> dated) {
    var current = task;
    for (var hops = 0; hops < 400; hops++) {
      final due = current.dueDate!;
      final id = current.id;
      final parent = dated
          .where(
            (p) =>
                p.dueDate!.isBefore(due) &&
                derivedId('${p.id}/${due.toIso()}') == id,
          )
          .firstOrNull;
      if (parent == null || parent.done) return false;
      if (!parent.deleted) return true;
      current = parent;
    }
    return false;
  }

  /// Creates the occurrence after [task] and returns its id, or null when
  /// the series has ended.
  ///
  /// The next date is [on], or else the first occurrence after the due date
  /// that is today or later, so completing an overdue daily task doesn't
  /// spawn a pile of past ones. The copy keeps the content, rule and tags,
  /// and gets the subtasks back unticked.
  ///
  /// Its ids are derived from [task] and the date ([derivedId]), so another
  /// device making the same copy before they sync writes the same records,
  /// and a copy removed by Undo comes back when the task is completed again.
  ///
  /// [stamp] is the `updatedAt` for every record written (default now); an
  /// existing live copy (made by another device, say) is never overwritten,
  /// only a removed one is brought back.
  Future<String?> _spawnNext(
    Task task,
    RecurrenceRule rule, {
    LocalDate? on,
    DateTime? stamp,
  }) async {
    final yesterday = today().addDays(-1);
    final due = task.dueDate;
    final after = due == null || due.isBefore(yesterday) ? yesterday : due;
    final nextDate = on ?? rule.nextAfter(after);
    if (nextDate == null) return null;

    final nextId = derivedId('${task.id}/${nextDate.toIso()}');
    var at = stamp ?? now();
    // Bringing back a removed copy (Undo, then completing again or a
    // roll-over) must be newer than its removal, or the other devices,
    // which have the removal, would keep theirs.
    final existing = await getTask(nextId);
    if (existing != null &&
        existing.deleted &&
        !at.isAfter(existing.updatedAt)) {
      at = existing.updatedAt.add(const Duration(milliseconds: 1));
    }
    final next = Task(
      id: nextId,
      title: task.title,
      notes: task.notes,
      dueDate: nextDate,
      dueTimeMinutes: task.dueTimeMinutes,
      priority: task.priority,
      categoryId: task.categoryId,
      recurrenceRule: task.recurrenceRule,
      notifyAllDevices: task.notifyAllDevices,
      createdAt: now(),
      updatedAt: at,
      updatedByDevice: deviceId,
    );
    await _insertOrRevive(db.tasks, toCompanion(next));

    final subtasks = await (db.select(
      db.subtasks,
    )..where((s) => s.taskId.equals(task.id) & s.deleted.not())).get();
    for (final s in subtasks) {
      await _insertOrRevive(
        db.subtasks,
        toSubtaskCompanion(
          Subtask(
            id: derivedId('$nextId/s/${s.id}'),
            taskId: next.id,
            title: s.title,
            sortOrder: s.sortOrder,
            updatedAt: at,
            updatedByDevice: deviceId,
          ),
        ),
      );
    }
    final tagIds =
        await (db.select(db.taskTags)
              ..where((l) => l.taskId.equals(task.id) & l.deleted.not()))
            .map((l) => l.tagId)
            .get();
    for (final tagId in tagIds.toSet()) {
      await _insertOrRevive(
        db.taskTags,
        TaskTagsCompanion.insert(
          id: derivedId('$nextId/t/$tagId'),
          taskId: nextId,
          tagId: tagId,
          updatedAt: at,
          deleted: const Value(false),
          updatedByDevice: Value(deviceId),
        ),
      );
    }

    // "Notify on" devices, when the task isn't set to all of them.
    final targets =
        await (db.select(db.taskTargetDevices)
              ..where((t) => t.taskId.equals(task.id) & t.deleted.not()))
            .map((t) => t.deviceId)
            .get();
    for (final target in targets.toSet()) {
      await _insertOrRevive(
        db.taskTargetDevices,
        TaskTargetDevicesCompanion.insert(
          id: derivedId('$nextId/d/$target'),
          taskId: nextId,
          deviceId: target,
          updatedAt: at,
          deleted: const Value(false),
          updatedByDevice: Value(deviceId),
        ),
      );
    }

    // Reminders follow the task: relative ones keep their offset, absolute
    // ones move by as many days as the due date did.
    final shift = due == null ? 0 : nextDate.differenceInDays(due);
    final reminders = await (db.select(
      db.reminders,
    )..where((r) => r.taskId.equals(task.id) & r.deleted.not())).get();
    for (final r in reminders) {
      final absolute = r.absoluteAt;
      await _insertOrRevive(
        db.reminders,
        ReminderRepository.toCompanion(
          Reminder(
            id: derivedId('$nextId/r/${r.id}'),
            taskId: next.id,
            kind: r.kind,
            absoluteAt: absolute == null ? null : _shiftDays(absolute, shift),
            minutesBeforeDue: r.minutesBeforeDue,
            placeId: r.placeId,
            latitude: r.latitude,
            longitude: r.longitude,
            radiusMeters: r.radiusMeters,
            trigger: r.trigger,
            label: r.label,
            updatedAt: at,
            updatedByDevice: deviceId,
          ),
        ),
      );
    }
    return next.id;
  }

  /// Inserts [row], or writes it over an existing row with the same id only
  /// when that row is a tombstone (a copy removed by Undo coming back). A
  /// live row is left as it is: it's the same copy, made on another device
  /// or earlier, and may have been changed since.
  Future<void> _insertOrRevive<T extends SyncColumns, D>(
    TableInfo<T, D> table,
    Insertable<D> row,
  ) => db
      .into(table)
      .insert(
        row,
        onConflict: DoUpdate((_) => row, where: (old) => old.deleted),
      );

  /// Soft-deletes a task (tombstone). Its subtasks and tag links are left as
  /// they are, so [restoreTask] brings everything back.
  Future<void> deleteTask(String id) => _setTaskDeleted(id, deleted: true);

  /// Undoes [deleteTask].
  Future<void> restoreTask(String id) => _setTaskDeleted(id, deleted: false);

  Future<void> _setTaskDeleted(String id, {required bool deleted}) =>
      (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(
          deleted: Value(deleted),
          updatedAt: Value(now()),
          updatedByDevice: Value(deviceId),
        ),
      );

  // ------------------------------------------------------------- subtasks

  /// A task's non-deleted subtasks, in checklist order.
  Stream<List<Subtask>> watchSubtasks(String taskId) =>
      (db.select(db.subtasks)
            ..where((s) => s.taskId.equals(taskId) & s.deleted.not())
            ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
          .watch()
          .map((rows) => rows.map(toSubtask).toList());

  /// Appends a subtask to the end of the checklist.
  Future<Subtask> addSubtask(String taskId, String title) {
    return db.transaction(() async {
      final maxOrder = db.subtasks.sortOrder.max();
      final last =
          await (db.selectOnly(db.subtasks)
                ..addColumns([maxOrder])
                ..where(db.subtasks.taskId.equals(taskId)))
              .map((row) => row.read(maxOrder))
              .getSingle();
      final subtask = Subtask(
        id: newId(),
        taskId: taskId,
        title: Task.validateTitle(title),
        sortOrder: (last ?? -1) + 1,
        updatedAt: now(),
        updatedByDevice: deviceId,
      );
      await db.into(db.subtasks).insert(toSubtaskCompanion(subtask));
      return subtask;
    });
  }

  Future<void> renameSubtask(String id, String title) => _updateSubtask(
    id,
    SubtasksCompanion(title: Value(Task.validateTitle(title))),
  );

  Future<void> setSubtaskDone(String id, {required bool done}) =>
      _updateSubtask(id, SubtasksCompanion(done: Value(done)));

  Future<void> deleteSubtask(String id) =>
      _updateSubtask(id, const SubtasksCompanion(deleted: Value(true)));

  /// Rewrites sort order so subtasks appear in [orderedIds] order.
  Future<void> reorderSubtasks(List<String> orderedIds) =>
      db.transaction(() async {
        for (final (index, id) in orderedIds.indexed) {
          await _updateSubtask(id, SubtasksCompanion(sortOrder: Value(index)));
        }
      });

  Future<void> _updateSubtask(String id, SubtasksCompanion changes) =>
      (db.update(db.subtasks)..where((s) => s.id.equals(id))).write(
        changes.copyWith(
          updatedAt: Value(now()),
          updatedByDevice: Value(deviceId),
        ),
      );

  // ----------------------------------------------------------------- tags

  /// All non-deleted tags, alphabetically.
  Stream<List<Tag>> watchTags() =>
      (db.select(db.tags)
            ..where((t) => t.deleted.not())
            ..orderBy([
              (t) => OrderingTerm.asc(t.name.collate(Collate.noCase)),
            ]))
          .watch()
          .map((rows) => rows.map(toTag).toList());

  /// Ids of the tags on a task.
  Stream<Set<String>> watchTaskTagIds(String taskId) =>
      (db.select(db.taskTags)
            ..where((l) => l.taskId.equals(taskId) & l.deleted.not()))
          .watch()
          .map((rows) => {for (final row in rows) row.tagId});

  /// Returns the tag named [name] (case-insensitive), creating it if needed.
  Future<Tag> findOrCreateTag(String name) {
    final trimmed = Task.validateTitle(name);
    return db.transaction(() async {
      final existing =
          await (db.select(db.tags)
                ..where(
                  (t) =>
                      t.deleted.not() &
                      t.name.lower().equals(trimmed.toLowerCase()),
                )
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) return toTag(existing);
      final tag = Tag(
        id: newId(),
        name: trimmed,
        updatedAt: now(),
        updatedByDevice: deviceId,
      );
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: tag.id,
              name: tag.name,
              updatedAt: tag.updatedAt,
              updatedByDevice: Value(deviceId),
            ),
          );
      return tag;
    });
  }

  /// Makes [tagIds] the exact set of tags on a task. Removed links are
  /// tombstoned; re-added links revive their old row instead of duplicating.
  Future<void> setTaskTags(String taskId, Set<String> tagIds) =>
      db.transaction(() async {
        final links = await (db.select(
          db.taskTags,
        )..where((l) => l.taskId.equals(taskId))).get();
        // Live links first, so an existing live link is the one we keep.
        links.sort((a, b) => (a.deleted ? 1 : 0) - (b.deleted ? 1 : 0));
        final at = now();
        final linkedTagIds = <String>{};
        for (final link in links) {
          // Keep exactly one live link per wanted tag; tombstone the rest.
          final keep =
              tagIds.contains(link.tagId) && linkedTagIds.add(link.tagId);
          final shouldBeDeleted = !keep;
          if (link.deleted != shouldBeDeleted) {
            await (db.update(
              db.taskTags,
            )..where((l) => l.id.equals(link.id))).write(
              TaskTagsCompanion(
                deleted: Value(shouldBeDeleted),
                updatedAt: Value(at),
                updatedByDevice: Value(deviceId),
              ),
            );
          }
        }
        for (final tagId in tagIds.difference(linkedTagIds)) {
          await db
              .into(db.taskTags)
              .insert(
                TaskTagsCompanion.insert(
                  id: newId(),
                  taskId: taskId,
                  tagId: tagId,
                  updatedAt: at,
                  updatedByDevice: Value(deviceId),
                ),
              );
        }
      });

  // ------------------------------------------------- device targeting

  /// Device ids each task notifies on, for tasks that don't notify on all
  /// devices (the `notifyAllDevices` flag is false). Keyed by task id.
  Stream<Map<String, Set<String>>> watchAllTaskTargets() =>
      (db.select(
        db.taskTargetDevices,
      )..where((t) => t.deleted.not())).watch().map((rows) {
        final targets = <String, Set<String>>{};
        for (final row in rows) {
          (targets[row.taskId] ??= {}).add(row.deviceId);
        }
        return targets;
      });

  /// Makes a task notify on all devices ([all], the default, which includes
  /// devices added later) or only on [deviceIds]. Like [setTaskTags],
  /// removed targets are tombstoned and re-added ones revived.
  Future<void> setTaskTargets(
    String taskId, {
    required bool all,
    Set<String> deviceIds = const {},
  }) => db.transaction(() async {
    final at = now();
    await (db.update(db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        notifyAllDevices: Value(all),
        updatedAt: Value(at),
        updatedByDevice: Value(deviceId),
      ),
    );
    final wanted = all ? const <String>{} : deviceIds;
    final rows = await (db.select(
      db.taskTargetDevices,
    )..where((t) => t.taskId.equals(taskId))).get();
    rows.sort((a, b) => (a.deleted ? 1 : 0) - (b.deleted ? 1 : 0));
    final linked = <String>{};
    for (final row in rows) {
      final keep = wanted.contains(row.deviceId) && linked.add(row.deviceId);
      if (row.deleted == keep) {
        await (db.update(
          db.taskTargetDevices,
        )..where((t) => t.id.equals(row.id))).write(
          TaskTargetDevicesCompanion(
            deleted: Value(!keep),
            updatedAt: Value(at),
            updatedByDevice: Value(deviceId),
          ),
        );
      }
    }
    for (final target in wanted.difference(linked)) {
      await db
          .into(db.taskTargetDevices)
          .insert(
            TaskTargetDevicesCompanion.insert(
              id: newId(),
              taskId: taskId,
              deviceId: target,
              updatedAt: at,
              updatedByDevice: Value(deviceId),
            ),
          );
    }
  });

  /// [utc] moved by [days] calendar days in local wall-clock time.
  static DateTime _shiftDays(DateTime utc, int days) {
    final local = utc.toLocal();
    return DateTime(
      local.year,
      local.month,
      local.day + days,
      local.hour,
      local.minute,
    ).toUtc();
  }

  // -------------------------------------------------------------- mapping

  static Task toTask(TaskRow row) => Task(
    id: row.id,
    title: row.title,
    notes: row.notes,
    dueDate: row.dueDate,
    dueTimeMinutes: row.dueTimeMinutes,
    priority: row.priority,
    categoryId: row.categoryId,
    done: row.done,
    skipped: row.skipped,
    completedAt: row.completedAt,
    recurrenceRule: row.recurrenceRule,
    notifyAllDevices: row.notifyAllDevices,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deleted: row.deleted,
    updatedByDevice: row.updatedByDevice,
  );

  static TasksCompanion toCompanion(Task task) => TasksCompanion.insert(
    id: task.id,
    title: task.title,
    notes: Value(task.notes),
    dueDate: Value(task.dueDate),
    dueTimeMinutes: Value(task.dueTimeMinutes),
    priority: Value(task.priority),
    categoryId: Value(task.categoryId),
    done: Value(task.done),
    skipped: Value(task.skipped),
    completedAt: Value(task.completedAt),
    recurrenceRule: Value(task.recurrenceRule),
    notifyAllDevices: Value(task.notifyAllDevices),
    createdAt: task.createdAt,
    updatedAt: task.updatedAt,
    deleted: Value(task.deleted),
    updatedByDevice: Value(task.updatedByDevice),
  );

  static Subtask toSubtask(SubtaskRow row) => Subtask(
    id: row.id,
    taskId: row.taskId,
    title: row.title,
    done: row.done,
    sortOrder: row.sortOrder,
    updatedAt: row.updatedAt,
    deleted: row.deleted,
    updatedByDevice: row.updatedByDevice,
  );

  static SubtasksCompanion toSubtaskCompanion(Subtask s) =>
      SubtasksCompanion.insert(
        id: s.id,
        taskId: s.taskId,
        title: s.title,
        done: Value(s.done),
        sortOrder: s.sortOrder,
        updatedAt: s.updatedAt,
        deleted: Value(s.deleted),
        updatedByDevice: Value(s.updatedByDevice),
      );

  static Tag toTag(TagRow row) => Tag(
    id: row.id,
    name: row.name,
    updatedAt: row.updatedAt,
    deleted: row.deleted,
    updatedByDevice: row.updatedByDevice,
  );
}
