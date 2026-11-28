import '../models/reminder.dart';
import '../models/task.dart';
import 'reminder_schedule.dart';

/// One Web Push the server should send at [fireAt].
final class PushPlanItem {
  const PushPlanItem({
    required this.key,
    required this.fireAt,
    required this.taskId,
    required this.title,
    required this.body,
  });

  /// On the wire [fireAt] is integer UTC milliseconds.
  factory PushPlanItem.fromJson(Map<String, Object?> json) => PushPlanItem(
    key: json['key']! as String,
    fireAt: DateTime.fromMillisecondsSinceEpoch(
      (json['fireAt']! as num).toInt(),
      isUtc: true,
    ),
    taskId: json['taskId']! as String,
    title: json['title']! as String,
    body: json['body']! as String,
  );

  /// The planner's stable id for this reminder and occurrence.
  final String key;

  /// UTC.
  final DateTime fireAt;
  final String taskId;
  final String title;
  final String body;

  Map<String, Object?> toJson() => {
    'key': key,
    'fireAt': fireAt.toUtc().millisecondsSinceEpoch,
    'taskId': taskId,
    'title': title,
    'body': body,
  };

  @override
  bool operator ==(Object other) =>
      other is PushPlanItem &&
      other.key == key &&
      other.fireAt.isAtSameMomentAs(fireAt) &&
      other.taskId == taskId &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode =>
      Object.hash(key, fireAt.millisecondsSinceEpoch, taskId, title, body);
}

/// How long a due item stays in a plan: the server's stale limit (it still
/// sends an item this late), so an upload just after a reminder's time
/// doesn't delete it before it's sent.
const pushPlanKeepDue = Duration(minutes: 60);

/// Items for one web device: its targeted tasks' reminders from
/// [pushPlanKeepDue] ago to [horizon] ahead, sorted by fireAt, at most
/// [limit], one per key. Uses [planNotifications] for the rules.
List<PushPlanItem> buildPushPlan({
  required Iterable<Task> tasks,
  required Iterable<Reminder> reminders,
  required bool Function(Task) notifiesDevice,
  required DateTime now,
  required String Function(PlannedNotification) body,
  Duration horizon = const Duration(days: 60),
  int limit = 500,
  int allDayMinutes = 9 * 60,
}) {
  final targeted = tasks.where(notifiesDevice).toList();
  final plan = planNotifications(
    tasks: targeted,
    reminders: reminders,
    now: now,
    after: now.subtract(pushPlanKeepDue),
    horizon: horizon,
    allDayMinutes: allDayMinutes,
    limit: limit,
  );
  return uniquePushPlanKeys([
    for (final p in plan)
      PushPlanItem(
        key: '${p.id}',
        fireAt: p.fireAt.toUtc(),
        taskId: p.taskId,
        title: p.title,
        body: body(p),
      ),
  ]);
}

/// [items] with one item per key, the first of each (the earliest, for a
/// plan sorted by fireAt): two ids can collide, and the server refuses a
/// plan with a duplicate key.
List<PushPlanItem> uniquePushPlanKeys(List<PushPlanItem> items) {
  final seen = <String>{};
  return [
    for (final i in items)
      if (seen.add(i.key)) i,
  ];
}

/// A stable hash of a plan (FNV-1a, 32 bits, as hex) that doesn't depend on
/// the order of [items]; it tells whether a plan changed since the last upload.
String pushPlanHash(List<PushPlanItem> items) {
  final sorted = [...items]
    ..sort((a, b) {
      final byKey = a.key.compareTo(b.key);
      return byKey != 0 ? byKey : a.fireAt.compareTo(b.fireAt);
    });
  var hash = 0x811c9dc5;
  for (final i in sorted) {
    final text =
        '${i.key}|${i.fireAt.millisecondsSinceEpoch}|${i.taskId}|${i.title}|${i.body}\n';
    for (final unit in text.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
