import 'dart:io' show Platform;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the device token lives: the system keychain (Windows Credential
/// Manager, the GNOME keyring through libsecret, the iOS Keychain).
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'taskwise_device_token';

  /// iOS: readable after the first unlock since the phone started, so
  /// background sync works while the phone is locked. The keychain matches
  /// on this attribute, so tokens saved before M7 (readable only while
  /// unlocked) are moved over by [read].
  static const _ios = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  /// How tokens were stored before M7.
  static const _iosBefore = IOSOptions();

  @override
  Future<String?> read() async {
    final token = await _storage.read(key: _key, iOptions: _ios);
    if (token != null || !Platform.isIOS) return token;
    final old = await _storage.read(key: _key, iOptions: _iosBefore);
    if (old != null) {
      await _storage.write(key: _key, value: old, iOptions: _ios);
      await _storage.delete(key: _key, iOptions: _iosBefore);
    }
    return old;
  }

  @override
  Future<void> write(String token) =>
      _storage.write(key: _key, value: token, iOptions: _ios);

  @override
  Future<void> delete() async {
    await _storage.delete(key: _key, iOptions: _ios);
    if (Platform.isIOS) {
      await _storage.delete(key: _key, iOptions: _iosBefore);
    }
  }
}

/// Keeps the token in memory (tests).
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;

  @override
  Future<void> delete() async => token = null;
}
