import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
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
  late TaskRepository tasks;
  late Task task;

  void addWebDevice(
    String id, {
    bool pushEnabled = true,
    String? timeZone = 'Europe/Berlin',
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
    };
  }

  setUpAll(() => initializeDateFormatting('en'));

  setUp(() async {
    server = FakeSyncServer();
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
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue(deviceId),
        deviceTypeProvider.overrideWithValue(DeviceType.linux),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        syncHttpClientProvider.overrideWithValue(server.client),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 28, 10)),
        deviceTimeZoneProvider.overrideWith((ref) async => 'Europe/Berlin'),
        pushPlanDebounceProvider.overrideWithValue(
          const Duration(milliseconds: 20),
        ),
      ],
    );
    container
      ..listen(syncControllerProvider, (_, _) {})
      ..listen(taskEntriesProvider, (_, _) {})
      ..listen(timeRemindersProvider, (_, _) {})
      ..listen(taskTargetsProvider, (_, _) {});
    await Future.wait([
      container.read(taskEntriesProvider.future),
      container.read(timeRemindersProvider.future),
      container.read(taskTargetsProvider.future),
    ]);
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

  test('unchanged data is not uploaded twice', () async {
    addWebDevice('web1');
    await signInAndStart();
    await uploader().uploadNow();
    await uploader().uploadNow();
    expect(server.pushPlanUploads, 1);
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
}
