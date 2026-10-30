import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/app.dart';
import 'package:taskwise/data/app_settings.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise/main.dart' show configureIntl;
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/ui/tasks/task_detail.dart';
import 'package:taskwise/ui/theme/app_theme.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

/// Tuesday 2026-10-20, 09:00 local.
final _now = DateTime(2026, 10, 20, 9);

const _desktop = Size(1280, 800);
const _phone = Size(400, 800);

/// Defines a widget test that runs the whole app on an in-memory database.
///
/// [body] gets a repository for arranging data directly. Afterwards the app
/// is unmounted and one more frame is pumped: drift closes cancelled query
/// streams on a zero-delay timer, which must fire inside the test.
void appTest(
  String description,
  Future<void> Function(WidgetTester tester, TaskRepository repo) body, {
  Size size = _desktop,
  AppSettings settings = const AppSettings(language: AppLanguage.en),
}) {
  testWidgets(description, (tester) async {
    configureIntl();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    final repo = TaskRepository(db, deviceId: 'test', clock: () => _now);
    // Persist the language too, or the live settings stream would fall back
    // to the system locale once it emits.
    if (settings.language case final language?) {
      await SettingsRepository(db, deviceId: 'test').setLanguage(language);
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue('test'),
          clockProvider.overrideWithValue(() => _now),
          todayProvider.overrideWithValue(LocalDate.fromDateTime(_now)),
          initialSettingsProvider.overrideWithValue(settings),
        ],
        child: const TaskwiseApp(),
      ),
    );
    await tester.pumpAndSettle();

    await body(tester, repo);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await db.close();
  });
}

Future<void> _quickAdd(WidgetTester tester, String title) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Add a task and press Enter'),
    title,
  );
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  appTest('shows the empty state on first launch', (tester, repo) async {
    expect(
      find.text('No tasks yet. Add your first one above.'),
      findsOneWidget,
    );
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  appTest('quick add puts an undated task under "No date"', (
    tester,
    repo,
  ) async {
    await _quickAdd(tester, 'Buy milk');

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('No date'), findsOneWidget);
    // The field is cleared and ready for the next task.
    expect(find.widgetWithText(TextField, 'Buy milk'), findsNothing);
  });

  appTest('tasks are grouped by due date', (tester, repo) async {
    await repo.createTask(title: 'Late', dueDate: LocalDate(2026, 10, 19));
    await repo.createTask(title: 'Now', dueDate: LocalDate(2026, 10, 20));
    await repo.createTask(title: 'Soon', dueDate: LocalDate(2026, 10, 21));
    await tester.pumpAndSettle();

    // .first: the group header comes before a row's "Today" due label.
    double y(String text) => tester.getTopLeft(find.text(text).first).dy;
    expect(y('Overdue') < y('Late'), isTrue);
    expect(y('Late') < y('Today'), isTrue);
    expect(y('Today') < y('Now'), isTrue);
    expect(y('Now') < y('Tomorrow'), isTrue);
    expect(y('Tomorrow') < y('Soon'), isTrue);
  });

  appTest('completing a task moves it to the collapsed Completed group', (
    tester,
    repo,
  ) async {
    await repo.createTask(title: 'Water plants');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mark "Water plants" as done'));
    await tester.pumpAndSettle();

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Water plants'), findsNothing); // collapsed by default

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Water plants'), findsOneWidget);
    expect(find.byTooltip('Mark "Water plants" as not done'), findsOneWidget);
  });

  appTest('delete offers undo, which restores the task', (tester, repo) async {
    await repo.createTask(title: 'Call the bank');
    await tester.pumpAndSettle();

    // Wide layout: tapping a row opens the side panel.
    await tester.tap(find.text('Call the bank'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailView), findsOneWidget);

    await tester.tap(find.byTooltip('Delete task'));
    await tester.pumpAndSettle();
    expect(find.text('Task deleted'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'Call the bank'), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Call the bank'), findsOneWidget);
  });

  appTest('editing in the detail panel saves title, priority and subtasks', (
    tester,
    repo,
  ) async {
    final task = await repo.createTask(title: 'Plan trip');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan trip'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Plan Erbil trip',
    );
    await tester.tap(find.text('High'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Add a subtask'),
      'Book hotel',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    // Let the typing debounce fire.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Plain queries in real time: drift query streams wait on the fake test
    // clock, so tests only observe them through the UI.
    final saved = (await tester.runAsync(() => repo.getTask(task.id)))!;
    expect(saved.title, 'Plan Erbil trip');
    expect(saved.priority, Priority.high);
    final subtasks = (await tester.runAsync(
      () => repo.db.select(repo.db.subtasks).get(),
    ))!;
    expect(subtasks.single.title, 'Book hotel');
    expect(find.text('0/1'), findsOneWidget); // subtask progress on the row
  });

  appTest('Arabic switches to RTL and keeps Western digits', (
    tester,
    repo,
  ) async {
    await repo.createTask(title: 'مهمة', dueDate: LocalDate(2026, 11, 25));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('مهمة'));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(find.text('لاحقًا'), findsOneWidget); // "Later" group
    final label = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((s) => s.contains('25'));
    expect(label, isNot(contains('٢٥')));
  }, settings: const AppSettings(language: AppLanguage.ar));

  appTest('Arabic priority labels in the side panel stay on one line', (
    tester,
    repo,
  ) async {
    await repo.createTask(title: 'مهمة');
    await tester.pumpAndSettle();
    await tester.tap(find.text('مهمة'));
    await tester.pumpAndSettle();

    final oneLine = tester.getSize(find.text('بلا')).height;
    for (final label in ['منخفضة', 'متوسطة', 'عالية']) {
      expect(tester.getSize(find.text(label)).height, oneLine, reason: label);
    }
  }, settings: const AppSettings(language: AppLanguage.ar));

  appTest('switching to dark theme in Settings applies immediately', (
    tester,
    repo,
  ) async {
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Theme'));
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  appTest('phone layout uses a bottom bar and full-screen details', (
    tester,
    repo,
  ) async {
    await repo.createTask(title: 'Pick up parcel');
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('Pick up parcel'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailPage), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailPage), findsNothing);
  }, size: _phone);
  appTest(
    'on iPhone, tapping outside the quick add field closes the keyboard',
    (tester, repo) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final field = find.widgetWithText(
          TextField,
          'Add a task and press Enter',
        );
        await tester.tap(field);
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isTrue);

        await tester.tap(find.text('No tasks yet. Add your first one above.'));
        await tester.pumpAndSettle();
        expect(tester.testTextInput.isVisible, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    size: _phone,
  );

  test('selected settings segments use the accent colour', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final style = theme.segmentedButtonTheme.style!;
      final scheme = theme.colorScheme;
      expect(
        style.backgroundColor!.resolve({WidgetState.selected}),
        scheme.primary,
      );
      expect(
        style.foregroundColor!.resolve({WidgetState.selected}),
        scheme.onPrimary,
      );
      expect(style.backgroundColor!.resolve({}), isNull);
    }
  });
  // ------------------------------------------------------------- M3

  Future<void> openCalendar(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
  }

  appTest('week columns follow the week start and RTL', (tester, repo) async {
    await openCalendar(tester);
    // Sunday start by default, left to right.
    expect(
      tester.getCenter(find.text('Sun')).dx,
      lessThan(tester.getCenter(find.text('Mon')).dx),
    );
    expect(find.textContaining('October 2026'), findsOneWidget);
  });

  appTest('in Arabic the week runs right to left', (tester, repo) async {
    await openCalendar(tester);
    expect(
      tester.getCenter(find.text('الأحد')).dx,
      greaterThan(tester.getCenter(find.text('الاثنين')).dx),
    );
  }, settings: const AppSettings(language: AppLanguage.ar));

  appTest('a timed task lands in its day column at its hour', (
    tester,
    repo,
  ) async {
    // _now is Tuesday 2026-10-20, 09:00.
    await repo.createTask(
      title: 'Standup',
      dueDate: LocalDate(2026, 10, 20),
      dueTimeMinutes: 10 * 60,
    );
    await openCalendar(tester);

    final chip = tester.getCenter(find.text('Standup'));
    final tue = tester.getRect(
      find.ancestor(of: find.text('Tue'), matching: find.byType(InkWell)),
    );
    expect(chip.dx, inInclusiveRange(tue.left, tue.right));
    // 10 AM is below the 9 AM label (shown as "9:00 AM", the time line).
    expect(chip.dy, greaterThan(tester.getCenter(find.text('9:00 AM')).dy));
  });

  appTest('repeats show in the week and month views', (tester, repo) async {
    final task = await repo.createTask(
      title: 'Water',
      dueDate: LocalDate(2026, 10, 20),
    );
    await repo.saveTask(
      task.copyWith(recurrenceRule: () => 'DTSTART=20261020;FREQ=DAILY'),
    );
    await openCalendar(tester);
    // Week of Sun 18 - Sat 24: the real task on Tuesday plus 4 repeats.
    expect(find.text('Water'), findsNWidgets(5));

    await tester.tap(find.byTooltip('Month'));
    await tester.pumpAndSettle();
    // Oct 20 to the end of the 6-week grid (Nov 7).
    expect(find.text('Water'), findsNWidgets(19));
  });

  appTest('arrows move by week and Today comes back', (tester, repo) async {
    await openCalendar(tester);
    expect(find.text('Today'), findsNothing);
    expect(find.textContaining('This week'), findsOneWidget);

    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    expect(find.text('25'), findsOneWidget);
    expect(find.textContaining('This week'), findsNothing);

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('18'), findsOneWidget);
    expect(find.textContaining('This week'), findsOneWidget);
  });

  appTest('tapping an empty slot adds a task at that hour', (
    tester,
    repo,
  ) async {
    await openCalendar(tester);
    // An empty spot in Wednesday's column, an hour below the 9 AM line.
    final wed = tester.getCenter(find.text('Wed'));
    final nine = tester.getCenter(find.text('9:00 AM'));
    await tester.tapAt(Offset(wed.dx, nine.dy + 80));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Dentist');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final tasks = await tester.runAsync(() => repo.watchEntries().first);
    final task = tasks!.single.task;
    expect(task.title, 'Dentist');
    expect(task.dueDate, LocalDate(2026, 10, 21));
    expect(task.dueTimeMinutes, 10 * 60);
  });

  appTest('the repeat editor sets a rule', (tester, repo) async {
    final task = await repo.createTask(
      title: 'Stretch',
      dueDate: LocalDate(2026, 10, 20),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stretch'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Does not repeat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly on Tuesday'));
    await tester.pumpAndSettle();

    final saved = await tester.runAsync(() => repo.getTask(task.id));
    expect(saved!.recurrenceRule, 'DTSTART=20261020;FREQ=WEEKLY;BYDAY=TU');
    expect(find.text('Every week on Tue'), findsOneWidget);
  });

  appTest('completing a repeating task spawns the next one; Undo removes it', (
    tester,
    repo,
  ) async {
    final task = await repo.createTask(
      title: 'Pills',
      dueDate: LocalDate(2026, 10, 20),
    );
    await repo.saveTask(
      task.copyWith(recurrenceRule: () => 'DTSTART=20261020;FREQ=DAILY'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mark "Pills" as done'));
    await tester.pumpAndSettle();
    expect(find.text('Done. Next: Tomorrow'), findsOneWidget);
    var entries = await tester.runAsync(() => repo.watchEntries().first);
    expect(entries!.length, 2);
    expect(
      entries.singleWhere((e) => !e.task.done).task.dueDate,
      LocalDate(2026, 10, 21),
    );

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    entries = await tester.runAsync(() => repo.watchEntries().first);
    expect(entries!.single.task.id, task.id);
    expect(entries.single.task.done, isFalse);
    expect(entries.single.task.recurrenceRule, isNotNull);
  });
}
