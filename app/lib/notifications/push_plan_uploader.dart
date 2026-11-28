import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/app_settings.dart';
import '../l10n/app_localizations.dart';
import '../logging/app_log.dart';
import '../state/providers.dart';
import '../sync/sync_api.dart';
import '../sync/sync_controller.dart';
import 'device_time_zone.dart';
import 'reminder_scheduler.dart';

/// How long after the last change the plans are rebuilt.
final pushPlanDebounceProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 5),
);

/// How long after a failure nothing is tried (except by [PushPlanUploader.uploadNow]).
final pushPlanBackoffProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 5),
);

/// Uploads each web device's push plan (the reminders the server sends as
/// Web Push) from every device that shares its time zone. Read it once (the
/// app root does) to start it. The web notification settings call
/// [PushPlanUploader.uploadNow] after subscribing or unsubscribing.
final pushPlanUploaderProvider = Provider<PushPlanUploader>((ref) {
  final uploader = PushPlanUploader(ref);
  ref.onDispose(uploader.dispose);
  uploader.start();
  return uploader;
});

/// When the last reminder of this device's push plan fires (the web app's
/// notification settings show it), from the same rules as the uploads.
/// Null: no reminders planned, or the tasks aren't loaded yet.
final ownPushPlanEndProvider = Provider<DateTime?>((ref) {
  final entries = ref.watch(taskEntriesProvider).value;
  final reminders = ref.watch(timeRemindersProvider).value;
  if (entries == null || reminders == null) return null;
  final taskTargets = ref.watch(taskTargetsProvider).value ?? const {};
  final settings = ref.watch(appSettingsProvider);
  final deviceId = ref.watch(deviceIdProvider);
  final now = ref.read(clockProvider)();
  final items = buildPushPlan(
    tasks: [for (final e in entries) e.task],
    reminders: reminders,
    notifiesDevice: (t) => notifiesHere(t, taskTargets, deviceId),
    now: now,
    allDayMinutes: settings.allDayReminderMinutes,
    // Only the times matter here.
    body: (_) => '',
  );
  // A plan keeps the last hour's items; only one still ahead counts.
  final end = items.isEmpty ? null : items.last.fireAt;
  return end == null || !end.isAfter(now) ? null : end.toLocal();
});

class PushPlanUploader {
  PushPlanUploader(this._ref);

  final Ref _ref;

  Timer? _pending;
  Timer? _retry;
  bool _failed = false;
  Timer? _periodic;
  Future<void>? _running;
  bool _again = false;
  bool _freshAgain = false;
  bool _disposed = false;

  /// The server has no web push (404 `push_not_configured`): stop until the
  /// next app start.
  bool _notConfigured = false;
  DateTime? _retryAfter;
  Map<String, String>? _hashes;

  void start() {
    _ref
      ..listen(taskEntriesProvider, (_, _) => _schedule())
      ..listen(timeRemindersProvider, (_, _) => _schedule())
      ..listen(taskTargetsProvider, (_, _) => _schedule())
      ..listen(devicesProvider, (_, _) => _schedule())
      ..listen(appSettingsProvider, (_, _) => _schedule())
      // After each successful sync.
      ..listen(
        syncControllerProvider.select((s) => s.lastSyncedAt),
        (_, _) => _schedule(),
      );
    _periodic = Timer.periodic(const Duration(hours: 24), (_) => _schedule());
    _schedule();
  }

  void _schedule() {
    if (_disposed || _notConfigured) return;
    _pending?.cancel();
    _pending = Timer(
      _ref.read(pushPlanDebounceProvider),
      () => unawaited(_run(fresh: false, force: false)),
    );
  }

  /// Rebuilds and uploads now, asking the server for the current device
  /// list first (a device may just have subscribed). Never throws.
  Future<void> uploadNow() async {
    _pending?.cancel();
    await _run(fresh: true, force: true);
  }

  Future<void> _run({required bool fresh, required bool force}) {
    if (_disposed || _notConfigured) return Future.value();
    if (!force) {
      final until = _retryAfter;
      if (until != null && _ref.read(clockProvider)().isBefore(until)) {
        return Future.value();
      }
    }
    if (_running case final running?) {
      _again = true;
      _freshAgain = _freshAgain || fresh;
      return running;
    }
    return _running = _loop(fresh).whenComplete(() => _running = null);
  }

  Future<void> _loop(bool fresh) async {
    var useFresh = fresh;
    do {
      _again = false;
      _freshAgain = false;
      _failed = false;
      try {
        await _upload(fresh: useFresh);
      } on Object catch (e, stack) {
        // Never a sync error: log (no titles) and wait.
        appLog.error('push', e, stack);
        _backOff();
      }
      if (!_failed) {
        // A clean run: no backoff, no pending retry.
        _retryAfter = null;
        _retry?.cancel();
        _retry = null;
      }
      useFresh = _freshAgain;
    } while (_again && !_disposed && !_notConfigured);
  }

  void _backOff() {
    _failed = true;
    final backoff = _ref.read(pushPlanBackoffProvider);
    _retryAfter = _ref.read(clockProvider)().add(backoff);
    // A change inside the window is dropped; this run picks it up after.
    _retry?.cancel();
    if (!_disposed) _retry = Timer(backoff, _schedule);
  }

  Future<void> _upload({required bool fresh}) async {
    final context = _ref.read(syncControllerProvider.notifier).pushContext;
    if (context == null) return;
    final entries = _ref.read(taskEntriesProvider).value;
    final reminders = _ref.read(timeRemindersProvider).value;
    if (entries == null || reminders == null) return;

    var devices = context.devices;
    if (fresh) {
      try {
        devices = await context.api.devices();
      } on SyncApiException catch (e) {
        appLog.warning('push', 'Could not list devices: ${e.message}');
        _backOff();
        return;
      }
    }
    // Not listed yet (just started, or offline): nothing to compare, so
    // keep the stored hashes as they are.
    if (devices == null) return;
    final myId = _ref.read(deviceIdProvider);
    final myZone = await _ref.read(deviceTimeZoneProvider.future);
    final settings = _ref.read(appSettingsProvider);
    // A web device plans for itself with its own all-day time; others use
    // the time it reported, and skip it until it has.
    int? allDayOf(Device d) =>
        d.id == myId ? settings.allDayReminderMinutes : d.allDayMinutes;
    final targets = [
      for (final d in devices)
        if (!d.deleted &&
            d.type == DeviceType.web &&
            d.pushEnabled &&
            allDayOf(d) != null &&
            (d.id == myId || (myZone != null && d.timeZone == myZone)))
          d,
    ];

    final settingsRepo = _ref.read(settingsRepositoryProvider);
    final hashes = _hashes ??= await settingsRepo.getPushPlanHashes();
    // Forget devices that are gone or no longer notify.
    final before = hashes.length;
    hashes.removeWhere((id, _) => !targets.any((d) => d.id == id));
    var changed = hashes.length != before;

    final l10n = lookupAppLocalizations(resolvedLocale(settings));
    final taskTargets = _ref.read(taskTargetsProvider).value ?? const {};
    final now = _ref.read(clockProvider)();
    final tasks = [for (final e in entries) e.task];

    for (final device in targets) {
      final items = buildPushPlan(
        tasks: tasks,
        reminders: reminders,
        notifiesDevice: (t) => notifiesHere(t, taskTargets, device.id),
        now: now,
        allDayMinutes: allDayOf(device)!,
        body: (p) => notificationBody(l10n, p, entries, settings.timeFormat),
      );
      final hash = pushPlanHash(items);
      if (hashes[device.id] == hash) continue;
      try {
        await context.api.putPushPlan(device.id, items);
      } on SyncHttpException catch (e) {
        if (e.status == 404 && e.code == 'push_not_configured') {
          _notConfigured = true;
          appLog.info('push', 'The server has no web push; uploads stopped');
          break;
        }
        appLog.warning('push', 'Plan upload refused: ${e.status} ${e.code}');
        _backOff();
        continue;
      } on SyncNetworkException catch (e) {
        appLog.warning('push', 'Plan upload failed: ${e.message}');
        _backOff();
        break;
      }
      hashes[device.id] = hash;
      changed = true;
      appLog.info('push', 'Uploaded a plan of ${items.length} reminders');
    }
    if (changed) await settingsRepo.setPushPlanHashes(hashes);
  }

  void dispose() {
    _disposed = true;
    _pending?.cancel();
    _retry?.cancel();
    _periodic?.cancel();
  }
}
