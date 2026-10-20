import 'sync_record.dart';

/// A checklist item inside a task.
final class Subtask implements SyncRecord {
  const Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    this.done = false,
    required this.sortOrder,
    required this.updatedAt,
    this.deleted = false,
    this.updatedByDevice,
  });

  factory Subtask.fromJson(Map<String, Object?> json) => Subtask(
    id: json['id']! as String,
    taskId: json['taskId']! as String,
    title: json['title']! as String,
    done: json['done'] as bool? ?? false,
    sortOrder: json['sortOrder']! as int,
    updatedAt: JsonFields.parseRequiredDateTime(json['updatedAt']),
    deleted: json['deleted'] as bool? ?? false,
    updatedByDevice: json['updatedByDevice'] as String?,
  );

  @override
  final String id;
  final String taskId;
  final String title;
  final bool done;

  /// Position within the task's checklist, ascending.
  final int sortOrder;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;
  @override
  final String? updatedByDevice;

  Subtask copyWith({
    String? title,
    bool? done,
    int? sortOrder,
    DateTime? updatedAt,
    bool? deleted,
    String? Function()? updatedByDevice,
  }) => Subtask(
    id: id,
    taskId: taskId,
    title: title ?? this.title,
    done: done ?? this.done,
    sortOrder: sortOrder ?? this.sortOrder,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    updatedByDevice: updatedByDevice != null
        ? updatedByDevice()
        : this.updatedByDevice,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'taskId': taskId,
    'title': title,
    'done': done,
    'sortOrder': sortOrder,
    'updatedAt': JsonFields.dateTime(updatedAt),
    'deleted': deleted,
    'updatedByDevice': updatedByDevice,
  };

  @override
  bool operator ==(Object other) =>
      other is Subtask &&
      other.id == id &&
      other.taskId == taskId &&
      other.title == title &&
      other.done == done &&
      other.sortOrder == sortOrder &&
      other.updatedAt == updatedAt &&
      other.deleted == deleted &&
      other.updatedByDevice == updatedByDevice;

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    title,
    done,
    sortOrder,
    updatedAt,
    deleted,
    updatedByDevice,
  );

  @override
  String toString() => 'Subtask($id, "$title")';
}
