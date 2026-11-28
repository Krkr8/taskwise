import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_target.dart';
import 'web_push_stub.dart'
    if (dart.library.js_interop) 'web_push_web.dart'
    as impl;

/// Whether this browser can get reminders through Web Push.
enum WebPushSupport {
  supported,

  /// An iPhone or iPad Safari tab: only the Home Screen app gets pushes.
  needsHomeScreen,
  unsupported,
}

/// The browser's push subscription, as `PUT /push/subscription` takes it.
final class WebPushSubscription {
  const WebPushSubscription({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });

  final String endpoint;
  final String p256dh;
  final String auth;
}

/// The browser's notifications and Web Push (the service worker shows the
/// pushes, app/web/sw.js). [NoWebPushClient] outside the browser.
abstract class WebPushClient {
  Future<WebPushSupport> support();

  /// The notification permission now: `granted`, `denied` or `default`
  /// (not asked yet, or the prompt was closed).
  Future<String> permission();

  /// Asks for the notification permission (only from a tap: iOS refuses
  /// otherwise) and answers like [permission].
  Future<String> requestPermission();

  /// The service worker's current subscription, if any.
  Future<WebPushSubscription?> current();

  /// Subscribes the service worker with the server's VAPID public key
  /// (base64url, from `GET /push/key`). Null if the browser refused.
  Future<WebPushSubscription?> subscribe(String vapidPublicKey);

  /// Drops the browser's subscription (no more pushes reach this browser).
  Future<void> unsubscribe();
}

/// Outside the browser: no Web Push.
class NoWebPushClient implements WebPushClient {
  const NoWebPushClient();

  @override
  Future<WebPushSupport> support() async => WebPushSupport.unsupported;

  @override
  Future<String> permission() async => 'denied';

  @override
  Future<String> requestPermission() async => 'denied';

  @override
  Future<WebPushSubscription?> current() async => null;

  @override
  Future<WebPushSubscription?> subscribe(String vapidPublicKey) async => null;

  @override
  Future<void> unsubscribe() async {}
}

final webPushClientProvider = Provider<WebPushClient>(
  (ref) =>
      appTarget.isWeb ? impl.createWebPushClient() : const NoWebPushClient(),
);
