/// A calendar date with no time and no timezone ("floating" date).
///
/// Due dates are stored this way so a task due on 2026-10-21 stays on that
/// day wherever the device is. Arithmetic goes through UTC [DateTime]s, which
/// have no DST gaps, so adding days is always exact.
final class LocalDate implements Comparable<LocalDate> {
  /// Creates a date, throwing [ArgumentError] if it doesn't exist
  /// (for example February 30).
  factory LocalDate(int year, int month, int day) {
    final utc = DateTime.utc(year, month, day);
    if (utc.year != year || utc.month != month || utc.day != day) {
      throw ArgumentError('Invalid date: $year-$month-$day');
    }
    return LocalDate._(year, month, day);
  }

  const LocalDate._(this.year, this.month, this.day);

  /// The calendar date of [dateTime] in its own timezone (local or UTC).
  factory LocalDate.fromDateTime(DateTime dateTime) =>
      LocalDate._(dateTime.year, dateTime.month, dateTime.day);

  /// Parses an ISO-8601 date such as `2026-10-21`.
  factory LocalDate.parse(String iso) {
    final match = _isoPattern.firstMatch(iso);
    if (match == null) {
      throw FormatException('Expected YYYY-MM-DD', iso);
    }
    return LocalDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static final RegExp _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// ISO weekday: [DateTime.monday] (1) to [DateTime.sunday] (7).
  int get weekday => _utc.weekday;

  /// Returns the date [days] days later (negative values go back).
  LocalDate addDays(int days) =>
      LocalDate.fromDateTime(DateTime.utc(year, month, day + days));

  /// Whole days from [other] to this date (positive if this is later).
  int differenceInDays(LocalDate other) => _utc.difference(other._utc).inDays;

  /// This date at [minutes] past local midnight, as a local [DateTime].
  DateTime atLocalTime([int minutes = 0]) =>
      DateTime(year, month, day, 0, minutes);

  bool isBefore(LocalDate other) => compareTo(other) < 0;
  bool isAfter(LocalDate other) => compareTo(other) > 0;

  /// `YYYY-MM-DD`.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
