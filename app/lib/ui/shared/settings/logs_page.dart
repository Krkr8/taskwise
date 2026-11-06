import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../logging/app_log.dart';
import '../common/messages.dart';
import '../tasks/labels.dart';
import '../theme/tokens.dart';

/// Settings → About → View logs: the newest log lines first, with copy,
/// save and clear. Shared by every design.
class LogsPage extends StatefulWidget {
  const LogsPage({super.key, this.log});

  /// The log to show; the app's own one when null (tests pass their own).
  final AppLog? log;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  bool _problemsOnly = false;

  AppLog get _log => widget.log ?? appLog;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.logsTitle),
        actions: [
          IconButton(
            tooltip: l10n.logsCopy,
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: _copy,
          ),
          IconButton(
            tooltip: l10n.logsSave,
            icon: const Icon(Icons.save_alt_outlined),
            onPressed: _save,
          ),
          IconButton(
            tooltip: l10n.logsClear,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _log.clear,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Spacing.sm),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l10n.logsFilterAll)),
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.logsFilterProblems),
                  ),
                ],
                selected: {_problemsOnly},
                onSelectionChanged: (s) =>
                    setState(() => _problemsOnly = s.single),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _log,
                builder: (context, _) {
                  final entries = _log.entries.reversed
                      .where((e) => !_problemsOnly || e.level != LogLevel.info)
                      .toList();
                  if (entries.isEmpty) {
                    return Center(child: Text(l10n.logsEmpty));
                  }
                  return ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) =>
                        _LogLine(entries[i], theme: theme),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy() async {
    final copied = context.l10n.logsCopied;
    final text = await _log.readAll();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showMessage(context, copied);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final now = DateTime.now();
    final name = 'taskwise-log-${now.toIso8601String().substring(0, 10)}.txt';
    await guardAction(context, 'logs', () async {
      final String path;
      if (Platform.isIOS) {
        path = '${(await getApplicationDocumentsDirectory()).path}/$name';
      } else {
        final location = await getSaveLocation(suggestedName: name);
        if (location == null) return;
        path = location.path;
      }
      await File(path).writeAsString(await _log.readAll(), flush: true);
      if (mounted) {
        showMessage(
          context,
          Platform.isIOS ? l10n.backupSavedIos(name) : l10n.backupSaved(path),
        );
      }
    });
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine(this.entry, {required this.theme});

  final LogEntry entry;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final (icon, color) = switch (entry.level) {
      LogLevel.info => (Icons.info_outline, scheme.onSurfaceVariant),
      LogLevel.warning => (Icons.warning_amber_outlined, scheme.tertiary),
      LogLevel.error => (Icons.error_outline, scheme.error),
    };
    final t = entry.time;
    final when =
        '${t.year}-${_two(t.month)}-${_two(t.day)} '
        '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 20),
      title: Text('[${entry.tag}] ${entry.message}'),
      subtitle: Text(when),
      titleTextStyle: theme.textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Courier New', 'Menlo'],
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');
