import 'enums.dart';
import 'local_date.dart';
import 'sync_record.dart';

/// A to-do item.
///
/// Due date and time are floating local values: [dueDate] is a calendar date
/// and [dueTimeMinutes] is minutes after local midnight. A task with a date
/// but no time is all-day.
final class Task implements SyncRecord {
  const Task({
    required this.id,
    required this.title,
    this.notes = '',
    this.dueDate,
    this.dueTimeMinutes,
    this.priority = Priority.none,
    this.categoryId,
    this.done = false,
    this.completedAt,
    this.recurrenceRule,
    this.notifyAllDevices = true,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    this.updatedByDevice,
  }) : assert(
         dueTimeMinutes == null ||
             (dueTimeMinutes >= 0 && dueTimeMinutes < 24 * 60),
         'dueTimeMinutes must be within one day',
       );

  factory Task.fromJson(Map<String, Object?> json) => Task(
    id: json['id']! as String,
    title: json['title']! as String,
    notes: json['notes'] as String? ?? '',
    dueDate: switch (json['dueDate']) {
      final String iso => LocalDate.parse(iso),
      _ => null,
    },
    dueTimeMinutes: json['dueTimeMinutes'] as int?,
    priority: Priority.fromName(json['priority'] as String?),
    categoryId: json['categoryId'] as String?,
    done: json['done'] as bool? ?? false,
    completedAt: JsonFields.parseDateTime(json['completedAt']),
    recurrenceRule: json['recurrenceRule'] as String?,
    notifyAllDevices: json['notifyAllDevices'] as bool? ?? true,
    createdAt: JsonFields.parseRequiredDateTime(json['createdAt']),
    updatedAt: JsonFields.parseRequiredDateTime(json['updatedAt']),
    deleted: json['deleted'] as bool? ?? false,
    updatedByDevice: json['updatedByDevice'] as String?,
  );

  @override
  final String id;
  final String title;

  /// Plain text or simple markdown.
  final String notes;
  final LocalDate? dueDate;

  /// Minutes after local midnight; null means all-day (or no due date).
  final int? dueTimeMinutes;
  final Priority priority;
  final String? categoryId;
  final bool done;
  final DateTime? completedAt;

  /// RRULE-style recurrence rule (used from M3).
  final String? recurrenceRule;

  /// True means "notify on all devices", including ones added later.
  /// When false, the explicit device list is used (from M6).
  final bool notifyAllDevices;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;
  @override
  final String? updatedByDevice;

  /// True when the task has a due date but no time.
  bool get isAllDay => dueDate != null && dueTimeMinutes == null;

  /// The due moment in local time, or null when there's no due time.
  DateTime? get dueAt => switch ((dueDate, dueTimeMinutes)) {
    (final LocalDate date, final int minutes) => date.atLocalTime(minutes),
    _ => null,
  };

  /// Trims [title] and throws [ArgumentError] if nothing is left.
  static String validateTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    return trimmed;
  }

  /// Returns a copy with the given fields replaced. Nullable fields take a
  /// function so they can be cleared: `copyWith(dueDate: () => null)`.
  Task copyWith({
    String? title,
    String? notes,
    LocalDate? Function()? dueDate,
    int? Function()? dueTimeMinutes,
    Priority? priority,
    String? Function()? categoryId,
    bool? done,
    DateTime? Function()? completedAt,
    String? Function()? recurrenceRule,
    bool? notifyAllDevices,
    DateTime? updatedAt,
    bool? deleted,
    String? Function()? updatedByDevice,
  }) => Task(
    id: id,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    dueDate: dueDate != null ? dueDate() : this.dueDate,
    dueTimeMinutes: dueTimeMinutes != null
        ? dueTimeMinutes()
        : this.dueTimeMinutes,
    priority: priority ?? this.priority,
    categoryId: categoryId != null ? categoryId() : this.categoryId,
    done: done ?? this.done,
    completedAt: completedAt != null ? completedAt() : this.completedAt,
    recurrenceRule: recurrenceRule != null
        ? recurrenceRule()
        : this.recurrenceRule,
    notifyAllDevices: notifyAllDevices ?? this.notifyAllDevices,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    updatedByDevice: updatedByDevice != null
        ? updatedByDevice()
        : this.updatedByDevice,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'notes': notes,
    'dueDate': dueDate?.toIso(),
    'dueTimeMinutes': dueTimeMinutes,
    'priority': priority.name,
    'categoryId': categoryId,
    'done': done,
    'completedAt': JsonFields.dateTime(completedAt),
    'recurrenceRule': recurrenceRule,
    'notifyAllDevices': notifyAllDevices,
    'createdAt': JsonFields.dateTime(createdAt),
    'updatedAt': JsonFields.dateTime(updatedAt),
    'deleted': deleted,
    'updatedByDevice': updatedByDevice,
  };

  @override
  bool operator ==(Object other) =>
      other is Task &&
      other.id == id &&
      other.title == title &&
      other.notes == notes &&
      other.dueDate == dueDate &&
      other.dueTimeMinutes == dueTimeMinutes &&
      other.priority == priority &&
      other.categoryId == categoryId &&
      other.done == done &&
      other.completedAt == completedAt &&
      other.recurrenceRule == recurrenceRule &&
      other.notifyAllDevices == notifyAllDevices &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.deleted == deleted &&
      other.updatedByDevice == updatedByDevice;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    notes,
    dueDate,
    dueTimeMinutes,
    priority,
    categoryId,
    done,
    completedAt,
    recurrenceRule,
    notifyAllDevices,
    createdAt,
    updatedAt,
    deleted,
    updatedByDevice,
  );

  @override
  String toString() => 'Task($id, "$title")';
}
