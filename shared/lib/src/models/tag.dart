import 'sync_record.dart';

/// A free-form label. A task can have many tags (see [TaskTag]).
final class Tag implements SyncRecord {
  const Tag({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.deleted = false,
    this.updatedByDevice,
  });

  factory Tag.fromJson(Map<String, Object?> json) => Tag(
    id: json['id']! as String,
    name: json['name']! as String,
    updatedAt: JsonFields.parseRequiredDateTime(json['updatedAt']),
    deleted: json['deleted'] as bool? ?? false,
    updatedByDevice: json['updatedByDevice'] as String?,
  );

  @override
  final String id;
  final String name;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;
  @override
  final String? updatedByDevice;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'updatedAt': JsonFields.dateTime(updatedAt),
    'deleted': deleted,
    'updatedByDevice': updatedByDevice,
  };

  @override
  bool operator ==(Object other) =>
      other is Tag &&
      other.id == id &&
      other.name == name &&
      other.updatedAt == updatedAt &&
      other.deleted == deleted &&
      other.updatedByDevice == updatedByDevice;

  @override
  int get hashCode =>
      Object.hash(id, name, updatedAt, deleted, updatedByDevice);

  @override
  String toString() => 'Tag($id, "$name")';
}

/// Links a task to a tag. Stored as its own record so links sync and can be
/// tombstoned like everything else.
final class TaskTag implements SyncRecord {
  const TaskTag({
    required this.id,
    required this.taskId,
    required this.tagId,
    required this.updatedAt,
    this.deleted = false,
    this.updatedByDevice,
  });

  factory TaskTag.fromJson(Map<String, Object?> json) => TaskTag(
    id: json['id']! as String,
    taskId: json['taskId']! as String,
    tagId: json['tagId']! as String,
    updatedAt: JsonFields.parseRequiredDateTime(json['updatedAt']),
    deleted: json['deleted'] as bool? ?? false,
    updatedByDevice: json['updatedByDevice'] as String?,
  );

  @override
  final String id;
  final String taskId;
  final String tagId;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;
  @override
  final String? updatedByDevice;

  Map<String, Object?> toJson() => {
    'id': id,
    'taskId': taskId,
    'tagId': tagId,
    'updatedAt': JsonFields.dateTime(updatedAt),
    'deleted': deleted,
    'updatedByDevice': updatedByDevice,
  };

  @override
  bool operator ==(Object other) =>
      other is TaskTag &&
      other.id == id &&
      other.taskId == taskId &&
      other.tagId == tagId &&
      other.updatedAt == updatedAt &&
      other.deleted == deleted &&
      other.updatedByDevice == updatedByDevice;

  @override
  int get hashCode =>
      Object.hash(id, taskId, tagId, updatedAt, deleted, updatedByDevice);
}
