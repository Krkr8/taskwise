import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../logging/app_log.dart';
import '../platform/app_target.dart';
import '../platform/web_push.dart';
import '../state/providers.dart';
import '../sync/sync_api.dart';
import '../sync/sync_controller.dart';
import 'push_plan_uploader.dart';

/// Web Push in this browser, as [WebPushRenewer.check] found it.
enum WebPushStatus {
  unsupported,

  /// An iPhone or iPad Safari tab: only the Home Screen app gets pushes.
  needsHomeScreen,
  signedOut,

  /// The server has no VAPID keys, or is older than web reminders.
  notConfigured,
  denied,
  off,

  /// The server lists this browser with a subscription.
  on,

  /// Renewing the subscription failed (it's off now).
  failed,
}

/// Keeps this browser's Web Push subscription alive. Read it once (the app
/// root does) to start it: after the first device list of each sign-in it
/// runs [check], and Settings → Notifications runs it when it opens.
final webPushRenewerProvider = Provider<WebPushRenewer>((ref) {
  final renewer = WebPushRenewer(ref);
  ref.onDispose(renewer.dispose);
  renewer.start();
  return renewer;
});

class WebPushRenewer {
  WebPushRenewer(this._ref);

  final Ref _ref;
  ProviderSubscription<bool>? _listed;
  Future<WebPushStatus>? _running;
  bool _checked = false;

  void start() {
    if (!appTarget.isWeb) return;
    _listed = _ref.listen(
      syncControllerProvider.select((s) => s.serverDevices != null),
      (_, listed) {
        // Signing in or out clears the list: check again after the next.
        if (!listed) {
          _checked = false;
        } else if (!_checked) {
          _checked = true;
          unawaited(check());
        }
      },
      fireImmediately: true,
    );
  }

  /// Finds out whether this browser gets reminders. When notifications are
  /// allowed and were turned on here, but the server lists this device
  /// without a subscription (it signed in again, or the push service
  /// dropped it) or the browser's subscription was made with another key,
  /// it subscribes again with the server's key (no tap needed once
  /// allowed), saves it and uploads the plan. Never throws.
  Future<WebPushStatus> check() =>
      _running ??= _check().whenComplete(() => _running = null);

  Future<WebPushStatus> _check() async {
    final client = _ref.read(webPushClientProvider);
    try {
      switch (await client.support()) {
        case WebPushSupport.unsupported:
          return WebPushStatus.unsupported;
        case WebPushSupport.needsHomeScreen:
          return WebPushStatus.needsHomeScreen;
        case WebPushSupport.supported:
      }
      final sync = _ref.read(syncControllerProvider.notifier);
      final context = sync.pushContext;
      if (context == null) return WebPushStatus.signedOut;
      final api = context.api;
      String? key;
      try {
        key = await api.pushKey();
      } on SyncHttpException catch (e) {
        // 404: no VAPID keys, or a server from before web reminders.
        if (e.status == 404) return WebPushStatus.notConfigured;
        appLog.warning('push', 'No push key: ${e.status} ${e.code}');
      } on SyncNetworkException catch (e) {
        appLog.warning('push', 'No push key: ${e.message}');
      }
      final permission = await client.permission();
      if (permission == 'denied') return WebPushStatus.denied;
      if (permission != 'granted') return WebPushStatus.off;

      final subscription = await client.current();
      // Offline: can't tell what the server has.
      if (key == null) return WebPushStatus.off;
      final made = subscription?.applicationServerKey;
      final otherKey =
          made != null && made.replaceAll('=', '') != key.replaceAll('=', '');
      final listed = await _serverHasSubscription(context);
      if (listed == null) return WebPushStatus.off;
      if (subscription != null && !otherKey && listed) return WebPushStatus.on;

      // Turned off here (or signed out): not renewed. Nothing was stored
      // before; a subscription means it was turned on.
      final wanted =
          await _ref.read(settingsRepositoryProvider).getWebPushWanted() ??
          subscription != null;
      if (!wanted) return WebPushStatus.off;

      appLog.info('push', 'Renewing the subscription of this browser');
      try {
        if (subscription != null) await client.unsubscribe();
        final fresh = await client.subscribe(key);
        if (fresh == null) throw StateError('No subscription');
        await api.putPushSubscription(
          endpoint: fresh.endpoint,
          p256dh: fresh.p256dh,
          auth: fresh.auth,
        );
      } on SyncApiException catch (e) {
        appLog.warning('push', 'Renewing the subscription failed: $e');
        return WebPushStatus.failed;
      }
      appLog.info('push', 'This browser gets reminders again');
      await _ref.read(pushPlanUploaderProvider).uploadNow();
      // The device list shows it.
      unawaited(sync.syncNow());
      return WebPushStatus.on;
    } on Object catch (e, stack) {
      appLog.error('push', e, stack);
      return WebPushStatus.failed;
    }
  }

  /// Whether the server lists this device with a subscription; null when
  /// the list can't be had (offline).
  Future<bool?> _serverHasSubscription(
    ({SyncApi api, List<Device>? devices}) context,
  ) async {
    var devices = context.devices;
    if (devices == null) {
      try {
        devices = await context.api.devices();
      } on SyncApiException catch (e) {
        appLog.warning('push', 'Could not list devices: ${e.message}');
        return null;
      }
    }
    final me = _ref.read(deviceIdProvider);
    return devices.where((d) => d.id == me).firstOrNull?.pushEnabled ?? false;
  }

  void dispose() => _listed?.close();
}
