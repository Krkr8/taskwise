import 'package:taskwise_shared/taskwise_shared.dart';
import 'package:test/test.dart';

final _t0 = DateTime.utc(2026, 10, 1);

Task _task({LocalDate? due, bool done = false}) => Task(
  id: 'id',
  title: 'x',
  dueDate: due,
  done: done,
  createdAt: _t0,
  updatedAt: _t0,
);

void main() {
  // Tuesday 2026-10-20.
  final today = LocalDate(2026, 10, 20);

  TaskGroup bucket(LocalDate? due, WeekStart weekStart, {LocalDate? on}) =>
      groupFor(
        _task(due: due),
        today: on ?? today,
        weekStart: weekStart,
      );

  group('startOfWeek', () {
    test('for each week start', () {
      expect(startOfWeek(today, WeekStart.sunday), LocalDate(2026, 10, 18));
      expect(startOfWeek(today, WeekStart.saturday), LocalDate(2026, 10, 17));
      expect(startOfWeek(today, WeekStart.monday), LocalDate(2026, 10, 19));
    });

    test('is the same day when the date is the week start', () {
      final sunday = LocalDate(2026, 10, 18);
      expect(startOfWeek(sunday, WeekStart.sunday), sunday);
      expect(endOfWeek(sunday, WeekStart.sunday), LocalDate(2026, 10, 24));
    });
  });

  group('groupFor', () {
    test('completed wins over any date', () {
      expect(
        groupFor(
          _task(due: today.addDays(-5), done: true),
          today: today,
          weekStart: WeekStart.sunday,
        ),
        TaskGroup.completed,
      );
    });

    test('basic buckets (week starts Sunday)', () {
      const ws = WeekStart.sunday;
      expect(bucket(null, ws), TaskGroup.noDate);
      expect(bucket(LocalDate(2026, 10, 19), ws), TaskGroup.overdue);
      expect(bucket(LocalDate(2026, 10, 20), ws), TaskGroup.today);
      expect(bucket(LocalDate(2026, 10, 21), ws), TaskGroup.tomorrow);
      expect(bucket(LocalDate(2026, 10, 22), ws), TaskGroup.thisWeek);
      expect(bucket(LocalDate(2026, 10, 24), ws), TaskGroup.thisWeek);
      expect(bucket(LocalDate(2026, 10, 25), ws), TaskGroup.later);
    });

    test('week starting Saturday ends on Friday', () {
      const ws = WeekStart.saturday;
      expect(bucket(LocalDate(2026, 10, 23), ws), TaskGroup.thisWeek);
      expect(bucket(LocalDate(2026, 10, 24), ws), TaskGroup.later);
    });

    test('week starting Monday ends on Sunday', () {
      const ws = WeekStart.monday;
      expect(bucket(LocalDate(2026, 10, 25), ws), TaskGroup.thisWeek);
      expect(bucket(LocalDate(2026, 10, 26), ws), TaskGroup.later);
    });

    test('"This week" is empty on the last day of the week', () {
      // Saturday 2026-10-24 is the last day of a Sunday-start week.
      final saturday = LocalDate(2026, 10, 24);
      expect(
        bucket(LocalDate(2026, 10, 25), WeekStart.sunday, on: saturday),
        TaskGroup.tomorrow,
      );
      expect(
        bucket(LocalDate(2026, 10, 26), WeekStart.sunday, on: saturday),
        TaskGroup.later,
      );
    });

    test('across a year boundary', () {
      // Thursday 2026-12-31; the Sunday-start week runs Dec 27 to Jan 2.
      final newYearsEve = LocalDate(2026, 12, 31);
      const ws = WeekStart.sunday;
      expect(
        bucket(LocalDate(2027, 1, 1), ws, on: newYearsEve),
        TaskGroup.tomorrow,
      );
      expect(
        bucket(LocalDate(2027, 1, 2), ws, on: newYearsEve),
        TaskGroup.thisWeek,
      );
      expect(
        bucket(LocalDate(2027, 1, 3), ws, on: newYearsEve),
        TaskGroup.later,
      );
      expect(
        bucket(LocalDate(2026, 12, 30), ws, on: newYearsEve),
        TaskGroup.overdue,
      );
    });

    test('across a month boundary', () {
      // Friday 2026-10-30; the Monday-start week runs Oct 26 to Nov 1.
      final friday = LocalDate(2026, 10, 30);
      const ws = WeekStart.monday;
      expect(
        bucket(LocalDate(2026, 10, 31), ws, on: friday),
        TaskGroup.tomorrow,
      );
      expect(
        bucket(LocalDate(2026, 11, 1), ws, on: friday),
        TaskGroup.thisWeek,
      );
      expect(bucket(LocalDate(2026, 11, 2), ws, on: friday), TaskGroup.later);
    });
  });
}
