import 'enums.dart';
import 'sync_record.dart';

/// An app install registered with the account.
final class Device implements SyncRecord {
  const Device({
    required this.id,
    required this.name,
    required this.type,
    this.lastSeenAt,
    required this.updatedAt,
    this.deleted = false,
    this.updatedByDevice,
    this.isMain = false,
  });

  factory Device.fromJson(Map<String, Object?> json) => Device(
    id: json['id']! as String,
    name: json['name']! as String,
    type: DeviceType.fromName(json['type'] as String?),
    lastSeenAt: JsonFields.parseDateTime(json['lastSeenAt']),
    updatedAt: JsonFields.parseRequiredDateTime(json['updatedAt']),
    deleted: json['deleted'] as bool? ?? false,
    updatedByDevice: json['updatedByDevice'] as String?,
    isMain: json['main'] as bool? ?? false,
  );

  @override
  final String id;
  final String name;
  final DeviceType type;
  final DateTime? lastSeenAt;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;
  @override
  final String? updatedByDevice;

  /// The main device manages the account's devices (set by the server).
  final bool isMain;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'lastSeenAt': JsonFields.dateTime(lastSeenAt),
    'updatedAt': JsonFields.dateTime(updatedAt),
    'deleted': deleted,
    'updatedByDevice': updatedByDevice,
    'main': isMain,
  };

  @override
  bool operator ==(Object other) =>
      other is Device &&
      other.id == id &&
      other.name == name &&
      other.type == type &&
      other.lastSeenAt == lastSeenAt &&
      other.updatedAt == updatedAt &&
      other.deleted == deleted &&
      other.updatedByDevice == updatedByDevice &&
      other.isMain == isMain;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    lastSeenAt,
    updatedAt,
    deleted,
    updatedByDevice,
    isMain,
  );

  @override
  String toString() => 'Device($id, "$name", ${type.name})';
}

/// Links a task to a device it should notify on. Only used when the task's
/// `notifyAllDevices` flag is false (from M6).
final class TaskTargetDevice implements SyncRecord {
  const TaskTargetDevice({
    required this.id,
    required this.taskId,
    required this.deviceId,
    required this.updatedAt,
    this.deleted = false,
    this.updatedByDevice,
  });

  factory TaskTargetDevice.fromJson(Map<String, Object?> json) =>
      TaskTargetDevice(
        id: json['id']! as String,
        taskId: json['taskId']! as String,
        deviceId: json['deviceId']! as String,
        updatedAt: JsonFields.parseRequiredDateTime(json['updatedAt']),
        deleted: json['deleted'] as bool? ?? false,
        updatedByDevice: json['updatedByDevice'] as String?,
      );

  @override
  final String id;
  final String taskId;
  final String deviceId;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;
  @override
  final String? updatedByDevice;

  Map<String, Object?> toJson() => {
    'id': id,
    'taskId': taskId,
    'deviceId': deviceId,
    'updatedAt': JsonFields.dateTime(updatedAt),
    'deleted': deleted,
    'updatedByDevice': updatedByDevice,
  };

  @override
  bool operator ==(Object other) =>
      other is TaskTargetDevice &&
      other.id == id &&
      other.taskId == taskId &&
      other.deviceId == deviceId &&
      other.updatedAt == updatedAt &&
      other.deleted == deleted &&
      other.updatedByDevice == updatedByDevice;

  @override
  int get hashCode =>
      Object.hash(id, taskId, deviceId, updatedAt, deleted, updatedByDevice);
}
