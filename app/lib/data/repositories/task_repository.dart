import 'package:drift/drift.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../db/app_database.dart';
import 'repository_base.dart';

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
            task: _toTask(db.tasks.map(row.data)),
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
          .map((row) => row == null ? null : _toTask(row));

  Future<Task?> getTask(String id) async {
    final row = await (db.select(
      db.tasks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toTask(row);
  }

  /// Creates a task. Throws [ArgumentError] if [title] is blank.
  Future<Task> createTask({
    required String title,
    LocalDate? dueDate,
    int? dueTimeMinutes,
    Priority priority = Priority.none,
    String? categoryId,
  }) async {
    final at = now();
    final task = Task(
      id: newId(),
      title: Task.validateTitle(title),
      dueDate: dueDate,
      dueTimeMinutes: dueDate == null ? null : dueTimeMinutes,
      priority: priority,
      categoryId: categoryId,
      createdAt: at,
      updatedAt: at,
      updatedByDevice: deviceId,
    );
    await db.into(db.tasks).insert(_toCompanion(task));
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

  /// Marks a task done (recording when) or not done.
  Future<void> setDone(String id, {required bool done}) async {
    final at = now();
    await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        done: Value(done),
        completedAt: Value(done ? at : null),
        updatedAt: Value(at),
        updatedByDevice: Value(deviceId),
      ),
    );
  }

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
          .map((rows) => rows.map(_toSubtask).toList());

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
      await db.into(db.subtasks).insert(_toSubtaskCompanion(subtask));
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
          .map((rows) => rows.map(_toTag).toList());

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
      if (existing != null) return _toTag(existing);
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

  // -------------------------------------------------------------- mapping

  static Task _toTask(TaskRow row) => Task(
    id: row.id,
    title: row.title,
    notes: row.notes,
    dueDate: row.dueDate,
    dueTimeMinutes: row.dueTimeMinutes,
    priority: row.priority,
    categoryId: row.categoryId,
    done: row.done,
    completedAt: row.completedAt,
    recurrenceRule: row.recurrenceRule,
    notifyAllDevices: row.notifyAllDevices,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deleted: row.deleted,
    updatedByDevice: row.updatedByDevice,
  );

  static TasksCompanion _toCompanion(Task task) => TasksCompanion.insert(
    id: task.id,
    title: task.title,
    notes: Value(task.notes),
    dueDate: Value(task.dueDate),
    dueTimeMinutes: Value(task.dueTimeMinutes),
    priority: Value(task.priority),
    categoryId: Value(task.categoryId),
    done: Value(task.done),
    completedAt: Value(task.completedAt),
    recurrenceRule: Value(task.recurrenceRule),
    notifyAllDevices: Value(task.notifyAllDevices),
    createdAt: task.createdAt,
    updatedAt: task.updatedAt,
    deleted: Value(task.deleted),
    updatedByDevice: Value(task.updatedByDevice),
  );

  static Subtask _toSubtask(SubtaskRow row) => Subtask(
    id: row.id,
    taskId: row.taskId,
    title: row.title,
    done: row.done,
    sortOrder: row.sortOrder,
    updatedAt: row.updatedAt,
    deleted: row.deleted,
    updatedByDevice: row.updatedByDevice,
  );

  static SubtasksCompanion _toSubtaskCompanion(Subtask s) =>
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

  static Tag _toTag(TagRow row) => Tag(
    id: row.id,
    name: row.name,
    updatedAt: row.updatedAt,
    deleted: row.deleted,
    updatedByDevice: row.updatedByDevice,
  );
}
