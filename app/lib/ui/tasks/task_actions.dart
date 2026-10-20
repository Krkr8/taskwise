import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import 'labels.dart';

/// Deletes a task (tombstone) and offers Undo in a snackbar.
Future<void> deleteTaskWithUndo(
  BuildContext context,
  WidgetRef ref,
  String taskId,
) async {
  final repo = ref.read(taskRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  if (ref.read(selectedTaskIdProvider) == taskId) {
    ref.read(selectedTaskIdProvider.notifier).select(null);
  }
  await repo.deleteTask(taskId);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l10n.taskDeleted),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => repo.restoreTask(taskId),
        ),
      ),
    );
}
