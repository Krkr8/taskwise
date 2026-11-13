import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../logging/app_log.dart';
import '../state/providers.dart';
import 'assistant_platform.dart';

/// The phone's assistant side. Overridden in `main()` on phones; desktop and
/// tests keep [NoAssistantPlatform].
final assistantPlatformProvider = Provider<AssistantPlatform>(
  (ref) => NoAssistantPlatform(),
);

/// Keeps Siri and Taskwise in step on the iPhone: moves the tasks Siri added
/// into the database (at start, on resume, when Siri adds one while Taskwise
/// is open, and in the background sync), and hands Siri a fresh list of
/// what's due whenever tasks change. Read it once (the app root does) to
/// start it. Does nothing where there is no inbox (desktop, Android).
final assistantSyncProvider = Provider<AssistantSync>((ref) {
  final sync = AssistantSync(ref);
  ref.onDispose(sync.dispose);
  sync.start();
  return sync;
});

class AssistantSync {
  AssistantSync(this._ref);

  final Ref _ref;
  static const _debounce = Duration(seconds: 1);

  late final AssistantPlatform _platform = _ref.read(assistantPlatformProvider);
  Timer? _pending;
  String? _sent;
  Future<int>? _importing;
  Future<int>? _queued;
  AppLifecycleListener? _lifecycle;
  StreamSubscription<AssistantAction?>? _events;
  bool _disposed = false;

  void start() {
    if (!_platform.hasInbox) return;
    _ref
      ..listen(taskEntriesProvider, (_, _) => scheduleSnapshot())
      ..listen(todayProvider, (_, _) => scheduleSnapshot());
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(importInbox()));
    _events = _platform.events.listen((event) {
      if (event == null) unawaited(importInbox());
    });
    unawaited(importInbox());
    scheduleSnapshot();
  }

  /// Moves Siri's tasks into the database and returns how many were added.
  /// A call while an import runs queues one more import after it (Siri may
  /// have added a task after the running one read the inbox).
  Future<int> importInbox() {
    if (_disposed || !_platform.hasInbox) return Future.value(0);
    final running = _importing;
    if (running == null) return _startImport();
    return _queued ??= running.then((_) {
      _queued = null;
      return _startImport();
    });
  }

  Future<int> _startImport() =>
      _importing = _import().whenComplete(() => _importing = null);

  Future<int> _import() async {
    try {
      final entries = await _platform.readInbox();
      if (entries.isEmpty) return 0;
      final tasks = _ref.read(taskRepositoryProvider);
      final reminders = _ref.read(reminderRepositoryProvider);
      final before = _ref.read(appSettingsProvider).defaultReminder;
      var added = 0;
      for (final e in entries) {
        // Already imported (or added and then deleted): don't add it again.
        if (await tasks.getTask(e.id) != null) continue;
        await tasks.createTask(
          id: e.id,
          title: e.title,
          notes: e.notes,
          dueDate: e.dueDate,
          dueTimeMinutes: e.dueTimeMinutes,
        );
        if (e.dueTimeMinutes != null) {
          await reminders.addDefaultReminder(e.id, before.minutesBefore);
        }
        added++;
      }
      await _platform.ackInbox([for (final e in entries) e.id]);
      if (added > 0) appLog.info('assistant', 'Added $added task(s) from Siri');
      return added;
    } on Object catch (e, stack) {
      appLog.error('assistant', e, stack, 'Importing Siri tasks failed');
      return 0;
    }
  }

  /// Updates Siri's list soon (debounced).
  void scheduleSnapshot() {
    if (_disposed || !_platform.hasInbox) return;
    _pending?.cancel();
    _pending = Timer(_debounce, () => unawaited(applySnapshot()));
  }

  /// Hands Siri the current list if it changed. Returns false while the
  /// tasks are still loading.
  Future<bool> applySnapshot() async {
    if (_disposed || !_platform.hasInbox) return false;
    final entries = _ref.read(taskEntriesProvider).value;
    if (entries == null) return false;
    final snapshot = buildAssistantSnapshot([
      for (final e in entries) e.task,
    ], _ref.read(todayProvider));
    final json = jsonEncode(snapshot);
    if (json == _sent) return true;
    try {
      await _platform.setSnapshot(snapshot);
      _sent = json;
    } on Object catch (e, stack) {
      appLog.error('assistant', e, stack, 'Updating Siri\'s list failed');
    }
    return true;
  }

  void dispose() {
    _disposed = true;
    _pending?.cancel();
    _lifecycle?.dispose();
    unawaited(_events?.cancel());
  }
}
