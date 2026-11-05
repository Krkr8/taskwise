import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/background/background_sync.dart';
import 'package:taskwise/data/app_settings.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/place_repository.dart';
import 'package:taskwise/data/repositories/reminder_repository.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise/location/location_platform.dart';
import 'package:taskwise/location/location_reminder_sync.dart';
import 'package:taskwise/notifications/notifier.dart';
import 'package:taskwise/notifications/reminder_scheduler.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeClock clock;
  late TaskRepository tasks;
  late ReminderRepository reminders;
  late PlaceRepository places;
  late FakeLocationPlatform platform;
  late ProviderContainer container;

  setUp(() {
    db = openTestDatabase();
    clock = FakeClock();
    tasks = TaskRepository(db, deviceId: 'phone', clock: clock.call);
    reminders = ReminderRepository(db, deviceId: 'phone', clock: clock.call);
    places = PlaceRepository(db, deviceId: 'phone', clock: clock.call);
    platform = FakeLocationPlatform();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue('phone'),
        clockProvider.overrideWithValue(clock.call),
        locationPlatformProvider.overrideWithValue(platform),
        initialSettingsProvider.overrideWithValue(
          const AppSettings(language: AppLanguage.en),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Lets the streams load, then plans and applies.
  Future<List<NativeLocationEntry>> apply() async {
    // Riverpod pauses providers nobody listens to (the app root watches it).
    container.listen(locationReminderSyncProvider, (_, _) {});
    final sync = container.read(locationReminderSyncProvider);
    await Future.wait([
      container.read(taskEntriesProvider.future),
      container.read(locationRemindersProvider.future),
      container.read(placesProvider.future),
      container.read(taskTargetsProvider.future),
    ]);
    // Let the streams catch up with the latest writes.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await sync.apply(), isTrue);
    return platform.lastEntries ?? const [];
  }

  test('hands the open tasks\' location reminders to the phone', () async {
    final home = await places.createPlace(
      name: 'Home',
      latitude: 33.31,
      longitude: 44.36,
    );
    final bread = await tasks.createTask(title: 'Buy bread');
    final done = await tasks.createTask(title: 'Old');
    await reminders.addLocation(
      bread.id,
      placeId: home.id,
      radiusMeters: 30,
      trigger: LocationTrigger.arrive,
    );
    await reminders.addLocation(
      bread.id,
      latitude: 33.3,
      longitude: 44.4,
      radiusMeters: 60,
      trigger: LocationTrigger.leave,
    );
    await reminders.addLocation(
      done.id,
      latitude: 1,
      longitude: 2,
      radiusMeters: 30,
      trigger: LocationTrigger.arrive,
    );
    await tasks.setDone(done.id, done: true);

    final entries = await apply();
    expect(entries.length, 2);
    final arrive = entries.firstWhere((e) => e.arrive);
    expect(arrive.title, 'Buy bread');
    expect(arrive.body, "You're at Home");
    expect(arrive.latitude, 33.31);
    final leave = entries.firstWhere((e) => !e.arrive);
    expect(leave.body, 'You left the place for this task');
    expect(leave.radiusMeters, 60);

    // Done and Snooze on the notification know it's a location reminder.
    final action = ActionIds.parse(ActionIds.done, arrive.payload);
    expect(action, isA<DoneAction>());
    expect(action!.taskId, bread.id);
    expect(action.fromLocation, isTrue);
  });

  test('skips tasks that don\'t notify on this phone', () async {
    final task = await tasks.createTask(title: 'Laptop only');
    await reminders.addLocation(
      task.id,
      latitude: 33.3,
      longitude: 44.4,
      radiusMeters: 30,
      trigger: LocationTrigger.arrive,
    );
    await tasks.setTaskTargets(task.id, all: false, deviceIds: {'pc'});
    expect(await apply(), isEmpty);
  });

  test('does nothing on desktop', () async {
    final desktop = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue('pc'),
      ],
    );
    addTearDown(desktop.dispose);
    desktop.listen(locationReminderSyncProvider, (_, _) {});
    expect(await desktop.read(locationReminderSyncProvider).apply(), isFalse);
    expect(
      desktop.read(locationPermissionProvider),
      LocationPermission.unsupported,
    );
  });

  test('a background run re-plans notifications and places', () async {
    final notifier = NoopNotifier();
    final background = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue('phone'),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 20, 8)),
        locationPlatformProvider.overrideWithValue(platform),
        reminderNotifierProvider.overrideWithValue(notifier),
      ],
    );
    addTearDown(background.dispose);
    final task = await tasks.createTask(
      title: 'Call the bank',
      dueDate: LocalDate(2026, 10, 20),
      dueTimeMinutes: 10 * 60,
    );
    await reminders.addRelative(task.id, 0);
    await reminders.addLocation(
      task.id,
      latitude: 33.3,
      longitude: 44.4,
      radiusMeters: 30,
      trigger: LocationTrigger.arrive,
    );

    // Not signed in: the sync step does nothing.
    await syncOnceInBackground(background);
    await refreshReminders(background);
    expect(notifier.lastPlan.single.taskId, task.id);
    expect(platform.lastEntries!.single.title, 'Call the bank');
  });
}
