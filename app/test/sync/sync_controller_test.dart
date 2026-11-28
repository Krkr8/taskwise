import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/app_settings.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/category_repository.dart';
import 'package:taskwise/data/repositories/place_repository.dart';
import 'package:taskwise/data/repositories/reminder_repository.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise/logging/app_log.dart';
import 'package:taskwise/platform/app_target.dart';
import 'package:taskwise/platform/page_reload.dart';
import 'package:taskwise/platform/web_push.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/sync/sync_api.dart';
import 'package:taskwise/sync/sync_controller.dart';
import 'package:taskwise/sync/token_store.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/test_db.dart';
import 'fake_server.dart';

class _CountingPush extends NoWebPushClient {
  _CountingPush();
  int unsubscribes = 0;

  @override
  Future<void> unsubscribe() async => unsubscribes++;
}

void main() {
  // The controller listens to app lifecycle events.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSyncServer server;
  late AppDatabase db;
  late MemoryTokenStore tokens;
  late ProviderContainer container;
  late String deviceId;
  late _CountingPush push;

  Future<ProviderContainer> start() async {
    push = _CountingPush();
    final c = ProviderContainer(
      overrides: [
        webPushClientProvider.overrideWithValue(push),
        databaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue(deviceId),
        deviceTypeProvider.overrideWithValue(DeviceType.linux),
        tokenStoreProvider.overrideWithValue(tokens),
        syncHttpClientProvider.overrideWithValue(server.client),
      ],
    );
    // Keep the controller alive and let it load the saved account.
    c.listen(syncControllerProvider, (_, _) {});
    await _settle(c);
    return c;
  }

  SyncController controller() =>
      container.read(syncControllerProvider.notifier);
  SyncState state() => container.read(syncControllerProvider);

  Future<void> signIn({String? secret}) => controller().signIn(
    serverUrl: 'sync.test',
    username: server.username,
    password: server.password,
    deviceName: 'My laptop',
    setupSecret: secret,
  );

  setUp(() async {
    server = FakeSyncServer();
    db = openTestDatabase();
    tokens = MemoryTokenStore();
    deviceId = await ensureThisDevice(
      db,
      type: DeviceType.linux,
      name: 'Fedora Laptop',
    );
    container = await start();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('starts not connected', () {
    expect(state().loaded, isTrue);
    expect(state().connected, isFalse);
  });

  test('signing in uploads existing tasks and names the device', () async {
    final task = await TaskRepository(
      db,
      deviceId: deviceId,
    ).createTask(title: 'Made before sync');
    // Pretend it predates the outbox (a v1 database).
    await db.customStatement('DELETE FROM sync_outbox');

    await signIn();
    await _settle(container);

    expect(state().connected, isTrue);
    expect(state().serverUrl, 'https://sync.test');
    expect(state().phase, SyncPhase.idle);
    expect(state().lastSyncedAt, isNotNull);
    expect(tokens.token, startsWith('tw_'));
    expect(server.record('task', task.id)!['title'], 'Made before sync');
    expect(server.devices[deviceId]!['name'], 'My laptop');
    final local = await db.select(db.devices).getSingle();
    expect(local.name, 'My laptop');
  });

  test('stays signed in after a restart', () async {
    await signIn();
    container.dispose();
    container = await start();
    expect(state().connected, isTrue);
    expect(state().username, server.username);
  });

  test('wrong password throws and stays disconnected', () async {
    await expectLater(
      controller().signIn(
        serverUrl: 'sync.test',
        username: server.username,
        password: 'nope',
        deviceName: 'x',
      ),
      throwsA(isA<SyncHttpException>().having((e) => e.status, 'status', 401)),
    );
    expect(state().connected, isFalse);
    expect(tokens.token, isNull);
  });

  test('a revoked device ends up signed out, keeping its data', () async {
    await signIn();
    await _settle(container);
    server.devices[deviceId]!['deleted'] = true;
    await controller().syncNow();
    expect(state().phase, SyncPhase.signedOut);
    expect(state().connected, isTrue); // Shows "Sign in again".
    expect(tokens.token, isNull);
  });

  test('offline, then back', () async {
    await signIn();
    await _settle(container);
    server.offline = true;
    await controller().syncNow();
    expect(state().phase, SyncPhase.offline);
    server.offline = false;
    await controller().syncNow();
    expect(state().phase, SyncPhase.idle);
  });

  test('signing out revokes this device and forgets the account', () async {
    await signIn();
    await _settle(container);
    await controller().signOut();
    expect(state().connected, isFalse);
    expect(tokens.token, isNull);
    expect(server.devices[deviceId]!['deleted'], isTrue);
    final saved = await SettingsRepository(
      db,
      deviceId: deviceId,
    ).getSyncSettings();
    expect(saved.serverUrl, isNull);
  });

  group('signing out with "remove my tasks"', () {
    late AppTarget? savedTarget;
    late int reloads;

    setUp(() {
      savedTarget = debugAppTargetOverride;
      reloads = 0;
      debugReloadPage = () => reloads++;
    });
    tearDown(() {
      debugAppTargetOverride = savedTarget;
      debugReloadPage = null;
    });

    Future<void> addData() async {
      final tasks = TaskRepository(db, deviceId: deviceId);
      final task = await tasks.createTask(title: 'Private task');
      await tasks.addSubtask(task.id, 'Step');
      final tag = await tasks.findOrCreateTag('home');
      await tasks.setTaskTags(task.id, {tag.id});
      await CategoryRepository(
        db,
        deviceId: deviceId,
      ).createCategory('Work', 0xFF336699);
      await ReminderRepository(
        db,
        deviceId: deviceId,
      ).addAbsolute(task.id, DateTime.utc(2026, 12, 1, 9));
      await PlaceRepository(
        db,
        deviceId: deviceId,
      ).createPlace(name: 'Home', latitude: 52.5, longitude: 13.4);
      await SettingsRepository(
        db,
        deviceId: deviceId,
      ).setLanguage(AppLanguage.ar);
    }

    Future<Map<String, int>> rowCounts() async => {
      for (final table in db.allTables)
        table.actualTableName:
            (await db
                    .customSelect(
                      'SELECT COUNT(*) AS n FROM ${table.actualTableName}',
                    )
                    .getSingle())
                .read<int>('n'),
    };

    test('on the web it empties the database and the stored log, '
        'then reloads the page', () async {
      debugAppTargetOverride = AppTarget.web;
      final store = MemoryKeyValueStore();
      appLog.useStore(store);
      appLog.info('test', 'a line');
      await signIn();
      await _settle(container);
      await addData();
      final before = await rowCounts();
      for (final table in [
        'tasks',
        'subtasks',
        'categories',
        'tags',
        'task_tags',
        'reminders',
        'places',
        'devices',
        'settings',
      ]) {
        expect(before[table], greaterThan(0), reason: table);
      }

      await controller().signOut(removeLocalData: true);
      await pumpEventQueue();

      expect(server.devices[deviceId]!['deleted'], isTrue);
      expect(tokens.token, isNull);
      expect((await rowCounts()).values, everyElement(0));
      expect(store.values, isEmpty);
      expect(reloads, 1);
    });

    test('without it the web keeps everything', () async {
      debugAppTargetOverride = AppTarget.web;
      await signIn();
      await _settle(container);
      await addData();
      await controller().signOut();
      final after = await rowCounts();
      expect(after['tasks'], greaterThan(0));
      expect(after['places'], greaterThan(0));
      expect(reloads, 0);
    });

    test('web sign-out drops the push subscription, even offline', () async {
      debugAppTargetOverride = AppTarget.web;
      await signIn();
      await _settle(container);
      server.offline = true;
      await controller().signOut();
      expect(push.unsubscribes, 1);
      expect(state().connected, isFalse);
    });

    test('native sign-out leaves the push client alone', () async {
      debugAppTargetOverride = AppTarget.linux;
      await signIn();
      await _settle(container);
      await controller().signOut();
      expect(push.unsubscribes, 0);
    });

    test('native apps never remove data on sign-out', () async {
      debugAppTargetOverride = AppTarget.linux;
      await signIn();
      await _settle(container);
      await addData();
      await controller().signOut(removeLocalData: true);
      final after = await rowCounts();
      expect(after['tasks'], greaterThan(0));
      expect(after['settings'], greaterThan(0));
      expect(reloads, 0);
    });
  });

  test('rename and remove devices go through the server', () async {
    await signIn();
    await _settle(container);
    server.devices['other'] = {
      'id': 'other',
      'name': 'Old phone',
      'type': 'ios',
      'lastSeenAt': null,
      'updatedAt': '2026-11-01T10:00:00.000Z',
      'deleted': false,
      'updatedByDevice': null,
    };
    await controller().renameDevice('other', 'Work phone');
    expect((await _deviceNames(db)), containsAll(['My laptop', 'Work phone']));
    await controller().removeDevice('other');
    final live = await (db.select(
      db.devices,
    )..where((d) => d.deleted.not())).get();
    expect(live.map((d) => d.name), ['My laptop']);
  });

  test('the main device: hand it on, take it back with the password', () async {
    await signIn();
    await _settle(container);
    server.devices['other'] = {
      'id': 'other',
      'name': 'iPhone',
      'type': 'ios',
      'lastSeenAt': null,
      'updatedAt': '2026-11-01T10:00:00.000Z',
      'deleted': false,
      'updatedByDevice': null,
    };
    Future<String?> mainId() async => (await (db.select(
      db.devices,
    )..where((d) => d.isMain)).getSingleOrNull())?.id;

    await controller().syncNow();
    expect(await mainId(), deviceId); // The first device to sign in.

    await controller().makeMain('other');
    expect(await mainId(), 'other');
    // No longer main: managing others is refused.
    await expectLater(
      controller().removeDevice('other'),
      throwsA(isA<SyncHttpException>().having((e) => e.status, 'status', 403)),
    );

    await expectLater(
      controller().claimMain('wrong'),
      throwsA(
        isA<SyncHttpException>().having(
          (e) => e.code,
          'code',
          'wrong_password',
        ),
      ),
    );
    expect(state().phase, isNot(SyncPhase.signedOut));
    await controller().claimMain(server.password);
    expect(await mainId(), deviceId);
  });

  test('the banner can be dismissed for good', () async {
    await controller().dismissBanner();
    container.dispose();
    container = await start();
    expect(state().bannerDismissed, isTrue);
  });
}

Future<List<String>> _deviceNames(AppDatabase db) async => [
  for (final d in await db.select(db.devices).get()) d.name,
];

/// Lets pending async work (loading, the first sync) finish.
Future<void> _settle(ProviderContainer container) async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  final controller = container.read(syncControllerProvider.notifier);
  await controller.syncNow();
}
