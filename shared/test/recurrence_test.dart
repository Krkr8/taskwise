import 'package:taskwise_shared/taskwise_shared.dart';
import 'package:test/test.dart';

LocalDate d(int y, int m, int day) => LocalDate(y, m, day);

/// The first [n] occurrences of [rule] (from its start).
List<LocalDate> firstN(RecurrenceRule rule, int n) =>
    rule.occurrences().take(n).toList();

void main() {
  group('parse and format', () {
    test('round-trips every field', () {
      const text =
          'DTSTART=20261020;FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;UNTIL=20270101';
      final rule = RecurrenceRule.parse(text);
      expect(rule.frequency, Frequency.weekly);
      expect(rule.interval, 2);
      expect(rule.weekdays, {DateTime.monday, DateTime.wednesday});
      expect(rule.until, d(2027, 1, 1));
      expect(rule.start, d(2026, 10, 20));
      expect(rule.toString(), text);
      expect(RecurrenceRule.parse(rule.toString()), rule);
    });

    test('round-trips monthly by nth weekday and by month day', () {
      for (final text in [
        'DTSTART=20261013;FREQ=MONTHLY;BYDAY=2TU',
        'DTSTART=20261030;FREQ=MONTHLY;BYDAY=-1FR;COUNT=6',
        'DTSTART=20261031;FREQ=MONTHLY;BYMONTHDAY=31',
        'DTSTART=20280229;FREQ=YEARLY',
        'DTSTART=20261020;FREQ=DAILY;INTERVAL=3',
      ]) {
        expect(RecurrenceRule.parse(text).toString(), text);
      }
    });

    test('accepts fields in any order and an RRULE: prefix', () {
      final rule = RecurrenceRule.parse(
        'RRULE:FREQ=DAILY;DTSTART=20261020;INTERVAL=1',
      );
      expect(rule.frequency, Frequency.daily);
      expect(rule.toString(), 'DTSTART=20261020;FREQ=DAILY');
    });

    test('rejects invalid rules', () {
      for (final text in [
        '',
        'FREQ=DAILY', // no DTSTART
        'DTSTART=20261020', // no FREQ
        'DTSTART=20261020;FREQ=HOURLY',
        'DTSTART=20261020;FREQ=DAILY;INTERVAL=0',
        'DTSTART=20261020;FREQ=DAILY;COUNT=0',
        'DTSTART=20261020;FREQ=DAILY;COUNT=2;UNTIL=20261101',
        'DTSTART=20261020;FREQ=WEEKLY;BYDAY=XX',
        'DTSTART=20261020;FREQ=MONTHLY;BYDAY=5TU',
        'DTSTART=20261020;FREQ=MONTHLY;BYMONTHDAY=32',
        'DTSTART=20261020;FREQ=MONTHLY;BYDAY=2TU;BYMONTHDAY=3',
        'DTSTART=20261020;FREQ=DAILY;BYDAY=MO',
        'DTSTART=2026-10-20;FREQ=DAILY',
        'DTSTART=20261020;FREQ=DAILY;FOO=1',
      ]) {
        expect(
          () => RecurrenceRule.parse(text),
          throwsFormatException,
          reason: text,
        );
        expect(RecurrenceRule.tryParse(text), isNull, reason: text);
      }
    });
  });

  group('daily', () {
    test('every day and every 3 days', () {
      expect(
        firstN(
          RecurrenceRule(frequency: Frequency.daily, start: d(2026, 12, 30)),
          3,
        ),
        [d(2026, 12, 30), d(2026, 12, 31), d(2027, 1, 1)],
      );
      expect(
        firstN(
          RecurrenceRule(
            frequency: Frequency.daily,
            interval: 3,
            start: d(2026, 2, 26),
          ),
          3,
        ),
        [d(2026, 2, 26), d(2026, 3, 1), d(2026, 3, 4)],
      );
    });
  });

  group('weekly', () {
    test('on several weekdays, starting mid-week', () {
      // 2026-10-20 is a Tuesday.
      final rule = RecurrenceRule(
        frequency: Frequency.weekly,
        weekdays: {DateTime.monday, DateTime.wednesday},
        start: d(2026, 10, 20),
      );
      expect(firstN(rule, 4), [
        d(2026, 10, 21),
        d(2026, 10, 26),
        d(2026, 10, 28),
        d(2026, 11, 2),
      ]);
    });

    test('every 2 weeks keeps the same weeks across copies', () {
      final rule = RecurrenceRule(
        frequency: Frequency.weekly,
        interval: 2,
        weekdays: {DateTime.monday, DateTime.friday},
        start: d(2026, 10, 19), // Monday
      );
      expect(firstN(rule, 4), [
        d(2026, 10, 19),
        d(2026, 10, 23),
        d(2026, 11, 2),
        d(2026, 11, 6),
      ]);
      // Asking from later on lands on the same fortnightly pattern.
      expect(rule.nextAfter(d(2026, 11, 7)), d(2026, 11, 16));
    });

    test('without weekdays repeats on the start weekday', () {
      final rule = RecurrenceRule(
        frequency: Frequency.weekly,
        start: d(2026, 10, 22), // Thursday
      );
      expect(firstN(rule, 2), [d(2026, 10, 22), d(2026, 10, 29)]);
    });

    test('a Sunday start with Saturday weekdays (week edges)', () {
      final rule = RecurrenceRule(
        frequency: Frequency.weekly,
        interval: 2,
        weekdays: {DateTime.saturday, DateTime.sunday},
        start: d(2026, 10, 25), // Sunday
      );
      final dates = firstN(rule, 4);
      expect(dates.first, d(2026, 10, 25));
      expect(dates, orderedEquals([...dates]..sort()));
      expect(dates.toSet().length, 4);
    });
  });

  group('monthly', () {
    test('day 31 falls back to the last day of shorter months', () {
      final rule = RecurrenceRule(
        frequency: Frequency.monthly,
        monthDay: 31,
        start: d(2026, 12, 31),
      );
      expect(firstN(rule, 4), [
        d(2026, 12, 31),
        d(2027, 1, 31),
        d(2027, 2, 28),
        d(2027, 3, 31),
      ]);
    });

    test('day 29 in February of a leap year', () {
      final rule = RecurrenceRule(
        frequency: Frequency.monthly,
        monthDay: 29,
        start: d(2028, 1, 29),
      );
      expect(firstN(rule, 3), [d(2028, 1, 29), d(2028, 2, 29), d(2028, 3, 29)]);
    });

    test('without a month day uses the start day', () {
      final rule = RecurrenceRule(
        frequency: Frequency.monthly,
        interval: 2,
        start: d(2026, 10, 15),
      );
      expect(firstN(rule, 3), [
        d(2026, 10, 15),
        d(2026, 12, 15),
        d(2027, 2, 15),
      ]);
    });

    test('the 2nd Tuesday', () {
      final rule = RecurrenceRule(
        frequency: Frequency.monthly,
        nthWeekday: const NthWeekday(2, DateTime.tuesday),
        start: d(2026, 10, 1),
      );
      expect(firstN(rule, 3), [
        d(2026, 10, 13),
        d(2026, 11, 10),
        d(2026, 12, 8),
      ]);
    });

    test('the last Friday', () {
      final rule = RecurrenceRule(
        frequency: Frequency.monthly,
        nthWeekday: const NthWeekday(-1, DateTime.friday),
        start: d(2026, 10, 1),
      );
      expect(firstN(rule, 3), [
        d(2026, 10, 30),
        d(2026, 11, 27),
        d(2026, 12, 25),
      ]);
    });

    test('a start after this month\'s nth weekday begins next month', () {
      final rule = RecurrenceRule(
        frequency: Frequency.monthly,
        nthWeekday: const NthWeekday(1, DateTime.monday),
        start: d(2026, 10, 20),
      );
      expect(rule.occurrences().first, d(2026, 11, 2));
    });
  });

  group('yearly', () {
    test('Feb 29 falls back to Feb 28 in non-leap years', () {
      final rule = RecurrenceRule(
        frequency: Frequency.yearly,
        start: d(2028, 2, 29),
      );
      expect(firstN(rule, 5), [
        d(2028, 2, 29),
        d(2029, 2, 28),
        d(2030, 2, 28),
        d(2031, 2, 28),
        d(2032, 2, 29),
      ]);
    });

    test('every 2 years', () {
      final rule = RecurrenceRule(
        frequency: Frequency.yearly,
        interval: 2,
        start: d(2026, 10, 20),
      );
      expect(firstN(rule, 2), [d(2026, 10, 20), d(2028, 10, 20)]);
    });
  });

  group('limits', () {
    test('COUNT counts from the start', () {
      final rule = RecurrenceRule(
        frequency: Frequency.daily,
        count: 3,
        start: d(2026, 10, 20),
      );
      expect(rule.occurrences().toList(), [
        d(2026, 10, 20),
        d(2026, 10, 21),
        d(2026, 10, 22),
      ]);
      expect(rule.nextAfter(d(2026, 10, 21)), d(2026, 10, 22));
      expect(rule.nextAfter(d(2026, 10, 22)), isNull);
    });

    test('UNTIL is inclusive', () {
      final rule = RecurrenceRule(
        frequency: Frequency.weekly,
        until: d(2026, 11, 3),
        start: d(2026, 10, 20),
      );
      expect(rule.occurrences().toList(), [
        d(2026, 10, 20),
        d(2026, 10, 27),
        d(2026, 11, 3),
      ]);
    });
  });

  group('queries', () {
    final daily = RecurrenceRule(
      frequency: Frequency.daily,
      start: d(2026, 10, 20),
    );

    test('nextAfter is strictly after the given date', () {
      expect(daily.nextAfter(d(2026, 10, 20)), d(2026, 10, 21));
      expect(daily.nextAfter(d(2026, 1, 1)), d(2026, 10, 20));
    });

    test('nextAfter far in the future stays fast', () {
      final sw = Stopwatch()..start();
      expect(daily.nextAfter(d(2126, 1, 1)), d(2126, 1, 2));
      expect(sw.elapsedMilliseconds, lessThan(500));
    });

    test('occurrencesBetween is inclusive on both ends', () {
      expect(daily.occurrencesBetween(d(2026, 10, 18), d(2026, 10, 22)), [
        d(2026, 10, 20),
        d(2026, 10, 21),
        d(2026, 10, 22),
      ]);
      expect(
        daily.occurrencesBetween(d(2026, 10, 22), d(2026, 10, 21)),
        isEmpty,
      );
    });

    test('withStart moves the anchor and keeps the pattern', () {
      final moved = daily.withStart(d(2026, 11, 1));
      expect(moved.start, d(2026, 11, 1));
      expect(moved.frequency, Frequency.daily);
    });
  });

  group('DST and timezones', () {
    // Occurrences are floating dates, so they never shift with DST. The
    // tests run in CI under several TZ values (see .github/workflows/ci.yml).
    test('daily occurrences across DST changes keep their date and time', () {
      final rule = RecurrenceRule(
        frequency: Frequency.daily,
        start: d(2026, 3, 1),
      );
      // Covers the US (Mar 8, Nov 1) and EU (Mar 29, Oct 25) transitions.
      for (final date in [
        ...rule.occurrencesBetween(d(2026, 3, 1), d(2026, 4, 5)),
        ...rule.occurrencesBetween(d(2026, 10, 20), d(2026, 11, 5)),
      ]) {
        final at = date.atLocalTime(9 * 60);
        expect(LocalDate.fromDateTime(at), date);
        expect(at.hour, 9);
      }
    });

    test('weekly occurrences stay 7 days apart across DST', () {
      final rule = RecurrenceRule(
        frequency: Frequency.weekly,
        start: d(2026, 3, 2),
      );
      final dates = rule.occurrencesBetween(d(2026, 3, 1), d(2026, 4, 30));
      for (var i = 1; i < dates.length; i++) {
        expect(dates[i].differenceInDays(dates[i - 1]), 7);
      }
    });
  });
}
