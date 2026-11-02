import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException, HandshakeException;

import 'package:http/http.dart' as http;
import 'package:taskwise_shared/taskwise_shared.dart';

import 'record_codec.dart';

/// Why a request to the sync server failed.
sealed class SyncApiException implements Exception {
  const SyncApiException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The server couldn't be reached (offline, wrong address, timeout...).
final class SyncNetworkException extends SyncApiException {
  const SyncNetworkException(super.message);
}

/// The server answered with an error (`{error: {code, message}}`).
final class SyncHttpException extends SyncApiException {
  const SyncHttpException(
    this.status,
    this.code,
    super.message, {
    this.retryAfter,
  });

  final int status;

  /// Error code from docs/sync-api.md, e.g. `unauthorized`.
  final String code;

  /// From the `Retry-After` header (rate limiting).
  final Duration? retryAfter;
}

/// The reply to a login: the device token and the device as registered.
typedef LoginResult = ({String token, Device device});

/// One page of a pull.
typedef PullPage = ({
  List<({String type, int seq, Map<String, Object?> record})> changes,
  int nextSince,
  bool hasMore,
});

/// HTTP client for the sync API (docs/sync-api.md).
class SyncApi {
  SyncApi({required String baseUrl, this.token, http.Client? client})
    : baseUri = normalizeServerUrl(baseUrl),
      _client = client ?? http.Client();

  /// The server root, e.g. `https://taskwise.vercel.app`.
  final Uri baseUri;
  final String? token;
  final http.Client _client;

  static const timeout = Duration(seconds: 20);

  /// Max changes per push (server limit).
  static const maxPushChanges = 500;

  /// Turns what the user typed into a server root: adds `https://` when no
  /// scheme is given and drops a trailing slash or `/api/v1`.
  static Uri normalizeServerUrl(String input) {
    var text = input.trim();
    if (!text.contains('://')) text = 'https://$text';
    var uri = Uri.parse(text);
    var path = uri.path;
    if (path.endsWith('/')) path = path.substring(0, path.length - 1);
    if (path.endsWith(AppInfo.apiBasePath)) {
      path = path.substring(0, path.length - AppInfo.apiBasePath.length);
    }
    uri = uri.replace(path: path, query: null, fragment: null);
    if (!uri.hasAuthority || uri.host.isEmpty) {
      throw const FormatException('Not a server address');
    }
    return uri;
  }

  SyncApi withToken(String token) =>
      SyncApi(baseUrl: baseUri.toString(), token: token, client: _client);

  /// Checks the server and its database answer. Throws if not.
  Future<void> health() async {
    final body = await _send('GET', '/health');
    if (body['status'] != 'ok') {
      throw const SyncHttpException(503, 'not_ok', 'Server is not healthy');
    }
  }

  /// Creates the one account (needs the server's setup secret).
  Future<void> setup({
    required String setupSecret,
    required String username,
    required String password,
  }) => _send(
    'POST',
    '/auth/setup',
    body: {
      'setupSecret': setupSecret,
      'username': username,
      'password': password,
    },
  );

  Future<LoginResult> login({
    required String username,
    required String password,
    required String deviceId,
    required String deviceName,
    required DeviceType deviceType,
  }) async {
    final body = await _send(
      'POST',
      '/auth/login',
      body: {
        'username': username,
        'password': password,
        'device': {'id': deviceId, 'name': deviceName, 'type': deviceType.name},
      },
    );
    return (
      token: body['token']! as String,
      device: Device.fromJson((body['device']! as Map).cast()),
    );
  }

  /// Pushes up to [maxPushChanges] changes; returns `applied`/`stale` per
  /// change, in order.
  Future<List<String>> push(List<SyncChange> changes) async {
    final body = await _send(
      'POST',
      '/sync',
      body: {
        'changes': [
          for (final c in changes) {'type': c.type, 'record': c.record},
        ],
      },
    );
    return [
      for (final r in (body['results']! as List).cast<Map<String, Object?>>())
        r['status']! as String,
    ];
  }

  Future<PullPage> pull({required int since, int limit = 500}) async {
    final body = await _send('GET', '/sync?since=$since&limit=$limit');
    return (
      changes: [
        for (final c in (body['changes']! as List).cast<Map<String, Object?>>())
          (
            type: c['type']! as String,
            seq: c['seq']! as int,
            record: (c['record']! as Map).cast<String, Object?>(),
          ),
      ],
      nextSince: body['nextSince']! as int,
      hasMore: body['hasMore']! as bool,
    );
  }

  Future<List<Device>> devices() async {
    final body = await _send('GET', '/devices');
    return [
      for (final d in (body['devices']! as List).cast<Map<String, Object?>>())
        Device.fromJson(d),
    ];
  }

  Future<Device> renameDevice(String id, String name) async => Device.fromJson(
    await _send(
      'PATCH',
      '/devices/${Uri.encodeComponent(id)}',
      body: {'name': name},
    ),
  );

  /// Revokes a device's token (this device too: that's signing out).
  Future<void> revokeDevice(String id) =>
      _send('DELETE', '/devices/${Uri.encodeComponent(id)}');

  void close() => _client.close();

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    Object? body,
  }) async {
    final uri = Uri.parse('$baseUri${AppInfo.apiBasePath}$path');
    final request = http.Request(method, uri);
    request.headers['accept'] = 'application/json';
    if (token case final token?) {
      request.headers['authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const SyncNetworkException('The server took too long to answer');
    } on SocketException catch (e) {
      throw SyncNetworkException(e.message);
    } on HandshakeException catch (e) {
      throw SyncNetworkException(e.message);
    } on http.ClientException catch (e) {
      throw SyncNetworkException(e.message);
    }

    Object? json;
    try {
      json = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      json = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (json is Map<String, Object?>) return json;
      throw SyncHttpException(
        response.statusCode,
        'bad_response',
        'Not a Taskwise server (unexpected reply)',
      );
    }
    final error = json is Map && json['error'] is Map
        ? (json['error'] as Map).cast<String, Object?>()
        : const <String, Object?>{};
    final retry = int.tryParse(response.headers['retry-after'] ?? '');
    throw SyncHttpException(
      response.statusCode,
      error['code'] as String? ??
          (response.statusCode == 404
              ? 'not_found'
              : 'http_${response.statusCode}'),
      error['message'] as String? ?? 'HTTP ${response.statusCode}',
      retryAfter: retry == null ? null : Duration(seconds: retry),
    );
  }
}
