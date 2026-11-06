import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../data/backup.dart';
import '../../../logging/app_log.dart';
import '../../../state/providers.dart';
import '../../../sync/sync_controller.dart';
import '../common/messages.dart';
import '../tasks/labels.dart';

const _json = XTypeGroup(
  label: 'JSON',
  extensions: ['json'],
  mimeTypes: ['application/json'],
  uniformTypeIdentifiers: ['public.json'],
);

/// Settings → Backup: export everything to a JSON file, or import one.
/// Shared by every design.
class BackupSection extends ConsumerWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.upload_file_outlined),
          title: Text(l10n.backupExport),
          subtitle: Text(l10n.backupExportSubtitle),
          onTap: () => exportBackup(context, ref),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.download_outlined),
          title: Text(l10n.backupImport),
          subtitle: Text(l10n.backupImportSubtitle),
          onTap: () => importBackup(context, ref),
        ),
      ],
    );
  }
}

Backup _backup(WidgetRef ref) => Backup(
  ref.read(databaseProvider),
  deviceId: ref.read(deviceIdProvider),
  clock: ref.read(clockProvider),
);

/// Writes a backup. Desktop: where the user picks. iPhone: the app's
/// Documents folder, which the Files app shows under "On My iPhone".
Future<void> exportBackup(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final now = ref.read(clockProvider)();
  final name =
      'taskwise-backup-${now.year}-${_two(now.month)}-${_two(now.day)}.json';
  await guardAction(context, 'backup', () async {
    final String path;
    if (Platform.isIOS) {
      path = '${(await getApplicationDocumentsDirectory()).path}/$name';
    } else {
      final location = await getSaveLocation(
        suggestedName: name,
        acceptedTypeGroups: const [_json],
      );
      if (location == null) return;
      path = location.path;
    }
    final json = await _backup(ref).export();
    await File(path).writeAsString(json, flush: true);
    appLog.info('backup', 'Exported ${json.length} bytes');
    if (context.mounted) {
      showMessage(
        context,
        Platform.isIOS ? l10n.backupSavedIos(name) : l10n.backupSaved(path),
      );
    }
  });
}

/// Merges a backup file the user picks into this device's data.
Future<void> importBackup(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  await guardAction(context, 'backup', () async {
    final file = await openFile(acceptedTypeGroups: const [_json]);
    if (file == null) return;
    String message;
    try {
      final report = await _backup(ref).import(await file.readAsString());
      appLog.info('backup', 'Imported: $report');
      message = l10n.backupImported(
        report.added + report.updated,
        report.kept,
        report.skipped,
      );
      // Send what changed to the other devices now.
      ref.read(syncControllerProvider.notifier).syncNow().ignore();
    } on BackupException catch (e) {
      appLog.warning('backup', 'Import refused: ${e.problem.name}');
      message = switch (e.problem) {
        BackupProblem.notABackup => l10n.backupNotABackup,
        BackupProblem.tooNew => l10n.backupTooNew,
      };
    }
    if (context.mounted) showMessage(context, message);
  });
}

String _two(int n) => n.toString().padLeft(2, '0');
