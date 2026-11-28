import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'web_push.dart';
import 'web_shell_web.dart' show isIosBrowserTab;

WebPushClient createWebPushClient() => const _BrowserWebPushClient();

/// How long to wait for the service worker (index.html registers it); a
/// page without one would otherwise wait forever.
const _workerTimeout = Duration(seconds: 15);

class _BrowserWebPushClient implements WebPushClient {
  const _BrowserWebPushClient();

  @override
  Future<WebPushSupport> support() async {
    if (isIosBrowserTab()) return WebPushSupport.needsHomeScreen;
    final window = web.window as JSObject;
    final navigator = web.window.navigator as JSObject;
    final ok =
        navigator.has('serviceWorker') &&
        window.has('PushManager') &&
        window.has('Notification');
    return ok ? WebPushSupport.supported : WebPushSupport.unsupported;
  }

  @override
  Future<String> permission() async => web.Notification.permission;

  @override
  Future<String> requestPermission() async =>
      (await web.Notification.requestPermission().toDart).toDart;

  Future<web.PushManager> _pushManager() async {
    final registration = await web.window.navigator.serviceWorker.ready.toDart
        .timeout(_workerTimeout);
    return registration.pushManager;
  }

  @override
  Future<WebPushSubscription?> current() async {
    final subscription = await (await _pushManager()).getSubscription().toDart;
    return subscription == null ? null : _toDart(subscription);
  }

  @override
  Future<WebPushSubscription?> subscribe(String vapidPublicKey) async {
    final subscription = await (await _pushManager())
        .subscribe(
          web.PushSubscriptionOptionsInit(
            userVisibleOnly: true,
            applicationServerKey: _base64UrlBytes(vapidPublicKey).toJS,
          ),
        )
        .toDart;
    return _toDart(subscription);
  }

  @override
  Future<void> unsubscribe() async {
    final subscription = await (await _pushManager()).getSubscription().toDart;
    await subscription?.unsubscribe().toDart;
  }
}

WebPushSubscription? _toDart(web.PushSubscription subscription) {
  final json = (subscription.toJSON() as JSAny).dartify();
  if (json is! Map) return null;
  final keys = json['keys'];
  if (keys is! Map) return null;
  final p256dh = keys['p256dh'];
  final auth = keys['auth'];
  if (p256dh is! String || auth is! String) return null;
  return WebPushSubscription(
    endpoint: subscription.endpoint,
    p256dh: p256dh,
    auth: auth,
  );
}

/// The VAPID key is base64url without padding.
Uint8List _base64UrlBytes(String text) =>
    base64Url.decode(text.padRight((text.length + 3) ~/ 4 * 4, '='));
