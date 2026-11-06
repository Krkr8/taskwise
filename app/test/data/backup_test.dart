import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/backup.dart';
import 'package:taskwise/data/repositories/category_repository.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import 'test_db.dart';

void main() {
  test(
    'export, then import into an empty device, gives the same data',
    () async {
      final a = openTestDatabase();
      final clock = FakeClock();
      final tasks = TaskRepository(a, deviceId: 'a', clock: clock.call);
      final home = await CategoryRepository(
        a,
        deviceId: 'a',
        clock: clock.call,
      ).createCategory('Home', 0xFF43A047);
      final task = await tasks.createTask(
        title: 'Water the plants',
        dueDate: LocalDate(2026, 10, 21),
        categoryId: home.id,
      );
      await tasks.addSubtask(task.id, 'Balcony');
      await tasks.setTaskTags(task.id, {
        (await tasks.findOrCreateTag('home')).id,
      });
      await SettingsRepository(
        a,
        deviceId: 'a',
        clock: clock.call,
      ).setWeekStart(WeekStart.monday);
      final gone = await tasks.createTask(title: 'Deleted one');
      await tasks.deleteTask(gone.id);

      final json = await Backup(a, deviceId: 'a', clock: clock.call).export();
      final decoded = jsonDecode(json) as Map<String, Object?>;
      expect(decoded['format'], 'taskwise-backup');
      expect(json, isNot(contains('Deleted one')));

      final b = openTestDatabase();
      final report = await Backup(b, deviceId: 'b').import(json);
      expect(report.added, 6); // setting, category, tag, task, subtask, link
      expect(report.skipped, 0);

      final restored = TaskRepository(b, deviceId: 'b');
      final copy = (await restored.getTask(task.id))!;
      expect(copy.title, 'Water the plants');
      expect(copy.categoryId, home.id);
      expect(
        (await restored.watchSubtasks(task.id).first).single.title,
        'Balcony',
      );
      expect(
        (await SettingsRepository(b, deviceId: 'b').loadSettings()).weekStart,
        WeekStart.monday,
      );
      // Imported records go to the other devices on the next sync.
      expect(await b.select(b.syncOutbox).get(), hasLength(6));

      // Exporting again gives the same records.
      final again = jsonDecode(await Backup(b, deviceId: 'b').export()) as Map;
      expect(again['records'], decoded['records']);
      await a.close();
      await b.close();
    },
  );

  test(
    'a newer edit on this device is kept; a deleted task comes back',
    () async {
      final db = openTestDatabase();
      final clock = FakeClock();
      final tasks = TaskRepository(db, deviceId: 'd', clock: clock.call);
      final edited = await tasks.createTask(title: 'Old title');
      final deleted = await tasks.createTask(title: 'Call grandma');
      final backup = Backup(db, deviceId: 'd', clock: clock.call);
      final json = await backup.export();

      clock.advance();
      await tasks.saveTask(edited.copyWith(title: 'New title'));
      await tasks.deleteTask(deleted.id);
      clock.advance();

      final report = await backup.import(json);
      expect(report, (added: 0, updated: 1, kept: 1, skipped: 0));
      expect((await tasks.getTask(edited.id))!.title, 'New title');
      final back = (await tasks.getTask(deleted.id))!;
      expect(back.deleted, isFalse);
      expect(back.updatedAt.isAfter(deleted.updatedAt), isTrue);
      await db.close();
    },
  );

  test(
    'wrong files and newer formats are refused; bad records skipped',
    () async {
      final db = openTestDatabase();
      final backup = Backup(db, deviceId: 'd');
      Matcher refused(BackupProblem p) => throwsA(
        isA<BackupException>().having((e) => e.problem, 'problem', p),
      );
      expect(backup.import('not json'), refused(BackupProblem.notABackup));
      expect(backup.import('{"a": 1}'), refused(BackupProblem.notABackup));
      expect(
        backup.import(
          '{"format": "taskwise-backup", "version": 2, "records": []}',
        ),
        refused(BackupProblem.tooNew),
      );
      final report = await backup.import(
        jsonEncode({
          'format': 'taskwise-backup',
          'version': 1,
          'records': [
            {
              'type': 'spaceship',
              'record': {'id': 'x'},
            },
            {
              'type': 'task',
              'record': {'id': 'y'},
            },
            'nonsense',
          ],
        }),
      );
      expect(report.skipped, 3);
      expect(await db.select(db.tasks).get(), isEmpty);
      await db.close();
    },
  );
}
