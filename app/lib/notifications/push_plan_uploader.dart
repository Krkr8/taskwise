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
import 'time_zones.dart';

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

/// Whether the last plan upload for this (web) device failed; the web
/// notification settings then say the reminders couldn't be planned.
final ownPushPlanFailedProvider = NotifierProvider<_Flag, bool>(_Flag.new);

class _Flag extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state != value) state = value;
  }
}

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
  bool _forceAgain = false;
  bool _disposed = false;

  /// A debounced run came while a sync was running: run when it ends.
  bool _afterSync = false;

  /// The server has no web push (404 `push_not_configured`, or `not_found`
  /// from a server before 1.4.0): stop until the next app start or sign-in.
  bool _notConfigured = false;
  DateTime? _retryAfter;

  /// Web devices already logged as skipped for their time zone.
  final _zoneSkipped = <String>{};

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
      )
      // After a sync that held back a run (also a failed one).
      ..listen(
        syncControllerProvider.select((s) => s.phase == SyncPhase.syncing),
        (_, syncing) {
          if (syncing || !_afterSync) return;
          _afterSync = false;
          _schedule();
        },
      )
      // Another account or server: start over.
      ..listen(syncControllerProvider.select((s) => s.serverUrl), (_, _) {
        _notConfigured = false;
        _zoneSkipped.clear();
        _ref.read(ownPushPlanFailedProvider.notifier).set(false);
      });
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

  /// Rebuilds and uploads every plan now (also unchanged ones), asking the
  /// server for the current device list first (a device may just have
  /// subscribed). Never throws.
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
      // The device list and the tasks are half updated during a sync.
      if (_ref.read(syncControllerProvider).phase == SyncPhase.syncing) {
        _afterSync = true;
        return Future.value();
      }
    }
    if (_running case final running?) {
      _again = true;
      _freshAgain = _freshAgain || fresh;
      _forceAgain = _forceAgain || force;
      return running;
    }
    return _running = _loop(fresh, force).whenComplete(() => _running = null);
  }

  Future<void> _loop(bool fresh, bool force) async {
    var useFresh = fresh;
    var useForce = force;
    do {
      _again = false;
      _freshAgain = false;
      _forceAgain = false;
      _failed = false;
      try {
        await _upload(fresh: useFresh, force: useForce);
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
      useForce = _forceAgain;
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

  void _stop(String why) {
    _notConfigured = true;
    appLog.info('push', '$why; uploads stopped');
  }

  Future<void> _upload({required bool fresh, required bool force}) async {
    final sync = _ref.read(syncControllerProvider.notifier);
    final context = sync.pushContext;
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
    final now = _ref.read(clockProvider)();
    // A web device plans for itself with its own all-day time; others use
    // the time it reported, and skip it until it has.
    int? allDayOf(Device d) =>
        d.id == myId ? settings.allDayReminderMinutes : d.allDayMinutes;
    bool sameZone(Device d) {
      final zone = d.timeZone;
      final same =
          myZone != null &&
          zone != null &&
          sameTimeZones(myZone, zone, from: now);
      if (!same && _zoneSkipped.add(d.id)) {
        appLog.info('push', 'A web device in another time zone is skipped');
      }
      return same;
    }

    final targets = [
      for (final d in devices)
        if (!d.deleted &&
            d.type == DeviceType.web &&
            d.pushEnabled &&
            allDayOf(d) != null &&
            (d.id == myId || sameZone(d)))
          d,
    ];
    if (!targets.any((d) => d.id == myId)) _ownFailed(false);

    final settingsRepo = _ref.read(settingsRepositoryProvider);
    final hashes = await settingsRepo.getPushPlanHashes();
    // Forget devices that are gone or no longer notify.
    final before = hashes.length;
    hashes.removeWhere((id, _) => !targets.any((d) => d.id == id));
    var changed = hashes.length != before;

    final l10n = lookupAppLocalizations(resolvedLocale(settings));
    final taskTargets = _ref.read(taskTargetsProvider).value ?? const {};
    final tasks = [for (final e in entries) e.task];

    for (final device in targets) {
      final own = device.id == myId;
      final items = buildPushPlan(
        tasks: tasks,
        reminders: reminders,
        notifiesDevice: (t) => notifiesHere(t, taskTargets, device.id),
        now: now,
        allDayMinutes: allDayOf(device)!,
        body: (p) => notificationBody(l10n, p, entries, settings.timeFormat),
      );
      final hash = pushPlanHash(items);
      if (!force && hashes[device.id] == hash) continue;
      try {
        await context.api.putPushPlan(device.id, items);
      } on SyncHttpException catch (e) {
        if (e.status == 404 && e.code == 'push_not_configured') {
          _stop('The server has no web push');
          break;
        }
        if (e.status == 404 && await _serverLacksPush(context.api)) {
          _stop('The server is older than web reminders');
          break;
        }
        appLog.warning('push', 'Plan upload refused: ${e.status} ${e.code}');
        if (own) _ownFailed(true);
        _backOff();
        continue;
      } on SyncNetworkException catch (e) {
        appLog.warning('push', 'Plan upload failed: ${e.message}');
        if (own) _ownFailed(true);
        _backOff();
        break;
      }
      if (own) _ownFailed(false);
      hashes[device.id] = hash;
      changed = true;
      appLog.info('push', 'Uploaded a plan of ${items.length} reminders');
    }
    // Signed out or in again meanwhile: these hashes are for the old one.
    if (!identical(sync.pushContext?.api, context.api)) return;
    if (changed) await settingsRepo.setPushPlanHashes(hashes);
  }

  /// After a 404 from `/push/plan`: a server from before 1.4.0 answers 404
  /// (`not_found`) to `/push/key` too.
  Future<bool> _serverLacksPush(SyncApi api) async {
    try {
      await api.pushKey();
      return false;
    } on SyncHttpException catch (e) {
      return e.status == 404;
    } on SyncNetworkException {
      return false;
    }
  }

  void _ownFailed(bool failed) =>
      _ref.read(ownPushPlanFailedProvider.notifier).set(failed);

  void dispose() {
    _disposed = true;
    _pending?.cancel();
    _retry?.cancel();
    _periodic?.cancel();
  }
}
