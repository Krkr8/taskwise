import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import 'test_db.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late TaskRepository repo;

  setUp(() {
    db = openTestDatabase();
    clock = FakeClock();
    repo = TaskRepository(db, deviceId: 'dev-1', clock: clock.call);
  });

  tearDown(() => db.close());

  Future<List<TaskEntry>> entries() => repo.watchEntries().first;

  group('tasks', () {
    test('create stamps ids, timestamps and device', () async {
      final task = await repo.createTask(
        title: '  Buy milk ',
        dueDate: LocalDate(2026, 10, 21),
        dueTimeMinutes: 540,
        priority: Priority.high,
      );
      expect(task.title, 'Buy milk');
      expect(task.id, hasLength(36));
      expect(task.createdAt, clock.current);
      expect(task.updatedAt, clock.current);
      expect(task.updatedByDevice, 'dev-1');
      expect(await repo.getTask(task.id), task);
    });

    test('rejects blank titles', () {
      expect(repo.createTask(title: '   '), throwsArgumentError);
    });

    test('a due time without a due date is dropped', () async {
      final task = await repo.createTask(title: 'x', dueTimeMinutes: 60);
      expect(task.dueTimeMinutes, isNull);
      final saved = await repo.saveTask(
        task.copyWith(dueTimeMinutes: () => 120),
      );
      expect(saved!.dueTimeMinutes, isNull);
    });

    test('save bumps updatedAt and keeps createdAt', () async {
      final task = await repo.createTask(title: 'x');
      clock.advance();
      final saved = await repo.saveTask(
        task.copyWith(notes: 'more', categoryId: () => 'cat'),
      );
      final loaded = await repo.getTask(task.id);
      expect(loaded, saved);
      expect(loaded!.notes, 'more');
      expect(loaded.categoryId, 'cat');
      expect(loaded.createdAt, task.createdAt);
      expect(loaded.updatedAt, clock.current);
    });

    test('saving a stale snapshot never undeletes or uncompletes', () async {
      final task = await repo.createTask(title: 'x');
      await repo.setDone(task.id, done: true);
      await repo.deleteTask(task.id);

      // e.g. the editor flushing typed text after the task was deleted.
      await repo.saveTask(task.copyWith(title: 'edited'));

      final loaded = (await repo.getTask(task.id))!;
      expect(loaded.title, 'edited');
      expect(loaded.deleted, isTrue);
      expect(loaded.done, isTrue);
      expect(loaded.createdAt, task.createdAt);
    });

    test('setDone records and clears completedAt', () async {
      final task = await repo.createTask(title: 'x');
      clock.advance();
      await repo.setDone(task.id, done: true);
      var loaded = (await repo.getTask(task.id))!;
      expect(loaded.done, isTrue);
      expect(loaded.completedAt, clock.current);
      expect(loaded.updatedAt, clock.current);

      await repo.setDone(task.id, done: false);
      loaded = (await repo.getTask(task.id))!;
      expect(loaded.done, isFalse);
      expect(loaded.completedAt, isNull);
    });

    test('delete is a tombstone that restore undoes', () async {
      final task = await repo.createTask(title: 'x');
      await repo.addSubtask(task.id, 'step');
      clock.advance();
      await repo.deleteTask(task.id);

      expect(await entries(), isEmpty);
      expect(await repo.watchTask(task.id).first, isNull);
      final tombstone = (await repo.getTask(task.id))!;
      expect(tombstone.deleted, isTrue);
      expect(tombstone.updatedAt, clock.current);

      await repo.restoreTask(task.id);
      final restored = await entries();
      expect(restored.single.task.id, task.id);
      expect(restored.single.subtaskCount, 1);
    });

    test('watchEntries emits again after a change', () async {
      final counts = repo
          .watchEntries()
          .map((list) => list.length)
          .asBroadcastStream();
      expect(await counts.first, 0);
      final next = counts.first;
      await repo.createTask(title: 'x');
      expect(await next, 1);
    });
  });

  group('subtasks', () {
    test('append in order, count done, reorder and delete', () async {
      final task = await repo.createTask(title: 'x');
      final a = await repo.addSubtask(task.id, 'a');
      final b = await repo.addSubtask(task.id, 'b');
      final c = await repo.addSubtask(task.id, 'c');
      expect([a.sortOrder, b.sortOrder, c.sortOrder], [0, 1, 2]);

      await repo.setSubtaskDone(b.id, done: true);
      var entry = (await entries()).single;
      expect(entry.subtaskCount, 3);
      expect(entry.subtasksDone, 1);

      await repo.reorderSubtasks([c.id, a.id, b.id]);
      var titles = [
        for (final s in await repo.watchSubtasks(task.id).first) s.title,
      ];
      expect(titles, ['c', 'a', 'b']);

      await repo.renameSubtask(a.id, 'A');
      await repo.deleteSubtask(c.id);
      titles = [
        for (final s in await repo.watchSubtasks(task.id).first) s.title,
      ];
      expect(titles, ['A', 'b']);
      entry = (await entries()).single;
      expect(entry.subtaskCount, 2);
    });

    test('new subtasks go after deleted ones', () async {
      final task = await repo.createTask(title: 'x');
      final a = await repo.addSubtask(task.id, 'a');
      await repo.deleteSubtask(a.id);
      final b = await repo.addSubtask(task.id, 'b');
      expect(b.sortOrder, 1);
    });
  });

  group('tags', () {
    test('findOrCreateTag is case-insensitive', () async {
      final a = await repo.findOrCreateTag('Errand');
      final b = await repo.findOrCreateTag(' errand ');
      expect(b.id, a.id);
      expect((await repo.watchTags().first).map((t) => t.name), ['Errand']);
    });

    test('setTaskTags adds, removes and revives links', () async {
      final task = await repo.createTask(title: 'x');
      final home = await repo.findOrCreateTag('home');
      final work = await repo.findOrCreateTag('work');

      await repo.setTaskTags(task.id, {home.id, work.id});
      expect(await repo.watchTaskTagIds(task.id).first, {home.id, work.id});
      expect((await entries()).single.tagIds, {home.id, work.id});

      await repo.setTaskTags(task.id, {work.id});
      expect(await repo.watchTaskTagIds(task.id).first, {work.id});

      await repo.setTaskTags(task.id, {home.id, work.id});
      expect(await repo.watchTaskTagIds(task.id).first, {home.id, work.id});
      // The home link was revived, not duplicated.
      final links = await db.select(db.taskTags).get();
      expect(links, hasLength(2));
    });
  });
}
