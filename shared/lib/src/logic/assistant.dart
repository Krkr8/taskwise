import '../models/local_date.dart';
import '../models/task.dart';

/// A task a phone assistant added while Taskwise may have been closed (Siri
/// on the iPhone). Native code appends these to an inbox file; the app moves
/// them into the database through the normal task repository, so they sync
/// like any other task.
///
/// The JSON shape is shared with `app/ios/Runner/AssistantStore.swift`:
/// `{"id", "title", "notes"?, "dueDate"? ("2026-11-12"),
/// "dueTimeMinutes"? (0-1439), "createdAt" (UTC ISO 8601)}`.
final class AssistantInboxEntry {
  AssistantInboxEntry({
    required this.id,
    required String title,
    this.notes = '',
    this.dueDate,
    int? dueTimeMinutes,
    required this.createdAt,
  }) : title = Task.validateTitle(title),
       dueTimeMinutes = dueDate == null ? null : dueTimeMinutes {
    final t = this.dueTimeMinutes;
    if (t != null && (t < 0 || t >= 24 * 60)) {
      throw ArgumentError.value(t, 'dueTimeMinutes', 'must be within one day');
    }
  }

  /// Reads one entry, or returns null if it is malformed (a bad entry must
  /// never block the others).
  static AssistantInboxEntry? tryFromJson(Object? json) {
    if (json is! Map) return null;
    try {
      final id = json['id'];
      final title = json['title'];
      final created = json['createdAt'];
      if (id is! String || id.isEmpty || title is! String) return null;
      if (created is! String) return null;
      final due = json['dueDate'];
      final time = json['dueTimeMinutes'];
      return AssistantInboxEntry(
        id: id,
        title: title,
        notes: json['notes'] is String ? json['notes'] as String : '',
        dueDate: due is String ? LocalDate.parse(due) : null,
        dueTimeMinutes: time is num ? time.toInt() : null,
        createdAt: DateTime.parse(created).toUtc(),
      );
    } on Object {
      return null;
    }
  }

  /// Becomes the task's id, so importing the same entry twice adds one task.
  final String id;
  final String title;
  final String notes;
  final LocalDate? dueDate;

  /// Minutes after local midnight; null means all-day (or no due date).
  final int? dueTimeMinutes;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    if (notes.isNotEmpty) 'notes': notes,
    if (dueDate != null) 'dueDate': dueDate!.toIso(),
    if (dueTimeMinutes != null) 'dueTimeMinutes': dueTimeMinutes,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}

/// The readable entries of an inbox (a JSON list); malformed ones are
/// skipped.
List<AssistantInboxEntry> parseAssistantInbox(Object? json) => [
  if (json is List)
    for (final item in json) ?AssistantInboxEntry.tryFromJson(item),
];

/// What the phone's assistant may read out without opening Taskwise: the
/// open tasks that are overdue or due within [days] days from [today],
/// soonest first, at most [limit].
///
/// The assistant filters by its own "today" when asked, so the list stays
/// right even if Taskwise last ran days ago. Shape (shared with
/// `AssistantStore.swift`): `{"version": 1, "tasks": [{"title", "dueDate",
/// "dueTimeMinutes"?}]}`.
Map<String, Object?> buildAssistantSnapshot(
  Iterable<Task> tasks,
  LocalDate today, {
  int days = 7,
  int limit = 100,
}) {
  final last = today.addDays(days);
  final due = [
    for (final t in tasks)
      if (!t.done &&
          !t.deleted &&
          t.dueDate != null &&
          !t.dueDate!.isAfter(last))
        t,
  ]..sort(_bySchedule);
  return {
    'version': 1,
    'tasks': [
      for (final t in due.take(limit))
        {
          'title': t.title,
          'dueDate': t.dueDate!.toIso(),
          if (t.dueTimeMinutes != null) 'dueTimeMinutes': t.dueTimeMinutes,
        },
    ],
  };
}

/// Date, then all-day before timed, then time, then title.
int _bySchedule(Task a, Task b) {
  final byDate = a.dueDate!.compareTo(b.dueDate!);
  if (byDate != 0) return byDate;
  final at = a.dueTimeMinutes ?? -1;
  final bt = b.dueTimeMinutes ?? -1;
  if (at != bt) return at.compareTo(bt);
  return a.title.compareTo(b.title);
}

/// Turns text shared to Taskwise (Android's share sheet) into a task: the
/// first non-empty line is the title and the rest the notes. Returns null if
/// there is no text.
({String title, String notes})? taskFromSharedText(String? text) {
  if (text == null) return null;
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  final first = lines.indexWhere((l) => l.trim().isNotEmpty);
  if (first < 0) return null;
  var title = lines[first].trim();
  var notes = lines.skip(first + 1).join('\n').trim();
  // A very long first line (a pasted paragraph) keeps a short title and
  // moves the whole text to the notes.
  if (title.length > maxSharedTitleLength) {
    notes = text.trim();
    title = '${title.substring(0, maxSharedTitleLength - 1).trimRight()}…';
  }
  return (title: title, notes: notes);
}

/// The longest title made from shared text.
const maxSharedTitleLength = 120;
