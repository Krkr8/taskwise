import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/storage_status.dart';
import 'package:taskwise/l10n/app_localizations.dart';
import 'package:taskwise/ui/shared/common/storage_warning_bar.dart';

void main() {
  Widget app(StorageStatus status) => ProviderScope(
    overrides: [storageStatusProvider.overrideWithValue(status)],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StorageWarningBar(child: Scaffold(body: Text('shell'))),
    ),
  );

  const warning =
      "This browser can't save your tasks. They're gone when you close or "
      'reload the page, unless you sync them.';

  testWidgets('warns when the tasks are only kept in memory', (tester) async {
    await tester.pumpWidget(app(StorageStatus.temporary));
    expect(find.text(warning), findsOneWidget);
    expect(find.text('shell'), findsOneWidget);

    // It can be put away for this visit.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text(warning), findsNothing);
    expect(find.text('shell'), findsOneWidget);
  });

  testWidgets('shows nothing when the browser keeps the tasks', (tester) async {
    await tester.pumpWidget(app(StorageStatus.persistent));
    expect(find.text(warning), findsNothing);
    expect(find.text('shell'), findsOneWidget);
  });
}
