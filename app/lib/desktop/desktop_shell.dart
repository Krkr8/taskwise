import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import '../data/app_settings.dart';
import '../l10n/app_localizations.dart';

/// Windows and Linux: keeps Taskwise running in the background so
/// reminders fire with the window closed.
///
/// - Closing the window hides it to the tray (when "Keep running in
///   background" is on); the tray menu has Show and Quit.
/// - Only one copy runs: launching again brings the window back. This also
///   covers GNOME without the AppIndicator extension, where no tray icon is
///   shown: open Taskwise from the app menu again.
/// - "Start on login" registers the app (started with `--hidden`).
class DesktopShell with WindowListener {
  DesktopShell._(this._server);

  /// The running shell, or null on other platforms.
  static DesktopShell? instance;

  /// Argument used by the login item: start in the tray, window hidden.
  static const hiddenArg = '--hidden';

  static const _hello = 'taskwise-show';
  static const _reply = 'taskwise-ok';

  final ServerSocket _server;
  tray.TrayIcon? _trayIcon;
  tray.MenuItem? _showItem;
  tray.MenuItem? _quitItem;
  bool _keepRunning = true;
  bool? _startOnLogin;

  /// Starts the shell, or returns null after asking an already running
  /// Taskwise to show itself (the caller should then exit).
  static Future<DesktopShell?> start({required bool hidden}) async {
    final portFile = File(
      '${(await getApplicationSupportDirectory()).path}/instance.port',
    );
    if (await _signalRunningInstance(portFile)) return null;

    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    await portFile.parent.create(recursive: true);
    await portFile.writeAsString('${server.port}');
    final shell = DesktopShell._(server);
    instance = shell;
    server.listen(shell._onPeer);

    await windowManager.ensureInitialized();
    windowManager.addListener(shell);
    await windowManager.setPreventClose(true);
    if (hidden) await windowManager.hide();

    LaunchAtStartup.instance.setup(
      appName: 'Taskwise',
      appPath: Platform.resolvedExecutable,
      args: const [hiddenArg],
    );
    shell._createTray();
    return shell;
  }

  /// True if another Taskwise answered and was told to show its window.
  static Future<bool> _signalRunningInstance(File portFile) async {
    try {
      final port = int.parse((await portFile.readAsString()).trim());
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 500),
      );
      socket.writeln(_hello);
      await socket.flush();
      // Only a real Taskwise answers; anything else on a stale port doesn't.
      final answer = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 1));
      await socket.close();
      return answer == _reply;
    } on Object {
      return false;
    }
  }

  void _onPeer(Socket socket) {
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (line == _hello) {
              socket.writeln(_reply);
              unawaited(showWindow());
            }
            unawaited(socket.close());
          },
          onError: (_) => socket.destroy(),
          cancelOnError: true,
        );
  }

  void _createTray() {
    try {
      final icon = tray.TrayIcon.create();
      if (icon == null) return;
      icon.icon = tray.ImageAsset.fromAsset('assets/tray/tray.png');
      icon.setTooltip('Taskwise');
      final menu = tray.Menu.create()!;
      _showItem = tray.MenuItem.createWithLabelAndType(
        'Show Taskwise',
        tray.MenuItemType.normal,
      );
      _quitItem = tray.MenuItem.createWithLabelAndType(
        'Quit Taskwise',
        tray.MenuItemType.normal,
      );
      _showItem?.addListener((event) {
        if (event is tray.MenuItemClickedEvent) unawaited(showWindow());
      });
      _quitItem?.addListener((event) {
        // Quit after the tray menu has closed: tearing the icon down from
        // inside its own menu callback can stall on Windows.
        if (event is tray.MenuItemClickedEvent) Timer.run(() => quit());
      });
      menu
        ..addItem(_showItem)
        ..addSeparator()
        ..addItem(_quitItem);
      icon.setContextMenu(menu);
      // Windows reports clicks on the icon (Linux panels keep them).
      icon.addListener((event) {
        if (event is tray.TrayIconClickedEvent ||
            event is tray.TrayIconDoubleClickedEvent) {
          unawaited(showWindow());
        }
      });
      icon.setVisible(true);
      _trayIcon = icon;
    } on Object catch (e) {
      // No tray host (e.g. GNOME without AppIndicator): run without it.
      debugPrint('Tray icon unavailable: $e');
    }
  }

  /// Applies the background settings and the menu language.
  Future<void> apply(AppSettings settings) async {
    _keepRunning = settings.keepRunningInBackground;
    final l10n = lookupAppLocalizations(resolvedLocale(settings));
    _showItem?.label = l10n.trayShow;
    _quitItem?.label = l10n.trayQuit;

    if (_startOnLogin != settings.startOnLogin) {
      _startOnLogin = settings.startOnLogin;
      try {
        if (settings.startOnLogin) {
          await LaunchAtStartup.instance.enable();
        } else if (await LaunchAtStartup.instance.isEnabled()) {
          await LaunchAtStartup.instance.disable();
        }
      } on Object catch (e) {
        debugPrint('Start on login failed: $e');
      }
    }
  }

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// Ends Taskwise. Each step is best-effort, and the process exits in the
  /// end even if a plugin call fails or hangs (seen with the tray on
  /// Windows), so "Quit" always quits.
  Future<void> quit() async {
    Future<void> step(FutureOr<void> Function() action) async {
      try {
        await Future.sync(action).timeout(const Duration(seconds: 2));
      } on Object catch (e) {
        debugPrint('Quit step failed: $e');
      }
    }

    await step(() => _trayIcon?.setVisible(false));
    await step(() => _trayIcon?.dispose());
    await step(_server.close);
    await step(() => windowManager.setPreventClose(false));
    await step(windowManager.destroy);
    exit(0);
  }

  @override
  void onWindowClose() {
    unawaited(_keepRunning ? windowManager.hide() : quit());
  }
}
