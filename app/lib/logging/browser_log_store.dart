import 'app_log.dart';
import 'browser_log_store_stub.dart'
    if (dart.library.js_interop) 'browser_log_store_web.dart'
    as impl;

/// The browser's `localStorage`, where the web app keeps its newest log
/// lines between visits; null outside the browser or when it's blocked.
KeyValueStore? browserLogStore() => impl.browserLogStore();
