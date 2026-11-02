// Two app devices syncing through the real TypeScript server (server/).
// Skipped unless TASKWISE_TEST_SERVER is set; run it with:
//
//   (cd server && DATABASE_URL=:memory: SETUP_SECRET=live-test-secret \
//      PORT=8787 npm run dev) &
//   TASKWISE_TEST_SERVER=http://localhost:8787 \
//     TASKWISE_TEST_SETUP_SECRET=live-test-secret flutter test --tags live
//
// CI runs it against a fresh in-memory server. The test creates the account
// if it doesn't exist yet.
@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise/sync/sync_api.dart';
import 'package:taskwise/sync/sync_engine.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/test_db.dart';

final _server = Platform.environment['TASKWISE_TEST_SERVER'];
final _secret = Platform.environment['TASKWISE_TEST_SETUP_SECRET'] ?? '';
const _user = 'live-test';
const _password = 'live test password';

class _Device {
  _Device(this.db, this.id, this.engine, this.clock);

  final AppDatabase db;
  final String id;
  final SyncEngine engine;
  final FakeClock clock;

  TaskRepository get tasks =>
      TaskRepository(db, deviceId: id, clock: clock.call);

  Future<Task?> task(String id) => tasks.getTask(id);
}

Future<_Device> _signIn(String name, DateTime start) async {
  final clock = FakeClock(start);
  final db = openTestDatabase();
  final id = await ensureThisDevice(
    db,
    type: DeviceType.linux,
    name: name,
    clock: clock.call,
  );
  final api = SyncApi(baseUrl: _server!);
  final login = await api.login(
    username: _user,
    password: _password,
    deviceId: id,
    deviceName: name,
    deviceType: DeviceType.linux,
  );
  return _Device(
    db,
    id,
    SyncEngine(db: db, api: api.withToken(login.token), deviceId: id),
    clock,
  );
}

void main() {
  setUpAll(() async {
    final server = _server;
    if (server == null) return;
    final api = SyncApi(baseUrl: server);
    await api.health();
    try {
      await api.setup(
        setupSecret: _secret,
        username: _user,
        password: _password,
      );
    } on SyncHttpException catch (e) {
      if (e.code != 'conflict') rethrow; // Already set up by an earlier run.
    }
  });

  test('two devices stay in step through the real server', () async {
    // Use "now" so records are newer than any from earlier runs.
    final start = DateTime.now().toUtc();
    final laptop = await _signIn('Live laptop', start);
    final phone = await _signIn('Live phone', start);

    // Create on the laptop, with a subtask, a tag, a reminder.
    final t = await laptop.tasks.createTask(
      title: 'Live task',
      dueDate: LocalDate(2026, 12, 1),
      dueTimeMinutes: 600,
    );
    await laptop.tasks.addSubtask(t.id, 'Step one');
    final tag = await laptop.tasks.findOrCreateTag('live');
    await laptop.tasks.setTaskTags(t.id, {tag.id});
    await laptop.engine.sync();

    await phone.engine.sync();
    final entry = (await phone.tasks.watchEntries().first).firstWhere(
      (e) => e.task.id == t.id,
    );
    expect(entry.task.title, 'Live task');
    expect(entry.task.dueTimeMinutes, 600);
    expect(entry.subtaskCount, 1);
    expect(entry.tagIds, {tag.id});

    // Limit it to the phone, from the phone.
    phone.clock.advance();
    await phone.tasks.setTaskTargets(t.id, all: false, deviceIds: {phone.id});
    await phone.engine.sync();
    await laptop.engine.sync();
    expect((await laptop.task(t.id))!.notifyAllDevices, isFalse);
    expect((await laptop.tasks.watchAllTaskTargets().first)[t.id], {phone.id});

    // Concurrent edits: the later one wins on both.
    laptop.clock.advance(const Duration(minutes: 1));
    await laptop.tasks.saveTask(
      (await laptop.task(t.id))!.copyWith(title: 'From laptop'),
    );
    phone.clock.advance(const Duration(minutes: 2));
    await phone.tasks.saveTask(
      (await phone.task(t.id))!.copyWith(title: 'From phone'),
    );
    await laptop.engine.sync();
    await phone.engine.sync();
    await laptop.engine.sync();
    expect((await laptop.task(t.id))!.title, 'From phone');
    expect((await phone.task(t.id))!.title, 'From phone');

    // Synced settings.
    laptop.clock.advance(const Duration(minutes: 3));
    await SettingsRepository(
      laptop.db,
      deviceId: laptop.id,
      clock: laptop.clock.call,
    ).setWeekStart(WeekStart.monday);
    await laptop.engine.sync();
    await phone.engine.sync();
    expect(
      (await SettingsRepository(
        phone.db,
        deviceId: phone.id,
      ).loadSettings()).weekStart,
      WeekStart.monday,
    );

    // Delete on the phone.
    phone.clock.advance(const Duration(minutes: 4));
    await phone.tasks.deleteTask(t.id);
    await phone.engine.sync();
    await laptop.engine.sync();
    expect((await laptop.task(t.id))!.deleted, isTrue);

    // Revoking the phone stops it.
    await laptop.engine.api.revokeDevice(phone.id);
    await expectLater(
      phone.engine.sync(),
      throwsA(isA<SyncHttpException>().having((e) => e.status, 'status', 401)),
    );

    await laptop.db.close();
    await phone.db.close();
  }, skip: _server == null ? 'Set TASKWISE_TEST_SERVER to run' : false);
}
