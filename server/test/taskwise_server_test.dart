import 'package:taskwise_server/taskwise_server.dart';
import 'package:test/test.dart';

void main() {
  test('startup banner names the product and API path', () {
    expect(startupBanner(), allOf(contains('Taskwise'), contains('/api/v1')));
  });
}
