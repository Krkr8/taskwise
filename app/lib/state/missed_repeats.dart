import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../logging/app_log.dart';
import '../sync/sync_controller.dart';
import 'providers.dart';

/// The sync state the roll-over waits on (overridable in tests).
final missedRepeatsSyncStateProvider = Provider<SyncState>(
  (ref) => ref.watch(syncControllerProvider),
);

/// Gives repeating tasks that weren't done in time their next copy
/// ([TaskRepository.rollOverMissedRepeats]) whenever the tasks or the date
/// change: at start, at midnight, after a sync brings tasks in, and when the
/// app comes back to the foreground on a new day. Read it once (the app root
/// does) to start it.
///
/// When signed in to a server, it waits for a sync that finished after the
/// app started, resumed or the date changed, so it works on the other
/// devices' latest changes (a task ticked on the phone last night isn't
/// copied again on the laptop), and never runs halfway through a sync. When
/// the server can't be reached it goes ahead: its writes are stamped so that
/// real changes from other devices still win.
final missedRepeatsProvider = Provider<MissedRepeats>((ref) {
  final watcher = MissedRepeats(ref);
  ref.onDispose(watcher.dispose);
  watcher.start();
  return watcher;
});

class MissedRepeats {
  MissedRepeats(this._ref);

  final Ref _ref;
  static const _debounce = Duration(seconds: 1);

  Timer? _pending;
  AppLifecycleListener? _lifecycle;

  /// When the app started, last resumed or the date last changed: a sync
  /// must have finished after this before rolling over (when signed in).
  DateTime _since = DateTime.utc(0);
  Future<void>? _running;
  bool _disposed = false;

  void start() {
    _since = _now();
    _ref
      ..listen(taskEntriesProvider, (_, _) => check(), fireImmediately: true)
      ..listen(todayProvider, (_, _) {
        _since = _now();
        check();
      })
      ..listen(missedRepeatsSyncStateProvider, (_, _) => check());
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  DateTime _now() => _ref.read(clockProvider)().toUtc();

  /// A suspended phone may miss the midnight timer: refresh the date.
  void _onResume() {
    if (_disposed) return;
    _since = _now();
    final now = LocalDate.fromDateTime(_ref.read(clockProvider)());
    if (now != _ref.read(todayProvider)) _ref.invalidate(todayProvider);
  }

  /// Whether sync allows a roll-over now (see the class comment).
  bool get _syncAllows {
    final sync = _ref.read(missedRepeatsSyncStateProvider);
    if (!sync.loaded) return false;
    if (!sync.connected) return true;
    return switch (sync.phase) {
      SyncPhase.syncing => false,
      SyncPhase.idle =>
        sync.lastSyncedAt != null && !sync.lastSyncedAt!.isBefore(_since),
      SyncPhase.offline || SyncPhase.signedOut || SyncPhase.error => true,
    };
  }

  /// Rolls over soon (debounced) if any task needs it.
  void check() {
    if (_disposed || !_syncAllows) return;
    final today = _ref.read(todayProvider);
    final entries = _ref.read(taskEntriesProvider).value;
    if (entries == null ||
        !entries.any((e) => missedRepeatDate(e.task, today) != null)) {
      return;
    }
    _pending?.cancel();
    _pending = Timer(_debounce, () => unawaited(runNow()));
  }

  /// Rolls over now; one run at a time.
  Future<void> runNow() async {
    if (_disposed) return;
    await _running;
    final run = _run();
    _running = run;
    await run;
  }

  Future<void> _run() async {
    if (!_syncAllows) return;
    try {
      final made = await _ref
          .read(taskRepositoryProvider)
          .rollOverMissedRepeats(_ref.read(todayProvider));
      if (made > 0) {
        appLog.info('repeats', 'Made $made copies of missed repeating tasks');
      }
    } on Object catch (error, stack) {
      appLog.error('repeats', error, stack, 'roll-over failed');
    }
  }

  void dispose() {
    _disposed = true;
    _pending?.cancel();
    _lifecycle?.dispose();
  }
}
