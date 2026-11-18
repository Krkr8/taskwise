import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:taskwise/data/repositories/reminder_repository.dart';
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

  group('repeating tasks', () {
    // The fake clock's "today" is Tuesday 2026-10-20.
    Future<Task> repeating(String rule, {LocalDate? due}) async {
      final task = await repo.createTask(
        title: 'Gym',
        dueDate: due ?? LocalDate(2026, 10, 20),
        dueTimeMinutes: 18 * 60,
        priority: Priority.high,
      );
      return (await repo.saveTask(task.copyWith(recurrenceRule: () => rule)))!;
    }

    test(
      'completing creates the next occurrence and keeps a done copy',
      () async {
        final task = await repeating(
          'DTSTART=20261019;FREQ=WEEKLY;BYDAY=MO,WE',
        );
        final step = await repo.addSubtask(task.id, 'Stretch');
        await repo.setSubtaskDone(step.id, done: true);
        final tag = await repo.findOrCreateTag('health');
        await repo.setTaskTags(task.id, {tag.id});

        final completion = await repo.setDone(task.id, done: true);

        final done = (await repo.getTask(task.id))!;
        expect(done.done, isTrue);
        expect(done.recurrenceRule, isNull);
        expect(completion.rule, task.recurrenceRule);

        final next = (await repo.getTask(completion.nextTaskId!))!;
        expect(next.done, isFalse);
        expect(next.dueDate, LocalDate(2026, 10, 21));
        expect(next.dueTimeMinutes, 18 * 60);
        expect(next.priority, Priority.high);
        expect(next.recurrenceRule, task.recurrenceRule);
        final nextSubtasks = await repo.watchSubtasks(next.id).first;
        expect(nextSubtasks.single.title, 'Stretch');
        expect(nextSubtasks.single.done, isFalse);
        expect(await repo.watchTaskTagIds(next.id).first, {tag.id});
      },
    );

    test('an overdue task skips to today or later', () async {
      final task = await repeating(
        'DTSTART=20261010;FREQ=DAILY',
        due: LocalDate(2026, 10, 10),
      );
      final completion = await repo.setDone(task.id, done: true);
      final next = (await repo.getTask(completion.nextTaskId!))!;
      expect(next.dueDate, LocalDate(2026, 10, 20));
    });

    test('a finished series makes no copy', () async {
      final task = await repeating(
        'DTSTART=20261019;FREQ=DAILY;UNTIL=20261020',
      );
      final completion = await repo.setDone(task.id, done: true);
      expect(completion.nextTaskId, isNull);
      expect((await entries()).length, 1);
    });

    test('undo removes the copy and restores the rule', () async {
      final task = await repeating('DTSTART=20261020;FREQ=DAILY');
      final completion = await repo.setDone(task.id, done: true);
      await repo.undoCompletion(task.id, completion);

      final restored = (await repo.getTask(task.id))!;
      expect(restored.done, isFalse);
      expect(restored.recurrenceRule, task.recurrenceRule);
      expect((await repo.getTask(completion.nextTaskId!))!.deleted, isTrue);
      expect((await entries()).single.task.id, task.id);
    });

    test('an invalid rule completes like a normal task', () async {
      final task = await repeating('nonsense');
      final completion = await repo.setDone(task.id, done: true);
      expect(completion.nextTaskId, isNull);
      expect((await repo.getTask(task.id))!.recurrenceRule, 'nonsense');
    });

    test('complete, undo, complete again leaves one live copy', () async {
      final task = await repeating('DTSTART=20261020;FREQ=DAILY');
      await repo.addSubtask(task.id, 'Stretch');
      final first = await repo.setDone(task.id, done: true);
      await repo.undoCompletion(task.id, first);
      final second = await repo.setDone(task.id, done: true);

      expect(second.nextTaskId, first.nextTaskId);
      final open = (await entries()).where((e) => !e.task.done).toList();
      expect(open.single.task.id, second.nextTaskId);
      expect(open.single.subtaskCount, 1);
    });
  });

  group('skip', () {
    test('a skipped task is done and marked skipped', () async {
      final task = await repo.createTask(title: 'Call');
      await repo.setDone(task.id, done: true, skipped: true);
      final skipped = (await repo.getTask(task.id))!;
      expect(skipped.done, isTrue);
      expect(skipped.skipped, isTrue);
      expect(skipped.completedAt, isNotNull);

      await repo.setDone(task.id, done: false);
      final reopened = (await repo.getTask(task.id))!;
      expect(reopened.done, isFalse);
      expect(reopened.skipped, isFalse);
    });

    test('completing never marks a task skipped', () async {
      final task = await repo.createTask(title: 'Call');
      await repo.setDone(task.id, done: true);
      expect((await repo.getTask(task.id))!.skipped, isFalse);
    });

    test(
      'skipping a repeating task makes the next one; undo reverses it',
      () async {
        final task = await repo.createTask(
          title: 'Gym',
          dueDate: LocalDate(2026, 10, 20),
        );
        await repo.saveTask(
          task.copyWith(recurrenceRule: () => 'DTSTART=20261020;FREQ=DAILY'),
        );
        final completion = await repo.setDone(
          task.id,
          done: true,
          skipped: true,
        );
        final next = (await repo.getTask(completion.nextTaskId!))!;
        expect(next.dueDate, LocalDate(2026, 10, 21));
        expect(next.skipped, isFalse);
        expect(next.done, isFalse);

        await repo.undoCompletion(task.id, completion);
        final restored = (await repo.getTask(task.id))!;
        expect(restored.done, isFalse);
        expect(restored.skipped, isFalse);
        expect(restored.recurrenceRule, 'DTSTART=20261020;FREQ=DAILY');
        expect((await repo.getTask(next.id))!.deleted, isTrue);
      },
    );
  });

  group('missed repeats', () {
    // The fake clock's "today" is Tuesday 2026-10-20.
    final today = LocalDate(2026, 10, 20);
    const daily = 'DTSTART=20261016;FREQ=DAILY';

    Future<Task> overdueDaily(TaskRepository repo) async {
      final task = await repo.createTask(
        title: 'Water plants',
        dueDate: LocalDate(2026, 10, 16),
      );
      return (await repo.saveTask(task.copyWith(recurrenceRule: () => daily)))!;
    }

    test(
      'an unfinished repeat stays overdue and a copy appears today',
      () async {
        final task = await overdueDaily(repo);
        final a = await repo.addSubtask(task.id, 'Kitchen');
        await repo.addSubtask(task.id, 'Balcony');
        await repo.setSubtaskDone(a.id, done: true);
        final tag = await repo.findOrCreateTag('home');
        await repo.setTaskTags(task.id, {tag.id});
        final reminders = ReminderRepository(
          db,
          deviceId: 'dev-1',
          clock: clock.call,
        );
        await reminders.addRelative(task.id, 30);

        expect(await repo.rollOverMissedRepeats(today), 1);

        final old = (await repo.getTask(task.id))!;
        expect(old.done, isFalse);
        expect(old.dueDate, LocalDate(2026, 10, 16));
        expect(old.recurrenceRule, isNull);

        final open = (await entries()).where((e) => e.task.id != task.id);
        final copy = open.single;
        expect(copy.task.dueDate, today);
        expect(copy.task.recurrenceRule, daily);
        expect(copy.task.done, isFalse);
        expect(copy.subtaskCount, 2);
        expect(copy.subtasksDone, 0);
        expect(copy.tagIds, {tag.id});
        expect(
          (await reminders.watchForTask(copy.task.id).first)
              .single
              .minutesBeforeDue,
          30,
        );

        expect(await repo.rollOverMissedRepeats(today), 0);
        expect((await entries()).length, 2);
      },
    );

    test('two devices rolling over make the same copy', () async {
      final task = await overdueDaily(repo);
      await repo.addSubtask(task.id, 'Kitchen');
      final tag = await repo.findOrCreateTag('home');
      await repo.setTaskTags(task.id, {tag.id});
      await ReminderRepository(
        db,
        deviceId: 'dev-1',
        clock: clock.call,
      ).addRelative(task.id, 30);

      // A second device with the same records (as after a sync).
      final other = openTestDatabase();
      addTearDown(other.close);
      for (final table in [
        'tasks',
        'subtasks',
        'tags',
        'task_tags',
        'reminders',
      ]) {
        final rows = await db.customSelect('SELECT * FROM $table').get();
        for (final row in rows) {
          final columns = row.data.keys.toList();
          await other.customInsert(
            'INSERT INTO $table (${columns.join(', ')}) '
            'VALUES (${List.filled(columns.length, '?').join(', ')})',
            variables: [for (final c in columns) Variable(row.data[c])],
          );
        }
      }
      final otherRepo = TaskRepository(
        other,
        deviceId: 'dev-2',
        clock: clock.call,
      );

      await repo.rollOverMissedRepeats(today);
      await otherRepo.rollOverMissedRepeats(today);

      Future<List<String>> ids(AppDatabase d, String table) async => [
        for (final row
            in await d.customSelect('SELECT id FROM $table ORDER BY id').get())
          row.read<String>('id'),
      ];
      for (final table in ['tasks', 'subtasks', 'task_tags', 'reminders']) {
        expect(await ids(other, table), await ids(db, table), reason: table);
      }
    });

    test('opened every day, only the first missed one stays', () async {
      final task = await overdueDaily(repo); // due Oct 16
      // The app runs on Oct 17, 18, 19 and 20 while the task is ignored.
      for (var day = 17; day <= 20; day++) {
        await repo.rollOverMissedRepeats(LocalDate(2026, 10, day));
      }
      final open = [
        for (final e in await entries())
          if (!e.task.done) e.task,
      ]..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
      expect(
        [for (final t in open) t.dueDate],
        [LocalDate(2026, 10, 16), LocalDate(2026, 10, 20)],
      );
      expect(open.first.id, task.id);
      expect(open.first.recurrenceRule, isNull);
      expect(open.last.recurrenceRule, daily);
    });

    test('after the first missed one is deleted, the next one stays', () async {
      final task = await overdueDaily(repo); // due Oct 16
      await repo.rollOverMissedRepeats(LocalDate(2026, 10, 17));
      await repo.deleteTask(task.id);
      await repo.rollOverMissedRepeats(LocalDate(2026, 10, 18));
      final open = [
        for (final e in await entries())
          if (!e.task.done) e.task.dueDate,
      ]..sort();
      expect(open, [LocalDate(2026, 10, 17), LocalDate(2026, 10, 18)]);
    });

    test('a ticked occurrence ends the chain', () async {
      final task = await overdueDaily(repo); // due Oct 16
      await repo.rollOverMissedRepeats(LocalDate(2026, 10, 17));
      await repo.setDone(task.id, done: true);
      await repo.rollOverMissedRepeats(LocalDate(2026, 10, 18));
      final open = [
        for (final e in await entries())
          if (!e.task.done) e.task.dueDate,
      ]..sort();
      expect(open, [LocalDate(2026, 10, 17), LocalDate(2026, 10, 18)]);
    });

    test('roll-over writes lose to newer changes from other devices', () async {
      final task = await overdueDaily(repo);
      await repo.rollOverMissedRepeats(today);
      final old = (await repo.getTask(task.id))!;
      expect(
        old.updatedAt,
        task.updatedAt.add(const Duration(milliseconds: 1)),
      );
      final copy = (await entries())
          .firstWhere((e) => e.task.id != task.id)
          .task;
      expect(copy.updatedAt, old.updatedAt);
    });

    test('a live copy is never overwritten', () async {
      final task = await overdueDaily(repo);
      await repo.addSubtask(task.id, 'Kitchen');
      await repo.rollOverMissedRepeats(today);
      final copy = (await entries())
          .firstWhere((e) => e.task.id != task.id)
          .task;
      final step = (await repo.watchSubtasks(copy.id).first).single;
      await repo.setSubtaskDone(step.id, done: true);
      await repo.saveTask(copy.copyWith(title: 'Water the garden'));

      // The old task gets its rule back (say, an older device's edit won).
      final old = (await repo.getTask(task.id))!;
      await repo.saveTask(old.copyWith(recurrenceRule: () => daily));
      await repo.rollOverMissedRepeats(today);

      expect((await repo.getTask(copy.id))!.title, 'Water the garden');
      expect((await repo.watchSubtasks(copy.id).first).single.done, isTrue);
    });

    test('a copy removed by Undo comes back newer than its removal', () async {
      final task = await overdueDaily(repo);
      final completion = await repo.setDone(task.id, done: true);
      clock.advance(const Duration(hours: 1));
      await repo.undoCompletion(task.id, completion);
      final removed = (await repo.getTask(completion.nextTaskId!))!;
      expect(removed.deleted, isTrue);

      await repo.rollOverMissedRepeats(today);
      final back = (await repo.getTask(completion.nextTaskId!))!;
      expect(back.deleted, isFalse);
      expect(back.updatedAt.isAfter(removed.updatedAt), isTrue);
    });

    test('the copy notifies on the same devices', () async {
      final task = await overdueDaily(repo);
      await repo.setTaskTargets(task.id, all: false, deviceIds: {'phone'});
      await repo.rollOverMissedRepeats(today);
      final copy = (await entries())
          .firstWhere((e) => e.task.id != task.id)
          .task;
      expect(copy.notifyAllDevices, isFalse);
      expect((await repo.watchAllTaskTargets().first)[copy.id], {'phone'});
    });

    test('a series that has ended is left alone', () async {
      final task = await repo.createTask(
        title: 'Course',
        dueDate: LocalDate(2026, 10, 16),
      );
      const ended = 'DTSTART=20261014;FREQ=DAILY;COUNT=3';
      await repo.saveTask(task.copyWith(recurrenceRule: () => ended));

      expect(await repo.rollOverMissedRepeats(today), 0);
      expect((await repo.getTask(task.id))!.recurrenceRule, ended);
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
