import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../desktop/desktop_shell.dart';
import '../logging/app_log.dart';

/// Installs a verified update for one way of installing Taskwise. Tasks and
/// settings live in the app-support folder, apart from the program, so they
/// are kept.
abstract class UpdateInstaller {
  UpdateTarget get target;

  /// Where to download the update file (on the same disk as the program
  /// when the install renames it into place).
  Future<File> downloadFile(ReleaseAsset asset);

  /// Installs [file] (already verified). Desktop installers quit Taskwise
  /// and start the new version; Android hands over to its install screen
  /// and returns what happened.
  Future<InstallOutcome> install(File file);
}

enum InstallOutcome {
  /// The new version is starting (desktop) or installed.
  started,

  /// Android: allow "Install unknown apps" for Taskwise first, then retry.
  needsPermission,

  /// Android: the user pressed Cancel on the update screen.
  cancelled,
}

/// The installer for this copy of Taskwise, or null when it can't update
/// itself: the iPhone, a build run from the source tree, or an unknown
/// install. Those still see that an update is out, with a link to it.
Future<UpdateInstaller?> detectUpdateInstaller() async {
  try {
    if (Platform.isAndroid) return AndroidUpdateInstaller();
    final exe = File(Platform.resolvedExecutable);
    final path = exe.path.replaceAll(r'\', '/');
    // `flutter run` / `flutter build` output: updating it makes no sense.
    if (path.contains('/build/linux/') || path.contains('/build/windows/')) {
      return null;
    }
    if (Platform.isLinux) {
      final appImage = Platform.environment['APPIMAGE'];
      if (appImage != null && appImage.isNotEmpty) {
        return AppImageInstaller(File(appImage));
      }
      final dataHome =
          Platform.environment['XDG_DATA_HOME'] ??
          '${Platform.environment['HOME']}/.local/share';
      // The folder install.sh copies the tar.gz's bundle to.
      if (exe.parent.path == '$dataHome/taskwise') {
        return TarballInstaller(exe.parent);
      }
      return null;
    }
    if (Platform.isWindows && await _writable(exe.parent)) {
      return WindowsUpdateInstaller(exe.parent);
    }
  } on Object catch (e) {
    appLog.warning('update', 'Update installer not available: $e');
  }
  return null;
}

Future<bool> _writable(Directory dir) async {
  final probe = File(
    '${dir.path}${Platform.pathSeparator}.taskwise-write-test',
  );
  try {
    await probe.writeAsString('');
    await probe.delete();
    return true;
  } on FileSystemException {
    return false;
  }
}

/// Starts [executable] once Taskwise has quit, then quits (Linux).
typedef Restart = Future<void> Function(String executable);

Future<void> _restart(String executable) async {
  await startAfterExit(pid, executable);
  await _quit();
}

/// Quits Taskwise; a helper started before has the new version waiting.
Future<void> _quit() async {
  final shell = DesktopShell.instance;
  if (shell != null) {
    await shell.quit();
  } else {
    exit(0);
  }
}

/// Linux: starts [executable] once process [processId] has exited (a
/// detached `sh` that outlives Taskwise). Needed because a second Taskwise
/// would only show the running window.
Future<void> startAfterExit(int processId, String executable) async {
  await Process.start('/bin/sh', [
    '-c',
    'while kill -0 $processId 2>/dev/null; do sleep 0.2; done; '
        r'exec "$0" >/dev/null 2>&1',
    executable,
  ], mode: ProcessStartMode.detached);
}

/// Linux AppImage: replaces the AppImage file itself (same path, so menus
/// and "Start when I log in" keep working).
class AppImageInstaller implements UpdateInstaller {
  AppImageInstaller(this.appImage, {this.restart = _restart});

  final File appImage;
  final Restart restart;

  @override
  UpdateTarget get target => UpdateTarget.linuxAppImage;

  @override
  Future<File> downloadFile(ReleaseAsset asset) async =>
      File('${appImage.parent.path}/.taskwise-update.AppImage');

  @override
  Future<InstallOutcome> install(File file) async {
    await _run('chmod', ['755', file.path]);
    // A rename on the same disk replaces the file in one step; the running
    // copy keeps its (now unlinked) file until it exits.
    await file.rename(appImage.path);
    await restart(appImage.path);
    return InstallOutcome.started;
  }
}

/// Linux tar.gz installed with install.sh: swaps the program folder.
class TarballInstaller implements UpdateInstaller {
  TarballInstaller(this.installDir, {this.restart = _restart});

  /// `~/.local/share/taskwise` (the bundle).
  final Directory installDir;
  final Restart restart;

  @override
  UpdateTarget get target => UpdateTarget.linuxTarball;

  @override
  Future<File> downloadFile(ReleaseAsset asset) async =>
      File('${installDir.path}.update.tar.gz');

  @override
  Future<InstallOutcome> install(File file) async {
    final unpacked = Directory('${installDir.path}.update');
    final old = Directory('${installDir.path}.old');
    for (final d in [unpacked, old]) {
      if (await d.exists()) await d.delete(recursive: true);
    }
    await unpacked.create();
    await _run('tar', ['-xzf', file.path, '-C', unpacked.path]);
    // taskwise-<v>-linux-x64/bundle/taskwise
    final bundle = await unpacked
        .list()
        .where((e) => e is Directory)
        .map((e) => Directory('${e.path}/bundle'))
        .firstWhere(
          (d) => File('${d.path}/taskwise').existsSync(),
          orElse: () => throw const FileSystemException('No bundle in update'),
        );
    await installDir.rename(old.path);
    try {
      await bundle.rename(installDir.path);
    } on Object {
      await old.rename(installDir.path); // put the old version back
      rethrow;
    }
    await Future.wait([
      old.delete(recursive: true),
      unpacked.delete(recursive: true),
      file.delete(),
    ]).catchError((Object e) {
      appLog.warning('update', 'Cleanup after update failed: $e');
      return const <FileSystemEntity>[];
    });
    await restart('${installDir.path}/taskwise');
    return InstallOutcome.started;
  }
}

/// Windows portable folder: a PowerShell helper waits for Taskwise to exit,
/// copies the new files over the folder (adding and replacing, never
/// deleting) and starts it again.
class WindowsUpdateInstaller implements UpdateInstaller {
  WindowsUpdateInstaller(this.installDir);

  final Directory installDir;

  @override
  UpdateTarget get target => UpdateTarget.windows;

  @override
  Future<File> downloadFile(ReleaseAsset asset) async =>
      File('${(await getTemporaryDirectory()).path}\\taskwise-update.zip');

  @override
  Future<InstallOutcome> install(File file) async {
    final script = File('${file.parent.path}\\taskwise-update.ps1');
    await script.writeAsString(windowsUpdateScript);
    await Process.start('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-WindowStyle',
      'Hidden',
      '-File',
      script.path,
      '-ProcessId',
      '$pid',
      '-Zip',
      file.path,
      '-Target',
      installDir.path,
      '-Exe',
      Platform.resolvedExecutable,
    ], mode: ProcessStartMode.detached);
    await _quit();
    return InstallOutcome.started;
  }
}

/// The Windows helper (see [WindowsUpdateInstaller]). robocopy retries files
/// that are still locked for a moment after Taskwise exits; exit codes below
/// 8 mean success. If copying fails, the old version starts again.
const windowsUpdateScript = r'''
param([int]$ProcessId, [string]$Zip, [string]$Target, [string]$Exe)
$ErrorActionPreference = 'Continue'
Wait-Process -Id $ProcessId -Timeout 60 -ErrorAction SilentlyContinue
$work = Join-Path $env:TEMP ('taskwise-update-' + [guid]::NewGuid())
try {
  Expand-Archive -LiteralPath $Zip -DestinationPath $work -Force
  $src = Join-Path $work 'Taskwise'
  if (-not (Test-Path (Join-Path $src 'taskwise.exe'))) { $src = $work }
  robocopy $src $Target /E /R:20 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
} finally {
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $Zip -Force -ErrorAction SilentlyContinue
  Start-Process -FilePath $Exe
}
''';

/// Android: installs the APK with the system's package installer
/// (`AppUpdater.kt`). Android shows its own "Update Taskwise?" screen and
/// checks that the APK is signed with the same key.
class AndroidUpdateInstaller implements UpdateInstaller {
  static const _channel = MethodChannel('taskwise/update');

  @override
  UpdateTarget get target => UpdateTarget.android;

  @override
  Future<File> downloadFile(ReleaseAsset asset) async =>
      File('${(await getTemporaryDirectory()).path}/taskwise-update.apk');

  @override
  Future<InstallOutcome> install(File file) async {
    final status = await _channel.invokeMethod<String>('installApk', {
      'path': file.path,
    });
    return switch (status) {
      'needsPermission' => InstallOutcome.needsPermission,
      'cancelled' => InstallOutcome.cancelled,
      'success' => InstallOutcome.started,
      _ => throw PlatformException(code: 'install_failed', message: status),
    };
  }
}

Future<void> _run(String command, List<String> args) async {
  final result = await Process.run(command, args);
  if (result.exitCode != 0) {
    throw ProcessException(command, args, '${result.stderr}', result.exitCode);
  }
}
