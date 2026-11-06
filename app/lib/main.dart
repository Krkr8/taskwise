import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'background/background_sync.dart';
import 'bootstrap.dart';
import 'desktop/desktop_shell.dart';
import 'logging/app_log.dart';
import 'version.dart';

export 'bootstrap.dart' show configureIntl;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  installErrorLogging();

  if (AppBootstrap.isDesktop) {
    // A second launch just shows the running Taskwise.
    final shell = await DesktopShell.start(
      hidden: args.contains(DesktopShell.hiddenArg),
    );
    if (shell == null) exit(0);
  }

  final boot = await AppBootstrap.start();
  appLog.info(
    'app',
    'Taskwise $appVersion started on ${boot.deviceType.name} '
        '(${Platform.operatingSystemVersion})',
  );
  await DesktopShell.instance?.apply(boot.settings);
  // iPhone: let iOS sync in the background now and then.
  unawaited(registerBackgroundSync());

  runApp(ProviderScope(overrides: boot.overrides, child: const TaskwiseApp()));
}
