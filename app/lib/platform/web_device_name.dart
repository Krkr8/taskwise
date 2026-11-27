import 'user_agent_stub.dart'
    if (dart.library.js_interop) 'user_agent_web.dart'
    as ua;

/// The browser's user agent; empty outside the browser.
String browserUserAgent() => ua.userAgent();

/// `<Browser> on <OS>` from a user agent, e.g. "Safari on iPhone".
String webDeviceName(String userAgent) {
  final browser = userAgent.contains('Edg')
      ? 'Edge'
      : userAgent.contains('Firefox') || userAgent.contains('FxiOS')
      ? 'Firefox'
      : userAgent.contains('Chrome') || userAgent.contains('CriOS')
      ? 'Chrome'
      : userAgent.contains('Safari')
      ? 'Safari'
      : 'Browser';
  final os = userAgent.contains('iPhone')
      ? 'iPhone'
      : userAgent.contains('iPad')
      ? 'iPad'
      : userAgent.contains('Android')
      ? 'Android'
      : userAgent.contains('Windows')
      ? 'Windows'
      : userAgent.contains('Mac')
      ? 'Mac'
      : userAgent.contains('Linux')
      ? 'Linux'
      : 'device';
  return '$browser on $os';
}
