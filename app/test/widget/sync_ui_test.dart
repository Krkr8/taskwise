import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
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
import 'package:taskwise/sync/sync_controller.dart';
import 'package:taskwise/sync/token_store.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../sync/fake_server.dart';

final _now = DateTime(2026, 11, 2, 9);

/// The whole app against a [FakeSyncServer], on a desktop-sized window.
void syncUiTest(
  String description,
  Future<void> Function(
    WidgetTester tester,
    FakeSyncServer server,
    AppDatabase db,
    MemoryTokenStore tokens,
  )
  body, {
  Future<void> Function(AppDatabase db, MemoryTokenStore tokens)? arrange,
}) {
  testWidgets(description, (tester) async {
    configureIntl();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tester.view
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final server = FakeSyncServer();
    final db = AppDatabase(NativeDatabase.memory());
    final tokens = MemoryTokenStore();
    await tester.runAsync(() async {
      final id = await ensureThisDevice(
        db,
        type: DeviceType.linux,
        name: 'Fedora Laptop',
      );
      await SettingsRepository(db, deviceId: id).setLanguage(AppLanguage.en);
      await arrange?.call(db, tokens);
    });
    final deviceId = (await tester.runAsync(
      () => (db.select(db.devices)).getSingle(),
    ))!.id;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue(deviceId),
          deviceTypeProvider.overrideWithValue(DeviceType.linux),
          clockProvider.overrideWithValue(() => _now),
          todayProvider.overrideWithValue(LocalDate.fromDateTime(_now)),
          initialSettingsProvider.overrideWithValue(
            const AppSettings(language: AppLanguage.en),
          ),
          tokenStoreProvider.overrideWithValue(tokens),
          syncHttpClientProvider.overrideWithValue(server.client),
        ],
        child: const TaskwiseApp(),
      ),
    );
    await _settle(tester);

    await body(tester, server, db, tokens);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await db.close();
  });
}

/// Pumps while async work (database, fake HTTP) completes.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _openSignIn(WidgetTester tester) async {
  await tester.tap(find.text('Connect'));
  await _settle(tester);
  expect(find.text('Connect to your server'), findsWidgets);
}

Future<void> _fillSignIn(
  WidgetTester tester, {
  required String password,
}) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Server address'),
    'sync.test',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Username'),
    'owner',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    password,
  );
  await tester.tap(find.text('Sign in'));
  await _settle(tester);
}

void main() {
  syncUiTest('the banner invites to connect and can be dismissed', (
    tester,
    server,
    db,
    tokens,
  ) async {
    expect(
      find.text('Sync your devices: connect to your Taskwise server.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Not now'));
    await _settle(tester);
    expect(find.text('Not now'), findsNothing);
  });

  syncUiTest('signing in: a wrong password is explained, then it works', (
    tester,
    server,
    db,
    tokens,
  ) async {
    await _openSignIn(tester);
    // The device name is pre-filled.
    expect(find.widgetWithText(TextFormField, 'Fedora Laptop'), findsOneWidget);

    await _fillSignIn(tester, password: 'wrong');
    expect(find.text('Wrong username or password.'), findsOneWidget);

    await _fillSignIn(tester, password: server.password);
    expect(tokens.token, isNotNull);
    // Back on the task list; the banner is gone, the status icon shows.
    expect(find.text('Connect'), findsNothing);
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
  });

  syncUiTest('Settings shows the connection and the devices', (
    tester,
    server,
    db,
    tokens,
  ) async {
    await _openSignIn(tester);
    await _fillSignIn(tester, password: server.password);

    await tester.tap(find.text('Settings').first);
    await _settle(tester);
    expect(find.text('Synced just now'), findsOneWidget);
    expect(find.textContaining('Signed in as owner'), findsOneWidget);

    server.devices['phone'] = {
      'id': 'phone',
      'name': 'iPhone',
      'type': 'ios',
      'lastSeenAt': '2026-11-02T08:00:00.000Z',
      'updatedAt': '2026-11-02T08:00:00.000Z',
      'deleted': false,
      'updatedByDevice': null,
    };
    await tester.tap(find.text('Sync now'));
    await _settle(tester);
    await tester.tap(find.text('Devices'));
    await _settle(tester);
    expect(find.text('Fedora Laptop'), findsOneWidget);
    // The first device to sign in is the main one, so it manages the others.
    expect(find.text('Main device · This device'), findsOneWidget);
    expect(find.text('Make this the main device'), findsNothing);
    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await _settle(tester);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Make main device'), findsOneWidget);

    // Hand the role to the iPhone: this device can't remove it any more.
    await tester.tap(find.text('Make main device'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Make main device'));
    await _settle(tester);
    expect(server.devices['phone']!['main'], isTrue);
    expect(find.text('Make this the main device'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget); // own row
  });

  syncUiTest('a task can be limited to some devices', (
    tester,
    server,
    db,
    tokens,
  ) async {
    await _openSignIn(tester);
    await _fillSignIn(tester, password: server.password);
    // A second device on the account.
    server.devices['phone'] = {
      'id': 'phone',
      'name': 'iPhone',
      'type': 'ios',
      'lastSeenAt': null,
      'updatedAt': '2026-11-02T08:00:00.000Z',
      'deleted': false,
      'updatedByDevice': null,
    };
    // The cloud button syncs straight away.
    await tester.tap(find.byIcon(Icons.cloud_done_outlined));
    await _settle(tester);
    await tester.tap(find.text('Tasks').first);
    await _settle(tester);

    final task = (await tester.runAsync(
      () => TaskRepository(db, deviceId: 'x').createTask(title: 'Call mum'),
    ))!;
    await _settle(tester);
    await tester.tap(find.text('Call mum'));
    await _settle(tester);

    await tester.ensureVisible(find.text('Notify on'));
    expect(find.text('All devices'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'iPhone'));
    await _settle(tester);

    final saved = (await tester.runAsync(
      () => TaskRepository(db, deviceId: 'x').getTask(task.id),
    ))!;
    expect(saved.notifyAllDevices, isFalse);
    final targets = (await tester.runAsync(
      () => TaskRepository(db, deviceId: 'x').watchAllTaskTargets().first,
    ))!;
    // Unticking the iPhone from "all" keeps the other device.
    expect(targets[task.id], hasLength(1));
    expect(targets[task.id], isNot(contains('phone')));
  });
}
