import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/assistant/assistant_sync.dart';
import 'package:taskwise/background/background_sync.dart';
import 'package:taskwise/data/app_settings.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/reminder_repository.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/test_db.dart';
import 'fake_assistant_platform.dart';

AssistantInboxEntry entry(
  String id,
  String title, {
  LocalDate? due,
  int? time,
}) => AssistantInboxEntry(
  id: id,
  title: title,
  dueDate: due,
  dueTimeMinutes: time,
  createdAt: DateTime.utc(2026, 10, 20, 8),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeClock clock;
  late TaskRepository tasks;
  late ReminderRepository reminders;
  late FakeAssistantPlatform platform;
  late ProviderContainer container;

  ProviderContainer makeContainer({
    DefaultReminder defaultReminder = DefaultReminder.none,
  }) => ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      deviceIdProvider.overrideWithValue('phone'),
      clockProvider.overrideWithValue(clock.call),
      assistantPlatformProvider.overrideWithValue(platform),
      initialSettingsProvider.overrideWithValue(
        AppSettings(language: AppLanguage.en, defaultReminder: defaultReminder),
      ),
    ],
  );

  setUp(() {
    db = openTestDatabase();
    clock = FakeClock(DateTime(2026, 10, 20, 9));
    tasks = TaskRepository(db, deviceId: 'phone', clock: clock.call);
    reminders = ReminderRepository(db, deviceId: 'phone', clock: clock.call);
    platform = FakeAssistantPlatform();
    container = makeContainer();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  AssistantSync sync() {
    // Riverpod pauses providers nobody listens to (the app root watches it).
    container.listen(assistantSyncProvider, (_, _) {});
    return container.read(assistantSyncProvider);
  }

  test('moves Siri\'s tasks into the database and empties the inbox', () async {
    final s = sync();
    await s.importInbox(); // the start-up import (empty)
    platform.inbox.addAll([
      entry('id-1', 'Buy milk'),
      entry('id-2', 'Call mum', due: LocalDate(2026, 10, 21), time: 17 * 60),
    ]);
    expect(await s.importInbox(), 2);
    expect(platform.inbox, isEmpty);

    final milk = (await tasks.getTask('id-1'))!;
    expect(milk.title, 'Buy milk');
    expect(milk.dueDate, isNull);
    expect(milk.updatedByDevice, 'phone');
    final mum = (await tasks.getTask('id-2'))!;
    expect(mum.dueDate, LocalDate(2026, 10, 21));
    expect(mum.dueTimeMinutes, 17 * 60);

    // Queued for upload like any other new task.
    final outbox = await db.select(db.syncOutbox).get();
    expect(
      outbox.where((o) => o.recordType == 'task').map((o) => o.recordId),
      containsAll(['id-1', 'id-2']),
    );
  });

  test('importing the same entry twice adds one task', () async {
    final s = sync();
    platform.inbox.add(entry('id-1', 'Buy milk'));
    await s.importInbox();
    // The inbox wasn't emptied (e.g. the app was killed before the ack).
    platform.inbox.add(entry('id-1', 'Buy milk'));
    expect(await s.importInbox(), 0);
    expect(platform.inbox, isEmpty);
    final rows = await db.select(db.tasks).get();
    expect(rows.length, 1);
  });

  test('a task added by Siri and then deleted is not brought back', () async {
    final s = sync();
    platform.inbox.add(entry('id-1', 'Buy milk'));
    await s.importInbox();
    await tasks.deleteTask('id-1');
    platform.inbox.add(entry('id-1', 'Buy milk'));
    expect(await s.importInbox(), 0);
    expect((await tasks.getTask('id-1'))!.deleted, isTrue);
  });

  test('a task with a time gets the default reminder', () async {
    container.dispose();
    container = makeContainer(defaultReminder: DefaultReminder.min15);
    final s = sync();
    platform.inbox.addAll([
      entry('timed', 'Dentist', due: LocalDate(2026, 10, 21), time: 10 * 60),
      entry('all-day', 'Bins', due: LocalDate(2026, 10, 21)),
    ]);
    await s.importInbox();
    final timed = await (db.select(
      db.reminders,
    )..where((r) => r.taskId.equals('timed'))).get();
    expect(timed.single.minutesBeforeDue, 15);
    expect(await reminders.hasReminders('all-day'), isFalse);
  });

  test('Siri adding a task while Taskwise is open imports it', () async {
    final s = sync();
    await s.importInbox();
    platform.inbox.add(entry('id-1', 'Buy milk'));
    platform.events$.add(null);
    await Future<void>.delayed(Duration.zero);
    await s.importInbox(); // waits for the running import
    expect(await tasks.getTask('id-1'), isNotNull);
  });

  test('hands Siri the open tasks that are due, and only on changes', () async {
    final s = sync();
    await tasks.createTask(title: 'Today', dueDate: LocalDate(2026, 10, 20));
    await tasks.createTask(title: 'Someday');
    await container.read(taskEntriesProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await s.applySnapshot(), isTrue);
    expect(jsonEncode(platform.snapshot), contains('"Today"'));
    expect(jsonEncode(platform.snapshot), isNot(contains('Someday')));
    expect(await s.applySnapshot(), isTrue);
    expect(platform.snapshotWrites, 1);
  });

  test('the background run imports Siri\'s tasks', () async {
    platform.inbox.add(entry('id-1', 'Buy milk'));
    await importAssistantInbox(container);
    expect(await tasks.getTask('id-1'), isNotNull);
  });

  test('does nothing without an inbox (desktop, Android)', () async {
    platform = FakeAssistantPlatform(hasInbox: false);
    container.dispose();
    container = makeContainer();
    platform.inbox.add(entry('id-1', 'Buy milk'));
    expect(await sync().importInbox(), 0);
    expect(await sync().applySnapshot(), isFalse);
    expect(await tasks.getTask('id-1'), isNull);
  });
}
