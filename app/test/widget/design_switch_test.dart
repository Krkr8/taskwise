// Switching designs in Settings: every design shows its main screens without
// errors, and the choice is saved for this device.
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/app.dart';
import 'package:taskwise/data/app_settings.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/location/geocoder.dart';
import 'package:taskwise/main.dart' show configureIntl;
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/ui/shared/location/map_providers.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

final _now = DateTime(2026, 10, 20, 9);

void main() {
  for (final size in [const Size(1280, 800), const Size(390, 844)]) {
    testWidgets('every design works at ${size.width.toInt()} px wide', (
      tester,
    ) async {
      configureIntl();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final db = AppDatabase(NativeDatabase.memory());
      final settings = SettingsRepository(db, deviceId: 'test');
      await settings.setLanguage(AppLanguage.en);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            deviceIdProvider.overrideWithValue('test'),
            clockProvider.overrideWithValue(() => _now),
            todayProvider.overrideWithValue(LocalDate.fromDateTime(_now)),
            initialSettingsProvider.overrideWithValue(
              const AppSettings(language: AppLanguage.en),
            ),
            geocoderProvider.overrideWithValue(_NoGeocoder()),
            mapTilesEnabledProvider.overrideWithValue(false),
          ],
          child: const TaskwiseApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final task = await container
          .read(taskRepositoryProvider)
          .createTask(
            title: 'Water the plants',
            dueDate: LocalDate(2026, 10, 20),
          );
      expect(
        container.read(appSettingsProvider).design,
        AppDesign.brutal,
        reason: 'Brutal is the default design',
      );

      for (final design in AppDesign.values) {
        // Pick it in Settings, like the user would.
        container
            .read(shellTabProvider.notifier)
            .select(ShellTabNotifier.settings);
        await tester.pumpAndSettle();
        final chip = find.byKey(ValueKey('design-${design.name}'));
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();

        expect((await settings.loadSettings()).design, design);
        expect(
          tester.widget<ChoiceChip>(chip).selected,
          isTrue,
          reason: '${design.name} shows as chosen',
        );

        // Backup and About sit at the end of every Settings page.
        final settingsList = find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('View logs'),
          300,
          scrollable: settingsList,
        );
        expect(find.text('Import from a file'), findsOneWidget);
        expect(find.textContaining('Taskwise 0.'), findsOneWidget);
        // Back to the top, where the design picker is.
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('design-classic')),
          -300,
          scrollable: settingsList,
        );

        // Tasks, a task, the calendar.
        container
            .read(shellTabProvider.notifier)
            .select(ShellTabNotifier.tasks);
        await tester.pumpAndSettle();
        expect(find.text('Water the plants'), findsWidgets);
        container.read(openTaskRequestProvider.notifier).request(task.id);
        await tester.pumpAndSettle();
        expect(find.text('Water the plants'), findsWidgets);
        // Phones show the task full-screen: go back to the shell.
        tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .popUntil((route) => route.isFirst);
        await tester.pumpAndSettle();
        container.read(selectedTaskIdProvider.notifier).select(null);
        container.read(shellTabProvider.notifier).select(1);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: design.name);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
      await db.close();
    });
  }
}

class _NoGeocoder implements Geocoder {
  @override
  String get attribution => 'test';

  @override
  Future<List<GeocodeResult>> search(String query, {String? language}) async =>
      [];
}
