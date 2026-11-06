// The pieces that keep big task lists fast (docs/performance.md).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/ui/shared/common/lazy_indexed_stack.dart';
import 'package:taskwise/ui/shared/tasks/task_rows.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

TaskEntry _entry(String id, {LocalDate? due, bool done = false}) {
  final at = DateTime.utc(2026, 11, 6);
  return TaskEntry(
    task: Task(
      id: id,
      title: id,
      dueDate: due,
      done: done,
      completedAt: done ? at : null,
      createdAt: at,
      updatedAt: at,
    ),
    subtaskCount: 0,
    subtasksDone: 0,
    tagIds: const {},
  );
}

void main() {
  test('task list rows: a header per section, tasks of open sections', () {
    final today = LocalDate(2026, 11, 6);
    final container = ProviderContainer(
      overrides: [
        todayProvider.overrideWithValue(today),
        taskEntriesProvider.overrideWithValue(
          AsyncData([
            _entry('a', due: today),
            _entry('b', due: today),
            _entry('c'),
            _entry('d', due: today, done: true),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final rows = container.read(taskListRowsProvider).requireValue;
    // Today (2 tasks), No date (1), Completed (collapsed at first).
    expect(rows.length, 6);
    expect(rows[0].isHeader, isTrue);
    expect(rows[0].section.group, TaskGroup.today);
    expect([rows[1].entry.task.id, rows[2].entry.task.id], ['a', 'b']);
    expect((rows[1].first, rows[1].last), (true, false));
    expect((rows[2].first, rows[2].last), (false, true));
    expect(rows[5].section.group, TaskGroup.completed);
    expect(rows.indexOf(const ValueKey('c')), 4);
    expect(rows.indexOf(const ValueKey(TaskGroup.completed)), 5);
    expect(rows.indexOf(const ValueKey('d')), isNull);

    container
        .read(collapsedGroupsProvider.notifier)
        .toggle(TaskGroup.completed);
    final opened = container.read(taskListRowsProvider).requireValue;
    expect(opened.length, 7);
    expect(opened.indexOf(const ValueKey('d')), 6);
  });

  testWidgets('lazy indexed stack builds a page only once it is shown', (
    tester,
  ) async {
    Widget stack(int index) => Directionality(
      textDirection: TextDirection.ltr,
      child: LazyIndexedStack(
        index: index,
        children: const [Text('one'), Text('two'), Text('three')],
      ),
    );

    await tester.pumpWidget(stack(0));
    expect(find.text('one'), findsOneWidget);
    expect(find.text('two', skipOffstage: false), findsNothing);

    await tester.pumpWidget(stack(1));
    expect(find.text('two'), findsOneWidget);
    // The first page is kept, just not shown.
    expect(find.text('one', skipOffstage: false), findsOneWidget);
    expect(find.text('three', skipOffstage: false), findsNothing);
  });
}
