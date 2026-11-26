// The Windows update helper: the PowerShell script that swaps the program
// folder once Taskwise has quit, and how it is started.
//
// Only `dart:` imports here, so a plain `dart run` driver can use this file
// on a Windows CI runner (`.github/workflows/ci.yml`, job windows-updater).

import 'dart:convert';
import 'dart:io';

/// The helper's log, next to the downloaded zip in `%TEMP%`. Taskwise reads
/// it into its own log at the next start ([takeWindowsUpdateLog]).
const windowsUpdateLogName = 'taskwise-update.log';

/// The helper script's file name, next to the zip.
const windowsUpdateScriptName = 'taskwise-update.ps1';

/// Writes [windowsUpdateScript] to [scriptPath] and starts it hidden, so it
/// outlives Taskwise: it waits for process [processId] to exit, copies the
/// update in [zip] over [target], logs its steps to [logPath] and starts
/// [exe] again.
///
/// A detached `Process.start` of powershell.exe (or cmd.exe) from Taskwise
/// never ran on Windows, so a short PowerShell in normal mode hands off with
/// `Start-Process` and exits ([windowsHandOffArguments]). Throws a
/// [ProcessException] when that hand-off fails, so Taskwise keeps running
/// and shows that installing failed.
Future<void> startWindowsUpdateHelper({
  required int processId,
  required String zip,
  required String target,
  required String exe,
  required String scriptPath,
  required String logPath,
}) async {
  final log = File(logPath);
  if (await log.exists()) await log.delete();
  // Plain ASCII, so Windows PowerShell 5.1 reads it right without a BOM.
  await File(scriptPath).writeAsString(windowsUpdateScript, encoding: ascii);
  final args = windowsHandOffArguments(
    processId: processId,
    zip: zip,
    target: target,
    exe: exe,
    scriptPath: scriptPath,
    logPath: logPath,
  );
  final result = await Process.run(
    'powershell.exe',
    args,
    environment: windowsHelperEnvironment(Platform.environment),
    includeParentEnvironment: false,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      'powershell.exe',
      args,
      '${result.stderr}'.trim(),
      result.exitCode,
    );
  }
}

/// The arguments for `powershell.exe` that start the helper script hidden
/// with `Start-Process` and return at once.
///
/// Each value for the helper goes in double quotes (Windows paths can't
/// contain `"`, but user names can contain spaces, `'`, `&`, `(` or `$`),
/// and the whole `-ArgumentList` in a PowerShell single-quoted string, where
/// nothing is expanded and only quotes are doubled.
List<String> windowsHandOffArguments({
  required int processId,
  required String zip,
  required String target,
  required String exe,
  required String scriptPath,
  required String logPath,
}) {
  final child = [
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    _quoted(scriptPath),
    '-ProcessId',
    _quoted('$processId'),
    '-Zip',
    _quoted(zip),
    '-Target',
    _quoted(target),
    '-Exe',
    _quoted(exe),
    '-Log',
    _quoted(logPath),
  ].join(' ');
  return [
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-Command',
    "\$ErrorActionPreference = 'Stop'; "
        'Start-Process -FilePath powershell.exe -WindowStyle Hidden '
        '-ArgumentList ${powerShellSingleQuoted(child)}',
  ];
}

/// [value] in double quotes for a Windows command line. Backslashes right
/// before the closing quote are doubled, or `C:\dir\"` would end in a quote.
String _quoted(String value) {
  if (value.contains('"')) {
    throw ArgumentError.value(value, 'value', 'contains a double quote');
  }
  final trailing =
      value.length - value.replaceFirst(RegExp(r'\\+$'), '').length;
  return '"$value${r'\' * trailing}"';
}

/// [value] as a PowerShell single-quoted string literal. PowerShell also
/// takes the typographic single quotes (‘ ’ ‚ ‛) as quotes, so those are
/// doubled too.
String powerShellSingleQuoted(String value) =>
    "'${value.replaceAllMapped(RegExp("['\u2018\u2019\u201A\u201B]"), (m) => '${m[0]}${m[0]}')}'";

/// [environment] without `PSModulePath` (any case). Windows PowerShell 5.1
/// would otherwise load PowerShell 7's modules from it, and their
/// Expand-Archive fails there.
Map<String, String> windowsHelperEnvironment(Map<String, String> environment) =>
    {
      for (final e in environment.entries)
        if (e.key.toUpperCase() != 'PSMODULEPATH') e.key: e.value,
    };

/// Reads and deletes the helper's log at [path]: its lines, or none when
/// there is no log.
Future<List<String>> takeWindowsUpdateLog(String path) async {
  final file = File(path);
  if (!await file.exists()) return const [];
  final text = await file.readAsString(
    encoding: const Utf8Codec(allowMalformed: true),
  );
  await file.delete();
  return const LineSplitter()
      .convert(text.replaceFirst('\uFEFF', ''))
      .map((l) => l.trimRight())
      .where((l) => l.isNotEmpty)
      .toList();
}

/// The Windows helper (see [startWindowsUpdateHelper]). It waits up to 60 s
/// for Taskwise to quit, unzips the update with .NET's ZipFile (not
/// Expand-Archive, which fails in PowerShell 5.1 when PowerShell 7's modules
/// are on PSModulePath) and copies it over the folder with robocopy (adding
/// and replacing, never deleting; it retries files still locked for a
/// moment; exit codes of 8 and above are failures). Every step goes to the
/// log. It always cleans up and starts Taskwise again, the new version or
/// the old one, unless the old one never quit.
const windowsUpdateScript = r'''
param([int]$ProcessId, [string]$Zip, [string]$Target, [string]$Exe, [string]$Log)
$ErrorActionPreference = 'Stop'
function Write-Log([string]$Text) {
  try {
    $line = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $Text
    [IO.File]::AppendAllText($Log, $line + [Environment]::NewLine)
  } catch {}
}
Write-Log ('helper started, waiting for Taskwise (process ' + $ProcessId + ')')
$work = Join-Path $env:TEMP ('taskwise-update-' + [guid]::NewGuid())
$restart = $true
try {
  try { Wait-Process -Id $ProcessId -Timeout 60 -ErrorAction SilentlyContinue } catch {}
  if (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue) {
    $restart = $false
    Write-Log 'FAILED: Taskwise was still running after 60 s, nothing copied'
  } else {
    Write-Log 'Taskwise has quit'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($Zip, $work)
    $src = Join-Path $work 'Taskwise'
    if (-not (Test-Path -LiteralPath (Join-Path $src 'taskwise.exe'))) { $src = $work }
    if (-not (Test-Path -LiteralPath (Join-Path $src 'taskwise.exe'))) {
      throw 'the update has no taskwise.exe'
    }
    Write-Log 'unzipped'
    $output = & robocopy $src $Target /E /R:20 /W:1 /NFL /NDL /NJH /NJS /NP
    $code = $LASTEXITCODE
    if ($code -ge 8) {
      Write-Log ('FAILED: robocopy exit code ' + $code)
      foreach ($l in @($output)) { if ("$l".Trim()) { Write-Log ('robocopy: ' + "$l".Trim()) } }
    } else {
      Write-Log ('robocopy exit code ' + $code)
      Write-Log 'updated'
    }
  }
} catch {
  Write-Log ('FAILED: ' + $_)
} finally {
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $Zip -Force -ErrorAction SilentlyContinue
  if ($restart) {
    # Logged first: the new Taskwise reads and deletes the log as it starts.
    Write-Log 'starting Taskwise'
    try {
      Start-Process -FilePath $Exe
    } catch {
      Write-Log ('FAILED to start Taskwise: ' + $_)
    }
  }
}
''';
