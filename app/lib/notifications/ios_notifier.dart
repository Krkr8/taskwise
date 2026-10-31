import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:taskwise_shared/taskwise_shared.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notifier.dart';

/// iPhone: iOS schedules the notifications, so they fire with the app
/// closed. Only local notifications (free signing has no push), at most 64
/// pending (an iOS limit), refreshed whenever the plan changes.
///
/// Done and Snooze open the app to run (the "foreground" option), which
/// avoids a background isolate with its own database connection.
class IosNotifier extends ReminderNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _categoryTask = 'task';
  static const _categoryProjected = 'projected';

  @override
  int? get limit => 64;

  @override
  bool get schedulesAhead => true;

  @override
  Future<void> init({
    required NotificationTexts texts,
    required void Function(NotificationAction action) onAction,
  }) async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } on Object {
      // Unknown zone name: tz.local stays UTC and times are converted from
      // the device's offset below, which is still right outside DST changes.
    }

    final snoozeActions = [
      for (final m in texts.snoozeMinutes)
        DarwinNotificationAction.plain(
          ActionIds.snooze(m),
          texts.snoozeLabel(m),
          options: {DarwinNotificationActionOption.foreground},
        ),
    ];
    await _plugin.initialize(
      settings: InitializationSettings(
        iOS: DarwinInitializationSettings(
          // Asked for when the first reminder is added, not at launch.
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              _categoryTask,
              actions: [
                DarwinNotificationAction.plain(
                  ActionIds.done,
                  texts.done,
                  options: {DarwinNotificationActionOption.foreground},
                ),
                ...snoozeActions,
              ],
            ),
            DarwinNotificationCategory(
              _categoryProjected,
              actions: snoozeActions,
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final action = ActionIds.parse(response.actionId, response.payload);
        if (action != null) onAction(action);
      },
    );

    // A notification that launched the app from scratch.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
      final action = ActionIds.parse(response.actionId, response.payload);
      if (action != null) onAction(action);
    }
  }

  @override
  Future<bool> requestPermission() async =>
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, sound: true, badge: true) ??
      false;

  @override
  Future<void> apply(
    List<PlannedNotification> plan,
    NotificationTexts texts, {
    void Function(DateTime checkedUpTo)? onShown,
  }) async {
    final wanted = {for (final p in plan) p.id: p};
    final pending = {
      for (final r in await _plugin.pendingNotificationRequests()) r.id: r,
    };

    for (final MapEntry(key: id, value: request) in pending.entries) {
      final want = wanted[id];
      // Same id but a new time or title: reschedule it.
      if (want == null ||
          request.payload != NotificationPayload.of(want).encode() ||
          request.body != texts.body(want)) {
        await _plugin.cancel(id: id);
        pending.remove(id);
      }
    }
    for (final p in plan) {
      if (pending.containsKey(p.id)) continue;
      await _plugin.zonedSchedule(
        id: p.id,
        title: p.title,
        body: texts.body(p),
        payload: NotificationPayload.of(p).encode(),
        scheduledDate: tz.TZDateTime.from(p.fireAt, tz.local),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: NotificationDetails(
          iOS: DarwinNotificationDetails(
            categoryIdentifier: p.projected
                ? _categoryProjected
                : _categoryTask,
          ),
        ),
      );
    }
  }
}
