import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/app.dart';
import 'package:taskwise/data/app_settings.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise/location/geocoder.dart';
import 'package:taskwise/location/location_platform.dart';
import 'package:taskwise/location/location_reminder_sync.dart';
import 'package:taskwise/main.dart' show configureIntl;
import 'package:taskwise/notifications/notifier.dart';
import 'package:taskwise/notifications/reminder_scheduler.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/ui/shared/location/map_providers.dart';
import 'package:taskwise/ui/designs/design.dart';
import 'package:taskwise/ui/designs/classic/location/location_picker_page.dart';
import 'package:taskwise/ui/designs/classic/tasks/task_detail.dart';
import 'package:taskwise/ui/designs/classic/theme/app_theme.dart';
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
  ReminderNotifier? notifier,
  List<Override> overrides = const [],
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
          if (notifier != null)
            reminderNotifierProvider.overrideWithValue(notifier),
          // No network in tests: a fake address search and no map tiles.
          geocoderProvider.overrideWithValue(_FakeGeocoder()),
          mapTilesEnabledProvider.overrideWithValue(false),
          appDesignProvider.overrideWithValue(AppDesign.classic),
          ...overrides,
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

  appTest('the Undo snackbar fades away by itself', (tester, repo) async {
    await repo.createTask(title: 'Call the bank');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Call the bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete task'));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Task deleted'), findsNothing);
    expect(find.text('Undo'), findsNothing);
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
    // The subtask field is further down the panel.
    final addSubtask = find.widgetWithText(TextField, 'Add a subtask');
    await tester.scrollUntilVisible(
      addSubtask,
      200,
      scrollable: find
          .descendant(
            of: find.byType(TaskDetailView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(addSubtask, 'Book hotel');
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

  appTest('a day column lists all-day tasks first, then by time', (
    tester,
    repo,
  ) async {
    // _now is Tuesday 2026-10-20.
    final tue = LocalDate(2026, 10, 20);
    await repo.createTask(title: 'Late', dueDate: tue, dueTimeMinutes: 18 * 60);
    await repo.createTask(title: 'Early', dueDate: tue, dueTimeMinutes: 8 * 60);
    await repo.createTask(title: 'Whole day', dueDate: tue);
    await openCalendar(tester);

    final column = tester.getRect(
      find.ancestor(of: find.text('Tue'), matching: find.byType(InkWell)),
    );
    double y(String title) => tester.getCenter(find.text(title)).dy;
    for (final title in ['Late', 'Early', 'Whole day']) {
      final x = tester.getCenter(find.text(title)).dx;
      expect(x, inInclusiveRange(column.left, column.right), reason: title);
    }
    expect(y('Whole day'), lessThan(y('Early')));
    expect(y('Early'), lessThan(y('Late')));
    expect(find.text('8:00 AM'), findsOneWidget);
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

  appTest('tapping the empty part of a day adds a task on that day', (
    tester,
    repo,
  ) async {
    await openCalendar(tester);
    final wed = tester.getCenter(find.text('Wed'));
    await tester.tapAt(Offset(wed.dx, wed.dy + 300));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Dentist');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final tasks = await tester.runAsync(() => repo.watchEntries().first);
    final task = tasks!.single.task;
    expect(task.title, 'Dentist');
    expect(task.dueDate, LocalDate(2026, 10, 21));
    expect(task.dueTimeMinutes, isNull);
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
  // ------------------------------------------------------------- M4

  appTest('adding a reminder plans a notification', (tester, repo) async {
    // _now is Tuesday 2026-10-20, 09:00.
    await repo.createTask(
      title: 'Call bank',
      dueDate: LocalDate(2026, 10, 20),
      dueTimeMinutes: 10 * 60,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Call bank'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 minutes before'));
    await tester.pumpAndSettle();
    expect(find.text('15 minutes before'), findsOneWidget); // the chip
    expect(find.byTooltip('Has reminders'), findsOneWidget); // the row

    // Let the scheduler's debounce run.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    final plan = _notifier.lastPlan;
    expect(plan.single.title, 'Call bank');
    expect(plan.single.fireAt, DateTime(2026, 10, 20, 9, 45));
  }, notifier: _notifier = NoopNotifier());

  appTest('Done and Snooze from a notification', (tester, repo) async {
    final task = await repo.createTask(
      title: 'Pay bill',
      dueDate: LocalDate(2026, 10, 20),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final scheduler = container.read(reminderSchedulerProvider);

    await tester.runAsync(
      () => scheduler.handleAction(
        SnoozeAction(task.id, LocalDate(2026, 10, 20), 15),
      ),
    );
    final snoozes = await tester.runAsync(
      () => container.read(settingsRepositoryProvider).getSnoozes(),
    );
    expect(
      snoozes!.single.until.isAtSameMomentAs(
        _now.add(const Duration(minutes: 15)),
      ),
      isTrue,
    );

    await tester.runAsync(
      () =>
          scheduler.handleAction(DoneAction(task.id, LocalDate(2026, 10, 20))),
    );
    final done = await tester.runAsync(() => repo.getTask(task.id));
    expect(done!.done, isTrue);
  });

  appTest('tapping a notification opens the task', (tester, repo) async {
    final task = await repo.createTask(title: 'Renew passport');
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    await container
        .read(reminderSchedulerProvider)
        .handleAction(OpenTaskAction(task.id, LocalDate(2026, 10, 20)));
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailView), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Renew passport'), findsOneWidget);
  });

  appTest('notification settings are saved', (tester, repo) async {
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('15 min before'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('15 min before'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 min before'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 min')); // ignored: 3 already picked
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 min')); // unpick
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 min'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final saved = await tester.runAsync(
      () => container.read(settingsRepositoryProvider).loadSettings(),
    );
    expect(saved!.defaultReminder, DefaultReminder.min15);
    expect(saved.snoozeMinutes, [10, 15, 60]);
  });
  // ------------------------------------------------------------- M7

  appTest('a location reminder from an address search', (tester, repo) async {
    final task = await repo.createTask(title: 'Buy bread');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy bread'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('At a location…'));
    await tester.pumpAndSettle();
    expect(find.byType(LocationPickerPage), findsOneWidget);
    expect(
      find.text('Only reminds on phones (iPhone and Android)'),
      findsOneWidget,
    );

    // Saving without a place explains what to do.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Choose a place first'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search for an address or place'),
      'bakery',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Corner Bakery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(LocationPickerPage), findsNothing);
    expect(find.text('Leave Corner Bakery · 30 m'), findsOneWidget);
    expect(
      find.text('Only reminds on phones (iPhone and Android)'),
      findsOneWidget,
    );
    expect(find.byTooltip('Location reminders'), findsOneWidget); // the row
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final saved = await tester.runAsync(
      () => container
          .read(reminderRepositoryProvider)
          .watchLocationForTask(task.id)
          .first,
    );
    expect(saved!.single.label, 'Corner Bakery');
    expect(saved.single.latitude, 33.3);
    expect(saved.single.trigger, LocationTrigger.leave);
  });

  appTest('saved places: add one on the map, then use it', (
    tester,
    repo,
  ) async {
    await repo.createTask(title: 'Water plants');
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Saved places'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Saved places'));
    await tester.pumpAndSettle();
    expect(find.text('No saved places yet.'), findsOneWidget);

    await tester.tap(find.text('Add place'));
    await tester.pumpAndSettle();
    // Drop a pin (the map waits a moment to tell a tap from a double tap).
    await tester.tap(find.byType(FlutterMap));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
      find.text('Tap the map to put the pin where the place is.'),
      findsNothing,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Place name'),
      'Home',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);

    // The place is offered when adding a location reminder.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tasks').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Water plants'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('At a location…'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Arrive at Home · 30 m'), findsOneWidget);
  });

  appTest('iPhone: the first location reminder explains the permission', (
    tester,
    repo,
  ) async {
    await repo.createTask(title: 'Buy bread');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy bread'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('At a location…'));
    await tester.pumpAndSettle();
    expect(
      find.text('Only reminds on phones (iPhone and Android)'),
      findsNothing,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Search for an address or place'),
      'bakery',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Corner Bakery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Location in the background'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Continue'),
      ),
    );
    await tester.pumpAndSettle();
    expect(_iphone.requests, 1);
    // "While using" only: the banner says reminders need "Always".
    expect(
      find.text('Location reminders need location access set to "Always".'),
      findsOneWidget,
    );
    await tester.tap(find.text('Open Settings'));
    expect(_iphone.settingsOpened, 1);
  }, overrides: [locationPlatformProvider.overrideWithValue(_iphone)]);

  appTest('Done on a location notification completes a task without a date', (
    tester,
    repo,
  ) async {
    final task = await repo.createTask(title: 'Buy bread');
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final payload = NotificationPayload.location(
      taskId: task.id,
      dueDate: null,
      title: 'Buy bread',
    ).encode();
    final action = ActionIds.parse(ActionIds.done, payload)!;
    await tester.runAsync(
      () => container.read(reminderSchedulerProvider).handleAction(action),
    );
    final done = await tester.runAsync(() => repo.getTask(task.id));
    expect(done!.done, isTrue);
  });

  appTest('Done on a set-time reminder completes a task without a date', (
    tester,
    repo,
  ) async {
    final task = await repo.createTask(title: 'Buy bread');
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    // A "Custom date & time" reminder: its occurrence is the day it fires.
    final payload = NotificationPayload(
      taskId: task.id,
      occurrence: LocalDate(2026, 11, 7),
      projected: false,
      fireAt: DateTime(2026, 11, 7, 8, 18),
      title: 'Buy bread',
    ).encode();
    final action = ActionIds.parse(ActionIds.done, payload)!;
    await tester.runAsync(
      () => container.read(reminderSchedulerProvider).handleAction(action),
    );
    final done = await tester.runAsync(() => repo.getTask(task.id));
    expect(done!.done, isTrue);
  });
}

final _iphone = FakeLocationPlatform(
  afterRequest: LocationPermission.whenInUse,
);

class _FakeGeocoder implements Geocoder {
  @override
  String get attribution => 'test';

  @override
  Future<List<GeocodeResult>> search(String query, {String? language}) async =>
      [
        (
          name: 'Corner Bakery',
          address: 'Corner Bakery, Main Street, Baghdad',
          latitude: 33.3,
          longitude: 44.4,
        ),
      ];
}

NoopNotifier _notifier = NoopNotifier();
