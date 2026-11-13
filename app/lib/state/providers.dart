import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/app_settings.dart';
import '../data/db/app_database.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/device_repository.dart';
import '../data/repositories/place_repository.dart';
import '../data/repositories/reminder_repository.dart';
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

final reminderRepositoryProvider = Provider(
  (ref) => ReminderRepository(
    ref.watch(databaseProvider),
    deviceId: ref.watch(deviceIdProvider),
    clock: ref.watch(clockProvider),
  ),
);

final placeRepositoryProvider = Provider(
  (ref) => PlaceRepository(
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

final deviceRepositoryProvider = Provider(
  (ref) => DeviceRepository(
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

/// Active devices, this one first.
final devicesProvider = StreamProvider<List<Device>>(
  (ref) => ref.watch(deviceRepositoryProvider).watchDevices(),
);

/// Explicit notify-on-device targets per task id (only for tasks whose
/// `notifyAllDevices` flag is false).
final taskTargetsProvider = StreamProvider<Map<String, Set<String>>>(
  (ref) => ref.watch(taskRepositoryProvider).watchAllTaskTargets(),
);

/// Whether a task notifies on this device.
bool notifiesHere(
  Task task,
  Map<String, Set<String>> targets,
  String deviceId,
) => task.notifyAllDevices || (targets[task.id]?.contains(deviceId) ?? false);

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

// ----------------------------------------------------------------- calendar

/// An inclusive date range, used as a calendar query key.
typedef DateRange = ({LocalDate from, LocalDate to});

/// Calendar items (real tasks plus projected repeats) for a date range.
final calendarItemsProvider =
    Provider.family<AsyncValue<Map<LocalDate, List<CalendarItem>>>, DateRange>(
      (ref, range) => ref
          .watch(taskEntriesProvider)
          .whenData(
            (entries) => calendarItems(
              entries.map((e) => e.task),
              from: range.from,
              to: range.to,
            ),
          ),
    );

/// The task open in the calendar's side panel (wide layouts). Separate from
/// [selectedTaskIdProvider] so the two tabs don't move each other.
final calendarSelectedTaskIdProvider =
    NotifierProvider<SelectedTaskNotifier, String?>(SelectedTaskNotifier.new);

// ---------------------------------------------------------------- reminders

/// All live time reminders.
final timeRemindersProvider = StreamProvider<List<Reminder>>(
  (ref) => ref.watch(reminderRepositoryProvider).watchTimeReminders(),
);

/// A task's time reminders, in display order.
final taskRemindersProvider = StreamProvider.family<List<Reminder>, String>(
  (ref, taskId) => ref.watch(reminderRepositoryProvider).watchForTask(taskId),
);

/// Ids of tasks that have at least one time reminder (for the 🔔 marker).
final taskIdsWithRemindersProvider = Provider<Set<String>>(
  (ref) => {
    for (final r
        in ref.watch(timeRemindersProvider).value ?? const <Reminder>[])
      r.taskId,
  },
);

/// All live location reminders.
final locationRemindersProvider = StreamProvider<List<Reminder>>(
  (ref) => ref.watch(reminderRepositoryProvider).watchLocationReminders(),
);

/// A task's location reminders.
final taskLocationRemindersProvider =
    StreamProvider.family<List<Reminder>, String>(
      (ref, taskId) =>
          ref.watch(reminderRepositoryProvider).watchLocationForTask(taskId),
    );

/// Ids of tasks that have at least one location reminder (for the 📍 marker).
final taskIdsWithLocationProvider = Provider<Set<String>>(
  (ref) => {
    for (final r
        in ref.watch(locationRemindersProvider).value ?? const <Reminder>[])
      r.taskId,
  },
);

/// Saved places, alphabetically.
final placesProvider = StreamProvider<List<Place>>(
  (ref) => ref.watch(placeRepositoryProvider).watchPlaces(),
);

/// Active snoozes on this device.
final snoozesProvider = StreamProvider<List<Snooze>>(
  (ref) => ref.watch(settingsRepositoryProvider).watchSnoozes(),
);

/// The shell's selected destination: 0 Tasks, 1 Calendar, 2 Settings.
class ShellTabNotifier extends Notifier<int> {
  static const tasks = 0;
  static const settings = 2;

  @override
  int build() => tasks;

  void select(int index) => state = index;
}

final shellTabProvider = NotifierProvider<ShellTabNotifier, int>(
  ShellTabNotifier.new,
);

/// Counts requests to focus the quick-add field (Android's "New task"
/// shortcut). Each design's quick-add field listens and takes the focus.
class QuickAddRequestNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

final quickAddRequestProvider = NotifierProvider<QuickAddRequestNotifier, int>(
  QuickAddRequestNotifier.new,
);

/// A task the app was asked to open (from a notification). The shell shows
/// it and clears the request.
class OpenTaskRequestNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void request(String taskId) => state = taskId;

  void clear() => state = null;
}

final openTaskRequestProvider =
    NotifierProvider<OpenTaskRequestNotifier, String?>(
      OpenTaskRequestNotifier.new,
    );

/// False once the user has refused notifications (iOS); null = not asked.
class NotificationPermissionNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;

  void set(bool granted) => state = granted;
}

final notificationPermissionProvider =
    NotifierProvider<NotificationPermissionNotifier, bool?>(
      NotificationPermissionNotifier.new,
    );
