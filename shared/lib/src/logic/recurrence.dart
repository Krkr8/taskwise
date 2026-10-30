import '../models/local_date.dart';

/// How often a [RecurrenceRule] repeats.
enum Frequency { daily, weekly, monthly, yearly }

/// "The [n]th [weekday] of the month": n is 1–4, or -1 for the last one.
final class NthWeekday {
  const NthWeekday(this.n, this.weekday)
    : assert(n == -1 || (n >= 1 && n <= 4), 'n must be 1-4 or -1'),
      assert(weekday >= 1 && weekday <= 7, 'weekday is ISO 1-7');

  final int n;

  /// ISO weekday: [DateTime.monday] (1) to [DateTime.sunday] (7).
  final int weekday;

  @override
  bool operator ==(Object other) =>
      other is NthWeekday && other.n == n && other.weekday == weekday;

  @override
  int get hashCode => Object.hash(n, weekday);
}

/// A repeat rule for tasks: a small, RRULE-style subset of RFC 5545.
///
/// Stored in `Task.recurrenceRule` as text, for example
/// `DTSTART=20261020;FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=10`.
/// [start] (`DTSTART`) anchors the series: "every 2 weeks" and [count] are
/// measured from it, so every copy of a repeating task agrees on the dates.
///
/// Everything works on floating [LocalDate]s, so DST never moves a date.
/// Where a date doesn't exist, it falls back to the last day of the month:
/// day 31 in a 30-day month gives the 30th, and Feb 29 yearly gives Feb 28 in
/// non-leap years. (RFC 5545 would skip those months instead.)
final class RecurrenceRule {
  RecurrenceRule({
    required this.frequency,
    required this.start,
    this.interval = 1,
    Set<int> weekdays = const {},
    this.monthDay,
    this.nthWeekday,
    this.until,
    this.count,
  }) : weekdays = Set.unmodifiable(weekdays) {
    if (interval < 1) throw ArgumentError.value(interval, 'interval');
    if (count != null && count! < 1) throw ArgumentError.value(count, 'count');
    if (count != null && until != null) {
      throw ArgumentError('Use either count or until, not both');
    }
    if (weekdays.any((w) => w < 1 || w > 7)) {
      throw ArgumentError.value(weekdays, 'weekdays');
    }
    if (weekdays.isNotEmpty && frequency != Frequency.weekly) {
      throw ArgumentError('weekdays only apply to weekly rules');
    }
    if ((monthDay != null || nthWeekday != null) &&
        frequency != Frequency.monthly) {
      throw ArgumentError('monthDay and nthWeekday only apply to monthly');
    }
    if (monthDay != null && nthWeekday != null) {
      throw ArgumentError('Use either monthDay or nthWeekday, not both');
    }
    if (monthDay != null && (monthDay! < 1 || monthDay! > 31)) {
      throw ArgumentError.value(monthDay, 'monthDay');
    }
  }

  /// Parses the stored text form, throwing [FormatException] if it's invalid.
  factory RecurrenceRule.parse(String text) {
    final body = text.startsWith('RRULE:') ? text.substring(6) : text;
    final fields = <String, String>{};
    for (final part in body.split(';')) {
      final eq = part.indexOf('=');
      if (eq <= 0) throw FormatException('Bad rule part', text);
      final key = part.substring(0, eq);
      if (!_keys.contains(key)) throw FormatException('Unknown $key', text);
      fields[key] = part.substring(eq + 1);
    }

    int number(String key) =>
        int.tryParse(fields[key]!) ?? (throw FormatException('Bad $key', text));

    final frequency = switch (fields['FREQ']) {
      'DAILY' => Frequency.daily,
      'WEEKLY' => Frequency.weekly,
      'MONTHLY' => Frequency.monthly,
      'YEARLY' => Frequency.yearly,
      _ => throw FormatException('Bad or missing FREQ', text),
    };
    final startText =
        fields['DTSTART'] ?? (throw FormatException('Missing DTSTART', text));

    final weekdays = <int>{};
    NthWeekday? nth;
    if (fields['BYDAY'] case final byDay?) {
      for (final item in byDay.split(',')) {
        final match = _byDayPattern.firstMatch(item);
        final weekday = match == null ? null : _dayCodes.indexOf(match[2]!);
        if (weekday == null || weekday < 0) {
          throw FormatException('Bad BYDAY', text);
        }
        if (match![1] case final n?) {
          if (frequency != Frequency.monthly || byDay.contains(',')) {
            throw FormatException('Numbered BYDAY is monthly-only', text);
          }
          final value = int.parse(n);
          if (value != -1 && (value < 1 || value > 4)) {
            throw FormatException('BYDAY must be 1-4 or -1', text);
          }
          nth = NthWeekday(value, weekday + 1);
        } else {
          weekdays.add(weekday + 1);
        }
      }
    }

    try {
      return RecurrenceRule(
        frequency: frequency,
        start: _parseDate(startText, text),
        interval: fields.containsKey('INTERVAL') ? number('INTERVAL') : 1,
        weekdays: weekdays,
        monthDay: fields.containsKey('BYMONTHDAY')
            ? number('BYMONTHDAY')
            : null,
        nthWeekday: nth,
        until: switch (fields['UNTIL']) {
          final u? => _parseDate(u, text),
          null => null,
        },
        count: fields.containsKey('COUNT') ? number('COUNT') : null,
      );
    } on ArgumentError catch (e) {
      throw FormatException('${e.message}', text);
    }
  }

  /// Like [RecurrenceRule.parse], but returns null for invalid text.
  static RecurrenceRule? tryParse(String? text) {
    if (text == null) return null;
    try {
      return RecurrenceRule.parse(text);
    } on FormatException {
      return null;
    }
  }

  static const _keys = {
    'DTSTART',
    'FREQ',
    'INTERVAL',
    'BYDAY',
    'BYMONTHDAY',
    'UNTIL',
    'COUNT',
  };
  static const _dayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
  static final _byDayPattern = RegExp(r'^([+-]?\d)?([A-Z]{2})$');
  static final _datePattern = RegExp(r'^(\d{4})(\d{2})(\d{2})$');

  static LocalDate _parseDate(String value, String text) {
    final m = _datePattern.firstMatch(value);
    if (m == null) throw FormatException('Bad date $value', text);
    try {
      return LocalDate(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    } on ArgumentError {
      throw FormatException('Bad date $value', text);
    }
  }

  final Frequency frequency;

  /// First possible date of the series (`DTSTART`).
  final LocalDate start;

  /// Repeat every [interval] days/weeks/months/years.
  final int interval;

  /// Weekly only: ISO weekdays. Empty means the weekday of [start].
  final Set<int> weekdays;

  /// Monthly only: day of the month (1–31). Null (with no [nthWeekday])
  /// means the day of [start].
  final int? monthDay;

  /// Monthly only: for example "the 2nd Tuesday".
  final NthWeekday? nthWeekday;

  /// Last allowed date, inclusive.
  final LocalDate? until;

  /// Total number of occurrences, counted from [start].
  final int? count;

  /// The same rule anchored at a new [start] (resets what [count] counts).
  RecurrenceRule withStart(LocalDate start) => RecurrenceRule(
    frequency: frequency,
    start: start,
    interval: interval,
    weekdays: weekdays,
    monthDay: monthDay,
    nthWeekday: nthWeekday,
    until: until,
    count: count,
  );

  /// All occurrences in order, from [start]. Endless unless [until] or
  /// [count] is set.
  Iterable<LocalDate> occurrences() sync* {
    var emitted = 0;
    // Each period always yields at least one candidate, so this terminates
    // as soon as the limits are reached.
    for (var period = 0; ; period++) {
      for (final date in _candidates(period)) {
        if (date.isBefore(start)) continue;
        if (until != null && date.isAfter(until!)) return;
        yield date;
        emitted++;
        if (count != null && emitted >= count!) return;
      }
    }
  }

  /// The first occurrence strictly after [date], or null if the series has
  /// ended by then.
  LocalDate? nextAfter(LocalDate date) {
    for (final occurrence in _occurrencesFrom(date)) {
      if (occurrence.isAfter(date)) return occurrence;
    }
    return null;
  }

  /// Occurrences from [from] to [to], both inclusive.
  List<LocalDate> occurrencesBetween(LocalDate from, LocalDate to) {
    if (to.isBefore(from)) return const [];
    return _occurrencesFrom(from)
        .takeWhile((occurrence) => !occurrence.isAfter(to))
        .where((occurrence) => !occurrence.isBefore(from))
        .toList();
  }

  /// Occurrences, possibly starting a little before [date]. Without [count]
  /// earlier periods can be skipped, which keeps far-future queries fast.
  Iterable<LocalDate> _occurrencesFrom(LocalDate date) sync* {
    if (count != null || !date.isAfter(start)) {
      yield* occurrences();
      return;
    }
    // Start one period before the one containing [date].
    final first = (_periodOf(date) - 1).clamp(0, 1 << 31);
    for (var period = first; ; period++) {
      for (final candidate in _candidates(period)) {
        if (candidate.isBefore(start)) continue;
        if (until != null && candidate.isAfter(until!)) return;
        yield candidate;
      }
    }
  }

  /// Index of the period that contains [date] (may be approximate, never
  /// too high).
  int _periodOf(LocalDate date) => switch (frequency) {
    Frequency.daily => date.differenceInDays(start) ~/ interval,
    Frequency.weekly =>
      _isoWeekStart(date).differenceInDays(_isoWeekStart(start)) ~/
          (7 * interval),
    Frequency.monthly =>
      ((date.year - start.year) * 12 + date.month - start.month) ~/ interval,
    Frequency.yearly => (date.year - start.year) ~/ interval,
  };

  /// Candidate dates of one period, in order (some may be before [start]).
  List<LocalDate> _candidates(int period) {
    switch (frequency) {
      case Frequency.daily:
        return [start.addDays(period * interval)];
      case Frequency.weekly:
        // Weeks are counted Monday to Sunday (RFC 5545's default WKST).
        final weekStart = _isoWeekStart(start).addDays(period * interval * 7);
        final days = weekdays.isEmpty ? {start.weekday} : weekdays;
        return [
          for (final w in days.toList()..sort()) weekStart.addDays(w - 1),
        ];
      case Frequency.monthly:
        final months = start.month - 1 + period * interval;
        final year = start.year + months ~/ 12;
        final month = months % 12 + 1;
        if (nthWeekday case final nth?) {
          return [_nthWeekdayOf(year, month, nth)];
        }
        return [_clampedDate(year, month, monthDay ?? start.day)];
      case Frequency.yearly:
        return [
          _clampedDate(start.year + period * interval, start.month, start.day),
        ];
    }
  }

  static LocalDate _isoWeekStart(LocalDate date) =>
      date.addDays(1 - date.weekday);

  static int _daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  static LocalDate _clampedDate(int year, int month, int day) {
    final last = _daysInMonth(year, month);
    return LocalDate(year, month, day > last ? last : day);
  }

  static LocalDate _nthWeekdayOf(int year, int month, NthWeekday nth) {
    if (nth.n > 0) {
      final first = LocalDate(year, month, 1);
      final offset = (nth.weekday - first.weekday) % 7;
      return first.addDays(offset + (nth.n - 1) * 7);
    }
    final last = LocalDate(year, month, _daysInMonth(year, month));
    return last.addDays(-((last.weekday - nth.weekday) % 7));
  }

  String _date(LocalDate date) => date.toIso().replaceAll('-', '');

  @override
  String toString() => [
    'DTSTART=${_date(start)}',
    'FREQ=${frequency.name.toUpperCase()}',
    if (interval != 1) 'INTERVAL=$interval',
    if (weekdays.isNotEmpty)
      'BYDAY=${[for (final w in weekdays.toList()..sort()) _dayCodes[w - 1]].join(',')}',
    if (nthWeekday case final nth?)
      'BYDAY=${nth.n}${_dayCodes[nth.weekday - 1]}',
    if (monthDay case final day?) 'BYMONTHDAY=$day',
    if (until case final u?) 'UNTIL=${_date(u)}',
    if (count case final c?) 'COUNT=$c',
  ].join(';');

  @override
  bool operator ==(Object other) =>
      other is RecurrenceRule &&
      other.frequency == frequency &&
      other.start == start &&
      other.interval == interval &&
      other.weekdays.length == weekdays.length &&
      other.weekdays.containsAll(weekdays) &&
      other.monthDay == monthDay &&
      other.nthWeekday == nthWeekday &&
      other.until == until &&
      other.count == count;

  @override
  int get hashCode => Object.hash(
    frequency,
    start,
    interval,
    Object.hashAllUnordered(weekdays),
    monthDay,
    nthWeekday,
    until,
    count,
  );
}
