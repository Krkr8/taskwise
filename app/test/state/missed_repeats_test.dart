import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise/state/missed_repeats.dart';
import 'package:taskwise/sync/sync_controller.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/test_db.dart';

final _now = DateTime(2026, 10, 20, 9);

/// A daily task due two days ago, a container running the watcher with
/// [sync] as the sync state, and a way to read the tasks.
Future<
  ({
    ProviderContainer container,
    Task task,
    Future<List<Task>> Function() tasks,
    Future<void> Function() close,
  })
>
_setUp(SyncState sync) async {
  final db = openTestDatabase();
  final repo = TaskRepository(db, deviceId: 'test', clock: () => _now);
  final task = await repo.createTask(
    title: 'Water plants',
    dueDate: LocalDate(2026, 10, 18),
  );
  await repo.saveTask(
    task.copyWith(recurrenceRule: () => 'DTSTART=20261018;FREQ=DAILY'),
  );
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      deviceIdProvider.overrideWithValue('test'),
      clockProvider.overrideWithValue(() => _now),
      todayProvider.overrideWithValue(LocalDate(2026, 10, 20)),
      missedRepeatsSyncStateProvider.overrideWithValue(sync),
    ],
  );
  // Providers nobody listens to are paused (Riverpod 3).
  container
    ..listen(taskEntriesProvider, (_, _) {})
    ..listen(missedRepeatsProvider, (_, _) {});
  return (
    container: container,
    task: task,
    tasks: () async => [
      for (final e in await repo.watchEntries().first) e.task,
    ],
    close: () async {
      container.dispose();
      await db.close();
    },
  );
}

/// Waits up to 3 s for [count] tasks.
Future<List<Task>> _waitFor(
  Future<List<Task>> Function() tasks,
  int count,
) async {
  var list = await tasks();
  for (var i = 0; i < 30 && list.length < count; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    list = await tasks();
  }
  return list;
}

void main() {
  testWidgets("an unfinished daily repeat gets today's copy on its own", (
    tester,
  ) async {
    await tester.runAsync(() async {
      final t = await _setUp(const SyncState(loaded: true));
      final tasks = await _waitFor(t.tasks, 2);
      expect(tasks.length, 2);
      final copy = tasks.firstWhere((x) => x.id != t.task.id);
      expect(copy.dueDate, LocalDate(2026, 10, 20));
      expect(copy.recurrenceRule, 'DTSTART=20261018;FREQ=DAILY');
      expect(tasks.firstWhere((x) => x.id == t.task.id).recurrenceRule, isNull);
      await t.close();
    });
  });

  testWidgets('when signed in, it waits for a sync after start', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final t = await _setUp(
        SyncState(
          loaded: true,
          serverUrl: 'https://example.invalid',
          // Synced before the app started: not good enough.
          lastSyncedAt: _now.toUtc().subtract(const Duration(hours: 1)),
        ),
      );
      expect((await _waitFor(t.tasks, 2)).length, 1);

      t.container.updateOverrides([
        databaseProvider.overrideWithValue(t.container.read(databaseProvider)),
        deviceIdProvider.overrideWithValue('test'),
        clockProvider.overrideWithValue(() => _now),
        todayProvider.overrideWithValue(LocalDate(2026, 10, 20)),
        missedRepeatsSyncStateProvider.overrideWithValue(
          SyncState(
            loaded: true,
            serverUrl: 'https://example.invalid',
            lastSyncedAt: _now.toUtc(),
          ),
        ),
      ]);
      expect((await _waitFor(t.tasks, 2)).length, 2);
      await t.close();
    });
  });

  testWidgets('when signed in but offline, it goes ahead', (tester) async {
    await tester.runAsync(() async {
      final t = await _setUp(
        const SyncState(
          loaded: true,
          serverUrl: 'https://example.invalid',
          phase: SyncPhase.offline,
        ),
      );
      expect((await _waitFor(t.tasks, 2)).length, 2);
      await t.close();
    });
  });
}
