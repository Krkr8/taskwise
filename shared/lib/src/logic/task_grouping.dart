import '../models/enums.dart';
import '../models/local_date.dart';
import '../models/task.dart';

/// List-view sections, in display order (SPEC.md section 3.2).
enum TaskGroup { overdue, today, tomorrow, thisWeek, later, noDate, completed }

/// The first day of the week containing [date].
LocalDate startOfWeek(LocalDate date, WeekStart weekStart) {
  // Dart's % is never negative for a positive divisor.
  final offset = (date.weekday - weekStart.weekday) % 7;
  return date.addDays(-offset);
}

/// The last day of the week containing [date].
LocalDate endOfWeek(LocalDate date, WeekStart weekStart) =>
    startOfWeek(date, weekStart).addDays(6);

/// Which list section [task] belongs in, given [today]'s date.
///
/// Grouping is by date only: a task due earlier today stays in Today rather
/// than Overdue. "This week" covers the days after tomorrow up to the end of
/// the current week, so it's empty when tomorrow already starts a new week.
TaskGroup groupFor(
  Task task, {
  required LocalDate today,
  required WeekStart weekStart,
}) {
  if (task.done) return TaskGroup.completed;
  final due = task.dueDate;
  if (due == null) return TaskGroup.noDate;
  if (due.isBefore(today)) return TaskGroup.overdue;
  if (due == today) return TaskGroup.today;
  if (due == today.addDays(1)) return TaskGroup.tomorrow;
  if (!due.isAfter(endOfWeek(today, weekStart))) return TaskGroup.thisWeek;
  return TaskGroup.later;
}
