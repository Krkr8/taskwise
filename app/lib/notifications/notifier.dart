import 'dart:convert';

import 'package:taskwise_shared/taskwise_shared.dart';

/// What the user did with a notification.
sealed class NotificationAction {
  const NotificationAction(
    this.taskId,
    this.occurrence, {
    this.fromLocation = false,
  });

  final String taskId;
  final LocalDate occurrence;

  /// From a location reminder: it isn't tied to an occurrence, so Done
  /// completes the task as it is now.
  final bool fromLocation;
}

/// Tapped the notification: open the task.
final class OpenTaskAction extends NotificationAction {
  const OpenTaskAction(super.taskId, super.occurrence, {super.fromLocation});
}

/// Pressed Done.
final class DoneAction extends NotificationAction {
  const DoneAction(super.taskId, super.occurrence, {super.fromLocation});
}

/// Pressed a Snooze button.
final class SnoozeAction extends NotificationAction {
  const SnoozeAction(
    super.taskId,
    super.occurrence,
    this.minutes, {
    super.fromLocation,
  });

  final int minutes;
}

/// Localised notification texts, built by the scheduler from the current
/// language and settings.
final class NotificationTexts {
  const NotificationTexts({
    required this.done,
    required this.snoozeLabel,
    required this.snoozeMinutes,
    required this.body,
    required this.open,
  });

  /// "Done" button.
  final String done;

  /// "Snooze 15 min" button text for a length.
  final String Function(int minutes) snoozeLabel;

  /// Snooze lengths to offer (1 to 3).
  final List<int> snoozeMinutes;

  /// Body text, e.g. "Due today, 6:00 PM".
  final String Function(PlannedNotification) body;

  /// Name of the default (click) action on Linux.
  final String open;
}

/// Action ids carried by notification buttons.
abstract final class ActionIds {
  static const done = 'done';
  static const snoozePrefix = 'snooze:';

  static String snooze(int minutes) => '$snoozePrefix$minutes';

  /// Turns a platform response (action id + payload) into an action.
  static NotificationAction? parse(String? actionId, String? payload) {
    final data = NotificationPayload.decode(payload);
    if (data == null) return null;
    final location = data.location;
    if (actionId == done && !data.projected) {
      return DoneAction(data.taskId, data.occurrence, fromLocation: location);
    }
    if (actionId != null && actionId.startsWith(snoozePrefix)) {
      final minutes = int.tryParse(actionId.substring(snoozePrefix.length));
      if (minutes != null && minutes > 0) {
        return SnoozeAction(
          data.taskId,
          data.occurrence,
          minutes,
          fromLocation: location,
        );
      }
    }
    return OpenTaskAction(data.taskId, data.occurrence, fromLocation: location);
  }
}

/// What a notification carries so its actions know which task and
/// occurrence they're about. [fireAt] lets iOS tell when a pending request
/// with the same id needs rescheduling.
final class NotificationPayload {
  const NotificationPayload({
    required this.taskId,
    required this.occurrence,
    required this.projected,
    required this.fireAt,
    required this.title,
    this.location = false,
  });

  /// The payload of a location reminder's notification. It has no
  /// occurrence of its own: [occurrence] is the task's due date (or
  /// [noDate]) when the reminder was handed to the phone.
  factory NotificationPayload.location({
    required String taskId,
    required LocalDate? dueDate,
    required String title,
  }) => NotificationPayload(
    taskId: taskId,
    occurrence: dueDate ?? noDate,
    projected: false,
    fireAt: DateTime.fromMillisecondsSinceEpoch(0),
    title: title,
    location: true,
  );

  /// Stands in for the occurrence of a task without a due date.
  static final noDate = LocalDate(1970, 1, 1);

  factory NotificationPayload.of(PlannedNotification p) => NotificationPayload(
    taskId: p.taskId,
    occurrence: p.occurrence,
    projected: p.projected,
    fireAt: p.fireAt,
    title: p.title,
  );

  final String taskId;
  final LocalDate occurrence;
  final bool projected;
  final DateTime fireAt;
  final String title;

  /// From a location reminder.
  final bool location;

  String encode() => jsonEncode({
    't': taskId,
    'o': occurrence.toIso(),
    'p': projected,
    'f': fireAt.millisecondsSinceEpoch,
    'n': title,
    if (location) 'l': true,
  });

  static NotificationPayload? decode(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      final json = (jsonDecode(text) as Map).cast<String, Object?>();
      return NotificationPayload(
        taskId: json['t']! as String,
        occurrence: LocalDate.parse(json['o']! as String),
        projected: json['p'] as bool? ?? false,
        fireAt: DateTime.fromMillisecondsSinceEpoch(json['f']! as int),
        title: json['n'] as String? ?? '',
        location: json['l'] as bool? ?? false,
      );
    } on Object {
      return null;
    }
  }
}

/// The platform side of reminders: shows or schedules notifications for a
/// plan and reports what the user does with them.
abstract class ReminderNotifier {
  /// How many pending notifications the platform allows (null = no limit).
  int? get limit => null;

  /// Whether the platform schedules ahead (iOS) or the app must be running
  /// and show notifications itself (desktop).
  bool get schedulesAhead => false;

  /// Sets up the plugin. [onAction] receives taps and button presses,
  /// including the one that launched the app.
  Future<void> init({
    required NotificationTexts texts,
    required void Function(NotificationAction action) onAction,
  });

  /// Makes the shown/scheduled notifications match [plan].
  ///
  /// Desktop shows entries whose time has come (including missed ones in
  /// the plan) and calls [onShown] with the time it checked up to.
  Future<void> apply(
    List<PlannedNotification> plan,
    NotificationTexts texts, {
    void Function(DateTime checkedUpTo)? onShown,
  });

  /// Asks the OS for permission (iOS). Returns false if denied.
  Future<bool> requestPermission() async => true;

  /// Shows a notification right away, to check notifications work here.
  Future<void> showTest({required String title, required String body}) async {}

  /// Id of the test notification (outside the range plans use).
  static const testId = 2147480000;

  void dispose() {}
}

/// Does nothing. Used in tests and on platforms without notifications.
class NoopNotifier extends ReminderNotifier {
  /// The last plan applied, for tests.
  List<PlannedNotification> lastPlan = const [];

  @override
  Future<void> init({
    required NotificationTexts texts,
    required void Function(NotificationAction action) onAction,
  }) async {}

  @override
  Future<void> apply(
    List<PlannedNotification> plan,
    NotificationTexts texts, {
    void Function(DateTime checkedUpTo)? onShown,
  }) async => lastPlan = plan;
}
