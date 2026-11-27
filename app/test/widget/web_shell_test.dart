import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/app_settings.dart';
import 'package:taskwise/platform/web_shell.dart';

import 'app_test.dart' show appTest;

/// Pretends to be the browser around the web app.
class FakeWebShell implements WebShell {
  FakeWebShell({this.isIosBrowserTab = false, this.guideDismissed = false});

  @override
  final bool isIosBrowserTab;

  @override
  bool guideDismissed;

  final newVersion$ = StreamController<void>.broadcast();
  final safeArea$ = StreamController<EdgeInsets>.broadcast();
  int reloads = 0;

  @override
  Stream<EdgeInsets> get safeAreaInsets => safeArea$.stream;

  @override
  Stream<void> get newVersionReady => newVersion$.stream;

  @override
  void dismissGuide() => guideDismissed = true;

  @override
  void reload() => reloads++;
}

const _taskList = 'Add a task and press Enter';
const _guideTitle = 'Add Taskwise to your Home Screen';
const _continue = 'Continue in the browser anyway';
const _newVersion = 'A new version of Taskwise is ready.';

void main() {
  group('Home Screen guide', () {
    final iosTab = FakeWebShell(isIosBrowserTab: true);

    appTest(
      'an iPhone Safari tab shows the guide first; "Continue in the browser '
      'anyway" shows the task list',
      (tester, repo) async {
        expect(find.text(_guideTitle), findsOneWidget);
        expect(find.textContaining('Add to Home Screen'), findsWidgets);
        expect(find.text(_taskList), findsNothing);

        await tester.tap(find.text(_continue));
        await tester.pumpAndSettle();
        expect(find.text(_guideTitle), findsNothing);
        expect(find.text(_taskList), findsOneWidget);
        // Not shown again in this tab.
        expect(iosTab.guideDismissed, isTrue);
      },
      overrides: [webShellProvider.overrideWithValue(iosTab)],
    );

    appTest(
      'not again once dismissed in this tab',
      (tester, repo) async {
        expect(find.text(_guideTitle), findsNothing);
        expect(find.text(_taskList), findsOneWidget);
      },
      overrides: [
        webShellProvider.overrideWithValue(
          FakeWebShell(isIosBrowserTab: true, guideDismissed: true),
        ),
      ],
    );

    appTest('anywhere else the task list comes straight away', (
      tester,
      repo,
    ) async {
      expect(find.text(_guideTitle), findsNothing);
      expect(find.text(_taskList), findsOneWidget);
    }, overrides: [webShellProvider.overrideWithValue(FakeWebShell())]);
  });

  group('new version', () {
    final shell = FakeWebShell();

    appTest('a waiting new version shows the bar; Reload reloads once', (
      tester,
      repo,
    ) async {
      expect(find.text(_newVersion), findsNothing);
      shell.newVersion$.add(null);
      await tester.pumpAndSettle();
      expect(find.text(_newVersion), findsOneWidget);
      // A second notice doesn't add a second bar.
      shell.newVersion$.add(null);
      await tester.pumpAndSettle();
      expect(find.text(_newVersion), findsOneWidget);

      await tester.tap(find.text('Reload'));
      await tester.pumpAndSettle();
      expect(shell.reloads, 1);
      expect(find.text(_newVersion), findsNothing);
    }, overrides: [webShellProvider.overrideWithValue(shell)]);
  });

  group('iPhone safe areas', () {
    final shell = FakeWebShell();

    appTest("the browser's safe area insets reach the app's layout", (
      tester,
      repo,
    ) async {
      // What the design's shell (under the app's Navigator) sees.
      MediaQueryData shellSees() =>
          MediaQuery.of(tester.element(find.byType(Navigator).first));
      expect(shellSees().padding.bottom, 0);
      await tester.enterText(find.byType(TextField).first, 'half a task');

      // viewport-fit=cover: the page runs under the home indicator.
      shell.safeArea$.add(const EdgeInsets.only(bottom: 34));
      await tester.pumpAndSettle();
      expect(shellSees().padding.bottom, 34);
      expect(shellSees().viewPadding.bottom, 34);
      // The shell kept its state.
      expect(find.text('half a task'), findsOneWidget);
    }, overrides: [webShellProvider.overrideWithValue(shell)]);
  });

  group('in Arabic', () {
    final shell = FakeWebShell(isIosBrowserTab: true);

    appTest(
      'the guide and the bar',
      (tester, repo) async {
        expect(find.text('أضف Taskwise إلى الشاشة الرئيسية'), findsOneWidget);
        shell.newVersion$.add(null);
        await tester.pumpAndSettle();
        expect(find.text('إصدار جديد من Taskwise جاهز.'), findsOneWidget);
        expect(find.text('أعد التحميل'), findsOneWidget);

        await tester.tap(find.text('المتابعة في المتصفح على أي حال'));
        await tester.pumpAndSettle();
        expect(find.text('أضف Taskwise إلى الشاشة الرئيسية'), findsNothing);
      },
      settings: const AppSettings(language: AppLanguage.ar),
      overrides: [webShellProvider.overrideWithValue(shell)],
    );
  });

  test('outside the browser there is no web shell', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final shell = container.read(webShellProvider);
    expect(shell, isA<NoWebShell>());
    expect(shell.isIosBrowserTab, isFalse);
    expect(await shell.newVersionReady.isEmpty, isTrue);
    expect(await shell.safeAreaInsets.isEmpty, isTrue);
  });

  group('isIosBrowserTabFor', () {
    const iPhoneSafari =
        'Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 '
        'Mobile/15E148 Safari/604.1';
    // iPadOS asks for desktop sites by default and says "Macintosh".
    const iPadDesktop =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Safari/605.1.15';
    const android =
        'Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

    bool check(
      String ua, {
      int touchPoints = 5,
      bool navigatorStandalone = false,
      bool displayModeStandalone = false,
    }) => isIosBrowserTabFor(
      userAgent: ua,
      maxTouchPoints: touchPoints,
      navigatorStandalone: navigatorStandalone,
      displayModeStandalone: displayModeStandalone,
    );

    test('an iPhone or iPad Safari tab', () {
      expect(check(iPhoneSafari), isTrue);
      expect(check(iPadDesktop), isTrue);
    });

    test('not the Home Screen app', () {
      expect(check(iPhoneSafari, navigatorStandalone: true), isFalse);
      expect(check(iPhoneSafari, displayModeStandalone: true), isFalse);
    });

    test('not other devices', () {
      expect(check(android), isFalse);
      // A Mac has no touch screen.
      expect(check(iPadDesktop, touchPoints: 0), isFalse);
      expect(check(''), isFalse);
    });
  });
}
