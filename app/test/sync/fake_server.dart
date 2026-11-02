import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// An in-memory sync server with the same rules as `server/`
/// (docs/sync-api.md): last write wins per record, a change sequence,
/// devices with tokens. Tests use it as the engine's HTTP client.
class FakeSyncServer {
  FakeSyncServer({this.username = 'owner', this.password = 'a long password'});

  final String username;
  final String password;

  /// (type, id) -> (seq, record)
  final records = <(String, String), (int, Map<String, Object?>)>{};
  int seq = 0;

  /// Devices by id, with their token and revoked flag.
  final devices = <String, Map<String, Object?>>{};
  final tokens = <String, String>{}; // token -> device id
  int _tokenCount = 0;

  /// Set to make every request fail like a network error.
  bool offline = false;

  /// Set to make the next pull with since > 0 answer 410.
  bool requireResync = false;

  /// Runs while a push is being handled, before the reply (to simulate
  /// edits made on the device during a push).
  Future<void> Function()? onPush;

  /// Requests seen, as "METHOD /path".
  final requests = <String>[];

  late final http.Client client = MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    if (offline) throw http.ClientException('offline');
    final path = request.url.path.replaceFirst('/api/v1', '');
    requests.add('${request.method} $path');
    final body = request.body.isEmpty
        ? null
        : jsonDecode(request.body) as Map<String, Object?>;

    if (path == '/health') return _json({'status': 'ok', 'apiVersion': 1});
    if (path == '/auth/login') {
      if (body!['username'] != username || body['password'] != password) {
        return _error(401, 'unauthorized');
      }
      final device = (body['device']! as Map).cast<String, Object?>();
      final token = 'tw_${_tokenCount++}';
      tokens.removeWhere((_, id) => id == device['id']);
      tokens[token] = device['id']! as String;
      final hasMain = devices.values.any(
        (d) => d['main'] == true && d['deleted'] != true,
      );
      final existing = devices[device['id']];
      devices[device['id']! as String] = {
        ...device,
        'main': (existing?['main'] ?? false) == true || !hasMain,
        'lastSeenAt': '2026-11-02T10:00:00.000Z',
        'updatedAt': '2026-11-02T10:00:00.000Z',
        'deleted': false,
        'updatedByDevice': null,
      };
      return _json({'token': token, 'device': devices[device['id']]});
    }

    final auth = request.headers['authorization']?.replaceFirst('Bearer ', '');
    final deviceId = tokens[auth];
    if (deviceId == null || devices[deviceId]?['deleted'] == true) {
      return _error(401, 'unauthorized');
    }

    if (path == '/sync' && request.method == 'POST') {
      await onPush?.call();
      final results = <Map<String, Object?>>[];
      for (final change
          in (body!['changes']! as List).cast<Map<String, Object?>>()) {
        final type = change['type']! as String;
        final record = {
          ...(change['record']! as Map).cast<String, Object?>(),
          'updatedByDevice': deviceId,
        };
        final key = (type, record['id']! as String);
        final current = records[key]?.$2;
        seq++;
        final wins = current == null || _compare(record, current) > 0;
        if (wins) records[key] = (seq, record);
        results.add({
          'type': type,
          'id': key.$2,
          'status': wins ? 'applied' : 'stale',
        });
      }
      return _json({'results': results, 'seq': seq});
    }
    if (path == '/sync' && request.method == 'GET') {
      final since = int.parse(request.url.queryParameters['since'] ?? '0');
      final limit = int.parse(request.url.queryParameters['limit'] ?? '500');
      if (requireResync && since > 0) {
        requireResync = false;
        return _error(410, 'resync_required');
      }
      final changes = [
        for (final MapEntry(key: (type, _), value: (s, record))
            in records.entries)
          if (s > since) {'type': type, 'seq': s, 'record': record},
      ]..sort((a, b) => (a['seq']! as int).compareTo(b['seq']! as int));
      final page = changes.take(limit).toList();
      return _json({
        'changes': page,
        'nextSince': page.isEmpty ? since : page.last['seq'],
        'hasMore': changes.length > limit,
      });
    }
    if (path == '/devices') return _json({'devices': devices.values.toList()});
    final me = devices[deviceId]!;
    if (path == '/devices/claim-main') {
      if (body!['password'] != password) return _error(403, 'wrong_password');
      for (final d in devices.values) {
        d['main'] = false;
      }
      me['main'] = true;
      return _json(me);
    }
    if (path.startsWith('/devices/')) {
      final id = Uri.decodeComponent(path.substring('/devices/'.length));
      final device = devices[id];
      if (device == null) return _error(404, 'not_found');
      final isMain = me['main'] == true;
      if (id != deviceId && !isMain) return _error(403, 'forbidden');
      if (request.method == 'PATCH') {
        if (body!['name'] case final String name) device['name'] = name;
        if (body['main'] == true) {
          if (!isMain) return _error(403, 'forbidden');
          for (final d in devices.values) {
            d['main'] = false;
          }
          device['main'] = true;
        }
      }
      if (request.method == 'DELETE') {
        device['deleted'] = true;
        device['main'] = false;
      }
      return _json(device);
    }
    return _error(404, 'not_found');
  }

  static int _compare(Map<String, Object?> a, Map<String, Object?> b) {
    final byTime = DateTime.parse(a['updatedAt']! as String)
        .compareTo(DateTime.parse(b['updatedAt']! as String));
    if (byTime != 0) return byTime;
    return (a['updatedByDevice'] as String? ?? '').compareTo(
      b['updatedByDevice'] as String? ?? '',
    );
  }

  /// The stored record of [type] with [id].
  Map<String, Object?>? record(String type, String id) =>
      records[(type, id)]?.$2;

  static http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  static http.Response _error(int status, String code) => _json({
    'error': {'code': code, 'message': code},
  }, status);
}
