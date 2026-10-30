import '../models/enums.dart';
import '../models/local_date.dart';
import '../models/task.dart';
import 'recurrence.dart';
import 'task_grouping.dart';

/// A task shown on one calendar day.
final class CalendarItem {
  const CalendarItem({
    required this.task,
    required this.date,
    this.projected = false,
  });

  final Task task;
  final LocalDate date;

  /// True for a future repeat of [task] that doesn't exist as a task yet
  /// (the next copy is only created when the current one is completed).
  final bool projected;

  /// Minutes after midnight, or null for an all-day item.
  int? get timeMinutes => task.dueTimeMinutes;

  @override
  bool operator ==(Object other) =>
      other is CalendarItem &&
      other.task == task &&
      other.date == date &&
      other.projected == projected;

  @override
  int get hashCode => Object.hash(task, date, projected);
}

/// Calendar items for every day from [from] to [to] (inclusive), keyed by
/// date. Days without items are left out.
///
/// Real tasks appear on their due date. Open repeating tasks also appear,
/// [CalendarItem.projected], on each later occurrence in the range. Each day
/// lists all-day items first, then timed ones by time, then by title.
Map<LocalDate, List<CalendarItem>> calendarItems(
  Iterable<Task> tasks, {
  required LocalDate from,
  required LocalDate to,
}) {
  final byDay = <LocalDate, List<CalendarItem>>{};
  void add(CalendarItem item) => (byDay[item.date] ??= []).add(item);

  for (final task in tasks) {
    final due = task.dueDate;
    if (task.deleted || due == null) continue;
    if (!due.isBefore(from) && !due.isAfter(to)) {
      add(CalendarItem(task: task, date: due));
    }
    if (task.done || due.isAfter(to)) continue;
    final rule = RecurrenceRule.tryParse(task.recurrenceRule);
    if (rule == null) continue;
    final start = due.isBefore(from) ? from : due.addDays(1);
    for (final date in rule.occurrencesBetween(start, to)) {
      if (date.isAfter(due)) {
        add(CalendarItem(task: task, date: date, projected: true));
      }
    }
  }
  for (final items in byDay.values) {
    items.sort(_compareItems);
  }
  return byDay;
}

int _compareItems(CalendarItem a, CalendarItem b) {
  final at = a.timeMinutes ?? -1;
  final bt = b.timeMinutes ?? -1;
  if (at != bt) return at.compareTo(bt);
  return a.task.title.toLowerCase().compareTo(b.task.title.toLowerCase());
}

/// The 7 dates of the week containing [date].
List<LocalDate> weekDays(LocalDate date, WeekStart weekStart) {
  final first = startOfWeek(date, weekStart);
  return [for (var i = 0; i < 7; i++) first.addDays(i)];
}

/// The 42 dates (6 weeks) shown for the month containing [date], starting
/// on the week-start day on or before the 1st.
List<LocalDate> monthGridDays(LocalDate date, WeekStart weekStart) {
  final first = startOfWeek(LocalDate(date.year, date.month, 1), weekStart);
  return [for (var i = 0; i < 42; i++) first.addDays(i)];
}

/// The first day of the month [months] months after [date]'s month.
LocalDate addMonths(LocalDate date, int months) {
  final index = date.year * 12 + date.month - 1 + months;
  return LocalDate(index ~/ 12, index % 12 + 1, 1);
}
