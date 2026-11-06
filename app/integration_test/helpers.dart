// Shared helpers for the integration tests that drive the real app in a
// window on the laptop (`flutter test integration_test/<file> -d linux`).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/app.dart';
import 'package:taskwise/data/app_settings.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/main.dart' show configureIntl;
import 'package:taskwise/notifications/notifier.dart';
import 'package:taskwise/notifications/reminder_scheduler.dart';
import 'package:taskwise/state/providers.dart';

/// Folder for screenshots, from `--dart-define=SHOTS=<dir>` (empty: none).
const shotsDir = String.fromEnvironment('SHOTS');

/// Starts the app in English, on [database] or a fresh in-memory one.
Future<AppDatabase> startApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
  String deviceId = 'laptop',
  AppDatabase? database,
}) async {
  configureIntl();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = database ?? AppDatabase(NativeDatabase.memory());
  await SettingsRepository(db, deviceId: deviceId).setLanguage(AppLanguage.en);
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
  return db;
}

/// The app's Riverpod container.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

extension PageBack on WidgetTester {
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

/// Saves a PNG of the window as `<SHOTS>/<name>.png` when SHOTS is set.
Future<void> shot(WidgetTester tester, String name) async {
  if (shotsDir.isEmpty) return;
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  // The root layer already includes the device pixel ratio.
  final image = await layer.toImage(Offset.zero & tester.view.physicalSize);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File('$shotsDir/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
}
