import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../state/providers.dart';

/// One row of the task list: a section's header, or one of its tasks.
final class TaskListRow {
  const TaskListRow.header(this.section) : index = -1;

  const TaskListRow.task(this.section, this.index);

  final TaskSection section;

  /// The task's place in its section; -1 for the header.
  final int index;

  bool get isHeader => index < 0;

  TaskEntry get entry => section.entries[index];

  /// The first and last task of the section (for cards drawn in slices).
  bool get first => index == 0;
  bool get last => index == section.entries.length - 1;

  /// The row widget's key, so rows keep their state when the list changes.
  Key get key =>
      isHeader ? ValueKey<TaskGroup>(section.group) : ValueKey(entry.task.id);
}

/// The rows of the task list, flattened from its sections.
///
/// Lists build their rows lazily from this (`ListView.builder`), so a list
/// of thousands of tasks only builds the rows on screen.
final class TaskListRows {
  TaskListRows(this.rows);

  final List<TaskListRow> rows;

  int get length => rows.length;
  bool get isEmpty => rows.isEmpty;
  TaskListRow operator [](int i) => rows[i];

  late final Map<Key, int> _indexByKey = {
    for (final (i, row) in rows.indexed) row.key: i,
  };

  /// Where the row with [key] is now, for `findChildIndexCallback`, so a row
  /// that moved keeps its state (a check box's animation, for example).
  int? indexOf(Key key) => _indexByKey[key];
}

/// The task list's rows: worked out once whenever the tasks, the filter,
/// the sort or the collapsed sections change, not on every build.
final taskListRowsProvider = Provider<AsyncValue<TaskListRows>>((ref) {
  final collapsed = ref.watch(collapsedGroupsProvider);
  return ref
      .watch(taskSectionsProvider)
      .whenData(
        (sections) => TaskListRows([
          for (final section in sections) ...[
            TaskListRow.header(section),
            if (!collapsed.contains(section.group))
              for (var i = 0; i < section.entries.length; i++)
                TaskListRow.task(section, i),
          ],
        ]),
      );
});
