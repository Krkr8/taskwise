import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/storage_status.dart';
import 'package:taskwise/l10n/app_localizations.dart';
import 'package:taskwise/ui/shared/common/storage_warning_bar.dart';

void main() {
  Widget app(StorageStatus status, {Widget? shell}) => ProviderScope(
    overrides: [storageStatusProvider.overrideWithValue(status)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StorageWarningBar(
        child: shell ?? const Scaffold(body: Text('shell')),
      ),
    ),
  );

  const warning =
      "This browser isn't keeping your tasks. Sign in to sync them, or "
      'leave private browsing.';

  testWidgets('warns for the whole visit when the tasks are only kept in '
      'memory', (tester) async {
    await tester.pumpWidget(app(StorageStatus.temporary));
    expect(find.text(warning), findsOneWidget);
    expect(find.text('shell'), findsOneWidget);
    // It can't be closed.
    expect(find.byType(IconButton), findsNothing);
    expect(find.byTooltip('Close'), findsNothing);
  });

  testWidgets('shows nothing when the browser keeps the tasks', (tester) async {
    await tester.pumpWidget(app(StorageStatus.persistent));
    expect(find.text(warning), findsNothing);
    expect(find.text('shell'), findsOneWidget);
  });

  testWidgets('says it in Arabic', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageStatusProvider.overrideWithValue(StorageStatus.temporary),
        ],
        child: const MaterialApp(
          locale: Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StorageWarningBar(child: SizedBox()),
        ),
      ),
    );
    expect(
      find.text(
        'هذا المتصفح لا يحفظ مهامك. سجّل الدخول لمزامنتها، أو اخرج من '
        'التصفح الخاص.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the shell keeps its state when the bar rebuilds', (
    tester,
  ) async {
    final host = GlobalKey<_HostState>();
    await tester.pumpWidget(
      _Host(
        key: host,
        build: (status) => app(
          status,
          shell: const Scaffold(body: TextField(key: Key('typed'))),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('typed')), 'half a task');
    final state = tester.state(find.byType(EditableText));

    void expectKept() {
      expect(find.text('half a task'), findsOneWidget);
      expect(tester.state(find.byType(EditableText)), same(state));
    }

    // The parent rebuilds.
    host.currentState!.rebuild();
    await tester.pump();
    expectKept();
    expect(find.text(warning), findsOneWidget);

    // The status changes, both ways.
    host.currentState!.setStatus(StorageStatus.persistent);
    await tester.pump();
    expectKept();
    expect(find.text(warning), findsNothing);

    host.currentState!.setStatus(StorageStatus.temporary);
    await tester.pump();
    expectKept();
    expect(find.text(warning), findsOneWidget);
  });
}

class _Host extends StatefulWidget {
  const _Host({super.key, required this.build});

  final Widget Function(StorageStatus status) build;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  StorageStatus _status = StorageStatus.temporary;

  void rebuild() => setState(() {});

  void setStatus(StorageStatus status) => setState(() => _status = status);

  @override
  Widget build(BuildContext context) => widget.build(_status);
}
