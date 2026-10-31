import 'package:taskwise_shared/taskwise_shared.dart';
import 'package:test/test.dart';

final _at = DateTime.utc(2026, 10, 1);

Task task(
  String id, {
  LocalDate? due,
  int? time,
  String? rule,
  bool done = false,
}) => Task(
  id: id,
  title: 'Task $id',
  dueDate: due,
  dueTimeMinutes: time,
  recurrenceRule: rule,
  done: done,
  createdAt: _at,
  updatedAt: _at,
);

Reminder before(String id, String taskId, int minutes) => Reminder(
  id: id,
  taskId: taskId,
  kind: ReminderKind.time,
  minutesBeforeDue: minutes,
  updatedAt: _at,
);

Reminder at(String id, String taskId, DateTime when) => Reminder(
  id: id,
  taskId: taskId,
  kind: ReminderKind.time,
  absoluteAt: when.toUtc(),
  updatedAt: _at,
);

LocalDate d(int y, int m, int day) => LocalDate(y, m, day);

/// Tuesday 2026-10-20, 08:00 local.
final now = DateTime(2026, 10, 20, 8);

void main() {
  test('relative reminders count back from the due time', () {
    final plan = planNotifications(
      tasks: [task('a', due: d(2026, 10, 20), time: 10 * 60)],
      reminders: [before('r1', 'a', 0), before('r2', 'a', 15)],
      now: now,
    );
    expect(plan.map((p) => p.fireAt), [
      DateTime(2026, 10, 20, 9, 45),
      DateTime(2026, 10, 20, 10),
    ]);
    expect(plan.first.taskId, 'a');
    expect(plan.first.occurrence, d(2026, 10, 20));
    expect(plan.first.projected, isFalse);
  });

  test('all-day tasks use the all-day reminder time', () {
    final plan = planNotifications(
      tasks: [task('a', due: d(2026, 10, 21))],
      reminders: [before('r', 'a', 0), before('r2', 'a', 24 * 60)],
      now: now,
      allDayMinutes: 9 * 60,
    );
    expect(plan.map((p) => p.fireAt), [
      DateTime(2026, 10, 20, 9),
      DateTime(2026, 10, 21, 9),
    ]);
  });

  test('absolute reminders fire once at their moment', () {
    final plan = planNotifications(
      tasks: [task('a')],
      reminders: [at('r', 'a', DateTime(2026, 10, 22, 7, 30))],
      now: now,
    );
    expect(plan.single.fireAt, DateTime(2026, 10, 22, 7, 30));
    expect(plan.single.occurrence, d(2026, 10, 22));
  });

  test('relative reminders need a due date', () {
    expect(
      planNotifications(
        tasks: [task('a')],
        reminders: [before('r', 'a', 0)],
        now: now,
      ),
      isEmpty,
    );
  });

  test('skips the past, done tasks, other kinds and deleted reminders', () {
    final plan = planNotifications(
      tasks: [
        task('past', due: d(2026, 10, 20), time: 7 * 60),
        task('done', due: d(2026, 10, 20), time: 12 * 60, done: true),
        task('ok', due: d(2026, 10, 20), time: 12 * 60),
      ],
      reminders: [
        before('r1', 'past', 0),
        before('r2', 'done', 0),
        before('r3', 'ok', 0),
        Reminder(
          id: 'r4',
          taskId: 'ok',
          kind: ReminderKind.location,
          updatedAt: _at,
        ),
        Reminder(
          id: 'r5',
          taskId: 'ok',
          kind: ReminderKind.time,
          minutesBeforeDue: 30,
          deleted: true,
          updatedAt: _at,
        ),
        before('r6', 'missing-task', 0),
      ],
      now: now,
    );
    expect(plan.single.reminderId, 'r3');
  });

  test('repeating tasks get reminders for each occurrence in the horizon', () {
    final plan = planNotifications(
      tasks: [
        task(
          'gym',
          due: d(2026, 10, 19),
          time: 18 * 60,
          rule: 'DTSTART=20261019;FREQ=WEEKLY;BYDAY=MO,WE,FR',
        ),
      ],
      reminders: [before('r', 'gym', 60)],
      now: now,
      horizon: const Duration(days: 7),
    );
    expect(plan.map((p) => p.occurrence), [
      d(2026, 10, 21),
      d(2026, 10, 23),
      d(2026, 10, 26),
    ]);
    expect(plan.every((p) => p.projected), isTrue);
    expect(plan.first.fireAt, DateTime(2026, 10, 21, 17));
  });

  test('the horizon cuts off later reminders', () {
    final plan = planNotifications(
      tasks: [task('a', due: d(2026, 11, 20), time: 9 * 60)],
      reminders: [before('r', 'a', 0)],
      now: now,
      horizon: const Duration(days: 14),
    );
    expect(plan, isEmpty);
  });

  test('sorted by time and limited to the soonest', () {
    final plan = planNotifications(
      tasks: [
        task('late', due: d(2026, 10, 25), time: 9 * 60),
        task('soon', due: d(2026, 10, 21), time: 9 * 60),
        task('mid', due: d(2026, 10, 23), time: 9 * 60),
      ],
      reminders: [
        before('a', 'late', 0),
        before('b', 'soon', 0),
        before('c', 'mid', 0),
      ],
      now: now,
      limit: 2,
    );
    expect(plan.map((p) => p.taskId), ['soon', 'mid']);
  });

  test('ids are stable and differ per occurrence', () {
    List<int> ids() => planNotifications(
      tasks: [
        task(
          'a',
          due: d(2026, 10, 20),
          time: 9 * 60,
          rule: 'DTSTART=20261020;FREQ=DAILY',
        ),
      ],
      reminders: [before('r', 'a', 0)],
      now: now,
      horizon: const Duration(days: 3),
    ).map((p) => p.id).toList();
    final first = ids();
    expect(first, ids());
    expect(first.toSet().length, first.length);
    expect(first.every((id) => id >= 0 && id < 1 << 31), isTrue);
  });

  test('snoozes fire at their time and replace nothing else', () {
    final plan = planNotifications(
      tasks: [task('a', due: d(2026, 10, 20), time: 7 * 60)],
      reminders: [before('r', 'a', 0)],
      snoozes: [
        Snooze(
          taskId: 'a',
          occurrence: d(2026, 10, 20),
          until: DateTime(2026, 10, 20, 8, 15),
        ),
        // Already over, and one for a task that's gone.
        Snooze(
          taskId: 'a',
          occurrence: d(2026, 10, 20),
          until: DateTime(2026, 10, 20, 7, 30),
        ),
        Snooze(
          taskId: 'gone',
          occurrence: d(2026, 10, 20),
          until: DateTime(2026, 10, 20, 9),
        ),
      ],
      now: now,
    );
    expect(plan.single.fireAt, DateTime(2026, 10, 20, 8, 15));
    expect(plan.single.snoozed, isTrue);
    expect(plan.single.reminderId, isNull);
  });

  test('after lets the caller catch up on missed reminders', () {
    final plan = planNotifications(
      tasks: [task('a', due: d(2026, 10, 20), time: 7 * 60)],
      reminders: [before('r', 'a', 0)],
      now: now,
      after: DateTime(2026, 10, 20, 6),
    );
    expect(plan.single.fireAt, DateTime(2026, 10, 20, 7));
  });

  group('snooze JSON', () {
    test('round-trips', () {
      final snooze = Snooze(
        taskId: 'a',
        occurrence: d(2026, 10, 20),
        until: DateTime.utc(2026, 10, 20, 8, 15),
      );
      expect(Snooze.fromJson(snooze.toJson()), snooze);
    });
  });

  group('DST', () {
    // Wall-clock maths: "1 day before 9:00" stays at 9:00 even when the
    // clocks change in between (US: Nov 1, EU: Oct 25, 2026).
    test('a day-before reminder keeps its wall-clock time', () {
      for (final due in [d(2026, 10, 26), d(2026, 11, 2), d(2026, 3, 9)]) {
        final plan = planNotifications(
          tasks: [task('a', due: due, time: 9 * 60)],
          reminders: [before('r', 'a', 24 * 60)],
          now: due.addDays(-10).atLocalTime(),
        );
        final fire = plan.single.fireAt;
        expect(LocalDate.fromDateTime(fire), due.addDays(-1));
        expect(fire.hour, 9);
        expect(fire.minute, 0);
      }
    });
  });
}
