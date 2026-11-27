import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/app.dart';
import 'package:taskwise/data/app_settings.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise/location/geocoder.dart';
import 'package:taskwise/main.dart' show configureIntl;
import 'package:taskwise/platform/app_target.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/ui/shared/location/map_providers.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

class _NoGeocoder implements Geocoder {
  @override
  Future<List<GeocodeResult>> search(String query, {String? language}) async =>
      const [];

  @override
  String get attribution => '';
}

/// The fonts each web design bundles for text (app/pubspec.yaml), and the
/// icon fonts. Text in any other font (the engine's default, Roboto, has no
/// Arabic) makes Flutter web fetch a fallback font, which the web app
/// doesn't host (app/web_README.md, "Fonts: nothing from Google").
const _textFonts = {
  AppDesign.brutal: {'SpaceGrotesk', 'Alexandria'},
  AppDesign.lapis: {'IBMPlexSansArabic'},
};
const _iconFonts = {'MaterialIcons', 'CupertinoIcons'};

final _arabic = RegExp(r'[؀-ۿ]');

/// Texts on screen whose font isn't bundled, or whose Arabic has no Arabic
/// font, as "text: families".
List<String> _badTexts(WidgetTester tester, AppDesign design) {
  final allowed = _textFonts[design]!;
  final bad = <String>[];
  void check(InlineSpan span, TextStyle inherited) {
    final style = span.style == null
        ? inherited
        : (span.style!.inherit ? inherited.merge(span.style) : span.style!);
    if (span is TextSpan) {
      final text = span.text ?? '';
      if (text.trim().isNotEmpty) {
        final families = [?style.fontFamily, ...?style.fontFamilyFallback];
        final isIcon = families.any(_iconFonts.contains);
        final usable = families.where(allowed.contains).toList();
        final arabicOk =
            !_arabic.hasMatch(text) ||
            usable.any((f) => f == 'Alexandria' || f == 'IBMPlexSansArabic');
        if (!isIcon && (usable.isEmpty || !arabicOk)) {
          bad.add('"$text": $families');
        }
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        check(child, style);
      }
    }
  }

  for (final render in tester.allRenderObjects) {
    if (render is RenderParagraph) {
      check(render.text, const TextStyle());
    } else if (render is RenderEditable && render.text != null) {
      check(render.text!, const TextStyle());
    }
  }
  return bad;
}

void main() {
  for (final design in [AppDesign.brutal, AppDesign.lapis]) {
    for (final language in AppLanguage.values) {
      testWidgets('web, ${design.name}, ${language.name}: every text uses '
          'the bundled fonts', (tester) async {
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
        await repo.setLanguage(language);
        await repo.setDesign(design);
        final ar = language == AppLanguage.ar;
        final title = ar ? 'شراء الخبز ١٢' : 'Buy bread 12';
        await TaskRepository(db, deviceId: 'test').createTask(
          title: title,
          notes: ar ? 'ملاحظة' : 'A note',
          dueDate: LocalDate.fromDateTime(DateTime.now()),
          dueTimeMinutes: 9 * 60 + 30,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              deviceIdProvider.overrideWithValue('test'),
              initialSettingsProvider.overrideWithValue(
                AppSettings(language: language, design: design),
              ),
              geocoderProvider.overrideWithValue(_NoGeocoder()),
              mapTilesEnabledProvider.overrideWithValue(false),
            ],
            child: const TaskwiseApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(_badTexts(tester, design), isEmpty, reason: 'task list');

        // A task's details.
        await tester.tap(find.text(title).first);
        await tester.pumpAndSettle();
        expect(_badTexts(tester, design), isEmpty, reason: 'task details');
        await tester.tapAt(const Offset(5, 5)); // closes a side panel/sheet
        await tester.pumpAndSettle();

        // Settings: the longest screen with the most kinds of text.
        await tester.tap(
          find
              .text(language == AppLanguage.ar ? 'الإعدادات' : 'Settings')
              .first,
        );
        await tester.pumpAndSettle();
        final scrollable = find.byType(Scrollable).first;
        for (var i = 0; i < 12; i++) {
          expect(_badTexts(tester, design), isEmpty, reason: 'settings');
          await tester.drag(scrollable, const Offset(0, -500));
          await tester.pumpAndSettle();
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
        await db.close();
      });
    }
  }
}
