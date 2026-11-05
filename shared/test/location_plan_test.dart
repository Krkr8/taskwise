import 'package:taskwise_shared/taskwise_shared.dart';
import 'package:test/test.dart';

final _at = DateTime.utc(2026, 11, 1);

Task task(String id, {bool done = false, bool deleted = false}) => Task(
  id: id,
  title: 'Task $id',
  done: done,
  deleted: deleted,
  createdAt: _at,
  updatedAt: _at,
);

Reminder spot(
  String id,
  String taskId, {
  int? radius = 40,
  LocationTrigger? trigger = LocationTrigger.leave,
  String? label = 'Shop',
  bool deleted = false,
}) => Reminder(
  id: id,
  taskId: taskId,
  kind: ReminderKind.location,
  latitude: 33.3,
  longitude: 44.4,
  radiusMeters: radius,
  trigger: trigger,
  label: label,
  deleted: deleted,
  updatedAt: _at,
);

Reminder atPlace(String id, String taskId, String placeId) => Reminder(
  id: id,
  taskId: taskId,
  kind: ReminderKind.location,
  placeId: placeId,
  radiusMeters: 30,
  trigger: LocationTrigger.arrive,
  updatedAt: _at,
);

final home = Place(
  id: 'home',
  name: 'Home',
  latitude: 33.31,
  longitude: 44.36,
  updatedAt: _at,
);

void main() {
  test('a spot keeps its own position, radius, trigger and label', () {
    final plan = planLocationReminders(
      tasks: [task('a')],
      reminders: [spot('r1', 'a')],
      places: const [],
    );
    expect(plan, [
      const LocationReminderEntry(
        reminderId: 'r1',
        taskId: 'a',
        taskTitle: 'Task a',
        latitude: 33.3,
        longitude: 44.4,
        radiusMeters: 40,
        trigger: LocationTrigger.leave,
        placeName: 'Shop',
      ),
    ]);
  });

  test('a saved place lends its current position and name', () {
    final plan = planLocationReminders(
      tasks: [task('a')],
      reminders: [atPlace('r1', 'a', 'home')],
      places: [home],
    );
    expect(plan.single.latitude, 33.31);
    expect(plan.single.longitude, 44.36);
    expect(plan.single.placeName, 'Home');
    expect(plan.single.trigger, LocationTrigger.arrive);
  });

  test('done, deleted and missing tasks are skipped', () {
    final plan = planLocationReminders(
      tasks: [task('done', done: true), task('gone', deleted: true)],
      reminders: [
        spot('r1', 'done'),
        spot('r2', 'gone'),
        spot('r3', 'not-here'),
      ],
      places: const [],
    );
    expect(plan, isEmpty);
  });

  test('deleted reminders, deleted places and time reminders are skipped', () {
    final plan = planLocationReminders(
      tasks: [task('a')],
      reminders: [
        spot('r1', 'a', deleted: true),
        atPlace('r2', 'a', 'home'),
        atPlace('r3', 'a', 'unknown'),
        Reminder(
          id: 'r4',
          taskId: 'a',
          kind: ReminderKind.time,
          minutesBeforeDue: 0,
          updatedAt: _at,
        ),
      ],
      places: [
        Place(
          id: 'home',
          name: 'Home',
          latitude: 1,
          longitude: 2,
          updatedAt: _at,
          deleted: true,
        ),
      ],
    );
    expect(plan, isEmpty);
  });

  test('missing radius and trigger fall back to 30 m on arrival', () {
    final plan = planLocationReminders(
      tasks: [task('a')],
      reminders: [
        spot('r1', 'a', radius: null, trigger: null),
        spot('r2', 'a', radius: 5),
        spot('r3', 'a', radius: 9000),
      ],
      places: const [],
    );
    expect(plan.map((e) => e.radiusMeters), [30, 30, 500]);
    expect(plan.first.trigger, LocationTrigger.arrive);
  });

  test('distanceMeters', () {
    expect(distanceMeters(33.3, 44.4, 33.3, 44.4), 0);
    // One thousandth of a degree of latitude is about 111 m.
    expect(distanceMeters(33.3, 44.4, 33.301, 44.4), closeTo(111.2, 0.5));
    // Baghdad to Erbil, about 320 km.
    expect(
      distanceMeters(33.3152, 44.3661, 36.1911, 44.0092),
      closeTo(321000, 3000),
    );
  });

  test('the label survives JSON', () {
    final r = spot('r1', 'a');
    expect(Reminder.fromJson(r.toJson()), r);
  });
}
