import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/app_settings.dart';
import '../l10n/app_localizations.dart';
import '../notifications/notifier.dart';
import '../notifications/reminder_scheduler.dart' show snoozeLabel;
import '../state/providers.dart';
import 'location_platform.dart';

/// The platform's location side. Overridden in `main()` on iOS; desktop and
/// tests keep [NoLocationPlatform].
final locationPlatformProvider = Provider<LocationPlatform>(
  (ref) => NoLocationPlatform(),
);

/// The current location permission, refreshed when the app resumes.
final locationPermissionProvider =
    NotifierProvider<LocationPermissionNotifier, LocationPermission>(
      LocationPermissionNotifier.new,
    );

class LocationPermissionNotifier extends Notifier<LocationPermission> {
  AppLifecycleListener? _lifecycle;

  @override
  LocationPermission build() {
    final platform = ref.watch(locationPlatformProvider);
    if (!platform.supported) return LocationPermission.unsupported;
    unawaited(refresh());
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(refresh()));
    ref.onDispose(() => _lifecycle?.dispose());
    return LocationPermission.notDetermined;
  }

  Future<void> refresh() async {
    final value = await ref.read(locationPlatformProvider).permission();
    if (ref.mounted) state = value;
  }

  /// Asks iOS for "Always" (via "While Using" the first time).
  Future<LocationPermission> request() async {
    final value = await ref.read(locationPlatformProvider).requestPermission();
    if (ref.mounted) state = value;
    return value;
  }
}

/// Keeps the phone's watched places in step with the data: watches tasks,
/// location reminders, places, "Notify on" targets and the language, and
/// hands the planned entries to the [LocationPlatform] (debounced). Read it
/// once (the app root does) to start it. Does nothing on desktop.
final locationReminderSyncProvider = Provider<LocationReminderSync>((ref) {
  final sync = LocationReminderSync(ref);
  ref.onDispose(sync.dispose);
  sync.start();
  return sync;
});

class LocationReminderSync {
  LocationReminderSync(this._ref);

  final Ref _ref;
  static const _debounce = Duration(seconds: 1);

  Timer? _pending;
  List<NativeLocationEntry>? _sent;
  bool _disposed = false;

  late final LocationPlatform _platform = _ref.read(locationPlatformProvider);

  void start() {
    if (!_platform.supported) return;
    _ref
      ..listen(taskEntriesProvider, (_, _) => schedule())
      ..listen(locationRemindersProvider, (_, _) => schedule())
      ..listen(placesProvider, (_, _) => schedule())
      ..listen(taskTargetsProvider, (_, _) => schedule())
      ..listen(appSettingsProvider, (_, _) => schedule());
    schedule();
  }

  /// Re-plans soon (debounced).
  void schedule() {
    if (_disposed || !_platform.supported) return;
    _pending?.cancel();
    _pending = Timer(_debounce, () => unawaited(apply()));
  }

  /// Plans now and hands the entries to the phone if they changed. Returns
  /// false while the data is still loading.
  Future<bool> apply() async {
    if (_disposed || !_platform.supported) return false;
    final entries = _ref.read(taskEntriesProvider).value;
    final reminders = _ref.read(locationRemindersProvider).value;
    final places = _ref.read(placesProvider).value;
    if (entries == null || reminders == null || places == null) return false;
    final targets = _ref.read(taskTargetsProvider).value ?? const {};
    final deviceId = _ref.read(deviceIdProvider);
    final tasks = {
      for (final e in entries)
        if (notifiesHere(e.task, targets, deviceId)) e.task.id: e.task,
    };
    final plan = planLocationReminders(
      tasks: tasks.values,
      reminders: reminders,
      places: places,
    );
    final l10n = lookupAppLocalizations(
      resolvedLocale(_ref.read(appSettingsProvider)),
    );
    final settings = _ref.read(appSettingsProvider);
    final actions = [
      (id: ActionIds.done, title: l10n.notifDone),
      for (final m in settings.snoozeMinutes)
        (id: ActionIds.snooze(m), title: snoozeLabel(l10n, m)),
    ];
    final native = [
      for (final e in plan) _native(e, tasks[e.taskId]!.dueDate, l10n, actions),
    ];
    if (_sameAsSent(native)) return true;
    await _platform.setEntries(native);
    _sent = native;
    return true;
  }

  static NativeLocationEntry _native(
    LocationReminderEntry e,
    LocalDate? dueDate,
    AppLocalizations l10n,
    List<({String id, String title})> actions,
  ) {
    final arrive = e.trigger == LocationTrigger.arrive;
    final place = e.placeName;
    return NativeLocationEntry(
      id: e.reminderId,
      latitude: e.latitude,
      longitude: e.longitude,
      radiusMeters: e.radiusMeters,
      arrive: arrive,
      title: e.taskTitle,
      body: switch ((arrive, place)) {
        (true, final String name) => l10n.locNotifArrived(name),
        (true, null) => l10n.locNotifArrivedNoName,
        (false, final String name) => l10n.locNotifLeft(name),
        (false, null) => l10n.locNotifLeftNoName,
      },
      payload: NotificationPayload.location(
        taskId: e.taskId,
        dueDate: dueDate,
        title: e.taskTitle,
      ).encode(),
      notificationId: _stableId('loc:${e.reminderId}'),
      actions: actions,
    );
  }

  bool _sameAsSent(List<NativeLocationEntry> next) {
    final sent = _sent;
    if (sent == null || sent.length != next.length) return false;
    for (var i = 0; i < sent.length; i++) {
      if (sent[i] != next[i]) return false;
    }
    return true;
  }

  /// FNV-1a, 31 bits (stable across runs).
  static int _stableId(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  void dispose() {
    _disposed = true;
    _pending?.cancel();
  }
}
