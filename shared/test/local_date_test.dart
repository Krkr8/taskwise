import 'package:taskwise_shared/taskwise_shared.dart';
import 'package:test/test.dart';

void main() {
  group('LocalDate', () {
    test('rejects dates that do not exist', () {
      expect(() => LocalDate(2026, 2, 29), throwsArgumentError);
      expect(() => LocalDate(2026, 13, 1), throwsArgumentError);
      expect(LocalDate(2028, 2, 29).day, 29); // leap year
    });

    test('parses and formats ISO dates', () {
      expect(LocalDate.parse('2026-01-05'), LocalDate(2026, 1, 5));
      expect(LocalDate(2026, 1, 5).toIso(), '2026-01-05');
      expect(() => LocalDate.parse('2026-1-5'), throwsFormatException);
      expect(() => LocalDate.parse('2026-02-30'), throwsArgumentError);
    });

    test('addDays crosses month, year and leap-day boundaries', () {
      expect(LocalDate(2026, 1, 31).addDays(1), LocalDate(2026, 2, 1));
      expect(LocalDate(2026, 12, 31).addDays(1), LocalDate(2027, 1, 1));
      expect(LocalDate(2028, 2, 28).addDays(1), LocalDate(2028, 2, 29));
      expect(LocalDate(2026, 3, 1).addDays(-1), LocalDate(2026, 2, 28));
    });

    test('addDays is exact across DST changes', () {
      // 2026-03-08 is the US spring-forward day; UTC maths has no gaps.
      expect(LocalDate(2026, 3, 7).addDays(2), LocalDate(2026, 3, 9));
      expect(LocalDate(2026, 3, 9).differenceInDays(LocalDate(2026, 3, 7)), 2);
    });

    test('weekday uses ISO numbering', () {
      expect(LocalDate(2026, 10, 18).weekday, DateTime.sunday);
      expect(LocalDate(2026, 10, 20).weekday, DateTime.tuesday);
    });

    test('compares and orders', () {
      final a = LocalDate(2026, 10, 20);
      final b = LocalDate(2026, 10, 21);
      expect(a.isBefore(b), isTrue);
      expect(b.isAfter(a), isTrue);
      expect([b, a]..sort(), [a, b]);
      expect(a, LocalDate(2026, 10, 20));
      expect(a.hashCode, LocalDate(2026, 10, 20).hashCode);
    });

    test('fromDateTime uses the DateTime own calendar fields', () {
      expect(
        LocalDate.fromDateTime(DateTime(2026, 10, 20, 23, 59)),
        LocalDate(2026, 10, 20),
      );
    });
  });
}
