import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// How serious a log line is.
enum LogLevel { info, warning, error }

/// One line of the app's log.
@immutable
final class LogEntry {
  const LogEntry(this.time, this.level, this.tag, this.message);

  final DateTime time;
  final LogLevel level;

  /// The part of the app that wrote it: `sync`, `backup`, `app`, …
  final String tag;
  final String message;

  @override
  String toString() =>
      '${time.toIso8601String()} ${level.name.toUpperCase().padRight(7)} '
      '[$tag] $message';
}

/// The app's log: the newest lines in memory (for Settings → About → Logs)
/// and, once [open] is called, a file that is rotated when it grows.
///
/// Never log personal data (task titles, notes, places, passwords, tokens):
/// only ids, counts and error types, so a log can be shared safely.
class AppLog extends ChangeNotifier {
  AppLog({this.memoryLines = 500, this.maxFileBytes = 512 * 1024});

  final int memoryLines;
  final int maxFileBytes;

  final _entries = ListQueue<LogEntry>();
  File? _file;

  /// The log file, once [open] was called.
  File? get file => _file;

  /// Newest last.
  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// Starts writing to `<directory>/taskwise.log` (the previous file is
  /// kept as `taskwise.1.log` when it gets too big). Lines logged before
  /// this are written too.
  Future<void> open(Directory directory) async {
    try {
      await directory.create(recursive: true);
      _file = File('${directory.path}/taskwise.log');
      final pending = _entries.map((e) => '$e\n').join();
      if (pending.isNotEmpty) _append(pending);
    } on Object catch (e) {
      _file = null;
      debugPrint('Log file unavailable: $e');
    }
  }

  void info(String tag, String message) => add(LogLevel.info, tag, message);

  void warning(String tag, String message) =>
      add(LogLevel.warning, tag, message);

  /// Logs [error] (its type and text) and the top of [stack].
  void error(String tag, Object error, [StackTrace? stack, String? context]) {
    final top = stack == null
        ? ''
        : '\n${stack.toString().trimRight().split('\n').take(8).join('\n')}';
    add(
      LogLevel.error,
      tag,
      '${context == null ? '' : '$context: '}${error.runtimeType}: $error$top',
    );
  }

  void add(LogLevel level, String tag, String message, {DateTime? time}) {
    final entry = LogEntry(time ?? DateTime.now(), level, tag, message);
    _entries.addLast(entry);
    while (_entries.length > memoryLines) {
      _entries.removeFirst();
    }
    if (kDebugMode) debugPrint('$entry');
    if (_file != null) _append('$entry\n');
    notifyListeners();
  }

  /// Everything still on disk (older file first), or the lines in memory
  /// when there is no file. For "Copy" and "Save to file".
  Future<String> readAll() async {
    final file = _file;
    if (file == null) return _entries.map((e) => '$e\n').join();
    final old = _rotated(file);
    return [
      if (await old.exists()) await old.readAsString(),
      if (await file.exists()) await file.readAsString(),
    ].join();
  }

  /// Empties the log, in memory and on disk.
  Future<void> clear() async {
    _entries.clear();
    final file = _file;
    if (file != null) {
      for (final f in [file, _rotated(file)]) {
        if (await f.exists()) await f.delete();
      }
    }
    notifyListeners();
  }

  void _append(String text) {
    final file = _file!;
    try {
      if (file.existsSync() && file.lengthSync() > maxFileBytes) {
        file.renameSync(_rotated(file).path);
      }
      file.writeAsStringSync(text, mode: FileMode.append, flush: true);
    } on Object catch (e) {
      debugPrint('Log write failed: $e');
    }
  }

  static File _rotated(File file) =>
      File(file.path.replaceFirst(RegExp(r'\.log$'), '.1.log'));
}

/// The app's one log.
final appLog = AppLog();

/// Sends errors nobody caught to [log]: framework errors (still shown in
/// debug builds) and errors from async code. The app keeps running.
void installErrorLogging([AppLog? log]) {
  final target = log ?? appLog;
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    target.error('flutter', details.exception, details.stack);
    previous?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    target.error('uncaught', error, stack);
    return true;
  };
}
