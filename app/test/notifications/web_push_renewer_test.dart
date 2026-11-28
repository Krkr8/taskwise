import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/notifications/push_plan_uploader.dart';
import 'package:taskwise/notifications/web_push_renewer.dart';
import 'package:taskwise/platform/app_target.dart';
import 'package:taskwise/platform/web_push.dart';
import 'package:taskwise/state/providers.dart';
import 'package:taskwise/sync/sync_api.dart';
import 'package:taskwise/sync/sync_controller.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../data/test_db.dart';

final _calls = <String>[];

class _FakeClient implements WebPushClient {
  String currentPermission = 'granted';
  WebPushSubscription? subscription;

  @override
  Future<WebPushSupport> support() async => WebPushSupport.supported;

  @override
  Future<String> permission() async => currentPermission;

  @override
  Future<String> requestPermission() async => currentPermission;

  @override
  Future<WebPushSubscription?> current() async => subscription;

  @override
  Future<WebPushSubscription?> subscribe(String vapidPublicKey) async {
    _calls.add('subscribe $vapidPublicKey');
    return subscription = const WebPushSubscription(
      endpoint: 'https://push.test/new',
      p256dh: 'p',
      auth: 'a',
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

  SyncApiException? putError;

  @override
  Future<String> pushKey() async => 'test-key';

  @override
  Future<void> putPushSubscription({
    required String endpoint,
    required String p256dh,
    required String auth,
  }) async {
    _calls.add('putSubscription $endpoint');
    if (putError case final error?) throw error;
  }
}

class _FakeUploader extends PushPlanUploader {
  _FakeUploader(super.ref);

  @override
  void start() {}

  @override
  Future<void> uploadNow() async => _calls.add('uploadNow');
}

class _FakeSync extends SyncController {
  _FakeSync(this.api);

  final SyncApi api;

  @override
  SyncState build() => const SyncState(loaded: true, serverUrl: 'https://x');

  void list(List<Device>? devices) =>
      state = state.copyWith(serverDevices: () => devices);

  @override
  ({SyncApi api, List<Device>? devices})? get pushContext =>
      (api: api, devices: state.serverDevices);

  @override
  Future<void> syncNow() async => _calls.add('syncNow');
}

final _lost = [
  Device(
    id: 'me',
    name: 'Browser',
    type: DeviceType.web,
    updatedAt: DateTime.utc(2026, 11, 1),
  ),
];

void main() {
  late AppDatabase db;
  late _FakeClient client;
  late _FakeApi api;
  late ProviderContainer container;
  late AppTarget savedTarget;

  setUp(() async {
    _calls.clear();
    savedTarget = appTarget;
    debugAppTargetOverride = AppTarget.web;
    db = openTestDatabase();
    client = _FakeClient()
      ..subscription = const WebPushSubscription(
        endpoint: 'https://push.test/old',
        p256dh: 'p',
        auth: 'a',
      );
    api = _FakeApi();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue('me'),
        webPushClientProvider.overrideWithValue(client),
        pushPlanUploaderProvider.overrideWith(_FakeUploader.new),
        syncControllerProvider.overrideWith(() => _FakeSync(api)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    debugAppTargetOverride = savedTarget;
    await db.close();
  });

  _FakeSync sync() =>
      container.read(syncControllerProvider.notifier) as _FakeSync;

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  test('at start, after the first device list, a lost subscription is '
      'renewed and the plan uploaded', () async {
    container.read(webPushRenewerProvider);
    await settle();
    expect(_calls, isEmpty, reason: 'no device list yet');

    sync().list(_lost);
    await settle();
    expect(_calls, [
      'unsubscribe',
      'subscribe test-key',
      'putSubscription https://push.test/new',
      'uploadNow',
      'syncNow',
    ]);

    // A later list doesn't check again; a new sign-in does.
    _calls.clear();
    sync().list([..._lost]);
    await settle();
    expect(_calls, isEmpty);
    sync().list(null);
    sync().list(_lost);
    await settle();
    expect(_calls, contains('putSubscription https://push.test/new'));
  });

  test('not allowed yet: nothing happens', () async {
    client.currentPermission = 'default';
    container.read(webPushRenewerProvider);
    sync().list(_lost);
    await settle();
    expect(_calls, isEmpty);
    expect(
      await container.read(webPushRenewerProvider).check(),
      WebPushStatus.off,
    );
  });

  test('turned off here: not renewed', () async {
    client.subscription = null;
    await SettingsRepository(db, deviceId: 'me').setWebPushWanted(false);
    expect(
      await container.read(webPushRenewerProvider).check(),
      WebPushStatus.off,
    );
    expect(_calls, isEmpty);
  });

  test('a failed renewal never throws and reports it', () async {
    api.putError = const SyncNetworkException('offline');
    sync().list(_lost);
    expect(
      await container.read(webPushRenewerProvider).check(),
      WebPushStatus.failed,
    );
    expect(_calls, isNot(contains('uploadNow')));
  });

  test('outside the browser it does nothing at start', () async {
    debugAppTargetOverride = AppTarget.linux;
    container.read(webPushRenewerProvider);
    sync().list(_lost);
    await settle();
    expect(_calls, isEmpty);
  });
}
