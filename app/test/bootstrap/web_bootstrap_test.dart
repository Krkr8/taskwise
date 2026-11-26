import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart'
    show WasmStorageImplementation;
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/assistant/assistant_platform.dart';
import 'package:taskwise/bootstrap.dart';
import 'package:taskwise/data/storage_status.dart';
import 'package:taskwise/location/location_platform.dart';
import 'package:taskwise/logging/app_log.dart';
import 'package:taskwise/notifications/notifier.dart';
import 'package:taskwise/platform/app_target.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

void main() {
  late AppTarget? saved;
  setUp(() {
    saved = debugAppTargetOverride;
    debugAppTargetOverride = AppTarget.web;
  });
  tearDown(() => debugAppTargetOverride = saved);

  test('starts as a web device with the native services off', () async {
    final boot = await AppBootstrap.start(executor: NativeDatabase.memory());
    addTearDown(boot.db.close);

    expect(boot.deviceType, DeviceType.web);
    expect(boot.update.enabled, isFalse);
    expect(boot.update.installer, isNull);
    expect(boot.notifier, isA<NoopNotifier>());
    expect(boot.location, isA<NoLocationPlatform>());
    expect(boot.assistant, isA<NoAssistantPlatform>());
    expect(boot.storageStatus, StorageStatus.persistent);
    // No log file in the browser.
    expect(appLog.file, isNull);
    // This device was stored with a browser name.
    final devices = await boot.db.select(boot.db.devices).get();
    expect(devices.single.id, boot.deviceId);
    expect(devices.single.name, 'Browser on device');
  });

  test('only the in-memory database counts as temporary storage', () {
    for (final storage in WasmStorageImplementation.values) {
      expect(
        storageStatusFor(storage),
        storage == WasmStorageImplementation.inMemory
            ? StorageStatus.temporary
            : StorageStatus.persistent,
        reason: storage.name,
      );
    }
  });
}
