// Runs an integration test in profile mode, for the performance check:
//
//   cd app && flutter drive --profile -d linux \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/performance_test.dart
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
