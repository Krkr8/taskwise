import 'page_reload_stub.dart'
    if (dart.library.js_interop) 'page_reload_web.dart'
    as impl;

/// Reloads the page in the browser (`window.location.reload()`). Does
/// nothing outside the browser.
void reloadPage() => impl.reloadPage();
