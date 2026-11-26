import 'persistent_storage_stub.dart'
    if (dart.library.js_interop) 'persistent_storage_web.dart'
    as impl;

/// Asks the browser to keep this site's data (the tasks) even when the
/// disk gets full (`navigator.storage.persist()`). True when it will, false
/// when it may still clear it, null outside the browser or when the browser
/// can't say. Some browsers ask the user first, so don't wait for it.
Future<bool?> requestPersistentStorage() => impl.requestPersistentStorage();
