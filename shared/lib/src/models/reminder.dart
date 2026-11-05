import 'enums.dart';
import 'sync_record.dart';

/// A reminder attached to a task. The schema exists from M1; time reminders
/// get UI and scheduling in M4, location reminders in M7.
///
/// - [ReminderKind.time]: either [absoluteAt] (a fixed moment) or
///   [minutesBeforeDue] (relative to the task's due time; 0 = at due time).
/// - [ReminderKind.location]: [placeId] or explicit coordinates, plus
///   [radiusMeters] and [trigger]. [label] names a spot that isn't a saved
///   place (e.g. the address picked from a search).
final class Reminder implements SyncRecord {
  const Reminder({
    required this.id,
    required this.taskId,
    required this.kind,
    this.absoluteAt,
    this.minutesBeforeDue,
    this.placeId,
    this.latitude,
    this.longitude,
    this.radiusMeters,
    this.trigger,
    this.label,
    required this.updatedAt,
    this.deleted = false,
    this.updatedByDevice,
  });

  factory Reminder.fromJson(Map<String, Object?> json) => Reminder(
    id: json['id']! as String,
    taskId: json['taskId']! as String,
    kind: ReminderKind.values.byName(json['kind']! as String),
    absoluteAt: JsonFields.parseDateTime(json['absoluteAt']),
    minutesBeforeDue: json['minutesBeforeDue'] as int?,
    placeId: json['placeId'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    radiusMeters: json['radiusMeters'] as int?,
    trigger: switch (json['trigger']) {
      final String name => LocationTrigger.values.byName(name),
      _ => null,
    },
    label: json['label'] as String?,
    updatedAt: JsonFields.parseRequiredDateTime(json['updatedAt']),
    deleted: json['deleted'] as bool? ?? false,
    updatedByDevice: json['updatedByDevice'] as String?,
  );

  @override
  final String id;
  final String taskId;
  final ReminderKind kind;
  final DateTime? absoluteAt;
  final int? minutesBeforeDue;
  final String? placeId;
  final double? latitude;
  final double? longitude;
  final int? radiusMeters;
  final LocationTrigger? trigger;
  final String? label;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;
  @override
  final String? updatedByDevice;

  Map<String, Object?> toJson() => {
    'id': id,
    'taskId': taskId,
    'kind': kind.name,
    'absoluteAt': JsonFields.dateTime(absoluteAt),
    'minutesBeforeDue': minutesBeforeDue,
    'placeId': placeId,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
    'trigger': trigger?.name,
    'label': label,
    'updatedAt': JsonFields.dateTime(updatedAt),
    'deleted': deleted,
    'updatedByDevice': updatedByDevice,
  };

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.id == id &&
      other.taskId == taskId &&
      other.kind == kind &&
      other.absoluteAt == absoluteAt &&
      other.minutesBeforeDue == minutesBeforeDue &&
      other.placeId == placeId &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.radiusMeters == radiusMeters &&
      other.trigger == trigger &&
      other.label == label &&
      other.updatedAt == updatedAt &&
      other.deleted == deleted &&
      other.updatedByDevice == updatedByDevice;

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    kind,
    absoluteAt,
    minutesBeforeDue,
    placeId,
    latitude,
    longitude,
    radiusMeters,
    trigger,
    label,
    updatedAt,
    deleted,
    updatedByDevice,
  );
}
