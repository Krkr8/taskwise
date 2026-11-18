import '../models/local_date.dart';
import '../models/task.dart';
import 'recurrence.dart';

/// The date of the new copy for a repeating [task] that wasn't done in time,
/// or null when none is due.
///
/// A copy is due once the occurrence after the task's due date has arrived
/// (is [today] or earlier) while the task is still open. The copy goes on the
/// first occurrence that is [today] or later, the same date completing the
/// task would give, so only one overdue copy is ever left behind. Null when
/// the task is done, deleted, has no due date or no valid rule, or when the
/// series has no occurrence left from [today].
LocalDate? missedRepeatDate(Task task, LocalDate today) {
  final due = task.dueDate;
  if (task.done || task.deleted || due == null || !due.isBefore(today)) {
    return null;
  }
  final rule = RecurrenceRule.tryParse(task.recurrenceRule);
  if (rule == null) return null;
  final next = rule.nextAfter(due);
  if (next == null || next.isAfter(today)) return null;
  return rule.nextAfter(today.addDays(-1));
}
