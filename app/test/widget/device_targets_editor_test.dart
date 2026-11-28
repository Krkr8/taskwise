import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise/l10n/app_localizations.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/sync/sync_controller.dart';
import 'package:taskwise/ui/shared/tasks/device_targets_editor.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/test_db.dart';

/// The server listed [devices] (null: not listed yet).
class _Listed extends SyncController {
  _Listed(this.devices);

  final List<Device>? devices;

  @override
  SyncState build() => SyncState(loaded: true, serverDevices: devices);
}

Device _web({required bool pushEnabled}) => Device(
  id: 'browser',
  name: 'Chrome on Linux',
  type: DeviceType.web,
  updatedAt: DateTime.utc(2026, 11, 27),
  pushEnabled: pushEnabled,
);

void main() {
  for (final (locale, browser, thisOne, listed) in [
    (
      'en',
      'Chrome on Linux (notifications off)',
      'Fedora Laptop (This device)',
      [_web(pushEnabled: false)],
    ),
    (
      'ar',
      'Chrome on Linux (الإشعارات متوقفة)',
      'Fedora Laptop (هذا الجهاز)',
      [_web(pushEnabled: false)],
    ),
    // Subscribed: just its name.
    (
      'en',
      'Chrome on Linux',
      'Fedora Laptop (This device)',
      [_web(pushEnabled: true)],
    ),
    // Not listed by the server yet: nothing is claimed.
    ('en', 'Chrome on Linux', 'Fedora Laptop (This device)', null),
  ]) {
    testWidgets('"Notify on" marks browsers without notifications: '
        '$browser ($locale)', (tester) async {
      final db = openTestDatabase();
      late Task task;
      late String deviceId;
      await tester.runAsync(() async {
        deviceId = await ensureThisDevice(
          db,
          type: DeviceType.linux,
          name: 'Fedora Laptop',
        );
        final at = DateTime.utc(2026, 11, 27);
        for (final (id, name, type) in [
          ('browser', 'Chrome on Linux', DeviceType.web),
          ('phone', 'iPhone', DeviceType.ios),
        ]) {
          await db
              .into(db.devices)
              .insert(
                DevicesCompanion.insert(
                  id: id,
                  name: name,
                  type: type,
                  updatedAt: at,
                  updatedByDevice: Value(id),
                ),
              );
        }
        task = await TaskRepository(
          db,
          deviceId: deviceId,
        ).createTask(title: 'Call mum');
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            deviceIdProvider.overrideWithValue(deviceId),
            syncControllerProvider.overrideWith(() => _Listed(listed)),
          ],
          child: MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DeviceTargetsEditor(task: task)),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }

      expect(find.widgetWithText(FilterChip, browser), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'iPhone'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, thisOne), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
      await db.close();
    });
  }
}
