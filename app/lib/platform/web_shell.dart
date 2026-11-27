import 'package:flutter/widgets.dart' show EdgeInsets;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_target.dart';
import 'web_shell_stub.dart'
    if (dart.library.js_interop) 'web_shell_web.dart'
    as impl;

/// The browser around the web app: the iPhone Safari tab check (see
/// `AddToHomeScreenGate`), the service worker's new versions (see
/// `NewVersionBar`) and the iPhone's safe areas (see `BrowserSafeArea`).
/// [NoWebShell] outside the browser.
abstract class WebShell {
  /// An iPhone or iPad Safari tab, not the Home Screen app. The two keep
  /// separate storage on iOS, so the tab suggests the Home Screen first.
  bool get isIosBrowserTab;

  /// "Continue in Safari anyway" was chosen in this tab already.
  bool get guideDismissed;

  /// Remembers [guideDismissed] for this tab (until it's closed).
  void dismissGuide();

  /// An event each time a new version of the web app is waiting
  /// (installed by the service worker). Late listeners still hear about a
  /// version that is already waiting.
  Stream<void> get newVersionReady;

  /// Switches to the waiting version and reloads the page.
  void reload();

  /// The page's `env(safe-area-inset-*)`: now, then after each resize.
  /// The page covers the whole screen (`viewport-fit=cover`), and Flutter
  /// doesn't read these itself.
  Stream<EdgeInsets> get safeAreaInsets;
}

/// Outside the browser: nothing to do.
class NoWebShell implements WebShell {
  const NoWebShell();

  @override
  bool get isIosBrowserTab => false;

  @override
  bool get guideDismissed => false;

  @override
  void dismissGuide() {}

  @override
  Stream<void> get newVersionReady => const Stream.empty();

  @override
  void reload() {}

  @override
  Stream<EdgeInsets> get safeAreaInsets => const Stream.empty();
}

class BrowserWebShell implements WebShell {
  const BrowserWebShell();

  @override
  bool get isIosBrowserTab => impl.isIosBrowserTab();

  @override
  bool get guideDismissed => impl.guideDismissed();

  @override
  void dismissGuide() => impl.dismissGuide();

  @override
  Stream<void> get newVersionReady => impl.newVersionReady();

  @override
  void reload() => impl.reloadToNewVersion();

  @override
  Stream<EdgeInsets> get safeAreaInsets => impl.safeAreaInsets();
}

final webShellProvider = Provider<WebShell>(
  (ref) => appTarget.isWeb ? const BrowserWebShell() : const NoWebShell(),
);

/// Whether a browser with this [userAgent] is an iPhone/iPad tab rather
/// than the Home Screen app. [navigatorStandalone] is Safari's
/// `navigator.standalone`; [displayModeStandalone] is
/// `matchMedia('(display-mode: standalone)')`.
bool isIosBrowserTabFor({
  required String userAgent,
  required int maxTouchPoints,
  required bool navigatorStandalone,
  required bool displayModeStandalone,
}) {
  final ios =
      RegExp('iPhone|iPad|iPod').hasMatch(userAgent) ||
      // iPadOS asks for desktop sites and says "Macintosh"; only the touch
      // screen tells it from a Mac.
      (userAgent.contains('Macintosh') && maxTouchPoints > 1);
  return ios && !navigatorStandalone && !displayModeStandalone;
}
