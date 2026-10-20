import 'package:taskwise_shared/taskwise_shared.dart';
import 'package:test/test.dart';

void main() {
  test('apiBasePath is versioned', () {
    expect(AppInfo.apiBasePath, '/api/v1');
  });
}
