import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool?> requestPersistentStorage() async {
  try {
    return (await web.window.navigator.storage.persist().toDart).toDart;
  } on Object {
    // Older browsers have no `navigator.storage`.
    return null;
  }
}
