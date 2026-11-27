import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/l10n/app_localizations.dart';
import 'package:taskwise/platform/app_target.dart';
import 'package:taskwise/platform/web_launch_params.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/sync/sync_controller.dart';
import 'package:taskwise/sync/token_store.dart';
import 'package:taskwise/ui/shared/settings/sign_in_page.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/test_db.dart';

void main() {
  group('checkServerForWeb', () {
    final page = Uri.parse('https://taskwise-app.vercel.app');
    test('http on an https page needs https', () {
      expect(
        checkServerForWeb(Uri.parse('http://example.com'), pageOrigin: page),
        SignInProblem.needsHttps,
      );
    });
    test('https is fine', () {
      expect(
        checkServerForWeb(Uri.parse('https://example.com'), pageOrigin: page),
        isNull,
      );
    });
    test('localhost is fine for local testing', () {
      expect(
        checkServerForWeb(Uri.parse('http://[::1]:8787'), pageOrigin: page),
        isNull,
      );
      expect(
        checkServerForWeb(Uri.parse('http://localhost:8787'), pageOrigin: page),
        isNull,
      );
      expect(
        checkServerForWeb(Uri.parse('http://127.0.0.1:8787'), pageOrigin: page),
        isNull,
      );
    });
  });

  group('serverParamIn', () {
    test('reads #server= (never sent to the host) and ?server=', () {
      expect(
        serverParamIn(
          Uri.parse(
            'https://taskwise-app.vercel.app/app/#server=https://my.example',
          ),
        ),
        'https://my.example',
      );
      expect(
        serverParamIn(
          Uri.parse(
            'https://taskwise-app.vercel.app/app/#server=https%3A%2F%2Fmy.example%2Fsync',
          ),
        ),
        'https://my.example/sync',
      );
      expect(
        serverParamIn(
          Uri.parse(
            'https://taskwise-app.vercel.app/app/?server=https://my.example',
          ),
        ),
        'https://my.example',
      );
    });
    test('nothing, empty or another fragment gives null', () {
      expect(serverParamIn(Uri.parse('https://t.example/app/')), isNull);
      expect(serverParamIn(Uri.parse('https://t.example/app/#/')), isNull);
      expect(
        serverParamIn(Uri.parse('https://t.example/app/#server=')),
        isNull,
      );
      expect(
        serverParamIn(Uri.parse('https://t.example/app/?server=%20')),
        isNull,
      );
    });
  });

  group('sign-in page on the web', () {
    late AppDatabase db;
    late List<Uri> requests;
    late http.Client client;
    late String deviceId;

    setUp(() async {
      final savedTarget = debugAppTargetOverride;
      debugAppTargetOverride = AppTarget.web;
      debugPageOrigin = Uri.parse('https://taskwise-app.vercel.app');
      db = openTestDatabase();
      final id = await ensureThisDevice(
        db,
        type: DeviceType.web,
        name: 'Chrome on Linux',
      );
      requests = [];
      client = MockClient((request) async {
        requests.add(request.url);
        throw http.ClientException('Failed to fetch', request.url);
      });
      addTearDown(() async {
        debugAppTargetOverride = savedTarget;
        debugPageOrigin = null;
        debugLaunchServerParam = null;
        await db.close();
      });
      deviceId = id;
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            deviceIdProvider.overrideWithValue(deviceId),
            deviceTypeProvider.overrideWithValue(DeviceType.web),
            tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
            syncHttpClientProvider.overrideWithValue(client),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SignInPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> fillAndSubmit(WidgetTester tester, String server) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), server);
      await tester.enterText(fields.at(1), 'me');
      await tester.enterText(fields.at(2), 'secret-password');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    }

    testWidgets('?server= pre-fills the server field', (tester) async {
      debugLaunchServerParam = () => 'https://my.example';
      await pump(tester);
      final field = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(field.controller!.text, 'https://my.example');
    });

    testWidgets('a blocked request explains the browser problem', (
      tester,
    ) async {
      await pump(tester);
      await fillAndSubmit(tester, 'https://sync.example');
      expect(requests, isNotEmpty);
      expect(
        find.textContaining("Can't reach this server from the browser"),
        findsOneWidget,
      );
    });

    testWidgets('an http address says https is needed, with no request', (
      tester,
    ) async {
      await pump(tester);
      await fillAndSubmit(tester, 'http://sync.example');
      expect(
        find.text('This server must use https:// to work in the browser'),
        findsOneWidget,
      );
      expect(requests, isEmpty);
    });
  });
}
