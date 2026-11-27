import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/logging/app_log.dart';
import 'package:taskwise/version.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('applog'));
  tearDown(() => dir.delete(recursive: true));

  test('keeps only the newest lines in memory', () {
    final log = AppLog(memoryLines: 3);
    for (var i = 0; i < 5; i++) {
      log.info('test', 'line $i');
    }
    expect(log.entries.map((e) => e.message), ['line 2', 'line 3', 'line 4']);
  });

  test('writes to a file, including lines from before it was opened', () async {
    final log = AppLog()..info('test', 'early');
    await log.open(dir);
    log.warning('sync', 'offline: no network');
    final text = await log.readAll();
    expect(text, contains('[test] early'));
    expect(text, contains('WARNING [sync] offline: no network'));
  });

  test('rotates the file when it grows too big', () async {
    final log = AppLog(maxFileBytes: 200);
    await log.open(dir);
    for (var i = 0; i < 20; i++) {
      log.info('test', 'line number $i with some padding text');
    }
    expect(File('${dir.path}/taskwise.1.log').existsSync(), isTrue);
    expect(File('${dir.path}/taskwise.log').lengthSync(), lessThan(400));
    final text = await log.readAll();
    expect(text, contains('line number 19'));
  });

  test('clear empties memory and disk', () async {
    final log = AppLog();
    await log.open(dir);
    log.info('test', 'something');
    await log.clear();
    expect(log.entries, isEmpty);
    expect(await log.readAll(), isEmpty);
  });

  group('browser storage', () {
    test('keeps the newest lines and loads them at the next start', () async {
      final store = MemoryKeyValueStore();
      final log = AppLog(memoryLines: 3)..info('test', 'before');
      log.useStore(store);
      for (var i = 0; i < 4; i++) {
        log.warning('sync', 'line $i');
      }
      await pumpEventQueue();
      expect(store.values.keys, [AppLog.storeKey]);

      // A reload: a new log reads what the last one kept.
      final next = AppLog(memoryLines: 3)..info('app', 'started');
      next.useStore(store);
      expect(next.entries.map((e) => e.message), [
        'line 2',
        'line 3',
        'started',
      ]);
      final loaded = next.entries.first;
      final original = log.entries[1];
      expect(loaded.level, LogLevel.warning);
      expect(loaded.tag, 'sync');
      expect(loaded.time, original.time);
      expect(await next.readAll(), contains('WARNING [sync] line 2'));
    });

    test('clear empties the stored lines too', () async {
      final store = MemoryKeyValueStore();
      final log = AppLog()..useStore(store);
      log.info('test', 'something');
      await pumpEventQueue();
      await log.clear();
      await pumpEventQueue();
      expect((AppLog()..useStore(store)).entries, isEmpty);
    });

    test('forgetStored removes the stored lines and stops saving', () async {
      final store = MemoryKeyValueStore();
      final log = AppLog()..useStore(store);
      log.info('test', 'something');
      log.forgetStored(); // before the scheduled save runs
      log.info('sync', 'signed out');
      await pumpEventQueue();
      expect(store.values, isEmpty);
      expect(log.entries.map((e) => e.message), ['signed out']);
    });

    test('ignores stored lines it cannot read', () {
      final store = MemoryKeyValueStore()
        ..values[AppLog.storeKey] = '{not json';
      final log = AppLog()..useStore(store);
      expect(log.entries, isEmpty);
      log.info('test', 'still logs');
      expect(log.entries.single.message, 'still logs');
    });

    test('a store that fails does not stop the log', () async {
      final log = AppLog()..useStore(_FailingStore());
      log.info('test', 'still logs');
      await pumpEventQueue();
      expect(log.entries.single.message, 'still logs');
    });
  });

  test('errors nobody caught are logged', () {
    final log = AppLog();
    final savedFlutter = FlutterError.onError;
    final savedPlatform = PlatformDispatcher.instance.onError;
    addTearDown(() => PlatformDispatcher.instance.onError = savedPlatform);
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = savedFlutter);
    installErrorLogging(log);
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError('boom'),
        stack: StackTrace.current,
      ),
    );
    expect(log.entries.single.level, LogLevel.error);
    expect(log.entries.single.message, contains('StateError'));
  });

  test('appVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version: ([\d.]+)\+',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(appVersion, version);
  });
}

class _FailingStore implements KeyValueStore {
  @override
  String? read(String key) => throw StateError('no storage');

  @override
  void write(String key, String value) => throw StateError('quota');

  @override
  void remove(String key) => throw StateError('no storage');
}
