import 'package:flutter/foundation.dart';

import 'platform_description_stub.dart'
    if (dart.library.io) 'platform_description_io.dart';

/// Where this copy of Taskwise runs. Use this instead of `Platform.isX`
/// (from `dart:io`), which throws in the browser.
enum AppTarget { windows, linux, ios, android, web, other }

/// Maps the Flutter platform values to an [AppTarget]. The web wins over
/// [platform], which only says which OS the browser runs on.
AppTarget appTargetFor({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (isWeb) return AppTarget.web;
  return switch (platform) {
    TargetPlatform.windows => AppTarget.windows,
    TargetPlatform.linux => AppTarget.linux,
    TargetPlatform.iOS => AppTarget.ios,
    TargetPlatform.android => AppTarget.android,
    _ => AppTarget.other,
  };
}

/// Tests set this to pretend to run somewhere else; reset it in `tearDown`.
@visibleForTesting
AppTarget? debugAppTargetOverride;

AppTarget get appTarget =>
    debugAppTargetOverride ??
    appTargetFor(isWeb: kIsWeb, platform: defaultTargetPlatform);

extension AppTargetX on AppTarget {
  bool get isDesktop => this == AppTarget.windows || this == AppTarget.linux;

  /// Phones: the system schedules reminders, and location reminders fire.
  bool get isMobile => this == AppTarget.ios || this == AppTarget.android;

  bool get isWeb => this == AppTarget.web;
}

/// Shown in the start log line, e.g. "Linux 6.x" or "web (iOS)".
String platformDescription() => appTarget.isWeb
    ? 'web (${defaultTargetPlatform.name})'
    : nativePlatformDescription();
