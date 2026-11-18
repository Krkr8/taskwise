import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../data/app_settings.dart';
import '../../../state/providers.dart';
import 'labels.dart';

/// How long an Undo snackbar stays before it fades away. Flutter keeps
/// snackbars with an action until dismissed unless `persist` is false.
const undoSnackBarDuration = Duration(seconds: 5);

/// Deletes a task (tombstone) and offers Undo in a snackbar.
Future<void> deleteTaskWithUndo(
  BuildContext context,
  WidgetRef ref,
  String taskId,
) async {
  final repo = ref.read(taskRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  for (final selected in [
    selectedTaskIdProvider,
    calendarSelectedTaskIdProvider,
  ]) {
    if (ref.read(selected) == taskId) ref.read(selected.notifier).select(null);
  }
  await repo.deleteTask(taskId);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        persist: false,
        duration: undoSnackBarDuration,
        content: Text(l10n.taskDeleted),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => repo.restoreTask(taskId),
        ),
      ),
    );
}

/// Marks a task done or not done. Completing a repeating task shows when
/// the next one is due, with Undo (which also removes that next copy).
Future<void> setTaskDone(
  BuildContext context,
  WidgetRef ref,
  Task task, {
  required bool done,
}) async {
  final repo = ref.read(taskRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final today = ref.read(todayProvider);
  final completion = await repo.setDone(task.id, done: done);
  if (completion.rule == null) return;
  final next = completion.nextTaskId == null
      ? null
      : await repo.getTask(completion.nextTaskId!);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        persist: false,
        duration: undoSnackBarDuration,
        content: Text(
          next?.dueDate == null
              ? l10n.doneSeriesEnded
              : l10n.doneNextOn(l10n.relativeDate(next!.dueDate!, today)),
        ),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => repo.undoCompletion(task.id, completion),
        ),
      ),
    );
}

/// Skips a task: it's finished as skipped (it leaves the list and shows in
/// Completed as skipped). A repeating task gets its next copy, like
/// completing. The snackbar offers Undo.
Future<void> skipTask(BuildContext context, WidgetRef ref, Task task) async {
  final repo = ref.read(taskRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final today = ref.read(todayProvider);
  for (final selected in [
    selectedTaskIdProvider,
    calendarSelectedTaskIdProvider,
  ]) {
    if (ref.read(selected) == task.id) ref.read(selected.notifier).select(null);
  }
  final completion = await repo.setDone(task.id, done: true, skipped: true);
  final next = completion.nextTaskId == null
      ? null
      : await repo.getTask(completion.nextTaskId!);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        persist: false,
        duration: undoSnackBarDuration,
        content: Text(switch ((completion.rule, next?.dueDate)) {
          (null, _) => l10n.taskSkipped(task.title),
          (_, null) => l10n.skippedSeriesEnded,
          (_, final LocalDate date) => l10n.skippedNextOn(
            l10n.relativeDate(date, today),
          ),
        }),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => repo.undoCompletion(task.id, completion),
        ),
      ),
    );
}

/// What a tap on a task row does, following the "Tapping a task with
/// subtasks" setting. Tasks without subtasks always open their details.
void handleTaskTap(
  WidgetRef ref, {
  required String taskId,
  required bool hasSubtasks,
  required VoidCallback openDetails,
}) {
  final action = ref.read(appSettingsProvider).taskTapAction;
  if (!hasSubtasks || action == TaskTapAction.detailsOnly) {
    openDetails();
    return;
  }
  ref.read(expandedTasksProvider.notifier).toggle(taskId);
  if (action == TaskTapAction.detailsAndSubtasks) openDetails();
}

/// Whether a row shows its own "open details" arrow: only when a tap folds
/// and unfolds the subtasks instead.
bool showsDetailsArrow(WidgetRef ref, {required bool hasSubtasks}) =>
    hasSubtasks &&
    ref.watch(appSettingsProvider).taskTapAction == TaskTapAction.subtasksOnly;
