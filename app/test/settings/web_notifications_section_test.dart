import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:taskwise/l10n/app_localizations.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/l10n/app_localizations_en.dart';
import 'package:taskwise/notifications/push_plan_uploader.dart';
import 'package:taskwise/platform/web_push.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/sync/sync_api.dart';
import 'package:taskwise/sync/sync_controller.dart';
import 'package:taskwise/ui/shared/settings/web_notifications_section.dart';
import 'package:taskwise/ui/shared/web/add_to_home_screen_page.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/test_db.dart';

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

  /// Makes unsubscribe throw after dropping the subscription.
  bool unsubscribeThrows = false;

  @override
  Future<void> unsubscribe() async {
    _calls.add('unsubscribe');
    if (unsubscribeThrows) throw StateError('unsubscribe failed');
    subscription = null;
  }
}

class _FakeApi extends SyncApi {
  _FakeApi() : super(baseUrl: 'sync.test', token: 'tw_1');

  /// Null: the server has web push; otherwise what /push/key answers.
  SyncApiException? keyError;

  /// What saving the subscription throws, if anything.
  SyncApiException? putError;

  /// What `GET /devices` answers (when the sync state has no list).
  List<Device> listed = [];

  @override
  Future<List<Device>> devices() async {
    _calls.add('devices');
    return listed;
  }

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
  late AppDatabase db;

  setUp(() {
    _calls.clear();
    client = _FakeClient();
    api = _FakeApi();
    db = openTestDatabase();
  });

  tearDown(() => db.close());

  SettingsRepository settings() => SettingsRepository(db, deviceId: 'me');

  /// This browser as the server lists it.
  final listedOn = [_device('me', pushEnabled: true)];
  final listedOff = [_device('me')];

  const subscribed = WebPushSubscription(
    endpoint: 'https://push.test/abc',
    p256dh: 'p',
    auth: 'a',
  );

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
          databaseProvider.overrideWithValue(db),
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
        await pump(
          tester,
          locale: locale,
          planEnd: end,
          serverDevices: listedOn,
        );
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
        await pump(tester, locale: locale, serverDevices: listedOn);
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
    await pump(tester, planEnd: end, serverDevices: listedOn);
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
      'pushKey',
      'subscribe test-key',
      'putSubscription https://push.test/abc p-key a-key',
      'uploadNow',
      'syncNow',
    ]);
    expect(find.text('Notifications are on in this browser.'), findsOneWidget);
    expect(await settings().getWebPushWanted(), isTrue);
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
      'pushKey',
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
    await pump(tester, serverDevices: listedOn);
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
    expect(await settings().getWebPushWanted(), isFalse);
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
      await pump(tester, serverDevices: listedOff);
      expect(_calls, [
        'pushKey',
        'unsubscribe',
        'subscribe test-key',
        'putSubscription https://push.test/abc p-key a-key',
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
    await pump(tester, serverDevices: listedOn);
    expect(_calls, ['pushKey']);
    expect(find.text('Notifications are on in this browser.'), findsOneWidget);
  });

  testWidgets('a subscription made with another key is renewed with the '
      "server's key", (tester) async {
    client
      ..currentPermission = 'granted'
      ..subscription = const WebPushSubscription(
        endpoint: 'https://push.test/abc',
        p256dh: 'p',
        auth: 'a',
        applicationServerKey: 'other-key',
      );
    // Even when the server lists a subscription (the old one).
    await pump(tester, serverDevices: listedOn);
    expect(_calls, [
      'pushKey',
      'unsubscribe',
      'subscribe test-key',
      'putSubscription https://push.test/abc p-key a-key',
      'uploadNow',
      'syncNow',
    ]);
    expect(find.text('Notifications are on in this browser.'), findsOneWidget);
  });

  testWidgets('a subscription with the server key and lost on the server '
      'is sent again', (tester) async {
    client
      ..currentPermission = 'granted'
      ..subscription = const WebPushSubscription(
        endpoint: 'https://push.test/abc',
        p256dh: 'p',
        auth: 'a',
        applicationServerKey: 'test-key',
      );
    await pump(tester, serverDevices: listedOff);
    expect(_calls, [
      'pushKey',
      'unsubscribe',
      'subscribe test-key',
      'putSubscription https://push.test/abc p-key a-key',
      'uploadNow',
      'syncNow',
    ]);
  });

  testWidgets('turning off when the browser fails afterwards shows the '
      'truth and the failure', (tester) async {
    client
      ..currentPermission = 'granted'
      ..subscription = const WebPushSubscription(
        endpoint: 'https://push.test/abc',
        p256dh: 'p',
        auth: 'a',
      );
    await pump(tester, serverDevices: listedOn);
    client.unsubscribeThrows = true;
    _calls.clear();
    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();
    expect(_calls.first, 'deleteSubscription https://push.test/abc');
    expect(_calls, contains('pushKey'));
    expect(
      find.text("Couldn't turn off notifications. Try again."),
      findsOneWidget,
    );
    expect(find.text(AppLocalizationsEn().webNotifFailed), findsNothing);
    // Still subscribed (the fake server still lists it): on, not renewed.
    expect(find.text('Turn off'), findsOneWidget);
    expect(_calls, isNot(contains('subscribe test-key')));
  });

  testWidgets('allowed and turned on before, but the server and the browser '
      'lost the subscription: renewed without a tap', (tester) async {
    client.currentPermission = 'granted';
    await settings().setWebPushWanted(true);
    await pump(tester, serverDevices: listedOff);
    expect(_calls, [
      'pushKey',
      'subscribe test-key',
      'putSubscription https://push.test/abc p-key a-key',
      'uploadNow',
      'syncNow',
    ]);
    expect(find.text('Notifications are on in this browser.'), findsOneWidget);
  });

  testWidgets('allowed but turned off here: stays off', (tester) async {
    client.currentPermission = 'granted';
    await settings().setWebPushWanted(false);
    await pump(tester, serverDevices: listedOff);
    expect(_calls, ['pushKey']);
    expect(find.text('Turn on notifications in this browser'), findsOneWidget);
  });

  testWidgets('not allowed yet: nothing is renewed', (tester) async {
    client.subscription = subscribed;
    await settings().setWebPushWanted(true);
    await pump(tester, serverDevices: listedOff);
    expect(_calls, ['pushKey']);
    expect(find.text('Turn on notifications in this browser'), findsOneWidget);
  });

  testWidgets('a failed renewal shows off and the failure', (tester) async {
    client
      ..currentPermission = 'granted'
      ..subscription = subscribed;
    api.putError = const SyncNetworkException('offline');
    await pump(tester, serverDevices: listedOff);
    expect(find.text('Turn on notifications in this browser'), findsOneWidget);
    expect(find.text(AppLocalizationsEn().webNotifFailed), findsOneWidget);
    expect(_calls, isNot(contains('uploadNow')));
  });

  testWidgets('without a device list it asks the server', (tester) async {
    client
      ..currentPermission = 'granted'
      ..subscription = subscribed;
    api.listed = listedOn;
    await pump(tester);
    expect(_calls, ['pushKey', 'devices']);
    expect(find.text('Notifications are on in this browser.'), findsOneWidget);
  });

  testWidgets('plan uploads that fail say so instead of a plain on', (
    tester,
  ) async {
    client
      ..currentPermission = 'granted'
      ..subscription = subscribed;
    await pump(tester, serverDevices: listedOn);
    ProviderScope.containerOf(
      tester.element(find.byType(WebNotificationsSection)),
    ).read(ownPushPlanFailedProvider.notifier).set(true);
    await tester.pumpAndSettle();
    expect(
      find.text(
        "Reminders couldn't be planned on the server. They'll be retried.",
      ),
      findsOneWidget,
    );
    expect(find.text('Notifications are on in this browser.'), findsNothing);
    expect(find.text('Turn off'), findsOneWidget);
  });
}
