import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise/l10n/app_localizations.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/ui/shared/tasks/subtask_tree.dart';

import '../data/test_db.dart';

SubtaskTreeStyle _style() => SubtaskTreeStyle(
  line: Colors.blue,
  lineInset: 20,
  indent: 40,
  text: const TextStyle(),
  doneText: const TextStyle(decoration: TextDecoration.lineThrough),
  checkbox: (context, s, onToggle) =>
      Checkbox(value: s.done, onChanged: (_) => onToggle()),
);

void main() {
  for (final rtl in [false, true]) {
    testWidgets('shows each subtask and ticks it in place (rtl: $rtl)', (
      tester,
    ) async {
      final db = openTestDatabase();
      final repo = TaskRepository(db, deviceId: 'test');
      late String taskId;
      await tester.runAsync(() async {
        final task = await repo.createTask(title: 'Trip');
        taskId = task.id;
        for (final title in ['Tickets', 'Hotel', 'Bags']) {
          await repo.addSubtask(task.id, title);
        }
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            deviceIdProvider.overrideWithValue('test'),
          ],
          child: MaterialApp(
            locale: Locale(rtl ? 'ar' : 'en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SubtaskTree(taskId: taskId, style: _style()),
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.text('Tickets'), findsOneWidget);
      expect(find.text('Hotel'), findsOneWidget);
      expect(find.text('Bags'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(3));

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      final subtasks = await tester.runAsync(
        () => repo.watchSubtasks(taskId).first,
      );
      expect([for (final s in subtasks!) s.done], [false, true, false]);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
      await db.close();
    });
  }
}
