import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/platform/app_target.dart';

void main() {
  final hostTarget = debugAppTargetOverride;
  tearDown(() => debugAppTargetOverride = hostTarget);

  test('the web wins over the browser OS', () {
    expect(
      appTargetFor(isWeb: true, platform: TargetPlatform.iOS),
      AppTarget.web,
    );
  });

  test('native platforms map one to one, macOS is other', () {
    AppTarget f(TargetPlatform p) => appTargetFor(isWeb: false, platform: p);
    expect(f(TargetPlatform.windows), AppTarget.windows);
    expect(f(TargetPlatform.linux), AppTarget.linux);
    expect(f(TargetPlatform.iOS), AppTarget.ios);
    expect(f(TargetPlatform.android), AppTarget.android);
    expect(f(TargetPlatform.macOS), AppTarget.other);
  });

  test('desktop, mobile and web flags', () {
    expect(AppTarget.web.isDesktop, isFalse);
    expect(AppTarget.web.isMobile, isFalse);
    expect(AppTarget.web.isWeb, isTrue);
    expect(AppTarget.linux.isDesktop, isTrue);
    expect(AppTarget.android.isMobile, isTrue);
  });

  test('the override changes appTarget and platformDescription', () {
    debugAppTargetOverride = AppTarget.web;
    expect(appTarget, AppTarget.web);
    // The start log says "started on web (<platform>)", not "web (web (…))".
    expect(platformDescription(), defaultTargetPlatform.name);
  });
}
