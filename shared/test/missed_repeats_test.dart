import 'package:taskwise_shared/taskwise_shared.dart';
import 'package:test/test.dart';

final _t0 = DateTime.utc(2026, 11, 1);
final _today = LocalDate(2026, 11, 18); // a Wednesday

Task _task({
  LocalDate? due,
  String? rule = 'DTSTART=20261101;FREQ=DAILY',
  bool done = false,
  bool deleted = false,
}) => Task(
  id: 't',
  title: 'T',
  dueDate: due,
  recurrenceRule: rule,
  done: done,
  deleted: deleted,
  createdAt: _t0,
  updatedAt: _t0,
);

void main() {
  group('missedRepeatDate', () {
    test('a daily task left for 4 days gets a copy today', () {
      expect(
        missedRepeatDate(_task(due: LocalDate(2026, 11, 14)), _today),
        _today,
      );
    });

    test('a daily task due yesterday gets a copy today', () {
      expect(
        missedRepeatDate(_task(due: LocalDate(2026, 11, 17)), _today),
        _today,
      );
    });

    test('a daily task due today needs nothing', () {
      expect(missedRepeatDate(_task(due: _today), _today), isNull);
    });

    test('weekly: the copy goes on the first occurrence today or later', () {
      const weekly = 'DTSTART=20261102;FREQ=WEEKLY;BYDAY=MO';
      expect(
        missedRepeatDate(
          _task(due: LocalDate(2026, 11, 9), rule: weekly),
          _today,
        ),
        LocalDate(2026, 11, 23),
      );
    });

    test('weekly: nothing until the next occurrence arrives', () {
      const weekly = 'DTSTART=20261102;FREQ=WEEKLY;BYDAY=MO';
      expect(
        missedRepeatDate(
          _task(due: LocalDate(2026, 11, 16), rule: weekly),
          _today,
        ),
        isNull,
      );
    });

    test('done, deleted, one-off and undated tasks need nothing', () {
      final due = LocalDate(2026, 11, 14);
      expect(missedRepeatDate(_task(due: due, done: true), _today), isNull);
      expect(missedRepeatDate(_task(due: due, deleted: true), _today), isNull);
      expect(missedRepeatDate(_task(due: due, rule: null), _today), isNull);
      expect(missedRepeatDate(_task(), _today), isNull);
      expect(
        missedRepeatDate(_task(due: due, rule: 'nonsense'), _today),
        isNull,
      );
    });

    test('a series that has ended needs nothing', () {
      // Nov 12, 13, 14: the overdue task is the last occurrence.
      const ended = 'DTSTART=20261112;FREQ=DAILY;COUNT=3';
      expect(
        missedRepeatDate(
          _task(due: LocalDate(2026, 11, 14), rule: ended),
          _today,
        ),
        isNull,
      );
    });

    test('a series that ends before today needs nothing', () {
      // Nov 14 and 15 only: the 15th was missed, but nothing is left today.
      const ended = 'DTSTART=20261114;FREQ=DAILY;UNTIL=20261115';
      expect(
        missedRepeatDate(
          _task(due: LocalDate(2026, 11, 14), rule: ended),
          _today,
        ),
        isNull,
      );
    });
  });
}
