// The performance check (SPEC M8): fills the app with 2,000 tasks and times
// the main screens of every design, on a desktop and a phone-sized window.
// See docs/performance.md for the results and what they mean.
//
// In a profile build (like the real app; the numbers to go by):
//
//   cd app && flutter drive --profile -d linux \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/performance_test.dart
//
// Or as a normal debug test (slower, for a quick check):
//
//   cd app && flutter test integration_test/performance_test.dart -d linux
//
// Add --dart-define=DESIGNS=brutal,lapis to time only some designs, and
// --dart-define=TASKS=<n> for another number of tasks. The results are
// printed as a table at the end.
//
// What is timed, in milliseconds of wall-clock time until the screen shows
// the result, with the slowest frame's build time meanwhile:
// - design→list: switching to the design until the task list shows (a cold
//   build of the design's screens);
// - tab→list: from the Calendar tab back to the task list;
// - scroll: frame build times while flinging the list down and up again
//   (p50 / p90 / worst, and how many frames took over 16 ms);
// - open task: tapping a task until its details show;
// - tick done: tapping a task's check box until it leaves the open list
//   (includes the check's own short animation before the row moves);
// - search: typing "garden" one letter per frame, then clearing it;
// - month view: switching the calendar to the month view; next month:
//   going to the next month.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show FrameTiming;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:taskwise/data/app_settings.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/reminder_repository.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise/l10n/app_localizations.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/ui/shared/theme/tokens.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import 'helpers.dart';

/// How many tasks to seed: 2,000, or `--dart-define=TASKS=<n>`.
const taskCount = int.fromEnvironment('TASKS', defaultValue: 2000);
const _onlyDesigns = String.fromEnvironment('DESIGNS');

List<AppDesign> get designs => _onlyDesigns.isEmpty
    ? AppDesign.values
    : [
        for (final name in _onlyDesigns.split(','))
          AppDesign.values.byName(name),
      ];

typedef Look = ({String name, Size size, double pixelRatio});

const looks = <Look>[
  (name: 'desktop', size: Size(1280, 800), pixelRatio: 1),
  (name: 'phone', size: Size(390, 844), pixelRatio: 2),
];

/// One row of the results table.
class Result {
  Result(this.design, this.look);

  final String design;
  final String look;
  late Timed designSwitch;
  late Timed tab;
  late FrameStats scroll;
  late Timed open;
  late Timed tick;
  late Timed search;
  late Timed month;
  late Timed nextMonth;
}

/// How long an action took until the screen showed its result, and the
/// frames drawn meanwhile.
typedef Timed = ({int ms, FrameStats frames});

/// Build times (build, layout and paint on the UI thread) of a run of
/// frames. The Linux engine reports no separate raster time.
class FrameStats {
  FrameStats(List<FrameTiming> timings)
    : frames = timings.length,
      build = [for (final t in timings) t.buildDuration.inMicroseconds / 1000]
        ..sort(),
      slow = timings
          .where((t) => t.buildDuration.inMicroseconds > 16000)
          .length;

  final int frames;
  final List<double> build;
  final int slow;

  static double _pct(List<double> sorted, double p) => sorted.isEmpty
      ? 0
      : sorted[math.min(sorted.length - 1, (sorted.length * p).floor())];

  static String _ms(double v) => v.toStringAsFixed(1);

  String _three(List<double> s) =>
      '${_ms(_pct(s, .5))}/${_ms(_pct(s, .9))}/${_ms(s.isEmpty ? 0 : s.last)}';

  String get buildText => _three(build);

  /// The slowest frame's build time.
  String get worstText => _ms(build.isEmpty ? 0 : build.last);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('performance with $taskCount tasks', (tester) async {
    // A database file on a background isolate, as in the real app.
    final dir = await Directory.systemTemp.createTemp('taskwise-perf');
    final db = await startApp(
      tester,
      database: AppDatabase(
        NativeDatabase.createInBackground(File('${dir.path}/perf.sqlite')),
      ),
    );
    final container = containerOf(tester);
    final seedWatch = Stopwatch()..start();
    await seed(db, container.read(todayProvider));
    // Wait for the first list of entries after the seed.
    await waitUntil(
      tester,
      () =>
          (container.read(taskEntriesProvider).value?.length ?? 0) >= taskCount,
      what: 'the seeded tasks',
    );
    seedWatch.stop();
    // ignore: avoid_print
    print('Seeded $taskCount tasks in ${seedWatch.elapsedMilliseconds} ms');

    // Show every design once first, so loading its fonts the first time
    // doesn't count against it.
    for (final design in designs) {
      await container.read(settingsRepositoryProvider).setDesign(design);
      await settle(tester);
      container.read(shellTabProvider.notifier).select(1);
      await settle(tester);
      container.read(shellTabProvider.notifier).select(ShellTabNotifier.tasks);
      await settle(tester);
    }

    final results = <Result>[];
    for (final design in designs) {
      for (final look in looks) {
        final r = Result(design.name, look.name);
        results.add(r);
        await measure(tester, binding, container, design, look, r);
      }
    }

    // ignore: avoid_print
    print(table(results));

    tester.view.reset();
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
    await dir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 30)));
}

Future<void> measure(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  ProviderContainer container,
  AppDesign design,
  Look look,
  Result r,
) async {
  Future<Timed> time(Future<void> Function() action, bool Function() done) =>
      timeUntil(tester, action, done);

  // Start each run on another design and on Settings, so switching the
  // design builds the task list from scratch.
  final settings = container.read(settingsRepositoryProvider);
  container.read(shellTabProvider.notifier).select(ShellTabNotifier.settings);
  container.read(selectedTaskIdProvider.notifier).select(null);
  tester.view
    ..devicePixelRatio = look.pixelRatio
    ..physicalSize = look.size * look.pixelRatio;
  await settle(tester);
  await settings.setDesign(
    design == AppDesign.classic ? AppDesign.slate : AppDesign.classic,
  );
  await settle(tester);
  container.read(shellTabProvider.notifier).select(ShellTabNotifier.tasks);
  await settle(tester);
  final wide = look.size.width >= Breakpoints.listDetail;
  bool listShown() => _taskTitles().evaluate().isNotEmpty;

  // 1. Design switch → list.
  r.designSwitch = await time(() => settings.setDesign(design), listShown);
  await settle(tester);
  final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  // 2. Calendar → tasks.
  container.read(shellTabProvider.notifier).select(1);
  await settle(tester);
  r.tab = await time(
    () async => container
        .read(shellTabProvider.notifier)
        .select(ShellTabNotifier.tasks),
    listShown,
  );
  await settle(tester);

  // 3. Scrolling: fling down three times and back up three times, with
  // frames drawn at the screen's rate (not only when the test pumps).
  final list = find
      .ancestor(of: _taskTitles().first, matching: find.byType(Scrollable))
      .first;
  final policy = binding.framePolicy;
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  r.scroll = await frameStats(() async {
    for (final dy in const <double>[-1500, -1500, -1500, 1500, 1500, 1500]) {
      await tester.fling(list, Offset(0, dy), 2500);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    }
  });
  binding.framePolicy = policy;
  await settle(tester);
  tester.state<ScrollableState>(list).position.jumpTo(0);
  await settle(tester);

  // 4. Open a task.
  final title = (tester.widget<Text>(_taskTitles().first)).data!;
  r.open = await time(
    () => tester.tap(find.text(title).first),
    () => find
        .byWidgetPredicate(
          (w) => w is EditableText && w.controller.text == title,
        )
        .evaluate()
        .isNotEmpty,
  );
  await settle(tester);
  if (wide) {
    container.read(selectedTaskIdProvider.notifier).select(null);
  } else {
    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
  }
  await settle(tester);

  // 5. Tick it done (it moves to the collapsed Completed section), then
  // undo through the repository.
  r.tick = await time(
    () => tester.tap(find.byTooltip(l10n.markDone(title)).first),
    () => find.text(title).evaluate().isEmpty,
  );
  await settle(tester);
  final ticked = container
      .read(taskEntriesProvider)
      .value!
      .firstWhere((e) => e.task.title == title);
  await container
      .read(taskRepositoryProvider)
      .setDone(ticked.task.id, done: false);
  await settle(tester);

  // 6. Search, one letter per frame.
  final search = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == l10n.searchHint,
  );
  await tester.tap(search.first);
  await settle(tester);
  // Types as the keyboard would (enterText doesn't reach the field in a
  // profile build).
  void type(String text) => tester
      .state<EditableTextState>(
        find.descendant(of: search.first, matching: find.byType(EditableText)),
      )
      .userUpdateTextEditingValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
        SelectionChangedCause.keyboard,
      );
  const word = 'garden';
  int shown() => [
    for (final s in container.read(taskSectionsProvider).value!) ...s.entries,
  ].length;
  r.search = await time(() async {
    for (var i = 1; i <= word.length; i++) {
      type(word.substring(0, i));
      await tester.pump();
    }
    expect(shown(), lessThan(taskCount ~/ 4));
    // And clear it again: the whole list comes back.
    type('');
    await tester.pump();
  }, () => shown() > taskCount ~/ 2);
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(tester);

  // 7. Calendar month view, then the next month.
  container.read(shellTabProvider.notifier).select(1);
  await settle(tester);
  final monthView = find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == 'MonthView',
  );
  r.month = await time(
    () => tester.tap(_labelled(l10n.calendarMonth)),
    () => monthView.evaluate().isNotEmpty,
  );
  await settle(tester);
  final shownMonth = tester.widget(monthView.first);
  r.nextMonth = await time(
    () => tester.tap(_labelled(l10n.nextMonth)),
    () =>
        monthView.evaluate().isNotEmpty &&
        !identical(tester.widget(monthView.first), shownMonth),
  );
  await settle(tester);
  await tester.tap(_labelled(l10n.calendarWeek));
  await settle(tester);
  // ignore: avoid_print
  print('${r.design}/${r.look} done');
}

/// Runs [action], then pumps frames until [done]. Returns the time that
/// took and the frames drawn meanwhile.
Future<Timed> timeUntil(
  WidgetTester tester,
  Future<void> Function() action,
  bool Function() done,
) async {
  late int ms;
  final frames = await frameStats(() async {
    final watch = Stopwatch()..start();
    await action();
    await tester.pump();
    while (!done()) {
      if (watch.elapsed > const Duration(seconds: 30)) fail('Timed out');
      await tester.pump();
    }
    ms = watch.elapsedMilliseconds;
  });
  return (ms: ms, frames: frames);
}

/// The engine's timings of the frames drawn while [action] runs.
Future<FrameStats> frameStats(Future<void> Function() action) async {
  final timings = <FrameTiming>[];
  void collect(List<FrameTiming> t) => timings.addAll(t);
  SchedulerBinding.instance.addTimingsCallback(collect);
  try {
    await action();
    // Timings arrive in batches, about once a second.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
  } finally {
    SchedulerBinding.instance.removeTimingsCallback(collect);
  }
  return FrameStats(timings);
}

/// Task titles in the list (every seeded title starts with "Perf").
Finder _taskTitles() => find.byWidgetPredicate(
  (w) => w is Text && (w.data?.startsWith('Perf task') ?? false),
);

Finder _labelled(String label) {
  final text = find.text(label);
  return text.evaluate().isNotEmpty ? text.last : find.byTooltip(label).last;
}

String table(List<Result> results) {
  String t(Timed x) => '${x.ms} (${x.frames.worstText})';
  final b = StringBuffer()
    ..writeln()
    ..writeln('Performance with $taskCount tasks. Times in ms; in brackets')
    ..writeln("the slowest frame's build time meanwhile.")
    ..writeln()
    ..writeln(
      '| design | look | design→list | tab→list | scroll frame p50/p90/max '
      '| scroll frames >16ms | open task '
      '| tick done | search (6 letters, clear) | month view | next month |',
    )
    ..writeln('|---|---|---|---|---|---|---|---|---|---|---|');
  for (final r in results) {
    final s = r.scroll;
    b.writeln(
      '| ${r.design} | ${r.look} | ${t(r.designSwitch)} | ${t(r.tab)} '
      '| ${s.buildText} | ${s.slow}/${s.frames} '
      '| ${t(r.open)} | ${t(r.tick)} | ${t(r.search)} '
      '| ${t(r.month)} | ${t(r.nextMonth)} |',
    );
  }
  return b.toString();
}

/// 2,000 tasks over ±60 days and without a date: about a fifth with
/// subtasks, a third with tags, some with reminders, some repeating and
/// some done. Written in one batch, so the list loads once.
Future<void> seed(AppDatabase db, LocalDate today) async {
  final random = math.Random(42);
  final now = DateTime.now().toUtc();
  var n = 0;
  String id(String kind) => 'perf-$kind-${n++}';

  final categories = [
    for (final (name, color) in [
      ('Home', 0xFF43A047),
      ('Work', 0xFF1E88E5),
      ('Personal', 0xFF8E24AA),
      ('Errands', 0xFFF4511E),
    ])
      CategoriesCompanion.insert(
        id: id('category'),
        name: name,
        colorValue: color,
        updatedAt: now,
      ),
  ];
  final tags = [
    for (final name in ['travel', 'family', 'shopping', 'reading', 'q4', 'car'])
      TagsCompanion.insert(id: id('tag'), name: name, updatedAt: now),
  ];
  String ymd(LocalDate d) =>
      '${d.year}${'${d.month}'.padLeft(2, '0')}${'${d.day}'.padLeft(2, '0')}';

  final taskRows = <TasksCompanion>[];
  final subtaskRows = <SubtasksCompanion>[];
  final tagRows = <TaskTagsCompanion>[];
  final reminderRows = <RemindersCompanion>[];
  for (var i = 0; i < taskCount; i++) {
    final dated = random.nextDouble() < 0.85;
    final due = dated ? today.addDays(random.nextInt(121) - 60) : null;
    final repeats = dated && i % 40 == 0;
    final done = !repeats && random.nextDouble() < 0.12;
    final category = random.nextDouble() < 0.7
        ? categories[random.nextInt(categories.length)].id.value
        : null;
    final taskId = id('task');
    final task = Task(
      id: taskId,
      title: repeats
          ? 'Perf repeat ${i.toString().padLeft(4, '0')}'
          : 'Perf task ${i.toString().padLeft(4, '0')} '
                '${_words[random.nextInt(_words.length)]}',
      notes: random.nextDouble() < 0.25 ? 'Some notes about task $i.' : '',
      dueDate: due,
      dueTimeMinutes: dated && random.nextBool()
          ? (random.nextInt(24 * 4)) * 15
          : null,
      priority: Priority.values[random.nextInt(Priority.values.length)],
      categoryId: category,
      done: done,
      completedAt: done ? now.subtract(Duration(hours: i % 200)) : null,
      recurrenceRule: repeats
          ? (i % 120 == 0
                ? 'DTSTART=${ymd(due!)};FREQ=DAILY'
                : 'DTSTART=${ymd(due!)};FREQ=WEEKLY')
          : null,
      createdAt: now,
      updatedAt: now,
    );
    taskRows.add(TaskRepository.toCompanion(task));
    if (random.nextDouble() < 0.2) {
      final count = 2 + random.nextInt(4);
      for (var s = 0; s < count; s++) {
        subtaskRows.add(
          SubtasksCompanion.insert(
            id: id('subtask'),
            taskId: taskId,
            title: 'Step ${s + 1}',
            done: Value(s < count ~/ 2),
            sortOrder: s,
            updatedAt: now,
          ),
        );
      }
    }
    if (random.nextDouble() < 0.3) {
      final picked = {
        for (var t = 0; t < 1 + random.nextInt(2); t++)
          tags[random.nextInt(tags.length)].id.value,
      };
      for (final tagId in picked) {
        tagRows.add(
          TaskTagsCompanion.insert(
            id: id('tasktag'),
            taskId: taskId,
            tagId: tagId,
            updatedAt: now,
          ),
        );
      }
    }
    if (dated && random.nextDouble() < 0.15) {
      reminderRows.add(
        ReminderRepository.toCompanion(
          Reminder(
            id: id('reminder'),
            taskId: taskId,
            kind: ReminderKind.time,
            minutesBeforeDue: 30,
            updatedAt: now,
          ),
        ),
      );
    }
    if (dated && random.nextDouble() < 0.02) {
      reminderRows.add(
        ReminderRepository.toCompanion(
          Reminder(
            id: id('reminder'),
            taskId: taskId,
            kind: ReminderKind.location,
            latitude: 33.34,
            longitude: 44.40,
            radiusMeters: 100,
            trigger: LocationTrigger.arrive,
            label: 'Market',
            updatedAt: now,
          ),
        ),
      );
    }
  }
  await db.batch((b) {
    b
      ..insertAll(db.categories, categories)
      ..insertAll(db.tags, tags)
      ..insertAll(db.tasks, taskRows)
      ..insertAll(db.subtasks, subtaskRows)
      ..insertAll(db.taskTags, tagRows)
      ..insertAll(db.reminders, reminderRows);
  });
}

const _words = [
  'groceries',
  'report',
  'call back',
  'invoice',
  'garden',
  'car service',
  'slides',
  'birthday gift',
  'library books',
  'tax forms',
];
