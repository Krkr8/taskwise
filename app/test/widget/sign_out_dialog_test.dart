import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise/l10n/app_localizations.dart';
import 'package:taskwise/platform/app_target.dart';
import 'package:taskwise/platform/page_reload.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/sync/sync_controller.dart';
import 'package:taskwise/sync/token_store.dart';
import 'package:taskwise/ui/shared/settings/sync_section.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/test_db.dart';
import '../sync/fake_server.dart';

/// Settings → Sync → Sign out, signed in to a [FakeSyncServer], as [target].
void signOutTest(
  String description,
  AppTarget target,
  Future<void> Function(WidgetTester tester, AppDatabase db, int Function())
  body,
) {
  testWidgets(description, (tester) async {
    final savedTarget = debugAppTargetOverride;
    debugAppTargetOverride = target;
    var reloads = 0;
    debugReloadPage = () => reloads++;
    addTearDown(() {
      debugAppTargetOverride = savedTarget;
      debugReloadPage = null;
    });

    final server = FakeSyncServer();
    final db = openTestDatabase();
    final container = (await tester.runAsync(() async {
      final deviceId = await ensureThisDevice(
        db,
        type: target.isWeb ? DeviceType.web : DeviceType.linux,
        name: 'This one',
      );
      await TaskRepository(
        db,
        deviceId: deviceId,
      ).createTask(title: 'Private task');
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue(deviceId),
          deviceTypeProvider.overrideWithValue(
            target.isWeb ? DeviceType.web : DeviceType.linux,
          ),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
          syncHttpClientProvider.overrideWithValue(server.client),
        ],
      );
      container.listen(syncControllerProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await container
          .read(syncControllerProvider.notifier)
          .signIn(
            serverUrl: 'sync.test',
            username: server.username,
            password: server.password,
            deviceName: 'This one',
          );
      // Let the first sync finish before the widgets take over.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await container.read(syncControllerProvider.notifier).syncNow();
      return container;
    }))!;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SyncSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    await body(tester, db, () => reloads);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(Duration.zero);
    await db.close();
  });
}

Future<int> _taskCount(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(() => db.select(db.tasks).get()))!.length;

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

void main() {
  signOutTest(
    'on the web, sign-out offers to remove the tasks (checked)',
    AppTarget.web,
    (tester, db, reloads) async {
      expect(
        find.text('Also remove my tasks from this browser'),
        findsOneWidget,
      );
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      await _confirm(tester);
      expect(await _taskCount(tester, db), 0);
      expect(reloads(), 1);
    },
  );

  signOutTest('on the web, unticking it keeps the tasks', AppTarget.web, (
    tester,
    db,
    reloads,
  ) async {
    await tester.tap(find.text('Also remove my tasks from this browser'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    await _confirm(tester);
    expect(await _taskCount(tester, db), 1);
    expect(reloads(), 0);
  });

  signOutTest(
    'native sign-out has no checkbox and keeps the tasks',
    AppTarget.linux,
    (tester, db, reloads) async {
      expect(find.byType(Checkbox), findsNothing);
      expect(find.textContaining('Your tasks stay on it.'), findsOneWidget);
      await _confirm(tester);
      expect(await _taskCount(tester, db), 1);
      expect(reloads(), 0);
    },
  );
}
