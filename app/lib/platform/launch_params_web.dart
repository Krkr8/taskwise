import 'dart:js_interop';

/// `#server=…` from the address the page was opened with: index.html keeps
/// it here and removes it from the address before Flutter starts (Flutter
/// would read it as a page of the app, then replace it).
@JS('taskwiseLaunchHash')
external JSString? get _launchHash;

Uri? currentPageUri() {
  final hash = _launchHash?.toDart;
  return hash == null ? Uri.base : Uri.base.replace(fragment: hash);
}
