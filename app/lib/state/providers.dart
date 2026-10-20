import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/app_settings.dart';
import '../data/db/app_database.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/repository_base.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/task_repository.dart';

// ------------------------------------------------------------ infrastructure

/// The open database. Overridden in `main()` (and in tests).
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

/// This install's device id. Overridden in `main()` (and in tests).
final deviceIdProvider = Provider<String>(
  (ref) => throw UnimplementedError('deviceIdProvider must be overridden'),
);

/// Settings loaded before the first frame, so the app opens with the right
/// theme and language instead of flashing the defaults.
final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

final clockProvider = Provider<Clock>((ref) => DateTime.now);

final taskRepositoryProvider = Provider(
  (ref) => TaskRepository(
    ref.watch(databaseProvider),
    deviceId: ref.watch(deviceIdProvider),
    clock: ref.watch(clockProvider),
  ),
);

final categoryRepositoryProvider = Provider(
  (ref) => CategoryRepository(
    ref.watch(databaseProvider),
    deviceId: ref.watch(deviceIdProvider),
    clock: ref.watch(clockProvider),
  ),
);

final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(
    ref.watch(databaseProvider),
    deviceId: ref.watch(deviceIdProvider),
    clock: ref.watch(clockProvider),
  ),
);

// ------------------------------------------------------------------ settings

final _settingsStreamProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watchSettings(),
);

/// Current settings (never loading: falls back to [initialSettingsProvider]).
final appSettingsProvider = Provider<AppSettings>(
  (ref) =>
      ref.watch(_settingsStreamProvider).value ??
      ref.watch(initialSettingsProvider),
);

/// Today's date; refreshes itself at local midnight.
final todayProvider = Provider<LocalDate>((ref) {
  final now = ref.watch(clockProvider)();
  final nextMidnight = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(nextMidnight.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return LocalDate.fromDateTime(now);
});

// --------------------------------------------------------------------- data

final taskEntriesProvider = StreamProvider<List<TaskEntry>>(
  (ref) => ref.watch(taskRepositoryProvider).watchEntries(),
);

final taskProvider = StreamProvider.family<Task?, String>(
  (ref, id) => ref.watch(taskRepositoryProvider).watchTask(id),
);

final subtasksProvider = StreamProvider.family<List<Subtask>, String>(
  (ref, taskId) => ref.watch(taskRepositoryProvider).watchSubtasks(taskId),
);

final taskTagIdsProvider = StreamProvider.family<Set<String>, String>(
  (ref, taskId) => ref.watch(taskRepositoryProvider).watchTaskTagIds(taskId),
);

final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchCategories(),
);

final tagsProvider = StreamProvider<List<Tag>>(
  (ref) => ref.watch(taskRepositoryProvider).watchTags(),
);

/// Categories by id, for quick lookup while rendering rows.
final categoriesByIdProvider = Provider<Map<String, Category>>(
  (ref) => {
    for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
      c.id: c,
  },
);

// ---------------------------------------------------------------- list view

class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => const TaskFilter();

  void setText(String text) => state = state.copyWith(text: text);

  void toggleCategory(String id) =>
      state = state.copyWith(categoryIds: _toggle(state.categoryIds, id));

  void togglePriority(Priority p) =>
      state = state.copyWith(priorities: _toggle(state.priorities, p));

  void toggleTag(String id) =>
      state = state.copyWith(tagIds: _toggle(state.tagIds, id));

  /// Clears the facets but keeps the search text.
  void clearFacets() => state = TaskFilter(text: state.text);

  static Set<T> _toggle<T>(Set<T> set, T value) =>
      set.contains(value) ? ({...set}..remove(value)) : {...set, value};
}

final taskFilterProvider = NotifierProvider<TaskFilterNotifier, TaskFilter>(
  TaskFilterNotifier.new,
);

class TaskSortNotifier extends Notifier<TaskSort> {
  @override
  TaskSort build() => TaskSort.dueDate;

  void set(TaskSort sort) => state = sort;
}

final taskSortProvider = NotifierProvider<TaskSortNotifier, TaskSort>(
  TaskSortNotifier.new,
);

/// Which list sections are collapsed. Completed starts collapsed.
class CollapsedGroupsNotifier extends Notifier<Set<TaskGroup>> {
  @override
  Set<TaskGroup> build() => {TaskGroup.completed};

  void toggle(TaskGroup group) => state = state.contains(group)
      ? ({...state}..remove(group))
      : {...state, group};
}

final collapsedGroupsProvider =
    NotifierProvider<CollapsedGroupsNotifier, Set<TaskGroup>>(
      CollapsedGroupsNotifier.new,
    );

/// The list sections after filtering, grouping and sorting.
final taskSectionsProvider = Provider<AsyncValue<List<TaskSection>>>((ref) {
  final filter = ref.watch(taskFilterProvider);
  final sort = ref.watch(taskSortProvider);
  final today = ref.watch(todayProvider);
  final weekStart = ref.watch(appSettingsProvider).weekStart;
  return ref
      .watch(taskEntriesProvider)
      .whenData(
        (entries) => buildTaskSections(
          entries,
          today: today,
          weekStart: weekStart,
          filter: filter,
          sort: sort,
        ),
      );
});

/// The task open in the side panel (wide layouts).
class SelectedTaskNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedTaskIdProvider = NotifierProvider<SelectedTaskNotifier, String?>(
  SelectedTaskNotifier.new,
);
