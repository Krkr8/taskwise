import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:taskwise_shared/taskwise_shared.dart' hide Priority;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../logging/app_log.dart';
import 'notifier.dart';

/// iPhone and Android: the system schedules the notifications, so they fire
/// with the app closed. Only local notifications (no push server), at most
/// 64 pending (an iOS limit, kept on Android too), refreshed whenever the
/// plan changes.
///
/// Done and Snooze open the app to run (iOS "foreground" actions, Android
/// `showsUserInterface`), which avoids a background isolate with its own
/// database connection.
///
/// Android needs `USE_EXACT_ALARM` (AndroidManifest.xml) for reminders on
/// the minute; without it they come within a few minutes.
class MobileNotifier extends ReminderNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _categoryTask = 'task';
  static const _categoryProjected = 'projected';

  /// The Android notification channel. Location reminders
  /// (LocationReminderManager.kt) post on the same one.
  static const androidChannelId = 'reminders';

  /// The small monochrome icon (android/app/src/main/res/drawable*).
  static const _androidIcon = 'ic_notification';

  NotificationTexts? _texts;

  @override
  int? get limit => 64;

  @override
  bool get schedulesAhead => true;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> init({
    required NotificationTexts texts,
    required void Function(NotificationAction action) onAction,
  }) async {
    _texts = texts;
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
        android: const AndroidInitializationSettings(_androidIcon),
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

    await _android?.createNotificationChannel(
      AndroidNotificationChannel(
        androidChannelId,
        texts.channelName,
        importance: Importance.high,
      ),
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
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      return await _android?.requestNotificationsPermission() ?? false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true, badge: true) ??
        false;
  }

  /// Android notification look and buttons. Projected repeats (not created
  /// yet) can't be ticked off, so they only offer Snooze.
  AndroidNotificationDetails _androidDetails({bool projected = false}) {
    final texts = _texts;
    return AndroidNotificationDetails(
      androidChannelId,
      texts?.channelName ?? 'Reminders',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      actions: texts == null
          ? null
          : [
              if (!projected)
                AndroidNotificationAction(
                  ActionIds.done,
                  texts.done,
                  showsUserInterface: true,
                  cancelNotification: true,
                ),
              for (final m in texts.snoozeMinutes)
                AndroidNotificationAction(
                  ActionIds.snooze(m),
                  texts.snoozeLabel(m),
                  showsUserInterface: true,
                  cancelNotification: true,
                ),
            ],
    );
  }

  @override
  Future<void> showTest({required String title, required String body}) =>
      _plugin.show(
        id: ReminderNotifier.testId,
        title: title,
        body: body,
        // Shown even with Taskwise open.
        notificationDetails: NotificationDetails(
          android: _androidDetails(),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentSound: true,
          ),
        ),
      );

  /// Android: exact alarms when allowed (`USE_EXACT_ALARM`), otherwise
  /// Android may deliver a few minutes late.
  Future<AndroidScheduleMode> _scheduleMode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      if (await _android?.canScheduleExactNotifications() ?? false) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } on Object catch (e) {
      appLog.warning('notifications', 'Exact alarm check failed: $e');
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  @override
  Future<void> apply(
    List<PlannedNotification> plan,
    NotificationTexts texts, {
    void Function(DateTime checkedUpTo)? onShown,
  }) async {
    _texts = texts;
    final wanted = {for (final p in plan) p.id: p};
    final pending = {
      for (final r in await _plugin.pendingNotificationRequests()) r.id: r,
    };

    // Loop over a copy: entries are removed from [pending] on the way (a
    // live view would throw, and nothing new would be scheduled).
    for (final MapEntry(key: id, value: request) in pending.entries.toList()) {
      final want = wanted[id];
      // Same id but a new time or title: reschedule it.
      if (want == null ||
          request.payload != NotificationPayload.of(want).encode() ||
          request.body != texts.body(want)) {
        await _plugin.cancel(id: id);
        pending.remove(id);
      }
    }
    final mode = await _scheduleMode();
    for (final p in plan) {
      if (pending.containsKey(p.id)) continue;
      await _plugin.zonedSchedule(
        id: p.id,
        title: p.title,
        body: texts.body(p),
        payload: NotificationPayload.of(p).encode(),
        scheduledDate: tz.TZDateTime.from(p.fireAt, tz.local),
        androidScheduleMode: mode,
        notificationDetails: NotificationDetails(
          android: _androidDetails(projected: p.projected),
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
