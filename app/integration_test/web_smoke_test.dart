// The web app in a real browser, against a local sync server: sign in, add a
// task, find it on the server, reload the page, and a second tab on the same
// data (docs/dev-setup-fedora.md, "The web app"):
//
//   (cd server && DATABASE_URL=:memory: SETUP_SECRET=live-test-secret \
//      PORT=8787 npx tsx src/node.ts) &
//   chromedriver --port=4444 &
//   cd app && flutter drive -d web-server --browser-name=chrome \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/web_smoke_test.dart \
//     --dart-define=SERVER=http://localhost:8787
//
// The account is created with the setup secret if the server has none yet
// (--dart-define=SETUP_SECRET=…, default the live test's).
//
// flutter drive opens this page, the conductor. It never opens the database
// itself (its tab would keep the browser's storage worker alive across the
// reload). It opens the real app in other tabs of the same page
// (`?smoke=<role>`), which report back over a BroadcastChannel:
//
//   1. writer tab: starts the app, signs in, adds a task;
//   2. the conductor finds the task with its own token (GET /sync);
//   3. the conductor reloads the writer tab: the task is in the database
//      before the app syncs (the browser kept it);
//   4. a second tab, while the first is open: shows the task and adds one,
//      which the first tab sees; the database passes an integrity check.
@Timeout(Duration(minutes: 10))
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:taskwise/app.dart';
import 'package:taskwise/bootstrap.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/storage_status.dart';
import 'package:taskwise/logging/app_log.dart';
import 'package:taskwise/sync/sync_api.dart';
import 'package:taskwise/ui/shared/settings/sign_in_page.dart';
import 'package:taskwise_shared/taskwise_shared.dart';
import 'package:web/web.dart' as web;

const _server = String.fromEnvironment('SERVER');
const _secret = String.fromEnvironment(
  'SETUP_SECRET',
  defaultValue: 'live-test-secret',
);
// The live sync test's account, so both can use one local server.
const _user = 'live-test';
const _password = 'live test password';
const _channelName = 'taskwise-web-smoke';
const _step = Duration(minutes: 3);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final params = Uri.parse(web.window.location.href).queryParameters;
  final role = params['smoke'];
  if (role == null) {
    _conductor(binding);
  } else {
    testWidgets('web smoke: $role tab', (tester) async {
      final tab = _Channel();
      try {
        await _runTab(tester, tab, role, params['title']!);
      } on Object catch (error, stack) {
        tab.send({'role': role, 'event': 'failed', 'error': '$error\n$stack'});
        rethrow;
      }
    });
  }
}

void _conductor(IntegrationTestWidgetsFlutterBinding binding) {
  setUpAll(() async {
    expect(_server, isNotEmpty, reason: 'pass --dart-define=SERVER=<url>');
    final api = SyncApi(baseUrl: _server);
    await api.health();
    try {
      await api.setup(
        setupSecret: _secret,
        username: _user,
        password: _password,
      );
    } on SyncHttpException catch (e) {
      if (e.code != 'conflict') rethrow; // The account exists already.
    }
  });

  testWidgets('web smoke: sign in, sync, reload, second tab', (_) async {
    final channel = _Channel();
    final title = 'Web smoke ${DateTime.now().millisecondsSinceEpoch}';
    final tabs = <web.Window>[];
    final report = <String, Object?>{};
    binding.reportData = report;
    try {
      final writer = _openTab('writer', title);
      tabs.add(writer);
      final added = await channel.next('writer', 'added', _step);
      report['storage'] = added['storage'];
      _log(
        'writer tab signed in and added a task (storage: '
        '${added['storage']})',
      );

      await _expectOnServer(title);
      _log('the server has the task');

      writer.location.reload();
      final reloaded = await channel.next('writer', 'reloaded', _step);
      _log(
        'after the reload the task is still there (storage: '
        '${reloaded['storage']})',
      );

      tabs.add(_openTab('second', title));
      final second = await channel.next('second', 'added', _step);
      report['integrity'] = second['integrity'];
      _log(
        'second tab shows the task and added one '
        '(integrity: ${second['integrity']})',
      );
      await channel.next('writer', 'saw-second', _step);
      _log('the first tab sees the second tab\'s task');
      report['steps'] = _progress;
    } on Object catch (error) {
      // flutter drive shows only the failure: say how far it got.
      fail('$error\nSteps done:\n${_progress.join('\n')}');
    } finally {
      channel.send({'event': 'done'});
      for (final tab in tabs) {
        tab.close();
      }
      channel.close();
    }
  });
}

web.Window _openTab(String role, String title) {
  final url = Uri.parse(web.window.location.href)
      .replace(queryParameters: {'smoke': role, 'title': title});
  final tab = web.window.open(url.toString(), 'taskwise-smoke-$role');
  if (tab == null) fail('The browser blocked opening the $role tab');
  return tab;
}

/// Finds [title] with the test's own token (its own device).
Future<void> _expectOnServer(String title) async {
  final id = 'web-smoke-${Random().nextInt(1 << 30)}';
  final login = await SyncApi(baseUrl: _server).login(
    username: _user,
    password: _password,
    deviceId: id,
    deviceName: 'Web smoke test',
    deviceType: DeviceType.other,
  );
  final api = SyncApi(baseUrl: _server, token: login.token);
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (true) {
    var since = 0;
    var hasMore = true;
    while (hasMore) {
      final page = await api.pull(since: since);
      for (final change in page.changes) {
        if (change.type == 'task' &&
            change.record['title'] == title &&
            change.record['deleted'] != true) {
          return;
        }
      }
      since = page.nextSince;
      hasMore = page.hasMore;
    }
    if (DateTime.now().isAfter(end)) {
      fail('The server never got the task (GET /sync)');
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
}

/// One tab of the app, as [role].
Future<void> _runTab(
  WidgetTester tester,
  _Channel channel,
  String role,
  String title,
) async {
  final secondTitle = '$title (second tab)';
  final loadKey = 'taskwise-smoke-$role-loaded';
  final reloaded = web.window.sessionStorage.getItem(loadKey) != null;
  web.window.sessionStorage.setItem(loadKey, '1');

  final boot = await AppBootstrap.start();
  // This start's choice (the log also keeps the lines of earlier starts).
  final storage = appLog.entries
      .lastWhere(
        (e) => e.tag == 'database' && e.message.startsWith('Browser storage'),
      )
      .message;
  expect(boot.deviceType, DeviceType.web);
  if (role == 'second' || reloaded) {
    // In the database before the app (and its sync) starts.
    expect(
      await _hasTask(boot.db, title),
      isTrue,
      reason: 'the task is in the browser database ($storage)',
    );
    expect(boot.storageStatus, StorageStatus.persistent, reason: storage);
  }

  await tester.pumpWidget(
    ProviderScope(overrides: boot.overrides, child: const TaskwiseApp()),
  );
  await _pumpFor(tester, const Duration(seconds: 2));

  if (role == 'writer' && !reloaded) {
    await _signIn(tester);
    await _quickAdd(tester, title);
    channel.send({'role': role, 'event': 'added', 'storage': storage});
  } else if (role == 'writer') {
    await _pumpUntil(tester, () => _shows(title), 'the task in the list');
    channel.send({'role': role, 'event': 'reloaded', 'storage': storage});
    // The second tab adds a task: it reaches this tab's database.
    final end = DateTime.now().add(_step);
    while (!await _hasTask(boot.db, secondTitle)) {
      if (DateTime.now().isAfter(end)) fail("never saw the second tab's task");
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    channel.send({'role': role, 'event': 'saw-second'});
  } else {
    await _pumpUntil(tester, () => _shows(title), 'the task in the list');
    await _quickAdd(tester, secondTitle);
    final check = await boot.db.customSelect('PRAGMA integrity_check').get();
    final integrity = check.map((row) => row.data.values.first).join(', ');
    expect(integrity, 'ok');
    channel.send({'role': role, 'event': 'added', 'integrity': integrity});
  }
  // Stay open (the other tab works on the same data) until the end.
  await channel.next(null, 'done', const Duration(minutes: 9));
}

Future<bool> _hasTask(AppDatabase db, String title) async => (await (db.select(
  db.tasks,
)..where((t) => t.title.equals(title))).get()).isNotEmpty;

bool _shows(String text) => find.text(text).evaluate().isNotEmpty;

Future<void> _signIn(WidgetTester tester) async {
  await _tap(tester, find.text('Settings').first);
  final connect = find.text('Connect to your server');
  await tester.scrollUntilVisible(
    connect,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await _tap(tester, connect.first);
  await _pumpUntil(
    tester,
    () => find.byType(SignInPage).evaluate().isNotEmpty,
    'the sign-in page',
  );
  Future<void> type(String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
    await tester.pump();
  }

  await type('Server address', _server);
  await type('Username', _user);
  await type('Password', _password);
  await _tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
  await _pumpUntil(
    tester,
    () => find.byType(SignInPage).evaluate().isEmpty,
    'the sign-in to finish',
    failIf: () => _signInError(tester),
  );
  await _tap(tester, find.text('Tasks').first);
}

String? _signInError(WidgetTester tester) {
  final page = find.byType(SignInPage);
  if (page.evaluate().isEmpty) return null;
  final error = Theme.of(tester.element(page)).colorScheme.error;
  for (final text in tester.widgetList<Text>(
    find.descendant(of: page, matching: find.byType(Text)),
  )) {
    if (text.style?.color == error) return 'Sign-in failed: ${text.data}';
  }
  return null;
}

Future<void> _quickAdd(WidgetTester tester, String title) async {
  final field = find.widgetWithText(TextField, 'Add a task and press Enter');
  await _tap(tester, field);
  await tester.enterText(field, title);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await _pumpUntil(tester, () => _shows(title), 'the new task in the list');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _pumpUntil(
    tester,
    () => finder.evaluate().isNotEmpty,
    finder.describeMatch(Plurality.one),
  );
  await tester.tap(finder);
  await _pumpFor(tester, const Duration(milliseconds: 500));
}

/// Pumps real frames until [done] (the app keeps animating while it syncs,
/// so pumpAndSettle may never return).
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() done,
  String what, {
  String? Function()? failIf,
  Duration timeout = const Duration(seconds: 60),
}) async {
  final end = DateTime.now().add(timeout);
  while (!done()) {
    final exception = tester.takeException();
    if (exception != null) fail('While waiting for $what: $exception');
    if (failIf?.call() case final reason?) fail(reason);
    if (DateTime.now().isAfter(end)) fail('Timed out waiting for $what');
    await tester.pump(const Duration(milliseconds: 100));
  }
  await _pumpFor(tester, const Duration(milliseconds: 300));
}

Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final exception = tester.takeException();
  if (exception != null) fail('$exception');
}

final _progress = <String>[];

void _log(String message) {
  _progress.add(message);
  debugPrint('web smoke: $message');
}

/// Messages between the tabs (JSON maps).
class _Channel {
  _Channel() {
    _channel.onmessage = ((web.MessageEvent event) {
      final data = event.data;
      if (data == null || !data.isA<JSString>()) return;
      _seen.add(
        (jsonDecode((data as JSString).toDart) as Map).cast<String, Object?>(),
      );
    }).toJS;
  }

  final _channel = web.BroadcastChannel(_channelName);
  final _seen = <Map<String, Object?>>[];

  void send(Map<String, Object?> message) =>
      _channel.postMessage(jsonEncode(message).toJS);

  /// The next [event] from [role] (any role when null); fails on a
  /// `failed` message from that role.
  Future<Map<String, Object?>> next(
    String? role,
    String event,
    Duration timeout,
  ) async {
    final end = DateTime.now().add(timeout);
    while (true) {
      for (final message in _seen) {
        if (role != null && message['role'] != role) continue;
        if (message['event'] == 'failed') {
          fail('The $role tab failed: ${message['error']}');
        }
        if (message['event'] == event) {
          _seen.remove(message);
          return message;
        }
      }
      if (DateTime.now().isAfter(end)) {
        fail('Timed out waiting for "$event" from the ${role ?? 'other'} tab');
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  void close() => _channel.close();
}
