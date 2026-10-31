import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/app_settings.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/reminder_repository.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import 'test_db.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late TaskRepository tasks;
  late ReminderRepository reminders;
  late SettingsRepository settings;

  setUp(() {
    db = openTestDatabase();
    clock = FakeClock();
    tasks = TaskRepository(db, deviceId: 'dev', clock: clock.call);
    reminders = ReminderRepository(db, deviceId: 'dev', clock: clock.call);
    settings = SettingsRepository(db, deviceId: 'dev', clock: clock.call);
  });

  tearDown(() => db.close());

  group('reminders', () {
    test('add, list in order and delete', () async {
      final task = await tasks.createTask(title: 'x');
      await reminders.addAbsolute(task.id, DateTime.utc(2026, 10, 22, 7));
      await reminders.addRelative(task.id, 0);
      await reminders.addRelative(task.id, 60);
      await reminders.addRelative(task.id, 60); // duplicate, ignored

      var list = await reminders.watchForTask(task.id).first;
      expect(list.map((r) => r.minutesBeforeDue), [60, 0, null]);
      expect(list.last.absoluteAt, DateTime.utc(2026, 10, 22, 7));
      expect(await reminders.hasReminders(task.id), isTrue);

      await reminders.delete(list.first.id);
      list = await reminders.watchForTask(task.id).first;
      expect(list.length, 2);
      expect((await reminders.watchTimeReminders().first).length, 2);
    });

    test('completing a repeating task copies its reminders', () async {
      final task = await tasks.createTask(
        title: 'Gym',
        dueDate: LocalDate(2026, 10, 20),
        dueTimeMinutes: 18 * 60,
      );
      await tasks.saveTask(
        task.copyWith(recurrenceRule: () => 'DTSTART=20261020;FREQ=WEEKLY'),
      );
      await reminders.addRelative(task.id, 30);
      final absolute = DateTime(2026, 10, 20, 12).toUtc();
      await reminders.addAbsolute(task.id, absolute);

      final completion = await tasks.setDone(task.id, done: true);
      final copied = await reminders.watchForTask(completion.nextTaskId!).first;
      expect(copied.first.minutesBeforeDue, 30);
      // Moved a week, same local time.
      expect(copied.last.absoluteAt!.toLocal(), DateTime(2026, 10, 27, 12));
      // The done copy keeps its own reminders (they no longer fire).
      expect((await reminders.watchForTask(task.id).first).length, 2);
    });
  });

  group('reminder settings', () {
    test('defaults', () async {
      final s = await settings.loadSettings();
      expect(s.defaultReminder, DefaultReminder.none);
      expect(s.snoozeMinutes, [5, 15, 60]);
      expect(s.allDayReminderMinutes, 9 * 60);
      expect(s.keepRunningInBackground, isTrue);
      expect(s.startOnLogin, isFalse);
    });

    test('store and read back', () async {
      await settings.setDefaultReminder(DefaultReminder.min15);
      await settings.setSnoozeMinutes([60, 10, 10, 30, 120]);
      await settings.setAllDayReminderMinutes(8 * 60);
      await settings.setKeepRunningInBackground(false);
      await settings.setStartOnLogin(true);
      final s = await settings.loadSettings();
      expect(s.defaultReminder, DefaultReminder.min15);
      expect(s.snoozeMinutes, [10, 30, 60]);
      expect(s.allDayReminderMinutes, 8 * 60);
      expect(s.keepRunningInBackground, isFalse);
      expect(s.startOnLogin, isTrue);
    });

    test('snoozes drop expired ones', () async {
      final day = LocalDate(2026, 10, 20);
      await settings.addSnooze(
        Snooze(taskId: 'a', occurrence: day, until: clock.current),
      );
      clock.advance(const Duration(minutes: 5));
      await settings.addSnooze(
        Snooze(
          taskId: 'b',
          occurrence: day,
          until: clock.current.add(const Duration(minutes: 10)),
        ),
      );
      expect((await settings.getSnoozes()).map((s) => s.taskId), ['b']);
    });

    test('remembers when reminders were last checked', () async {
      expect(await settings.getRemindersCheckedAt(), isNull);
      await settings.setRemindersCheckedAt(clock.current);
      expect(await settings.getRemindersCheckedAt(), clock.current);
    });
  });
}
