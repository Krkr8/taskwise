import 'package:web/web.dart' as web;

import 'app_log.dart';

KeyValueStore? browserLogStore() {
  try {
    // Throws when the browser blocks site data.
    return _LocalStorage(web.window.localStorage);
  } on Object {
    return null;
  }
}

final class _LocalStorage implements KeyValueStore {
  _LocalStorage(this._storage);

  final web.Storage _storage;

  @override
  String? read(String key) => _storage.getItem(key);

  @override
  void write(String key, String value) => _storage.setItem(key, value);

  @override
  void remove(String key) => _storage.removeItem(key);
}
