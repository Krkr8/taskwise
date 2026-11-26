import 'dart:async';
import 'dart:io' show Platform;

import 'package:taskwise/platform/app_target.dart';

/// flutter_test pretends to run on Android; the app's own checks used to
/// see the real host (`Platform.isX`). Keep that, so tests see the desktop
/// they run on. Tests that need another target set the override themselves.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  debugAppTargetOverride = Platform.isWindows
      ? AppTarget.windows
      : AppTarget.linux;
  await testMain();
}
