import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/app_settings.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise/sync/sync_api.dart';
import 'package:taskwise/sync/sync_engine.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/test_db.dart';
import 'fake_server.dart';

/// One app install signed in to [server].
class _Device {
  _Device._(this.db, this.id, this.engine, this.clock);

  static Future<_Device> signIn(
    FakeSyncServer server,
    String name, {
    FakeClock? clock,
    int pushBatch = SyncApi.maxPushChanges,
    int pullLimit = 500,
  }) async {
    final c = clock ?? FakeClock(DateTime.utc(2026, 11, 2, 9));
    final db = openTestDatabase();
    final id = await ensureThisDevice(
      db,
      type: DeviceType.linux,
      name: name,
      clock: c.call,
    );
    final api = SyncApi(baseUrl: 'https://sync.test', client: server.client);
    final login = await api.login(
      username: server.username,
      password: server.password,
      deviceId: id,
      deviceName: name,
      deviceType: DeviceType.linux,
    );
    final engine = SyncEngine(
      db: db,
      api: api.withToken(login.token),
      deviceId: id,
      pushBatch: pushBatch,
      pullLimit: pullLimit,
    );
    return _Device._(db, id, engine, c);
  }

  final AppDatabase db;
  final String id;
  final SyncEngine engine;
  final FakeClock clock;

  TaskRepository get tasks =>
      TaskRepository(db, deviceId: id, clock: clock.call);
  SettingsRepository get settings =>
      SettingsRepository(db, deviceId: id, clock: clock.call);

  Future<List<Task>> liveTasks() async => [
    for (final e in await tasks.watchEntries().first) e.task,
  ];

  Future<int> outboxSize() async =>
      (await db.select(db.syncOutbox).get()).length;
}

void main() {
  late FakeSyncServer server;
  late _Device laptop;
  late _Device phone;

  setUp(() async {
    server = FakeSyncServer();
    laptop = await _Device.signIn(server, 'Laptop');
    phone = await _Device.signIn(server, 'Phone');
  });

  tearDown(() async {
    await laptop.db.close();
    await phone.db.close();
  });

  test('a task with subtasks and tags reaches the other device', () async {
    final task = await laptop.tasks.createTask(title: 'Buy milk');
    await laptop.tasks.addSubtask(task.id, 'Check the fridge');
    final tag = await laptop.tasks.findOrCreateTag('errands');
    await laptop.tasks.setTaskTags(task.id, {tag.id});

    final report = await laptop.engine.sync();
    expect(report.pushed, 4); // task, subtask, tag, task-tag link
    expect(await laptop.outboxSize(), 0);

    await phone.engine.sync();
    final entries = await phone.tasks.watchEntries().first;
    expect(entries.single.task.title, 'Buy milk');
    expect(entries.single.subtaskCount, 1);
    expect(entries.single.tagIds, {tag.id});
    // Pulled rows aren't pushed back.
    expect(await phone.outboxSize(), 0);
    expect(entries.single.task.updatedByDevice, laptop.id);
  });

  test('edits and deletes sync both ways', () async {
    final task = await laptop.tasks.createTask(title: 'Draft');
    await laptop.engine.sync();
    await phone.engine.sync();

    phone.clock.advance();
    await phone.tasks.saveTask(
      (await phone.tasks.getTask(task.id))!.copyWith(title: 'Final'),
    );
    await phone.engine.sync();
    await laptop.engine.sync();
    expect((await laptop.liveTasks()).single.title, 'Final');

    laptop.clock.advance(const Duration(minutes: 5));
    await laptop.tasks.deleteTask(task.id);
    await laptop.engine.sync();
    await phone.engine.sync();
    expect(await phone.liveTasks(), isEmpty);
  });

  test('the later edit wins, whichever device syncs first', () async {
    final task = await laptop.tasks.createTask(title: 'v0');
    await laptop.engine.sync();
    await phone.engine.sync();

    // Both edit while apart; the phone's edit is later.
    laptop.clock.advance(const Duration(minutes: 1));
    await laptop.tasks.saveTask(
      (await laptop.tasks.getTask(task.id))!.copyWith(title: 'laptop'),
    );
    phone.clock.advance(const Duration(minutes: 2));
    await phone.tasks.saveTask(
      (await phone.tasks.getTask(task.id))!.copyWith(title: 'phone'),
    );

    // The phone syncs first; the laptop's older edit is then stale.
    await phone.engine.sync();
    await laptop.engine.sync();
    await phone.engine.sync();
    expect((await laptop.liveTasks()).single.title, 'phone');
    expect((await phone.liveTasks()).single.title, 'phone');
    expect(server.record('task', task.id)!['title'], 'phone');
  });

  test(
    'a pulled older version doesn\'t overwrite an unpushed local edit',
    () async {
      final task = await laptop.tasks.createTask(title: 'v0');
      await laptop.engine.sync();
      await phone.engine.sync();

      laptop.clock.advance(const Duration(minutes: 1));
      await laptop.tasks.saveTask(
        (await laptop.tasks.getTask(task.id))!.copyWith(title: 'laptop'),
      );
      await laptop.engine.sync();

      phone.clock.advance(const Duration(minutes: 2));
      await phone.tasks.saveTask(
        (await phone.tasks.getTask(task.id))!.copyWith(title: 'phone'),
      );
      // Pull only: the server's "laptop" version is older than the local edit.
      await phone.engine.pull();
      expect((await phone.liveTasks()).single.title, 'phone');
      expect(await phone.outboxSize(), 1);
      await phone.engine.sync();
      expect(server.record('task', task.id)!['title'], 'phone');
    },
  );

  test('pushes in batches and pulls in pages', () async {
    server = FakeSyncServer();
    final a = await _Device.signIn(server, 'A', pushBatch: 2);
    final b = await _Device.signIn(server, 'B', pullLimit: 2);
    for (var i = 0; i < 5; i++) {
      await a.tasks.createTask(title: 'Task $i');
    }
    expect((await a.engine.sync()).pushed, 5);
    expect(server.requests.where((r) => r == 'POST /sync'), hasLength(3));

    server.requests.clear();
    expect((await b.engine.sync()).pulled, 5);
    // Pages of 2, 2 and 1.
    expect(server.requests.where((r) => r == 'GET /sync'), hasLength(3));
    expect((await b.settings.getSyncSettings()).seq, server.seq);
    // Nothing new: one more pull, nothing applied.
    expect((await b.engine.sync()).pulled, 0);
    await a.db.close();
    await b.db.close();
  });

  test('an edit made during a push stays queued', () async {
    final task = await laptop.tasks.createTask(title: 'v1');
    server.onPush = () async {
      server.onPush = null;
      laptop.clock.advance();
      await laptop.tasks.saveTask(
        (await laptop.tasks.getTask(task.id))!.copyWith(title: 'v2'),
      );
    };
    await laptop.engine.push();
    expect(server.record('task', task.id)!['title'], 'v1');
    expect(await laptop.outboxSize(), 1);
    await laptop.engine.push();
    expect(server.record('task', task.id)!['title'], 'v2');
    expect(await laptop.outboxSize(), 0);
  });

  test('synced settings travel, device-only ones don\'t', () async {
    await laptop.settings.setWeekStart(WeekStart.monday);
    await laptop.settings.setTheme(ThemePreference.dark);
    await laptop.engine.sync();
    await phone.engine.sync();
    final settings = await phone.settings.loadSettings();
    expect(settings.weekStart, WeekStart.monday);
    expect(settings.theme, ThemePreference.system);
  });

  test('410 starts over and drops records the server purged', () async {
    final kept = await laptop.tasks.createTask(title: 'kept');
    await laptop.engine.sync();
    await phone.engine.sync();
    // A record the server purged while the phone was away...
    final purged = await phone.tasks.createTask(title: 'purged');
    await phone.db.customStatement('DELETE FROM sync_outbox');
    // ...and one still waiting to be pushed.
    final unpushed = await phone.tasks.createTask(title: 'unpushed');

    server.requireResync = true;
    await phone.engine.pull();
    final ids = {for (final t in await phone.liveTasks()) t.id};
    expect(ids, {kept.id, unpushed.id});
    expect(ids, isNot(contains(purged.id)));
  });

  test('errors come through: signed out and offline', () async {
    server.devices[phone.id]!['deleted'] = true;
    await expectLater(
      phone.engine.sync(),
      throwsA(isA<SyncHttpException>().having((e) => e.status, 'status', 401)),
    );
    server.offline = true;
    await expectLater(
      laptop.engine.sync(),
      throwsA(isA<SyncNetworkException>()),
    );
  });

  test('the device list comes from the server', () async {
    await laptop.engine.sync();
    final names = [
      for (final d in await laptop.db.select(laptop.db.devices).get()) d.name,
    ];
    expect(names, unorderedEquals(['Laptop', 'Phone']));
  });

  test('server URLs are normalised', () {
    expect(
      SyncApi.normalizeServerUrl(' taskwise.vercel.app/ ').toString(),
      'https://taskwise.vercel.app',
    );
    expect(
      SyncApi.normalizeServerUrl('http://localhost:8787/api/v1').toString(),
      'http://localhost:8787',
    );
    expect(() => SyncApi.normalizeServerUrl('https://'), throwsFormatException);
  });
}
