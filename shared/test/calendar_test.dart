import 'package:taskwise_shared/taskwise_shared.dart';
import 'package:test/test.dart';

final _at = DateTime.utc(2026, 10, 20);

Task task(
  String title, {
  LocalDate? due,
  int? time,
  String? rule,
  bool done = false,
  bool deleted = false,
}) => Task(
  id: title,
  title: title,
  dueDate: due,
  dueTimeMinutes: time,
  recurrenceRule: rule,
  done: done,
  deleted: deleted,
  createdAt: _at,
  updatedAt: _at,
);

LocalDate d(int y, int m, int day) => LocalDate(y, m, day);

void main() {
  group('calendarItems', () {
    final from = d(2026, 10, 18);
    final to = d(2026, 10, 24);

    test('places tasks on their due date, all-day first then by time', () {
      final items = calendarItems(
        [
          task('Late', due: d(2026, 10, 20), time: 18 * 60),
          task('Early', due: d(2026, 10, 20), time: 8 * 60),
          task('Allday', due: d(2026, 10, 20)),
          task('Outside', due: d(2026, 10, 25)),
          task('Undated'),
          task('Gone', due: d(2026, 10, 20), deleted: true),
        ],
        from: from,
        to: to,
      );
      expect(items.keys, [d(2026, 10, 20)]);
      expect(items[d(2026, 10, 20)]!.map((i) => i.task.title), [
        'Allday',
        'Early',
        'Late',
      ]);
    });

    test('projects later occurrences of open repeating tasks', () {
      final items = calendarItems(
        [
          task(
            'Gym',
            due: d(2026, 10, 19),
            time: 18 * 60,
            rule: 'DTSTART=20261019;FREQ=WEEKLY;BYDAY=MO,WE,FR',
          ),
        ],
        from: from,
        to: to,
      );
      expect(items.keys.toList()..sort(), [
        d(2026, 10, 19),
        d(2026, 10, 21),
        d(2026, 10, 23),
      ]);
      expect(items[d(2026, 10, 19)]!.single.projected, isFalse);
      expect(items[d(2026, 10, 21)]!.single.projected, isTrue);
    });

    test('an overdue repeating task projects from the range start', () {
      final items = calendarItems(
        [
          task(
            'Water',
            due: d(2026, 10, 1),
            rule: 'DTSTART=20261001;FREQ=DAILY',
          ),
        ],
        from: from,
        to: to,
      );
      expect(items.length, 7);
      expect(items.values.every((list) => list.single.projected), isTrue);
    });

    test('done tasks show but do not project', () {
      final items = calendarItems(
        [
          task(
            'Old',
            due: d(2026, 10, 19),
            rule: 'DTSTART=20261019;FREQ=DAILY',
            done: true,
          ),
        ],
        from: from,
        to: to,
      );
      expect(items.keys, [d(2026, 10, 19)]);
    });

    test('tasks due after the range are not projected backwards', () {
      final items = calendarItems(
        [
          task(
            'Later',
            due: d(2026, 11, 1),
            rule: 'DTSTART=20261101;FREQ=DAILY',
          ),
        ],
        from: from,
        to: to,
      );
      expect(items, isEmpty);
    });
  });

  group('grids', () {
    test('weekDays follows the week start', () {
      // 2026-10-20 is a Tuesday.
      expect(
        weekDays(d(2026, 10, 20), WeekStart.sunday).first,
        d(2026, 10, 18),
      );
      expect(
        weekDays(d(2026, 10, 20), WeekStart.saturday).first,
        d(2026, 10, 17),
      );
      expect(weekDays(d(2026, 10, 20), WeekStart.monday).last, d(2026, 10, 25));
    });

    test('monthGridDays covers the month in 6 weeks', () {
      final days = monthGridDays(d(2026, 10, 20), WeekStart.sunday);
      expect(days.length, 42);
      expect(days.first, d(2026, 9, 27)); // Oct 1 2026 is a Thursday
      expect(days, contains(d(2026, 10, 31)));
      expect(days.first.weekday, DateTime.sunday);
    });

    test('addMonths crosses years', () {
      expect(addMonths(d(2026, 12, 31), 1), d(2027, 1, 1));
      expect(addMonths(d(2026, 1, 15), -1), d(2025, 12, 1));
    });
  });
}
