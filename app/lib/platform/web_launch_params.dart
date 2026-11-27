import 'package:flutter/foundation.dart';

import 'launch_params_stub.dart'
    if (dart.library.js_interop) 'launch_params_web.dart'
    as page;

/// Tests set these to pretend to run in a browser at some address.
@visibleForTesting
String? Function()? debugLaunchServerParam;

@visibleForTesting
Uri? debugPageOrigin;

/// The `?server=` address the page was opened with (the web only), so
/// the sign-in form can start filled in. Null elsewhere or when absent.
String? launchServerParam() {
  if (debugLaunchServerParam case final fake?) return fake();
  final value = page.currentPageUri()?.queryParameters['server']?.trim();
  return value == null || value.isEmpty ? null : value;
}

/// The address of the page itself (the web only; null elsewhere).
Uri? pageOrigin() => debugPageOrigin ?? page.currentPageUri();

/// What stops a browser from using a server address.
enum SignInProblem { needsHttps }

/// A page served over https can't call an http server (the browser blocks
/// it), except on this computer for local testing.
SignInProblem? checkServerForWeb(Uri server, {required Uri pageOrigin}) {
  if (server.scheme != 'http' || pageOrigin.scheme != 'https') return null;
  if (server.host == 'localhost' || server.host == '127.0.0.1') return null;
  return SignInProblem.needsHttps;
}
