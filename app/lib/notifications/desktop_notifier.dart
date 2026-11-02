import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import 'notifier.dart';

/// Windows and Linux: the app shows reminders itself while it runs (in the
/// tray when the window is closed). Linux notifications can't be scheduled,
/// and Windows can't cancel scheduled ones without MSIX packaging, so a
/// timer to the next reminder is simpler and works the same on both.
class DesktopNotifier extends ReminderNotifier {
  DesktopNotifier({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final _plugin = FlutterLocalNotificationsPlugin();
  Timer? _timer;
  List<PlannedNotification> _plan = const [];
  late NotificationTexts _texts;
  void Function(DateTime)? _onShown;

  /// Ids already shown, so a re-plan doesn't show them twice.
  final _shown = <int>{};

  @override
  Future<void> init({
    required NotificationTexts texts,
    required void Function(NotificationAction action) onAction,
  }) async {
    _texts = texts;
    await _plugin.initialize(
      settings: InitializationSettings(
        linux: LinuxInitializationSettings(defaultActionName: texts.open),
        windows: const WindowsInitializationSettings(
          appName: 'Taskwise',
          appUserModelId: 'Taskwise.Taskwise.Desktop',
          // Fixed GUID identifying the app's toast activator.
          guid: 'b6c1f3e2-6c3a-4f0e-9a57-3d7e2f1c8a40',
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final action = ActionIds.parse(response.actionId, response.payload);
        if (action != null) onAction(action);
      },
    );
  }

  @override
  Future<void> apply(
    List<PlannedNotification> plan,
    NotificationTexts texts, {
    void Function(DateTime checkedUpTo)? onShown,
  }) async {
    _plan = plan;
    _texts = texts;
    _shown.retainAll({for (final p in plan) p.id});
    _onShown = onShown;
    await _tick();
  }

  /// Shows everything due now, then sleeps until the next one.
  Future<void> _tick() async {
    _timer?.cancel();
    final now = _clock();
    for (final p in _plan) {
      if (p.fireAt.isAfter(now)) break;
      if (_shown.add(p.id)) await _show(p);
    }
    _onShown?.call(now);
    final next = _plan.where((p) => p.fireAt.isAfter(now)).firstOrNull;
    if (next == null) return;
    // Wake at least every hour, so a sleeping laptop catches up soon after
    // it wakes (timers don't count suspended time reliably).
    final wait = next.fireAt.difference(now);
    _timer = Timer(
      wait > const Duration(hours: 1) ? const Duration(hours: 1) : wait,
      _tick,
    );
  }

  @override
  Future<void> showTest({required String title, required String body}) =>
      _plugin.show(
        id: ReminderNotifier.testId,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          linux: LinuxNotificationDetails(),
          windows: WindowsNotificationDetails(),
        ),
      );

  Future<void> _show(PlannedNotification p) {
    final payload = NotificationPayload.of(p).encode();
    final snoozes = _texts.snoozeMinutes;
    return _plugin.show(
      id: p.id,
      title: p.title,
      body: _texts.body(p),
      payload: payload,
      notificationDetails: NotificationDetails(
        linux: LinuxNotificationDetails(
          defaultActionName: _texts.open,
          actions: [
            if (!p.projected)
              LinuxNotificationAction(key: ActionIds.done, label: _texts.done),
            for (final m in snoozes)
              LinuxNotificationAction(
                key: ActionIds.snooze(m),
                label: _texts.snoozeLabel(m),
              ),
          ],
        ),
        windows: Platform.isWindows
            ? WindowsNotificationDetails(
                actions: [
                  if (!p.projected)
                    WindowsAction(
                      content: _texts.done,
                      arguments: ActionIds.done,
                    ),
                  for (final m in snoozes)
                    WindowsAction(
                      content: _texts.snoozeLabel(m),
                      arguments: ActionIds.snooze(m),
                    ),
                ],
              )
            : null,
      ),
    );
  }

  @override
  void dispose() => _timer?.cancel();
}
