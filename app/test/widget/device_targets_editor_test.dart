import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise/l10n/app_localizations.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/ui/shared/tasks/device_targets_editor.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/test_db.dart';

void main() {
  for (final (locale, browser, phone, thisOne) in [
    (
      'en',
      'Chrome on Linux (no reminders yet)',
      'iPhone',
      'Fedora Laptop (This device)',
    ),
    (
      'ar',
      'Chrome on Linux (لا تذكيرات بعد)',
      'iPhone',
      'Fedora Laptop (هذا الجهاز)',
    ),
  ]) {
    testWidgets('"Notify on" marks browsers as having no reminders yet '
        '($locale)', (tester) async {
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
      expect(find.widgetWithText(FilterChip, phone), findsOneWidget);
      expect(find.widgetWithText(FilterChip, thisOne), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
      await db.close();
    });
  }
}
