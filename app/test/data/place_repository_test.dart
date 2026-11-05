import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/place_repository.dart';
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
  late PlaceRepository places;

  setUp(() {
    db = openTestDatabase();
    clock = FakeClock();
    tasks = TaskRepository(db, deviceId: 'dev', clock: clock.call);
    reminders = ReminderRepository(db, deviceId: 'dev', clock: clock.call);
    places = PlaceRepository(db, deviceId: 'dev', clock: clock.call);
  });

  tearDown(() => db.close());

  test('places are listed by name, edited and tombstoned', () async {
    final work = await places.createPlace(
      name: 'Work',
      latitude: 33.3,
      longitude: 44.4,
    );
    await places.createPlace(name: 'home', latitude: 33.31, longitude: 44.36);
    expect((await places.watchPlaces().first).map((p) => p.name), [
      'home',
      'Work',
    ]);
    expect(work.radiusMeters, 30);

    clock.advance();
    await places.updatePlace(work.id, name: 'Office', radiusMeters: 80);
    final office = await places.getPlace(work.id);
    expect(office!.name, 'Office');
    expect(office.radiusMeters, 80);
    expect(office.updatedAt, clock.current);

    await places.deletePlace(work.id);
    expect(await places.getPlace(work.id), isNull);
    expect((await places.watchPlaces().first).map((p) => p.name), ['home']);
  });

  test('deleting a place keeps its reminders working as spots', () async {
    final task = await tasks.createTask(title: 'Water plants');
    final home = await places.createPlace(
      name: 'Home',
      latitude: 33.31,
      longitude: 44.36,
    );
    final r = await reminders.addLocation(
      task.id,
      placeId: home.id,
      radiusMeters: 50,
      trigger: LocationTrigger.arrive,
    );
    await places.deletePlace(home.id);

    final kept = (await reminders.watchLocationForTask(task.id).first).single;
    expect(kept.id, r.id);
    expect(kept.placeId, isNull);
    expect(kept.latitude, 33.31);
    expect(kept.longitude, 44.36);
    expect(kept.label, 'Home');
    expect(kept.radiusMeters, 50);
  });

  test('location reminders: add, update, clamp, and keep apart from time '
      'reminders', () async {
    final task = await tasks.createTask(title: 'Buy bread');
    final r = await reminders.addLocation(
      task.id,
      latitude: 33.3,
      longitude: 44.4,
      label: 'Bakery',
      radiusMeters: 5,
      trigger: LocationTrigger.leave,
    );
    expect(r.radiusMeters, 30);
    await reminders.addRelative(task.id, 0);

    expect((await reminders.watchForTask(task.id).first).length, 1);
    expect((await reminders.watchLocationReminders().first).single.id, r.id);

    await reminders.updateLocation(
      r.id,
      latitude: 33.5,
      longitude: 44.5,
      label: 'Market',
      radiusMeters: 900,
      trigger: LocationTrigger.arrive,
    );
    final updated =
        (await reminders.watchLocationForTask(task.id).first).single;
    expect(updated.label, 'Market');
    expect(updated.latitude, 33.5);
    expect(updated.radiusMeters, 500);
    expect(updated.trigger, LocationTrigger.arrive);

    expect(
      () => reminders.addLocation(
        task.id,
        radiusMeters: 30,
        trigger: LocationTrigger.arrive,
      ),
      throwsArgumentError,
    );
  });

  test('a repeating task passes its location reminders on', () async {
    final task = await tasks.createTask(
      title: 'Groceries',
      dueDate: LocalDate(2026, 10, 20),
    );
    await tasks.saveTask(
      task.copyWith(recurrenceRule: () => 'DTSTART=20261020;FREQ=WEEKLY'),
    );
    await reminders.addLocation(
      task.id,
      latitude: 33.3,
      longitude: 44.4,
      label: 'Market',
      radiusMeters: 40,
      trigger: LocationTrigger.arrive,
    );
    final completion = await tasks.setDone(task.id, done: true);
    final next =
        (await reminders.watchLocationForTask(completion.nextTaskId!).first)
            .single;
    expect(next.label, 'Market');
    expect(next.radiusMeters, 40);
  });

  test('default location radius is a synced setting', () async {
    final settings = SettingsRepository(db, deviceId: 'dev');
    expect((await settings.loadSettings()).defaultLocationRadius, 30);
    await settings.setDefaultLocationRadius(100);
    expect((await settings.loadSettings()).defaultLocationRadius, 100);
    final row =
        await (db.select(db.settings)
              ..where((s) => s.id.equals(SettingKeys.defaultLocationRadius)))
            .getSingle();
    expect(row.synced, isTrue);
  });
}
