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
import 'package:taskwise/platform/app_target.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/ui/designs/brutal/shell/adaptive_shell.dart' as brutal;
import 'package:taskwise/ui/designs/lapis/shell/adaptive_shell.dart' as lapis;
import 'package:taskwise/ui/shared/location/map_providers.dart';

class _NoGeocoder implements Geocoder {
  @override
  Future<List<GeocodeResult>> search(String query, {String? language}) async =>
      const [];

  @override
  String get attribution => '';
}

void main() {
  group('availableDesigns / effectiveDesign', () {
    test('the web offers Brutal and Lapis only', () {
      expect(availableDesigns(AppTarget.web), [
        AppDesign.brutal,
        AppDesign.lapis,
      ]);
    });

    test('other targets offer every design', () {
      expect(availableDesigns(AppTarget.linux), AppDesign.values);
      expect(availableDesigns(AppTarget.ios), AppDesign.values);
    });

    test('a design the web lacks shows Brutal', () {
      expect(
        effectiveDesign(AppDesign.classic, AppTarget.web),
        AppDesign.brutal,
      );
      expect(effectiveDesign(AppDesign.slate, AppTarget.web), AppDesign.brutal);
      expect(effectiveDesign(AppDesign.lapis, AppTarget.web), AppDesign.lapis);
      expect(
        effectiveDesign(AppDesign.classic, AppTarget.linux),
        AppDesign.classic,
      );
    });
  });

  Future<Future<void> Function()> pumpWeb(
    WidgetTester tester,
    AppDesign design,
  ) async {
    final savedTarget = debugAppTargetOverride;
    debugAppTargetOverride = AppTarget.web;
    addTearDown(() => debugAppTargetOverride = savedTarget);
    configureIntl();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tester.view
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    final repo = SettingsRepository(db, deviceId: 'test');
    await repo.setLanguage(AppLanguage.en);
    await repo.setDesign(design);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue('test'),
          initialSettingsProvider.overrideWithValue(
            AppSettings(language: AppLanguage.en, design: design),
          ),
          geocoderProvider.overrideWithValue(_NoGeocoder()),
          mapTilesEnabledProvider.overrideWithValue(false),
        ],
        child: const TaskwiseApp(),
      ),
    );
    await tester.pumpAndSettle();
    return () async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
      await db.close();
    };
  }

  testWidgets('a stored Slate design renders Brutal on the web, and Settings '
      'hides what the browser cannot do', (tester) async {
    final close = await pumpWeb(tester, AppDesign.slate);
    expect(find.byType(brutal.AdaptiveShell), findsOneWidget);

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();

    final picker = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('design-'),
    );
    expect(picker, findsNWidgets(2));
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('design-brutal')))
          .selected,
      isTrue,
    );

    await tester.scrollUntilVisible(
      find.text('Web app'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Start when I log in'), findsNothing);
    expect(find.text('Check for updates'), findsNothing);
    expect(find.text('Location debug'), findsNothing);
    expect(find.text('Web app'), findsOneWidget);
    expect(
      find.text("On a shared computer, sign out when you're done."),
      findsOneWidget,
    );
    await close();
  });

  testWidgets('Lapis is kept on the web', (tester) async {
    final close = await pumpWeb(tester, AppDesign.lapis);
    expect(find.byType(lapis.AdaptiveShell), findsOneWidget);
    await close();
  });
}
