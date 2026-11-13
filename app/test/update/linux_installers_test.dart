@TestOn('linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/update/update_installer.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

/// The Linux installers on real files (the restart is faked).
void main() {
  late Directory dir;
  final restarted = <String>[];
  Future<void> fakeRestart(String exe) async => restarted.add(exe);
  const asset = ReleaseAsset(name: 'x', url: 'u');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('taskwise-installers');
    restarted.clear();
  });
  tearDown(() => dir.delete(recursive: true));

  test('AppImage: the new file replaces the old one, executable', () async {
    final appImage = File('${dir.path}/taskwise-1.1.0-linux-x86_64.AppImage');
    await appImage.writeAsString('old');
    final installer = AppImageInstaller(appImage, restart: fakeRestart);
    final download = await installer.downloadFile(asset);
    expect(download.parent.path, dir.path); // same disk: rename works
    await download.writeAsString('new');

    expect(await installer.install(download), InstallOutcome.started);
    expect(await appImage.readAsString(), 'new');
    expect(download.existsSync(), isFalse);
    final mode = (await appImage.stat()).mode;
    expect(mode & 0x49, 0x49, reason: 'executable by all'); // o+x g+x u+x
    expect(restarted, [appImage.path]);
  });

  test('tar.gz: the bundle folder is swapped, nothing else touched', () async {
    final install = Directory('${dir.path}/taskwise');
    await File('${install.path}/data/old.txt').create(recursive: true);
    await File('${install.path}/taskwise').writeAsString('old');
    // A release tar.gz: taskwise-<v>-linux-x64/bundle/… plus install.sh.
    final stage = Directory('${dir.path}/stage/taskwise-1.2.0-linux-x64');
    await File('${stage.path}/bundle/taskwise').create(recursive: true);
    await File('${stage.path}/bundle/taskwise').writeAsString('new');
    await File('${stage.path}/bundle/data/new.txt').create(recursive: true);
    await File('${stage.path}/install.sh').writeAsString('#!/bin/sh');
    final installer = TarballInstaller(install, restart: fakeRestart);
    final download = await installer.downloadFile(asset);
    final tar = await Process.run('tar', [
      '-C',
      stage.parent.path,
      '-czf',
      download.path,
      'taskwise-1.2.0-linux-x64',
    ]);
    expect(tar.exitCode, 0);

    expect(await installer.install(download), InstallOutcome.started);
    expect(await File('${install.path}/taskwise').readAsString(), 'new');
    expect(File('${install.path}/data/new.txt').existsSync(), isTrue);
    expect(File('${install.path}/data/old.txt').existsSync(), isFalse);
    expect(File('${install.path}/install.sh').existsSync(), isFalse);
    // Leftovers are cleaned up.
    expect(Directory('${install.path}.old').existsSync(), isFalse);
    expect(Directory('${install.path}.update').existsSync(), isFalse);
    expect(download.existsSync(), isFalse);
    expect(restarted, ['${install.path}/taskwise']);
  });

  test('tar.gz: a broken download leaves the old version in place', () async {
    final install = Directory('${dir.path}/taskwise');
    await File('${install.path}/taskwise').create(recursive: true);
    final installer = TarballInstaller(install, restart: fakeRestart);
    final download = await installer.downloadFile(asset);
    await download.writeAsString('not a tar.gz');
    await expectLater(installer.install(download), throwsA(anything));
    expect(File('${install.path}/taskwise').existsSync(), isTrue);
    expect(restarted, isEmpty);
  });

  test('the restart helper waits for the old process, then starts', () async {
    final marker = File('${dir.path}/started');
    final exe = File('${dir.path}/new-taskwise');
    await exe.writeAsString('#!/bin/sh\ntouch "${marker.path}"\n');
    await Process.run('chmod', ['755', exe.path]);
    final old = await Process.start('sleep', ['30']);
    await startAfterExit(old.pid, exe.path);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(marker.existsSync(), isFalse, reason: 'the old one still runs');
    old.kill();
    await old.exitCode;
    for (var i = 0; i < 30 && !marker.existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(marker.existsSync(), isTrue);
  });

  test('the Windows helper script copies, cleans up and restarts', () {
    expect(windowsUpdateScript, contains('Wait-Process -Id \$ProcessId'));
    expect(windowsUpdateScript, contains('robocopy \$src \$Target /E'));
    expect(windowsUpdateScript, isNot(contains('/MIR')));
    expect(windowsUpdateScript, contains('Start-Process -FilePath \$Exe'));
  });
}
