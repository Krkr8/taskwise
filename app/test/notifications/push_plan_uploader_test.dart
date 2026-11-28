import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:taskwise/data/app_settings.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/reminder_repository.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise/notifications/device_time_zone.dart';
import 'package:taskwise/notifications/push_plan_uploader.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/sync/sync_controller.dart';
import 'package:taskwise/sync/token_store.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/test_db.dart';
import '../sync/fake_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSyncServer server;
  late AppDatabase db;
  late ProviderContainer container;
  late String deviceId;
  late MemoryTokenStore tokens;
  late DateTime now;
  late TaskRepository tasks;
  late Task task;
  late DeviceType deviceType;
  late String? zone;

  void addWebDevice(
    String id, {
    bool pushEnabled = true,
    String? timeZone = 'Europe/Berlin',
    int? allDayMinutes = 9 * 60,
  }) {
    server.devices[id] = {
      'id': id,
      'name': 'Browser $id',
      'type': 'web',
      'main': false,
      'lastSeenAt': null,
      'updatedAt': '2026-11-01T10:00:00.000Z',
      'deleted': false,
      'updatedByDevice': null,
      'timeZone': ?timeZone,
      if (pushEnabled) 'pushEnabled': true,
      'allDayMinutes': ?allDayMinutes,
    };
  }

  setUpAll(() => initializeDateFormatting('en'));

  Future<ProviderContainer> makeContainer() async {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue(deviceId),
        deviceTypeProvider.overrideWithValue(deviceType),
        tokenStoreProvider.overrideWithValue(tokens),
        syncHttpClientProvider.overrideWithValue(server.client),
        clockProvider.overrideWithValue(() => now),
        deviceTimeZoneProvider.overrideWith((ref) async => zone),
        pushPlanDebounceProvider.overrideWithValue(
          const Duration(milliseconds: 20),
        ),
        pushPlanBackoffProvider.overrideWithValue(
          const Duration(milliseconds: 150),
        ),
      ],
    );
    c
      ..listen(syncControllerProvider, (_, _) {})
      ..listen(taskEntriesProvider, (_, _) {})
      ..listen(timeRemindersProvider, (_, _) {})
      ..listen(taskTargetsProvider, (_, _) {});
    await Future.wait([
      c.read(taskEntriesProvider.future),
      c.read(timeRemindersProvider.future),
      c.read(taskTargetsProvider.future),
    ]);
    return c;
  }

  setUp(() async {
    server = FakeSyncServer();
    deviceType = DeviceType.linux;
    zone = 'Europe/Berlin';
    db = openTestDatabase();
    deviceId = await ensureThisDevice(
      db,
      type: DeviceType.linux,
      name: 'Fedora Laptop',
    );
    tasks = TaskRepository(db, deviceId: deviceId);
    final due = LocalDate.fromDateTime(DateTime(2026, 11, 29));
    task = await tasks.createTask(
      title: 'Pay rent',
      dueDate: due,
      dueTimeMinutes: 9 * 60,
    );
    await ReminderRepository(db, deviceId: deviceId).addRelative(task.id, 30);
    tokens = MemoryTokenStore();
    now = DateTime(2026, 11, 28, 10);
    container = await makeContainer();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> signInAndStart() async {
    await container
        .read(syncControllerProvider.notifier)
        .signIn(
          serverUrl: 'sync.test',
          username: server.username,
          password: server.password,
          deviceName: 'Laptop',
        );
    await container.read(syncControllerProvider.notifier).syncNow();
    container.read(pushPlanUploaderProvider);
  }

  PushPlanUploader uploader() => container.read(pushPlanUploaderProvider);

  test('a subscribed web device in the same time zone gets its plan', () async {
    addWebDevice('web1');
    await signInAndStart();
    await uploader().uploadNow();

    expect(server.pushPlanUploads, 1);
    final items = server.pushPlans['web1']!;
    expect(items, hasLength(1));
    expect(items.single['taskId'], task.id);
    expect(items.single['title'], 'Pay rent');
    expect(
      items.single['fireAt'],
      DateTime(2026, 11, 29, 8, 30).toUtc().millisecondsSinceEpoch,
    );
    expect(items.single['body'], isNotEmpty);
  });

  test('sends this device\'s time zone at login', () async {
    await signInAndStart();
    expect(server.devices[deviceId]!['timeZone'], 'Europe/Berlin');
  });

  test('unchanged data is not uploaded twice by the debounced runs, but '
      'uploadNow always uploads', () async {
    addWebDevice('web1');
    await signInAndStart();
    await uploader().uploadNow();
    expect(server.pushPlanUploads, 1);
    // A sync and a settings change both start debounced runs.
    await container.read(syncControllerProvider.notifier).syncNow();
    await SettingsRepository(
      db,
      deviceId: deviceId,
    ).setTheme(ThemePreference.dark);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(server.pushPlanUploads, 1);
    await uploader().uploadNow();
    expect(server.pushPlanUploads, 2);
  });

  test('signing out and in again forgets the uploaded plans', () async {
    addWebDevice('web1');
    await signInAndStart();
    await uploader().uploadNow();
    expect(server.pushPlanUploads, 1);
    final settings = SettingsRepository(db, deviceId: deviceId);
    expect(await settings.getPushPlanHashes(), isNotEmpty);

    await container.read(syncControllerProvider.notifier).signOut();
    expect(await settings.getPushPlanHashes(), isEmpty);

    // Hashes from before (e.g. another server's) are dropped at sign-in too.
    await settings.setPushPlanHashes({'web1': 'stale'});
    await signInAndStart();
    expect(await settings.getPushPlanHashes(), isNot({'web1': 'stale'}));
    // The debounced run uploads the unchanged plan again.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(server.pushPlanUploads, 2);
  });

  test('a web device in a zone with the same clock gets its plan', () async {
    addWebDevice('paris', timeZone: 'Europe/Paris');
    await signInAndStart();
    await uploader().uploadNow();
    expect(server.pushPlans.keys, ['paris']);
  });

  test(
    'a server from before web reminders (404 not_found) stops uploads',
    () async {
      addWebDevice('web1');
      server.pushMissing = true;
      await signInAndStart();
      await uploader().uploadNow();
      await uploader().uploadNow();
      expect(server.pushPlanUploads, 0);
      expect(
        server.requests.where((r) => r == 'PUT /push/plan/web1'),
        hasLength(1),
      );
      expect(container.read(syncControllerProvider).message, isNull);
    },
  );

  test('a 404 for one device from a server with push only skips it', () async {
    addWebDevice('gone');
    addWebDevice('web1');
    server.pushPlanNotFound.add('gone');
    await signInAndStart();
    await uploader().uploadNow();
    expect(server.pushPlans.keys, ['web1']);
    server.pushPlanNotFound.clear();
    await uploader().uploadNow();
    expect(server.pushPlans.keys, containsAll(['gone', 'web1']));
  });

  test('no run while a sync is in progress; it runs after the sync', () async {
    addWebDevice('web1');
    await signInAndStart();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(server.pushPlanUploads, 1);

    final release = Completer<void>();
    server.onPush = () => release.future;
    await tasks.saveTask(task.copyWith(title: 'Pay rent today'));
    final sync = container.read(syncControllerProvider.notifier).syncNow();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(container.read(syncControllerProvider).phase, SyncPhase.syncing);
    expect(server.pushPlanUploads, 1, reason: 'held back during the sync');

    release.complete();
    await sync;
    server.onPush = null;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(server.pushPlanUploads, 2);
    expect(server.pushPlans['web1']!.single['title'], 'Pay rent today');
  });

  test('a failed upload of this web device\'s own plan is reported', () async {
    container.dispose();
    deviceType = DeviceType.web;
    container = await makeContainer();
    await signInAndStart();
    server.devices[deviceId]!['pushEnabled'] = true;
    server.pushPlanFailures = 1;
    await uploader().uploadNow();
    expect(container.read(ownPushPlanFailedProvider), isTrue);
    await uploader().uploadNow();
    expect(server.pushPlans.keys, [deviceId]);
    expect(container.read(ownPushPlanFailedProvider), isFalse);
  });

  test('a task edit uploads a new plan', () async {
    addWebDevice('web1');
    await signInAndStart();
    await uploader().uploadNow();
    await tasks.saveTask(task.copyWith(title: 'Pay rent today'));
    // The debounced listener does it, without uploadNow.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(server.pushPlanUploads, 2);
    expect(server.pushPlans['web1']!.single['title'], 'Pay rent today');
  });

  test('a web device without push, or in another zone, gets nothing', () async {
    addWebDevice('off', pushEnabled: false);
    addWebDevice('far', timeZone: 'Asia/Tokyo');
    addWebDevice('unknown', timeZone: null);
    await signInAndStart();
    await uploader().uploadNow();
    expect(server.pushPlanUploads, 0);
  });

  test('a device that never plans for non-web devices', () async {
    addWebDevice('phone');
    server.devices['phone'] = {
      ...server.devices['phone']!,
      'type': 'ios',
      'pushEnabled': true,
      'timeZone': 'Europe/Berlin',
    };
    await signInAndStart();
    await uploader().uploadNow();
    expect(server.pushPlanUploads, 0);
  });

  test('push not configured stops uploads without a sync error', () async {
    addWebDevice('web1');
    server.pushConfigured = false;
    await signInAndStart();
    await uploader().uploadNow();
    server.pushConfigured = true;
    await uploader().uploadNow();
    expect(server.pushPlanUploads, 0);
    expect(container.read(syncControllerProvider).phase, SyncPhase.idle);
    expect(container.read(syncControllerProvider).message, isNull);
  });

  test('the plan is uploaded after sync on its own', () async {
    addWebDevice('web1');
    await signInAndStart();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(server.pushPlanUploads, 1);
  });

  test('hashes survive a restart until the devices are loaded', () async {
    addWebDevice('web1');
    await signInAndStart();
    await uploader().uploadNow();
    expect(server.pushPlanUploads, 1);
    final stored = await SettingsRepository(
      db,
      deviceId: deviceId,
    ).getPushPlanHashes();
    expect(stored, isNotEmpty);
    container.dispose();

    // Restart while offline: the engine exists but has no device list.
    server.offline = true;
    container = await makeContainer();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    container.read(pushPlanUploaderProvider);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(
      await SettingsRepository(db, deviceId: deviceId).getPushPlanHashes(),
      stored,
    );

    // Back online: devices load, nothing changed, nothing is uploaded.
    server.offline = false;
    await container.read(syncControllerProvider.notifier).syncNow();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(server.pushPlanUploads, 1);
    expect(
      await SettingsRepository(db, deviceId: deviceId).getPushPlanHashes(),
      stored,
    );
  });

  test('a change inside the backoff window is retried afterwards', () async {
    addWebDevice('web1');
    await signInAndStart();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.pushPlanUploads, 1);

    server.pushPlanFailures = 1;
    await tasks.saveTask(task.copyWith(title: 'Pay rent today'));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(server.pushPlanUploads, 1, reason: 'the upload failed');

    // The clock passes the backoff; the one-shot retry uploads, with no
    // further change to trigger it.
    now = now.add(const Duration(minutes: 10));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(server.pushPlanUploads, 2);
    expect(server.pushPlans['web1']!.single['title'], 'Pay rent today');
  });

  group('all-day reminders', () {
    late Task allDay;

    setUp(() async {
      allDay = await tasks.createTask(
        title: 'Call mum',
        dueDate: LocalDate.fromDateTime(DateTime(2026, 11, 30)),
      );
      await ReminderRepository(
        db,
        deviceId: deviceId,
      ).addRelative(allDay.id, 0);
    });

    int? allDayFireAt(String webId) =>
        server.pushPlans[webId]!
                .where((i) => i['taskId'] == allDay.id)
                .single['fireAt']
            as int?;

    test('a web device\'s plan uses the all-day time it reported', () async {
      addWebDevice('web1', allDayMinutes: 7 * 60);
      await signInAndStart();
      await uploader().uploadNow();
      expect(
        allDayFireAt('web1'),
        DateTime(2026, 11, 30, 7).toUtc().millisecondsSinceEpoch,
      );
    });

    test('a web device that reported no all-day time is skipped', () async {
      addWebDevice('web1', allDayMinutes: null);
      await signInAndStart();
      await uploader().uploadNow();
      expect(server.pushPlanUploads, 0);
    });

    test('a web device reports its all-day time at login and on change, and '
        'plans for itself with its own setting', () async {
      container.dispose();
      deviceType = DeviceType.web;
      container = await makeContainer();
      await container
          .read(syncControllerProvider.notifier)
          .signIn(
            serverUrl: 'sync.test',
            username: server.username,
            password: server.password,
            deviceName: 'Browser',
          );
      expect(server.devices[deviceId]!['allDayMinutes'], 9 * 60);
      await container.read(syncControllerProvider.notifier).syncNow();

      await SettingsRepository(
        db,
        deviceId: deviceId,
      ).setAllDayReminderMinutes(8 * 60);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(server.devices[deviceId]!['allDayMinutes'], 8 * 60);
      expect(server.requests.where((r) => r == 'PATCH /devices/$deviceId'), [
        'PATCH /devices/$deviceId',
      ]);

      // Its own plan: its own setting, whatever the server lists.
      server.devices[deviceId]!['pushEnabled'] = true;
      server.devices[deviceId]!['allDayMinutes'] = 6 * 60;
      await container.read(syncControllerProvider.notifier).syncNow();
      container.read(pushPlanUploaderProvider);
      await uploader().uploadNow();
      expect(
        allDayFireAt(deviceId),
        DateTime(2026, 11, 30, 8).toUtc().millisecondsSinceEpoch,
      );
    });
  });

  test('a device signed in before 1.4.0 (no new login) reports its time '
      'zone on the first device listing, and again after it changes', () async {
    // Signed in by 1.3.0: the server has no time zone for it.
    zone = null;
    container.dispose();
    container = await makeContainer();
    await signInAndStart();
    expect(server.devices[deviceId]!['timeZone'], isNull);
    container.dispose();
    server.requests.clear();

    // Updated to 1.4.0: the next start syncs with the saved token.
    zone = 'Europe/Berlin';
    container = await makeContainer();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await container.read(syncControllerProvider.notifier).syncNow();
    expect(server.devices[deviceId]!['timeZone'], 'Europe/Berlin');
    expect(server.requests, isNot(contains('POST /auth/login')));
    expect(server.requests, contains('PATCH /devices/$deviceId'));

    // Travelled: the zone is read again (on resume) and sent.
    zone = 'Asia/Baghdad';
    container.invalidate(deviceTimeZoneProvider);
    await container.read(syncControllerProvider.notifier).syncNow();
    expect(server.devices[deviceId]!['timeZone'], 'Asia/Baghdad');
  });
}
