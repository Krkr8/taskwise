import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/l10n/app_localizations.dart';
import 'package:taskwise/logging/app_log.dart';
import 'package:taskwise/ui/shared/settings/logs_page.dart';

void main() {
  testWidgets('the logs page lists lines newest first and filters problems', (
    tester,
  ) async {
    final log = AppLog()
      ..info('sync', 'Synced: (pulled: 2, pushed: 1)')
      ..warning('sync', 'offline: no network')
      ..info('backup', 'Exported 1200 bytes');
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LogsPage(log: log),
      ),
    );

    final lines = find.textContaining('] ');
    expect(lines, findsNWidgets(3));
    expect(
      tester.widget<Text>(lines.first).data,
      '[backup] Exported 1200 bytes',
    );

    await tester.tap(find.text('Problems only'));
    await tester.pumpAndSettle();
    expect(find.textContaining('] '), findsOneWidget);
    expect(find.text('[sync] offline: no network'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing logged yet.'), findsOneWidget);
  });
}
