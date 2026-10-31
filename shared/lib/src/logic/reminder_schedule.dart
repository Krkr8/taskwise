import 'dart:convert';

import '../models/enums.dart';
import '../models/local_date.dart';
import '../models/reminder.dart';
import '../models/task.dart';
import 'recurrence.dart';

/// A reminder the user snoozed: it fires again at [until].
final class Snooze {
  const Snooze({
    required this.taskId,
    required this.occurrence,
    required this.until,
  });

  factory Snooze.fromJson(Map<String, Object?> json) => Snooze(
    taskId: json['taskId']! as String,
    occurrence: LocalDate.parse(json['occurrence']! as String),
    until: DateTime.parse(json['until']! as String),
  );

  final String taskId;

  /// The occurrence of the task the snoozed reminder belonged to.
  final LocalDate occurrence;
  final DateTime until;

  Map<String, Object?> toJson() => {
    'taskId': taskId,
    'occurrence': occurrence.toIso(),
    'until': until.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is Snooze &&
      other.taskId == taskId &&
      other.occurrence == occurrence &&
      other.until.isAtSameMomentAs(until);

  @override
  int get hashCode =>
      Object.hash(taskId, occurrence, until.microsecondsSinceEpoch);

  /// Encodes a list for storage in a setting.
  static String encodeList(List<Snooze> snoozes) =>
      jsonEncode([for (final s in snoozes) s.toJson()]);

  /// Decodes [encodeList] output; invalid text gives an empty list.
  static List<Snooze> decodeList(String? text) {
    if (text == null || text.isEmpty) return const [];
    try {
      return [
        for (final item in jsonDecode(text) as List<Object?>)
          Snooze.fromJson((item! as Map).cast<String, Object?>()),
      ];
    } on Object {
      return const [];
    }
  }
}

/// One notification the device should show.
final class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.taskId,
    required this.title,
    required this.occurrence,
    required this.fireAt,
    this.reminderId,
    this.projected = false,
    this.snoozed = false,
  });

  /// Stable 31-bit id: the same reminder and occurrence always get the same
  /// id, so a platform's pending notifications can be diffed against a plan.
  final int id;
  final String taskId;

  /// The task's title, for the notification text.
  final String title;
  final LocalDate occurrence;

  /// When to show it, as a local wall-clock time.
  final DateTime fireAt;

  /// The reminder it comes from (null for a snooze).
  final String? reminderId;

  /// For a future repeat that isn't a task yet (it can't be ticked off from
  /// the notification).
  final bool projected;
  final bool snoozed;

  @override
  String toString() =>
      'PlannedNotification($taskId @ $fireAt${projected ? ', projected' : ''}'
      '${snoozed ? ', snoozed' : ''})';
}

/// Which time-reminder notifications to show, soonest first.
///
/// - Relative reminders count back from each occurrence's due time, or from
///   [allDayMinutes] for all-day tasks. The maths is in wall-clock time, so
///   "1 day before 9:00" stays at 9:00 across a DST change.
/// - Absolute reminders fire once at their moment.
/// - Open repeating tasks get reminders for every occurrence up to
///   [horizon] ahead, including ones that aren't tasks yet (projected).
/// - Only notifications after [after] (default [now]) and before
///   `now + horizon` are returned, at most [limit] (iOS allows 64 pending).
List<PlannedNotification> planNotifications({
  required Iterable<Task> tasks,
  required Iterable<Reminder> reminders,
  required DateTime now,
  DateTime? after,
  Duration horizon = const Duration(days: 14),
  int allDayMinutes = 9 * 60,
  Iterable<Snooze> snoozes = const [],
  int? limit,
}) {
  final from = after ?? now;
  final until = now.add(horizon);
  final byId = {
    for (final t in tasks)
      if (!t.deleted && !t.done) t.id: t,
  };
  final plan = <PlannedNotification>[];

  void add(PlannedNotification p) {
    if (p.fireAt.isAfter(from) && !p.fireAt.isAfter(until)) plan.add(p);
  }

  for (final reminder in reminders) {
    if (reminder.deleted || reminder.kind != ReminderKind.time) continue;
    final task = byId[reminder.taskId];
    if (task == null) continue;

    if (reminder.absoluteAt case final absolute?) {
      final local = absolute.toLocal();
      final occurrence = LocalDate.fromDateTime(local);
      add(
        PlannedNotification(
          id: _stableId('${reminder.id}@abs'),
          taskId: task.id,
          title: task.title,
          occurrence: occurrence,
          fireAt: local,
          reminderId: reminder.id,
        ),
      );
      continue;
    }

    final before = reminder.minutesBeforeDue;
    final due = task.dueDate;
    if (before == null || due == null) continue;
    final dueMinutes = task.dueTimeMinutes ?? allDayMinutes;

    void addOccurrence(LocalDate date, {required bool projected}) => add(
      PlannedNotification(
        id: _stableId('${reminder.id}@${date.toIso()}'),
        taskId: task.id,
        title: task.title,
        occurrence: date,
        // DateTime normalises out-of-range minutes in local wall time.
        fireAt: DateTime(
          date.year,
          date.month,
          date.day,
          0,
          dueMinutes - before,
        ),
        reminderId: reminder.id,
        projected: projected,
      ),
    );

    addOccurrence(due, projected: false);
    final rule = RecurrenceRule.tryParse(task.recurrenceRule);
    if (rule == null) continue;
    // A reminder can fire days before its occurrence, so look a bit past
    // the horizon for occurrences.
    final lastDate = LocalDate.fromDateTime(until)
        .addDays(before ~/ (24 * 60) + 1);
    final today = LocalDate.fromDateTime(now);
    final start = due.isBefore(today) ? today : due.addDays(1);
    for (final date in rule.occurrencesBetween(start, lastDate)) {
      if (date.isAfter(due)) addOccurrence(date, projected: true);
    }
  }

  for (final snooze in snoozes) {
    final task = byId[snooze.taskId];
    if (task == null) continue;
    add(
      PlannedNotification(
        id: _stableId(
          'snooze:${snooze.taskId}@${snooze.occurrence.toIso()}'
          '@${snooze.until.millisecondsSinceEpoch}',
        ),
        taskId: task.id,
        title: task.title,
        occurrence: snooze.occurrence,
        fireAt: snooze.until.toLocal(),
        projected: snooze.occurrence != task.dueDate,
        snoozed: true,
      ),
    );
  }

  plan.sort((a, b) {
    final byTime = a.fireAt.compareTo(b.fireAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  });
  return limit == null || plan.length <= limit ? plan : plan.sublist(0, limit);
}

/// FNV-1a over UTF-16 code units, masked to 31 bits (stable across runs,
/// unlike [String.hashCode]).
int _stableId(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}
