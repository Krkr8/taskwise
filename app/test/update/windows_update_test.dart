import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/logging/app_log.dart';
import 'package:taskwise/update/update_installer.dart';

/// The Windows update helper, checked on any OS: how it is started (the
/// command is parsed back the way PowerShell and Windows would), the script
/// and its log. The real run on Windows is CI's windows-updater job.
void main() {
  group('hand-off command', () {
    List<String> build({
      String zip = r'C:\Users\Sam\AppData\Local\Temp\taskwise-update.zip',
      String target = r'C:\Users\Sam\AppData\Local\Programs\Taskwise',
      String? exe,
      String script = r'C:\Users\Sam\AppData\Local\Temp\taskwise-update.ps1',
      String log = r'C:\Users\Sam\AppData\Local\Temp\taskwise-update.log',
    }) => windowsHandOffArguments(
      processId: 4242,
      zip: zip,
      target: target,
      exe: exe ?? '$target\\taskwise.exe',
      scriptPath: script,
      logPath: log,
    );

    test('a short PowerShell starts the helper hidden', () {
      final args = build();
      expect(args.take(4), [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
      ]);
      expect(args, hasLength(5));
      expect(
        args[4],
        startsWith(
          r"$ErrorActionPreference = 'Stop'; Start-Process "
          '-FilePath powershell.exe -WindowStyle Hidden -ArgumentList ',
        ),
      );
      expect(childArguments(args), [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        r'C:\Users\Sam\AppData\Local\Temp\taskwise-update.ps1',
        '-ProcessId',
        '4242',
        '-Zip',
        r'C:\Users\Sam\AppData\Local\Temp\taskwise-update.zip',
        '-Target',
        r'C:\Users\Sam\AppData\Local\Programs\Taskwise',
        '-Exe',
        r'C:\Users\Sam\AppData\Local\Programs\Taskwise\taskwise.exe',
        '-Log',
        r'C:\Users\Sam\AppData\Local\Temp\taskwise-update.log',
      ]);
    });

    for (final user in [
      'Sam Lee',
      "Sam O'Neil",
      'Sam O\u2019Neil', // a typographic apostrophe
      'R&D (2)',
      r'$env:USERNAME $(calc) `n',
      "it's '' & \$x;",
    ]) {
      test('paths with "$user" come through unchanged', () {
        final temp = 'C:\\Users\\$user\\AppData\\Local\\Temp';
        final target = 'C:\\Users\\$user\\AppData\\Local\\Programs\\Taskwise';
        final args = build(
          zip: '$temp\\taskwise-update.zip',
          target: target,
          script: '$temp\\taskwise-update.ps1',
          log: '$temp\\taskwise-update.log',
        );
        final child = childArguments(args);
        expect(child[4], '$temp\\taskwise-update.ps1');
        expect(child[8], '$temp\\taskwise-update.zip');
        expect(child[10], target);
        expect(child[12], '$target\\taskwise.exe');
        expect(child[14], '$temp\\taskwise-update.log');
      });
    }

    test('a folder ending in a backslash keeps it', () {
      final child = childArguments(build(target: r'D:\Taskwise\'));
      expect(child[10], r'D:\Taskwise\');
      expect(child[11], '-Exe');
    });

    test('a path with a double quote is refused', () {
      expect(() => build(zip: 'C:\\a"b.zip'), throwsArgumentError);
    });

    test('the helper gets no PSModulePath, in any spelling', () {
      final env = windowsHelperEnvironment({
        'PATH': r'C:\Windows',
        'PSModulePath': r'C:\Program Files\PowerShell\7\Modules',
        'psmodulepath': 'x',
        'SystemRoot': r'C:\Windows',
      });
      expect(env, {'PATH': r'C:\Windows', 'SystemRoot': r'C:\Windows'});
    });
  });

  group('helper script', () {
    test('is plain ASCII (PowerShell 5.1 reads files without a BOM so)', () {
      expect(windowsUpdateScript.codeUnits.every((c) => c < 128), isTrue);
    });

    test('takes the log path and writes every step to it', () {
      expect(
        windowsUpdateScript,
        contains(
          'param([int]\$ProcessId, [string]\$Zip, [string]\$Target, '
          '[string]\$Exe, [string]\$Log)',
        ),
      );
      expect(windowsUpdateScript, contains('AppendAllText(\$Log'));
      for (final step in [
        'helper started',
        'Taskwise has quit',
        'still running after 60 s',
        'unzipped',
        'robocopy exit code',
        "Write-Log 'updated'",
        "Write-Log ('FAILED: ' + \$_)",
      ]) {
        expect(windowsUpdateScript, contains(step));
      }
    });

    test('waits for Taskwise and copies only once it has quit', () {
      final wait = windowsUpdateScript.indexOf(
        'Wait-Process -Id \$ProcessId -Timeout 60',
      );
      final stillRunning = windowsUpdateScript.indexOf(
        'if (Get-Process -Id \$ProcessId',
      );
      final copy = windowsUpdateScript.indexOf('robocopy \$src');
      expect(wait, greaterThan(0));
      expect(stillRunning, greaterThan(wait));
      expect(copy, greaterThan(stillRunning));
      // No second copy of Taskwise when the first one never quit.
      expect(
        windowsUpdateScript.substring(stillRunning, copy),
        contains('\$restart = \$false'),
      );
    });

    test('unzips with ZipFile, not Expand-Archive', () {
      expect(windowsUpdateScript, isNot(contains('Expand-Archive')));
      expect(
        windowsUpdateScript,
        contains('Add-Type -AssemblyName System.IO.Compression.FileSystem'),
      );
      expect(
        windowsUpdateScript,
        contains('[IO.Compression.ZipFile]::ExtractToDirectory(\$Zip, \$work)'),
      );
    });

    test('adds and replaces files and checks robocopy\'s exit code', () {
      expect(windowsUpdateScript, contains('& robocopy \$src \$Target /E'));
      expect(windowsUpdateScript, isNot(contains('/MIR')));
      expect(windowsUpdateScript, isNot(contains('Out-Null')));
      expect(windowsUpdateScript, contains('\$code = \$LASTEXITCODE'));
      expect(windowsUpdateScript, contains('if (\$code -ge 8)'));
      expect(windowsUpdateScript, contains('FAILED: robocopy exit code'));
    });

    test('always cleans up and starts Taskwise again', () {
      final cleanup = windowsUpdateScript.substring(
        windowsUpdateScript.indexOf('} finally {'),
      );
      expect(cleanup, contains('Remove-Item -LiteralPath \$work -Recurse'));
      expect(cleanup, contains('Remove-Item -LiteralPath \$Zip'));
      expect(cleanup, contains('if (\$restart)'));
      expect(cleanup, contains('Start-Process -FilePath \$Exe'));
    });
  });

  group('helper log', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('taskwise-update-log');
    });
    tearDown(() => dir.delete(recursive: true));

    test(
      'a good update goes to the app log as info, then is deleted',
      () async {
        final file = File('${dir.path}/$windowsUpdateLogName');
        await file.writeAsString(
          '\uFEFF2026-11-27 10:00:00 helper started\r\n'
          '2026-11-27 10:00:01 Taskwise has quit\r\n'
          '\r\n'
          '2026-11-27 10:00:03 updated\r\n',
        );
        final log = AppLog();
        await importWindowsUpdateLog(file.path, log);
        expect(log.entries.map((e) => e.message), [
          'Update helper: 2026-11-27 10:00:00 helper started',
          'Update helper: 2026-11-27 10:00:01 Taskwise has quit',
          'Update helper: 2026-11-27 10:00:03 updated',
        ]);
        expect(log.entries.map((e) => e.level).toSet(), {LogLevel.info});
        expect(log.entries.map((e) => e.tag).toSet(), {'update'});
        expect(file.existsSync(), isFalse);
      },
    );

    test('a failed step makes every line a warning', () async {
      final file = File('${dir.path}/$windowsUpdateLogName');
      await file.writeAsString(
        '2026-11-27 10:00:00 helper started\n'
        '2026-11-27 10:00:02 FAILED: robocopy exit code 16\n'
        '2026-11-27 10:00:02 starting Taskwise\n',
      );
      final log = AppLog();
      await importWindowsUpdateLog(file.path, log);
      expect(log.entries, hasLength(3));
      expect(log.entries.map((e) => e.level).toSet(), {LogLevel.warning});
      expect(file.existsSync(), isFalse);
    });

    test('no log, no lines', () async {
      final log = AppLog();
      await importWindowsUpdateLog('${dir.path}/missing.log', log);
      expect(log.entries, isEmpty);
    });
  });
}

/// The helper's arguments, as the child powershell.exe gets them: the
/// `-ArgumentList` string read the way PowerShell reads a single-quoted
/// literal, then split the way Windows programs split a command line.
List<String> childArguments(List<String> handOff) {
  final command = handOff.last;
  const marker = '-ArgumentList ';
  return splitWindowsCommandLine(
    readPowerShellSingleQuoted(
      command.substring(command.indexOf(marker) + marker.length),
    ),
  );
}

const _singleQuotes = "'\u2018\u2019\u201A\u201B";

/// A PowerShell single-quoted string that must make up all of [source]:
/// two quotes in a row are one quote; nothing else is special.
String readPowerShellSingleQuoted(String source) {
  expect(_singleQuotes, contains(source[0]));
  final out = StringBuffer();
  var i = 1;
  while (true) {
    expect(i, lessThan(source.length), reason: 'unterminated string');
    final c = source[i];
    if (_singleQuotes.contains(c)) {
      if (i + 1 < source.length && _singleQuotes.contains(source[i + 1])) {
        out.write(source[i + 1]);
        i += 2;
        continue;
      }
      expect(i, source.length - 1, reason: 'text after the string');
      return out.toString();
    }
    out.write(c);
    i++;
  }
}

/// The Microsoft C runtime's rules (CommandLineToArgvW), which
/// powershell.exe uses: `2n` backslashes before `"` give `n` and toggle
/// quoting, `2n+1` give `n` and a literal `"`; other backslashes are
/// literal.
List<String> splitWindowsCommandLine(String line) {
  final args = <String>[];
  final current = StringBuffer();
  var inQuotes = false;
  var hasArg = false;
  var i = 0;
  while (i < line.length) {
    final c = line[i];
    if (c == r'\') {
      var n = 0;
      while (i < line.length && line[i] == r'\') {
        n++;
        i++;
      }
      if (i < line.length && line[i] == '"') {
        current.write(r'\' * (n ~/ 2));
        if (n.isOdd) {
          current.write('"');
          i++;
        }
      } else {
        current.write(r'\' * n);
      }
      hasArg = true;
    } else if (c == '"') {
      inQuotes = !inQuotes;
      hasArg = true;
      i++;
    } else if ((c == ' ' || c == '\t') && !inQuotes) {
      if (hasArg) args.add(current.toString());
      current.clear();
      hasArg = false;
      i++;
    } else {
      current.write(c);
      hasArg = true;
      i++;
    }
  }
  if (hasArg) args.add(current.toString());
  return args;
}
