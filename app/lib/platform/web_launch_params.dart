import 'package:flutter/foundation.dart';

import 'launch_params_stub.dart'
    if (dart.library.js_interop) 'launch_params_web.dart'
    as page;

/// Tests set these to pretend to run in a browser at some address.
@visibleForTesting
String? Function()? debugLaunchServerParam;

@visibleForTesting
Uri? debugPageOrigin;

/// The server address the page was opened with (the web only), so the
/// sign-in form can start filled in. Null elsewhere or when absent.
String? launchServerParam() {
  if (debugLaunchServerParam case final fake?) return fake();
  final uri = page.currentPageUri();
  return uri == null ? null : serverParamIn(uri);
}

/// The server address in a page address: `#server=<url>` (a fragment, which
/// the browser never sends to the site's host) or `?server=<url>`.
String? serverParamIn(Uri page) {
  String? clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  if (page.fragment.contains('server=')) {
    try {
      final value = clean(Uri.splitQueryString(page.fragment)['server']);
      if (value != null) return value;
    } on FormatException {
      // Not a key=value fragment.
    }
  }
  return clean(page.queryParameters['server']);
}

/// The address of the page itself (the web only; null elsewhere).
Uri? pageOrigin() => debugPageOrigin ?? page.currentPageUri();

/// What stops a browser from using a server address.
enum SignInProblem { needsHttps }

/// A page served over https can't call an http server (the browser blocks
/// it), except on this computer for local testing.
SignInProblem? checkServerForWeb(Uri server, {required Uri pageOrigin}) {
  if (server.scheme != 'http' || pageOrigin.scheme != 'https') return null;
  // Uri.host has no brackets for IPv6: http://[::1]:8787 gives '::1'.
  const local = {'localhost', '127.0.0.1', '::1'};
  if (local.contains(server.host)) return null;
  return SignInProblem.needsHttps;
}
