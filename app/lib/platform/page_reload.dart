import 'package:flutter/foundation.dart';

import 'page_reload_stub.dart'
    if (dart.library.js_interop) 'page_reload_web.dart'
    as impl;

/// Tests set this to see a reload instead of doing it.
@visibleForTesting
void Function()? debugReloadPage;

/// Reloads the page in the browser (`window.location.reload()`). Does
/// nothing outside the browser.
void reloadPage() {
  if (debugReloadPage case final fake?) return fake();
  impl.reloadPage();
}
