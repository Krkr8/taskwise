import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskwise/sync/sync_api.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

/// The push endpoints answer `204 No Content` (server/src/routes/push.ts).
void main() {
  late List<String> seen;
  late SyncApi api;

  setUp(() {
    seen = [];
    api = SyncApi(
      baseUrl: 'sync.test',
      token: 'tw_1',
      client: MockClient((request) async {
        seen.add('${request.method} ${request.url.path} ${request.body}');
        return http.Response('', 204);
      }),
    );
  });

  test('saving a subscription accepts 204', () async {
    await api.putPushSubscription(
      endpoint: 'https://push.test/abc',
      p256dh: 'p',
      auth: 'a',
    );
    expect(seen.single, startsWith('PUT /api/v1/push/subscription '));
    expect(jsonDecode(seen.single.split(' ').skip(2).join(' ')), {
      'endpoint': 'https://push.test/abc',
      'keys': {'p256dh': 'p', 'auth': 'a'},
    });
  });

  test('deleting a subscription accepts 204', () async {
    await api.deletePushSubscription('https://push.test/abc');
    expect(seen.single, startsWith('DELETE /api/v1/push/subscription '));
  });

  test('uploading a plan accepts 204', () async {
    await api.putPushPlan('web1', [
      PushPlanItem(
        key: 'k',
        fireAt: DateTime.utc(2026, 11, 29, 8),
        taskId: 't',
        title: 'Pay rent',
        body: 'Today',
      ),
    ]);
    expect(seen.single, startsWith('PUT /api/v1/push/plan/web1 '));
  });

  test('a 200 without JSON is still not a Taskwise server', () async {
    final other = SyncApi(
      baseUrl: 'sync.test',
      client: MockClient((_) async => http.Response('<html>', 200)),
    );
    await expectLater(
      other.health(),
      throwsA(
        isA<SyncHttpException>().having((e) => e.code, 'code', 'bad_response'),
      ),
    );
  });
}
