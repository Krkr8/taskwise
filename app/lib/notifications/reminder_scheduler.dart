import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/app_settings.dart';
import '../l10n/app_localizations.dart';
import '../state/providers.dart';
import '../ui/tasks/labels.dart';
import 'notifier.dart';

/// The platform notifier. Overridden in `main()`; tests keep the no-op.
final reminderNotifierProvider = Provider<ReminderNotifier>(
  (ref) => NoopNotifier(),
);

/// Keeps the device's notifications in step with the data: watches tasks,
/// reminders, settings and snoozes, rebuilds the plan (debounced) and hands
/// it to the [ReminderNotifier]. Also handles what the user does with a
/// notification. Read it once (the app root does) to start it.
final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final scheduler = ReminderScheduler(ref);
  ref.onDispose(scheduler.dispose);
  scheduler.start();
  return scheduler;
});

class ReminderScheduler {
  ReminderScheduler(this._ref);

  final Ref _ref;
  static const _debounce = Duration(seconds: 1);

  /// Desktop shows reminders missed while the app wasn't running, but only
  /// from this far back.
  static const _maxCatchUp = Duration(hours: 24);

  late final ReminderNotifier _notifier = _ref.read(reminderNotifierProvider);
  Future<void>? _ready;
  Timer? _pending;
  Timer? _periodic;
  AppLifecycleListener? _lifecycle;
  DateTime? _checkedAt;
  DateTime? _savedCheckedAt;
  bool _disposed = false;

  void start() {
    _ref
      ..listen(taskEntriesProvider, (_, _) => schedule())
      ..listen(timeRemindersProvider, (_, _) => schedule())
      ..listen(appSettingsProvider, (_, _) => schedule())
      ..listen(snoozesProvider, (_, _) => schedule())
      ..listen(taskTargetsProvider, (_, _) => schedule());
    _ready = _init();
    // The horizon slides and "today" changes: re-plan now and then, and
    // when the app comes back to the foreground.
    _periodic = Timer.periodic(const Duration(minutes: 30), (_) => schedule());
    _lifecycle = AppLifecycleListener(onResume: schedule);
  }

  Future<void> _init() async {
    final settings = _ref.read(settingsRepositoryProvider);
    _checkedAt = await settings.getRemindersCheckedAt();
    _savedCheckedAt = _checkedAt;
    await _notifier.init(
      texts: _texts(_ref.read(appSettingsProvider)),
      onAction: handleAction,
    );
    schedule();
  }

  /// Re-plans soon (debounced).
  void schedule() {
    if (_disposed) return;
    _pending?.cancel();
    _pending = Timer(_debounce, () => unawaited(_replan()));
  }

  /// Plans and applies now, without the debounce (background sync).
  Future<void> replanNow() async {
    _pending?.cancel();
    await _ready;
    await _replan();
  }

  /// Asks for notification permission (iOS) and remembers the answer.
  Future<bool> requestPermission() async {
    await _ready;
    final granted = await _notifier.requestPermission();
    _ref.read(notificationPermissionProvider.notifier).set(granted);
    return granted;
  }

  /// Shows a test notification now. Returns false if notifications are
  /// turned off for Taskwise (iOS permission).
  Future<bool> sendTest() async {
    await _ready;
    if (!await requestPermission()) return false;
    final l10n = lookupAppLocalizations(
      resolvedLocale(_ref.read(appSettingsProvider)),
    );
    await _notifier.showTest(title: l10n.appTitle, body: l10n.notifTestBody);
    return true;
  }

  Future<void> _replan() async {
    await _ready;
    if (_disposed) return;
    final entries = _ref.read(taskEntriesProvider).value;
    final reminders = _ref.read(timeRemindersProvider).value;
    if (entries == null || reminders == null) return;
    final settings = _ref.read(appSettingsProvider);
    final now = _ref.read(clockProvider)();

    DateTime? after;
    if (!_notifier.schedulesAhead) {
      final floor = now.subtract(_maxCatchUp);
      final checked = _checkedAt;
      after = checked == null
          ? now
          : (checked.isBefore(floor) ? floor : checked.toLocal());
    }
    // Only tasks that notify on this device (SPEC.md section 3.1).
    final targets = _ref.read(taskTargetsProvider).value ?? const {};
    final deviceId = _ref.read(deviceIdProvider);
    final plan = planNotifications(
      tasks: [
        for (final e in entries)
          if (notifiesHere(e.task, targets, deviceId)) e.task,
      ],
      reminders: reminders,
      now: now,
      after: after,
      allDayMinutes: settings.allDayReminderMinutes,
      snoozes: _ref.read(snoozesProvider).value ?? const [],
      limit: _notifier.limit,
    );
    await _notifier.apply(plan, _texts(settings), onShown: _markChecked);
  }

  void _markChecked(DateTime at) {
    _checkedAt = at;
    // Persist at most once a minute.
    final saved = _savedCheckedAt;
    if (saved == null || at.difference(saved) > const Duration(minutes: 1)) {
      _savedCheckedAt = at;
      unawaited(
        _ref.read(settingsRepositoryProvider).setRemindersCheckedAt(at),
      );
    }
  }

  /// Runs what the user picked on a notification (public for tests).
  Future<void> handleAction(NotificationAction action) async {
    if (_disposed) return;
    final tasks = _ref.read(taskRepositoryProvider);
    switch (action) {
      case DoneAction(:final taskId, :final occurrence, :final fromLocation):
        final task = await tasks.getTask(taskId);
        // Only the real, current occurrence can be ticked off. A location
        // reminder is about the task as it is now.
        if (task != null &&
            !task.done &&
            (fromLocation || task.dueDate == occurrence)) {
          await tasks.setDone(taskId, done: true);
        } else {
          _ref.read(openTaskRequestProvider.notifier).request(taskId);
        }
      case SnoozeAction(
        :final taskId,
        :final occurrence,
        :final minutes,
        :final fromLocation,
      ):
        final now = _ref.read(clockProvider)();
        var snoozed = occurrence;
        if (fromLocation) {
          // Comes back as a time notification for the task's current
          // occurrence (or today, for a task without a date).
          final task = await tasks.getTask(taskId);
          snoozed = task?.dueDate ?? LocalDate.fromDateTime(now);
        }
        await _ref
            .read(settingsRepositoryProvider)
            .addSnooze(
              Snooze(
                taskId: taskId,
                occurrence: snoozed,
                until: now.add(Duration(minutes: minutes)),
              ),
            );
      case OpenTaskAction(:final taskId):
        _ref.read(openTaskRequestProvider.notifier).request(taskId);
    }
  }

  /// Notification texts in the app's language.
  NotificationTexts _texts(AppSettings settings) {
    final l10n = lookupAppLocalizations(resolvedLocale(settings));
    String duration(int minutes) => minutes % (24 * 60) == 0
        ? l10n.durationDays(minutes ~/ (24 * 60))
        : minutes % 60 == 0
        ? l10n.durationHours(minutes ~/ 60)
        : l10n.durationMinutes(minutes);
    return NotificationTexts(
      done: l10n.notifDone,
      open: l10n.notifOpen,
      snoozeMinutes: settings.snoozeMinutes,
      snoozeLabel: (m) => l10n.notifSnooze(duration(m)),
      body: (p) {
        final entries = _ref.read(taskEntriesProvider).value ?? const [];
        final task = entries
            .map((e) => e.task)
            .where((t) => t.id == p.taskId)
            .firstOrNull;
        // Relative to the day it fires: "Due today, 6:00 PM".
        final day = l10n.relativeDate(
          p.occurrence,
          LocalDate.fromDateTime(p.fireAt),
        );
        if (p.snoozed && task != null && task.dueDate == null) {
          return l10n.notifSnoozedNoDate;
        }
        final minutes = task?.dueTimeMinutes;
        final when = minutes == null
            ? day
            : '$day, ${l10n.clockTime(minutes, settings.timeFormat)}';
        return p.snoozed ? l10n.notifSnoozed(when) : l10n.notifDue(when);
      },
    );
  }

  void dispose() {
    _disposed = true;
    _pending?.cancel();
    _periodic?.cancel();
    _lifecycle?.dispose();
    _notifier.dispose();
  }
}
