import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart' show EdgeInsets;
import 'package:web/web.dart' as web;

import 'page_reload_web.dart';
import 'web_shell.dart' show isIosBrowserTabFor;

// The page side of the service worker lives in web/index.html: it sets
// `taskwiseNewVersionReady`, fires `taskwise-new-version` and defines
// `taskwiseReloadToNewVersion()`.
const _newVersionEvent = 'taskwise-new-version';
const _guideKey = 'taskwise.homeScreenGuideDismissed';

bool isIosBrowserTab() {
  final navigator = web.window.navigator;
  return isIosBrowserTabFor(
    userAgent: navigator.userAgent,
    maxTouchPoints: navigator.maxTouchPoints,
    // Safari only; undefined elsewhere.
    navigatorStandalone: _isTrue(
      (navigator as JSObject).getProperty<JSAny?>('standalone'.toJS),
    ),
    displayModeStandalone: web.window
        .matchMedia('(display-mode: standalone)')
        .matches,
  );
}

bool guideDismissed() {
  try {
    return web.window.sessionStorage.getItem(_guideKey) == '1';
  } on Object {
    return false;
  }
}

void dismissGuide() {
  try {
    web.window.sessionStorage.setItem(_guideKey, '1');
  } on Object {
    // No session storage: the guide comes back after a reload.
  }
}

Stream<void> newVersionReady() => Stream<void>.multi((controller) {
  if (_isTrue(
    globalContext.getProperty<JSAny?>('taskwiseNewVersionReady'.toJS),
  )) {
    controller.add(null);
  }
  final sub = web.EventStreamProvider<web.Event>(_newVersionEvent)
      .forTarget(web.window)
      .listen((_) => controller.add(null));
  controller.onCancel = sub.cancel;
});

void reloadToNewVersion() {
  if (globalContext.has('taskwiseReloadToNewVersion')) {
    globalContext.callMethod<JSAny?>('taskwiseReloadToNewVersion'.toJS);
  } else {
    reloadPage();
  }
}

Stream<EdgeInsets> safeAreaInsets() => Stream<EdgeInsets>.multi((controller) {
  // CSS only tells an element's own `env()`; this one measures them.
  final probe = web.document.createElement('div') as web.HTMLElement;
  probe.style.cssText =
      'position:fixed;top:0;left:0;width:0;height:0;visibility:hidden;'
      'pointer-events:none;padding:env(safe-area-inset-top) '
      'env(safe-area-inset-right) env(safe-area-inset-bottom) '
      'env(safe-area-inset-left)';
  web.document.body?.append(probe);
  double px(web.CSSStyleDeclaration style, String side) =>
      double.tryParse(
        style.getPropertyValue('padding-$side').replaceAll('px', ''),
      ) ??
      0;
  void measure() {
    final style = web.window.getComputedStyle(probe);
    controller.add(
      EdgeInsets.fromLTRB(
        px(style, 'left'),
        px(style, 'top'),
        px(style, 'right'),
        px(style, 'bottom'),
      ),
    );
  }

  measure();
  final sub = web.EventStreamProviders.resizeEvent
      .forTarget(web.window)
      .listen((_) => measure());
  controller.onCancel = () {
    sub.cancel();
    probe.remove();
  };
});

bool _isTrue(JSAny? value) => value.dartify() == true;
