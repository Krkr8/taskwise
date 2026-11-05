// Drives the real app in a window on the laptop, with real map tiles and
// the real address search (Nominatim, a few requests), on a throwaway
// in-memory database. Screenshots go to the folder given by
// --dart-define=SHOTS=/some/dir (optional).
//
//   cd app && flutter test integration_test/location_test.dart -d linux
//
// The iPhone part uses a fake location platform: it checks what Taskwise
// would hand to the iPhone's native code. The native code itself is
// checked by tools/geofence_sim (Swift walk simulator and unit tests).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:taskwise/app.dart';
import 'package:taskwise/data/app_settings.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/location/location_platform.dart';
import 'package:taskwise/location/location_reminder_sync.dart';
import 'package:taskwise/main.dart' show configureIntl;
import 'package:taskwise/notifications/notifier.dart';
import 'package:taskwise/notifications/reminder_scheduler.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/sync/sync_controller.dart' show deviceTypeProvider;
import 'package:taskwise_shared/taskwise_shared.dart';

const _shots = String.fromEnvironment('SHOTS');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  Future<void> start(
    WidgetTester tester, {
    List<Override> overrides = const [],
    String deviceId = 'laptop',
  }) async {
    configureIntl();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    await SettingsRepository(
      db,
      deviceId: deviceId,
    ).setLanguage(AppLanguage.en);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue(deviceId),
          initialSettingsProvider.overrideWithValue(
            const AppSettings(language: AppLanguage.en),
          ),
          // No desktop pop-ups from the test.
          reminderNotifierProvider.overrideWithValue(NoopNotifier()),
          ...overrides,
        ],
        child: const TaskwiseApp(),
      ),
    );
    await settle(tester);
  }

  testWidgets('laptop: places, location reminders and the map', (tester) async {
    await start(tester);

    // Settings → default radius 50 m → Saved places → Add place.
    await tester.tap(find.text('Settings').first);
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Saved places'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '50 m'));
    await settle(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '50 m'));
    await settle(tester);
    final saved = await SettingsRepository(
      db,
      deviceId: 'laptop',
    ).loadSettings();
    expect(saved.defaultLocationRadius, 50, reason: 'saved in the database');
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '50 m'),
    );
    expect(chip.selected, isTrue, reason: 'the chip shows it');
    await shot(tester, '01-settings-location');
    await tester.tap(find.text('Saved places'));
    await settle(tester);
    await tester.tap(find.text('Add place'));
    await settle(tester);

    // A real address search.
    await tester.enterText(
      find.widgetWithText(TextField, 'Search for an address or place'),
      'Al Mutanabbi Street, Baghdad',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    final result = find.descendant(
      of: find.byType(Card),
      matching: find.byType(ListTile),
    );
    await waitFor(tester, result, what: 'search results from Nominatim');
    await shot(tester, '02-search-results');
    await tester.tap(result.first);
    await waitForTiles(tester);
    await shot(tester, '03-place-on-map');
    await tester.enterText(
      find.widgetWithText(TextField, 'Place name'),
      'Home',
    );
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Home'), findsOneWidget);
    final places = await db.select(db.places).get();
    expect(places.single.name, 'Home');
    expect(places.single.latitude, closeTo(33.34, 0.05));
    expect(places.single.longitude, closeTo(44.39, 0.05));

    // A leave reminder at Home, with the new default radius.
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.text('Tasks').first);
    await settle(tester);
    await quickAdd(tester, 'Test: leave home');
    await tester.tap(find.text('Test: leave home'));
    await settle(tester);
    await tester.tap(find.text('Add reminder'));
    await settle(tester);
    await tester.tap(find.text('At a location…'));
    await settle(tester);
    expect(find.text('Only reminds on the iPhone'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Home'));
    await tester.tap(find.text('Leave'));
    await waitForTiles(tester);
    await shot(tester, '04-picker-home-leave');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Leave Home · 50 m'), findsOneWidget);
    await shot(tester, '05-task-with-location');

    // A spot from a search that isn't a saved place, radius 120 m.
    await tester.pageBackIfAny();
    await quickAdd(tester, 'Buy books');
    await tester.tap(find.text('Buy books'));
    await settle(tester);
    await tester.tap(find.text('Add reminder'));
    await settle(tester);
    await tester.tap(find.text('At a location…'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search for an address or place'),
      'Baghdad International Airport',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await waitFor(tester, result, what: 'search results from Nominatim');
    await tester.tap(result.first);
    await settle(tester);
    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(40, 0));
    await waitForTiles(tester);
    await shot(tester, '06-picker-search-spot');
    await tester.tap(find.text('Save'));
    await settle(tester);
    final rows = await (db.select(
      db.reminders,
    )..where((r) => r.kind.equals(ReminderKind.location.name))).get();
    expect(rows, hasLength(2));
    final spot = rows.singleWhere((r) => r.placeId == null);
    expect(spot.label, isNotEmpty);
    expect(spot.radiusMeters, greaterThan(50));
    expect(spot.trigger, LocationTrigger.arrive);
    await tester.pageBackIfAny();
    await shot(tester, '07-task-list');
    expect(find.byTooltip('Location reminders'), findsNWidgets(2));

    // Arabic.
    await SettingsRepository(
      db,
      deviceId: 'laptop',
    ).setLanguage(AppLanguage.ar);
    await settle(tester);
    await tester.tap(find.text('Buy books'));
    await settle(tester);
    await shot(tester, '08-arabic-task');

    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  });

  testWidgets('iPhone (simulated): what reaches the native location code', (
    tester,
  ) async {
    final phone = FakeLocationPlatform(current: LocationPermission.always);
    await start(
      tester,
      deviceId: 'iphone',
      overrides: [
        locationPlatformProvider.overrideWithValue(phone),
        deviceTypeProvider.overrideWithValue(DeviceType.ios),
      ],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final home = await container
        .read(placeRepositoryProvider)
        .createPlace(name: 'Home', latitude: 33.3, longitude: 44.4);
    await quickAdd(tester, 'Take out the trash');
    await quickAdd(tester, 'Done already');
    final tasks = await db.select(db.tasks).get();
    String idOf(String title) => tasks.firstWhere((t) => t.title == title).id;
    for (final (task, trigger) in [
      (idOf('Take out the trash'), LocationTrigger.leave),
      (idOf('Done already'), LocationTrigger.arrive),
    ]) {
      await container
          .read(reminderRepositoryProvider)
          .addLocation(
            task,
            placeId: home.id,
            radiusMeters: 30,
            trigger: trigger,
          );
    }
    await waitUntil(tester, () => phone.lastEntries?.length == 2);
    // Completing a task takes its reminder off the phone.
    await tester.tap(find.byTooltip('Mark "Done already" as done'));
    await waitUntil(tester, () => phone.lastEntries?.length == 1);
    final entry = phone.lastEntries!.single;
    expect(entry.title, 'Take out the trash');
    expect(entry.body, 'You left Home');
    expect(entry.arrive, isFalse);
    expect(entry.radiusMeters, 30);
    expect(entry.latitude, 33.3);
    await shot(tester, '09-iphone-task-list');

    await tester.tap(find.text('Settings').first);
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Location debug'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Location debug'));
    await settle(tester);
    expect(find.text('Location reminders on this phone: 1'), findsOneWidget);
    await shot(tester, '10-iphone-debug');

    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  });
}

extension on WidgetTester {
  /// Closes the task panel.
  Future<void> pageBackIfAny() async {
    final close = find.byIcon(Icons.close);
    if (close.evaluate().isNotEmpty) {
      await tap(close.first);
      await settle(this);
    }
  }
}

Future<void> quickAdd(WidgetTester tester, String title) async {
  final field = find.widgetWithText(TextField, 'Add a task and press Enter');
  await tester.tap(field);
  await settle(tester);
  await tester.enterText(field, title);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await settle(tester);
}

/// Lets real time pass (the map, the network) until nothing animates.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}

Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  required String what,
}) => waitUntil(tester, () => finder.evaluate().isNotEmpty, what: what);

Future<void> waitUntil(
  WidgetTester tester,
  bool Function() done, {
  String what = 'the condition',
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for $what');
    await tester.pump(const Duration(milliseconds: 200));
  }
  await settle(tester);
}

/// Gives the map a few seconds to download its tiles.
Future<void> waitForTiles(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await settle(tester);
}

/// Saves a PNG of the window when SHOTS is set.
Future<void> shot(WidgetTester tester, String name) async {
  if (_shots.isEmpty) return;
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final size = tester.view.physicalSize;
  final image = await layer.toImage(Offset.zero & size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  await File('$_shots/$name.png')
      .writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
}
