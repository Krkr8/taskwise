import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:taskwise/l10n/app_localizations.dart';
import 'package:taskwise/notifications/push_plan_uploader.dart';
import 'package:taskwise/platform/web_push.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/sync/sync_api.dart';
import 'package:taskwise/sync/sync_controller.dart';
import 'package:taskwise/ui/shared/settings/web_notifications_section.dart';
import 'package:taskwise/ui/shared/web/add_to_home_screen_page.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

/// Every call the section makes, in order, from the browser and the server.
final _calls = <String>[];

class _FakeClient implements WebPushClient {
  WebPushSupport supportResult = WebPushSupport.supported;
  String currentPermission = 'default';

  /// What the permission prompt answers.
  String prompt = 'granted';
  WebPushSubscription? subscription;

  @override
  Future<WebPushSupport> support() async => supportResult;

  @override
  Future<String> permission() async => currentPermission;

  @override
  Future<String> requestPermission() async {
    _calls.add('requestPermission');
    return currentPermission = prompt;
  }

  @override
  Future<WebPushSubscription?> current() async => subscription;

  @override
  Future<WebPushSubscription?> subscribe(String vapidPublicKey) async {
    _calls.add('subscribe $vapidPublicKey');
    return subscription = const WebPushSubscription(
      endpoint: 'https://push.test/abc',
      p256dh: 'p-key',
      auth: 'a-key',
    );
  }

  @override
  Future<void> unsubscribe() async {
    _calls.add('unsubscribe');
    subscription = null;
  }
}

class _FakeApi extends SyncApi {
  _FakeApi() : super(baseUrl: 'sync.test', token: 'tw_1');

  /// Null: the server has web push; otherwise what /push/key answers.
  SyncApiException? keyError;

  /// What saving the subscription throws, if anything.
  SyncApiException? putError;

  @override
  Future<String> pushKey() async {
    _calls.add('pushKey');
    if (keyError case final error?) throw error;
    return 'test-key';
  }

  @override
  Future<void> putPushSubscription({
    required String endpoint,
    required String p256dh,
    required String auth,
  }) async {
    _calls.add('putSubscription $endpoint $p256dh $auth');
    if (putError case final error?) throw error;
  }

  @override
  Future<void> deletePushSubscription(String endpoint) async =>
      _calls.add('deleteSubscription $endpoint');
}

class _FakeUploader extends PushPlanUploader {
  _FakeUploader(super.ref);

  @override
  Future<void> uploadNow() async => _calls.add('uploadNow');
}

/// Signed in (or not), with the devices the server listed.
class _FakeSync extends SyncController {
  _FakeSync(this._initial, this.api);

  final SyncState _initial;
  final SyncApi? api;

  @override
  SyncState build() => _initial;

  @override
  ({SyncApi api, List<Device>? devices})? get pushContext =>
      api == null ? null : (api: api!, devices: state.serverDevices);

  @override
  Future<void> syncNow() async => _calls.add('syncNow');
}

Device _device(String id, {bool pushEnabled = false}) => Device(
  id: id,
  name: 'Browser',
  type: DeviceType.web,
  updatedAt: DateTime.utc(2026, 11, 1),
  pushEnabled: pushEnabled,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('ar');
  });

  late _FakeClient client;
  late _FakeApi api;

  setUp(() {
    _calls.clear();
    client = _FakeClient();
    api = _FakeApi();
  });

  Future<void> pump(
    WidgetTester tester, {
    String locale = 'en',
    bool signedIn = true,
    List<Device>? serverDevices,
    DateTime? planEnd,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          webPushClientProvider.overrideWithValue(client),
          deviceIdProvider.overrideWithValue('me'),
          clockProvider.overrideWithValue(() => DateTime(2026, 11, 28, 10)),
          pushPlanUploaderProvider.overrideWith(_FakeUploader.new),
          ownPushPlanEndProvider.overrideWithValue(planEnd),
          syncControllerProvider.overrideWith(
            () => _FakeSync(
              SyncState(
                loaded: true,
                serverUrl: signedIn ? 'https://sync.test' : null,
                serverDevices: serverDevices,
              ),
              signedIn ? api : null,
            ),
          ),
        ],
        child: MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: WebNotificationsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const texts = {
    'en': (
      unsupported: "This browser can't show notifications.",
      homeScreen:
          'Add Taskwise to your Home Screen first, then turn on '
          'notifications there.',
      notConfigured: "This server isn't set up for reminders yet.",
      denied:
          'Notifications are blocked for this site. Allow them in the '
          "browser's settings.",
      turnOn: 'Turn on notifications in this browser',
      on: 'Notifications are on in this browser.',
      noUpcoming: 'No upcoming reminders',
      turnOff: 'Turn off',
      signIn: 'Sign in to your server first, then turn on notifications here.',
    ),
    'ar': (
      unsupported: 'هذا المتصفح لا يستطيع عرض الإشعارات.',
      homeScreen:
          'أضف Taskwise إلى الشاشة الرئيسية أولًا، ثم فعّل الإشعارات من هناك.',
      notConfigured: 'هذا الخادم غير مُعدّ للتذكيرات بعد.',
      denied: 'الإشعارات محظورة لهذا الموقع. اسمح بها من إعدادات المتصفح.',
      turnOn: 'تفعيل الإشعارات في هذا المتصفح',
      on: 'الإشعارات مفعّلة في هذا المتصفح.',
      noUpcoming: 'لا تذكيرات قادمة',
      turnOff: 'إيقاف',
      signIn: 'سجّل الدخول إلى خادمك أولًا، ثم فعّل الإشعارات هنا.',
    ),
  };

  for (final MapEntry(key: locale, value: t) in texts.entries) {
    group(locale, () {
      testWidgets('a browser without notifications says so', (tester) async {
        client.supportResult = WebPushSupport.unsupported;
        await pump(tester, locale: locale);
        expect(find.text(t.unsupported), findsOneWidget);
        expect(find.text(t.turnOn), findsNothing);
      });

      testWidgets('an iPhone tab asks for the Home Screen first', (
        tester,
      ) async {
        client.supportResult = WebPushSupport.needsHomeScreen;
        await pump(tester, locale: locale);
        expect(find.text(t.homeScreen), findsOneWidget);
        expect(find.text(t.turnOn), findsNothing);
        await tester.tap(find.byKey(const ValueKey('web-notif-guide')));
        await tester.pumpAndSettle();
        expect(find.byType(AddToHomeScreenPage), findsOneWidget);
      });

      testWidgets('not signed in: sign in first', (tester) async {
        await pump(tester, locale: locale, signedIn: false);
        expect(find.text(t.signIn), findsOneWidget);
        expect(find.text(t.turnOn), findsNothing);
      });

      testWidgets('a server without web push says so, with a link', (
        tester,
      ) async {
        api.keyError = const SyncHttpException(
          404,
          'push_not_configured',
          'not set up',
        );
        await pump(tester, locale: locale);
        expect(find.text(t.notConfigured), findsOneWidget);
        expect(find.byKey(const ValueKey('web-notif-setup')), findsOneWidget);
        expect(find.text(t.turnOn), findsNothing);
      });

      testWidgets('an older server (no push endpoints) is not set up either', (
        tester,
      ) async {
        api.keyError = const SyncHttpException(404, 'not_found', 'No such');
        await pump(tester, locale: locale);
        expect(find.text(t.notConfigured), findsOneWidget);
      });

      testWidgets('blocked notifications say where to allow them', (
        tester,
      ) async {
        client.currentPermission = 'denied';
        await pump(tester, locale: locale);
        expect(find.text(t.denied), findsOneWidget);
        expect(find.text(t.turnOn), findsNothing);
      });

      testWidgets('off: the turn-on button', (tester) async {
        await pump(tester, locale: locale);
        expect(find.text(t.turnOn), findsOneWidget);
        expect(find.text(t.on), findsNothing);
      });

      testWidgets('on: the planned date and Turn off', (tester) async {
        client
          ..currentPermission = 'granted'
          ..subscription = const WebPushSubscription(
            endpoint: 'https://push.test/abc',
            p256dh: 'p',
            auth: 'a',
          );
        final end = DateTime(2026, 12, 20, 9);
        await pump(tester, locale: locale, planEnd: end);
        expect(find.text(t.on), findsOneWidget);
        final date = DateFormat.MMMEd(locale).format(end);
        expect(find.textContaining(date), findsOneWidget);
        expect(find.text(t.turnOff), findsOneWidget);
        expect(find.text(t.turnOn), findsNothing);
      });

      testWidgets('on without reminders: none upcoming', (tester) async {
        client
          ..currentPermission = 'granted'
          ..subscription = const WebPushSubscription(
            endpoint: 'https://push.test/abc',
            p256dh: 'p',
            auth: 'a',
          );
        await pump(tester, locale: locale);
        expect(find.text(t.on), findsOneWidget);
        expect(find.text(t.noUpcoming), findsOneWidget);
      });
    });
  }

  testWidgets('a plan that ends next year shows the year', (tester) async {
    client
      ..currentPermission = 'granted'
      ..subscription = const WebPushSubscription(
        endpoint: 'https://push.test/abc',
        p256dh: 'p',
        auth: 'a',
      );
    final end = DateTime(2027, 1, 12, 9);
    await pump(tester, planEnd: end);
    expect(
      find.text(
        'Reminders planned until ${DateFormat.yMMMEd('en').format(end)}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('turning on: permission, subscribe with the server key, save '
      'the subscription, upload the plan now', (tester) async {
    await pump(tester);
    _calls.clear();
    await tester.tap(find.text('Turn on notifications in this browser'));
    await tester.pumpAndSettle();

    expect(_calls, [
      'requestPermission',
      'subscribe test-key',
      'putSubscription https://push.test/abc p-key a-key',
      'uploadNow',
      'syncNow',
    ]);
    expect(find.text('Notifications are on in this browser.'), findsOneWidget);
  });

  testWidgets('turning on while the key could not be fetched asks again', (
    tester,
  ) async {
    api.keyError = const SyncNetworkException('offline');
    await pump(tester);
    expect(find.text('Turn on notifications in this browser'), findsOneWidget);
    api.keyError = null;
    _calls.clear();
    await tester.tap(find.text('Turn on notifications in this browser'));
    await tester.pumpAndSettle();
    expect(_calls.take(3), [
      'requestPermission',
      'pushKey',
      'subscribe test-key',
    ]);
    expect(find.text('Notifications are on in this browser.'), findsOneWidget);
  });

  testWidgets('refusing the prompt shows the blocked text and sends nothing', (
    tester,
  ) async {
    client.prompt = 'denied';
    await pump(tester);
    _calls.clear();
    await tester.tap(find.text('Turn on notifications in this browser'));
    await tester.pumpAndSettle();

    expect(_calls, ['requestPermission']);
    expect(
      find.text(
        'Notifications are blocked for this site. Allow them in the '
        "browser's settings.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('closing the prompt keeps the button', (tester) async {
    client.prompt = 'default';
    await pump(tester);
    _calls.clear();
    await tester.tap(find.text('Turn on notifications in this browser'));
    await tester.pumpAndSettle();
    expect(_calls, ['requestPermission']);
    expect(find.text('Turn on notifications in this browser'), findsOneWidget);
  });

  testWidgets('a failed save says so and stays off', (tester) async {
    api.putError = const SyncNetworkException('offline');
    await pump(tester);
    _calls.clear();
    await tester.tap(find.text('Turn on notifications in this browser'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        "Couldn't turn on notifications. Check your connection and try again.",
      ),
      findsOneWidget,
    );
    expect(find.text('Turn on notifications in this browser'), findsOneWidget);
    // The browser's subscription is dropped again: the server doesn't know it.
    expect(_calls, [
      'requestPermission',
      'subscribe test-key',
      'putSubscription https://push.test/abc p-key a-key',
      'unsubscribe',
    ]);
  });

  testWidgets('turning off: the server forgets it, the browser unsubscribes, '
      'the plan is uploaded', (tester) async {
    client
      ..currentPermission = 'granted'
      ..subscription = const WebPushSubscription(
        endpoint: 'https://push.test/abc',
        p256dh: 'p',
        auth: 'a',
      );
    await pump(tester);
    _calls.clear();
    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();
    expect(_calls, [
      'deleteSubscription https://push.test/abc',
      'unsubscribe',
      'uploadNow',
      'syncNow',
    ]);
    expect(find.text('Turn on notifications in this browser'), findsOneWidget);
  });

  testWidgets(
    'subscribed here but the server has no subscription: sent again',
    (tester) async {
      client
        ..currentPermission = 'granted'
        ..subscription = const WebPushSubscription(
          endpoint: 'https://push.test/abc',
          p256dh: 'p',
          auth: 'a',
        );
      await pump(tester, serverDevices: [_device('me')]);
      expect(_calls, [
        'pushKey',
        'putSubscription https://push.test/abc p a',
        'uploadNow',
        'syncNow',
      ]);
      expect(
        find.text('Notifications are on in this browser.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('subscribed here and on the server: nothing to send', (
    tester,
  ) async {
    client
      ..currentPermission = 'granted'
      ..subscription = const WebPushSubscription(
        endpoint: 'https://push.test/abc',
        p256dh: 'p',
        auth: 'a',
      );
    await pump(tester, serverDevices: [_device('me', pushEnabled: true)]);
    expect(_calls, ['pushKey']);
  });
}
