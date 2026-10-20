import '../models/enums.dart';
import '../models/local_date.dart';
import 'task_entry.dart';
import 'task_grouping.dart';

/// Filters for the task list. Facets combine with AND; values inside one
/// facet combine with OR (e.g. category A or B, and priority high).
final class TaskFilter {
  const TaskFilter({
    this.text = '',
    this.categoryIds = const {},
    this.priorities = const {},
    this.tagIds = const {},
  });

  /// Case-insensitive search in title and notes.
  final String text;
  final Set<String> categoryIds;
  final Set<Priority> priorities;
  final Set<String> tagIds;

  bool get isEmpty =>
      text.trim().isEmpty &&
      categoryIds.isEmpty &&
      priorities.isEmpty &&
      tagIds.isEmpty;

  /// Number of active facets, excluding the text search.
  int get activeFacetCount =>
      (categoryIds.isEmpty ? 0 : 1) +
      (priorities.isEmpty ? 0 : 1) +
      (tagIds.isEmpty ? 0 : 1);

  bool matches(TaskEntry entry) {
    final task = entry.task;
    final query = text.trim().toLowerCase();
    if (query.isNotEmpty &&
        !task.title.toLowerCase().contains(query) &&
        !task.notes.toLowerCase().contains(query)) {
      return false;
    }
    if (categoryIds.isNotEmpty && !categoryIds.contains(task.categoryId)) {
      return false;
    }
    if (priorities.isNotEmpty && !priorities.contains(task.priority)) {
      return false;
    }
    if (tagIds.isNotEmpty && !entry.tagIds.any(tagIds.contains)) {
      return false;
    }
    return true;
  }

  TaskFilter copyWith({
    String? text,
    Set<String>? categoryIds,
    Set<Priority>? priorities,
    Set<String>? tagIds,
  }) => TaskFilter(
    text: text ?? this.text,
    categoryIds: categoryIds ?? this.categoryIds,
    priorities: priorities ?? this.priorities,
    tagIds: tagIds ?? this.tagIds,
  );
}

/// Sort orders offered in the list view.
enum TaskSort {
  /// Earliest due first; all-day before timed on the same day; undated last.
  dueDate,

  /// Highest priority first, then by due date.
  priority,

  /// Alphabetical (case-insensitive).
  title,

  /// Newest first.
  created;

  static TaskSort fromName(String? name) =>
      values.asNameMap()[name] ?? TaskSort.dueDate;
}

/// Compares entries by [sort], falling back to creation time so the order is
/// always stable and deterministic.
int compareEntries(TaskEntry a, TaskEntry b, TaskSort sort) {
  final result = switch (sort) {
    TaskSort.dueDate => _compareDue(a, b),
    TaskSort.priority => _comparePriority(a, b, thenDue: true),
    TaskSort.title => a.task.title.toLowerCase().compareTo(
      b.task.title.toLowerCase(),
    ),
    TaskSort.created => b.task.createdAt.compareTo(a.task.createdAt),
  };
  if (result != 0) return result;
  return a.task.createdAt.compareTo(b.task.createdAt);
}

int _compareDue(TaskEntry a, TaskEntry b) {
  final dateA = a.task.dueDate;
  final dateB = b.task.dueDate;
  if (dateA == null || dateB == null) {
    if (dateA == dateB) return _comparePriority(a, b, thenDue: false);
    return dateA == null ? 1 : -1;
  }
  final byDate = dateA.compareTo(dateB);
  if (byDate != 0) return byDate;
  // All-day (null time) sorts before timed tasks on the same day.
  final timeA = a.task.dueTimeMinutes ?? -1;
  final timeB = b.task.dueTimeMinutes ?? -1;
  if (timeA != timeB) return timeA.compareTo(timeB);
  return _comparePriority(a, b, thenDue: false);
}

int _comparePriority(TaskEntry a, TaskEntry b, {required bool thenDue}) {
  final byPriority = b.task.priority.index.compareTo(a.task.priority.index);
  if (byPriority != 0 || !thenDue) return byPriority;
  return _compareDue(a, b);
}

/// One list section with its tasks, already sorted.
final class TaskSection {
  const TaskSection(this.group, this.entries);

  final TaskGroup group;
  final List<TaskEntry> entries;
}

/// Filters, groups and sorts [entries] into the list-view sections.
///
/// Empty sections are left out. Deleted tasks are always excluded. The
/// Completed section is always ordered by completion time, newest first.
List<TaskSection> buildTaskSections(
  Iterable<TaskEntry> entries, {
  required LocalDate today,
  required WeekStart weekStart,
  TaskFilter filter = const TaskFilter(),
  TaskSort sort = TaskSort.dueDate,
}) {
  final byGroup = <TaskGroup, List<TaskEntry>>{};
  for (final entry in entries) {
    if (entry.task.deleted || !filter.matches(entry)) continue;
    final group = groupFor(entry.task, today: today, weekStart: weekStart);
    (byGroup[group] ??= []).add(entry);
  }
  return [
    for (final group in TaskGroup.values)
      if (byGroup[group] case final list?)
        TaskSection(
          group,
          list..sort(
            group == TaskGroup.completed
                ? _compareCompleted
                : (a, b) => compareEntries(a, b, sort),
          ),
        ),
  ];
}

int _compareCompleted(TaskEntry a, TaskEntry b) {
  final atA = a.task.completedAt ?? a.task.updatedAt;
  final atB = b.task.completedAt ?? b.task.updatedAt;
  return atB.compareTo(atA);
}
