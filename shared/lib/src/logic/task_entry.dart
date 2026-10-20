import '../models/task.dart';

/// A task plus the related data the list view needs to filter and display it.
final class TaskEntry {
  const TaskEntry({
    required this.task,
    this.tagIds = const {},
    this.subtaskCount = 0,
    this.subtasksDone = 0,
  });

  final Task task;
  final Set<String> tagIds;
  final int subtaskCount;
  final int subtasksDone;

  @override
  bool operator ==(Object other) =>
      other is TaskEntry &&
      other.task == task &&
      other.subtaskCount == subtaskCount &&
      other.subtasksDone == subtasksDone &&
      other.tagIds.length == tagIds.length &&
      other.tagIds.containsAll(tagIds);

  @override
  int get hashCode => Object.hash(
    task,
    subtaskCount,
    subtasksDone,
    Object.hashAllUnordered(tagIds),
  );
}
