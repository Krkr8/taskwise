// The design tour: fills the app with realistic sample tasks and takes a
// screenshot of every main screen, in every design (lib/ui/designs/) and
// four looks (desktop light, desktop dark, phone light, phone Arabic).
// Screenshots go to <SHOTS>/<design>/<look>/<screen>.png.
//
//   cd app && flutter test integration_test/design_tour_test.dart -d linux \
//     --dart-define=SHOTS=$PWD/../design
//
// Add --dart-define=DESIGNS=brutal,lapis to shoot only some designs.
//
// Navigation goes through the app's providers where it can (tabs, opening a
// task), so a new layout keeps working. Buttons inside screens are found by
// their translated labels; if a redesign renames or moves one, update the
// finder here, but keep the list of screenshots the same.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:taskwise/data/app_settings.dart';
import 'package:taskwise/l10n/app_localizations.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/ui/shared/theme/tokens.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import 'helpers.dart';

typedef Look = ({
  String name,
  Size size,
  double pixelRatio,
  ThemePreference theme,
  AppLanguage language,
});

const looks = <Look>[
  (
    name: 'desktop-light',
    size: Size(1280, 800),
    pixelRatio: 1,
    theme: ThemePreference.light,
    language: AppLanguage.en,
  ),
  (
    name: 'desktop-dark',
    size: Size(1280, 800),
    pixelRatio: 1,
    theme: ThemePreference.dark,
    language: AppLanguage.en,
  ),
  (
    name: 'phone-light',
    size: Size(390, 844),
    pixelRatio: 2,
    theme: ThemePreference.light,
    language: AppLanguage.en,
  ),
  (
    name: 'phone-arabic',
    size: Size(390, 844),
    pixelRatio: 2,
    theme: ThemePreference.light,
    language: AppLanguage.ar,
  ),
];

const _onlyDesigns = String.fromEnvironment('DESIGNS');

/// The designs to shoot: all, or the DESIGNS dart-define's list.
List<AppDesign> get designs => _onlyDesigns.isEmpty
    ? AppDesign.values
    : [
        for (final name in _onlyDesigns.split(','))
          AppDesign.values.byName(name),
      ];

const richTask = 'Plan the weekend trip to Erbil';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('design tour', (tester) async {
    final db = await startApp(tester);
    final container = containerOf(tester);
    await seed(container);
    await settle(tester);

    final richId = (await (db.select(
      db.tasks,
    )..where((t) => t.title.equals(richTask))).getSingle()).id;

    for (final design in designs) {
      await container.read(settingsRepositoryProvider).setDesign(design);
      for (final look in looks) {
        await apply(tester, container, look);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(Scaffold).first),
        );
        final wide = look.size.width >= Breakpoints.listDetail;
        String n(String screen) => '${design.name}/${look.name}/$screen';

        // 1. The task list.
        container
            .read(shellTabProvider.notifier)
            .select(ShellTabNotifier.tasks);
        await settle(tester);
        await shot(tester, n('01-tasks'));

        // 2. A task with everything: notes, subtasks, tags, reminders, repeat.
        container.read(openTaskRequestProvider.notifier).request(richId);
        await settle(tester);
        await shot(tester, n('02-task-detail'));

        // 3. The repeat choices.
        await tester.ensureVisible(labelled(l10n.repeat));
        await settle(tester);
        await tester.tap(labelled(l10n.repeat));
        await settle(tester);
        await shot(tester, n('03-repeat'));
        await popTop(tester);

        // 4. The reminder menu, then 5. the map picker.
        await tester.ensureVisible(labelled(l10n.addReminder));
        await settle(tester);
        await tester.tap(labelled(l10n.addReminder));
        await settle(tester);
        await shot(tester, n('04-reminder-menu'));
        await tester.tap(labelled(l10n.reminderAtLocation));
        await waitForTiles(tester);
        await shot(tester, n('05-location-picker'));
        await popTop(tester);

        // Close the task again.
        if (wide) {
          container.read(selectedTaskIdProvider.notifier).select(null);
        } else {
          await popTop(tester);
        }
        await settle(tester);

        // 6. Calendar week, 7. month.
        container.read(shellTabProvider.notifier).select(1);
        await settle(tester);
        await shot(tester, n('06-calendar-week'));
        await tester.tap(labelled(l10n.calendarMonth));
        await settle(tester);
        await shot(tester, n('07-calendar-month'));
        await tester.tap(labelled(l10n.calendarWeek));
        await settle(tester);

        // 8. Settings.
        container
            .read(shellTabProvider.notifier)
            .select(ShellTabNotifier.settings);
        await settle(tester);
        await shot(tester, n('08-settings'));
      }
    }

    // 9. An empty task list, in every design and look.
    final tasks = container.read(taskRepositoryProvider);
    for (final t in await db.select(db.tasks).get()) {
      await tasks.deleteTask(t.id);
    }
    for (final design in designs) {
      await container.read(settingsRepositoryProvider).setDesign(design);
      for (final look in looks) {
        await apply(tester, container, look);
        container
            .read(shellTabProvider.notifier)
            .select(ShellTabNotifier.tasks);
        await settle(tester);
        await shot(tester, '${design.name}/${look.name}/09-empty');
      }
    }

    tester.view.reset();
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  });
}

Future<void> apply(
  WidgetTester tester,
  ProviderContainer container,
  Look look,
) async {
  tester.view
    ..devicePixelRatio = look.pixelRatio
    ..physicalSize = look.size * look.pixelRatio;
  final settings = container.read(settingsRepositoryProvider);
  await settings.setTheme(look.theme);
  await settings.setLanguage(look.language);
  await settle(tester);
}

/// A button or text with this label, or with this tooltip (icon buttons).
Finder labelled(String label) {
  final text = find.text(label);
  return text.evaluate().isNotEmpty ? text.last : find.byTooltip(label).last;
}

/// Closes the top dialog, sheet, menu or page without saving.
Future<void> popTop(WidgetTester tester) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
  navigator.pop();
  await settle(tester);
}

/// Realistic sample data around today.
Future<void> seed(ProviderContainer container) async {
  final tasks = container.read(taskRepositoryProvider);
  final categories = container.read(categoryRepositoryProvider);
  final reminders = container.read(reminderRepositoryProvider);
  final places = container.read(placeRepositoryProvider);
  final today = container.read(todayProvider);

  final home = await categories.createCategory('Home', 0xFF43A047);
  final work = await categories.createCategory('Work', 0xFF1E88E5);
  final personal = await categories.createCategory('Personal', 0xFF8E24AA);
  final market = await places.createPlace(
    name: 'Market',
    latitude: 33.3406,
    longitude: 44.4009,
  );

  Future<Task> add(
    String title, {
    int? inDays,
    int? at,
    Priority priority = Priority.none,
    Category? category,
    String notes = '',
    String? rule,
    List<String> tags = const [],
    List<String> subtasks = const [],
  }) async {
    var task = await tasks.createTask(
      title: title,
      dueDate: inDays == null ? null : today.addDays(inDays),
      dueTimeMinutes: at,
      priority: priority,
      categoryId: category?.id,
    );
    if (notes.isNotEmpty || rule != null) {
      task = task.copyWith(notes: notes, recurrenceRule: () => rule);
      await tasks.saveTask(task);
    }
    final tagIds = <String>{};
    for (final name in tags) {
      tagIds.add((await tasks.findOrCreateTag(name)).id);
    }
    if (tagIds.isNotEmpty) await tasks.setTaskTags(task.id, tagIds);
    for (final s in subtasks) {
      await tasks.addSubtask(task.id, s);
    }
    return task;
  }

  String ymd(LocalDate d) =>
      '${d.year}${'${d.month}'.padLeft(2, '0')}${'${d.day}'.padLeft(2, '0')}';

  await add(
    'Pay the electricity bill',
    inDays: -2,
    priority: Priority.high,
    category: home,
  );
  await add('Reply to Sara about the report', inDays: -1, category: work);
  final rich = await add(
    richTask,
    inDays: 0,
    at: 18 * 60,
    priority: Priority.medium,
    category: personal,
    notes: 'Book the hotel near the citadel. Ask Ali if he can drive.',
    rule: 'DTSTART=${ymd(today)};FREQ=MONTHLY;BYMONTHDAY=${today.day}',
    tags: ['travel', 'family'],
    subtasks: ['Book the hotel', 'Check the car', 'Pack snacks'],
  );
  await reminders.addRelative(rich.id, 60);
  await reminders.addLocation(
    rich.id,
    placeId: market.id,
    radiusMeters: 50,
    trigger: LocationTrigger.arrive,
  );
  final standup = await add(
    'Team stand-up',
    inDays: 0,
    at: 9 * 60 + 30,
    category: work,
    rule: 'DTSTART=${ymd(today)};FREQ=WEEKLY;BYDAY=SU,MO,TU,WE,TH',
  );
  await reminders.addRelative(standup.id, 10);
  await add(
    'Buy bread and milk',
    inDays: 0,
    category: home,
    tags: ['shopping'],
  );
  await add(
    'Finish the quarterly slides',
    inDays: 1,
    at: 14 * 60,
    priority: Priority.high,
    category: work,
    subtasks: ['Sales numbers', 'Charts', 'Rehearse'],
  );
  await add('Call grandma', inDays: 2, category: personal);
  await add('Dentist appointment', inDays: 4, at: 11 * 60, category: personal);
  await add('Renew car insurance', inDays: 9, priority: Priority.low);
  await add('Read "Atomic Habits"', tags: ['reading']);
  await add('Fix the kitchen tap', category: home);
  final done = await add('Send the invoice', inDays: -1, category: work);
  await tasks.setDone(done.id, done: true);
}
