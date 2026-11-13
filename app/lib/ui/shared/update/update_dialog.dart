import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../logging/app_log.dart';
import '../../../update/update_controller.dart';
import '../../../version.dart';
import '../tasks/labels.dart';

/// Shows the available update: what's new, and Update (or how to get it on
/// the iPhone). Follows the download and install as they run.
Future<void> showUpdateDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const UpdateDialog());

class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(updateControllerProvider);
    final config = ref.watch(updateConfigProvider);
    final release = state.release;
    if (release == null) {
      // Checked again and nothing is newer (or the check failed).
      return AlertDialog(
        content: Text(updateStatusText(l10n, state)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      );
    }
    final installer = config.installer;
    final canInstall = installer != null;
    final desktop = canInstall && installer.target != UpdateTarget.android;
    final hint = config.isIos
        ? l10n.updateIosHint
        : !canInstall
        ? l10n.updateManualHint
        : desktop
        ? l10n.updateDesktopHint
        : l10n.updateAndroidHint;
    final notes = plainReleaseNotes(release.notes);

    return AlertDialog(
      title: Text(l10n.updateTitle(release.version.toString())),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.updateCurrent(appVersion),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(notes),
              ],
              const SizedBox(height: 16),
              Text(hint, style: Theme.of(context).textTheme.bodySmall),
              if (state.phase == UpdatePhase.downloading ||
                  state.phase == UpdatePhase.installing) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: state.phase == UpdatePhase.downloading
                      ? state.progress
                      : null,
                ),
                const SizedBox(height: 8),
                Text(updateStatusText(l10n, state)),
              ],
              if (state.phase == UpdatePhase.failed) ...[
                const SizedBox(height: 16),
                Text(
                  updateStatusText(l10n, state),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!state.busy)
          TextButton(
            onPressed: () {
              ref.read(updateControllerProvider.notifier).dismiss();
              Navigator.of(context).pop();
            },
            child: Text(l10n.updateLater),
          ),
        if (!canInstall || state.phase == UpdatePhase.failed)
          TextButton(
            onPressed: () => openReleasePage(release.pageUrl),
            child: Text(l10n.updateOpenPage),
          ),
        if (canInstall)
          FilledButton(
            onPressed: state.busy
                ? null
                : () => ref.read(updateControllerProvider.notifier).install(),
            child: Text(
              state.phase == UpdatePhase.failed
                  ? l10n.updateTryAgain
                  : desktop
                  ? l10n.updateNowRestart
                  : l10n.updateNow,
            ),
          ),
      ],
    );
  }
}

/// One line about the update state, for Settings and the dialog.
String updateStatusText(AppLocalizations l10n, UpdateState state) =>
    switch (state.phase) {
      UpdatePhase.idle => '',
      UpdatePhase.checking => l10n.updateChecking,
      UpdatePhase.upToDate => l10n.updateUpToDate,
      UpdatePhase.available => l10n.updateAvailable(
        state.release!.version.toString(),
      ),
      UpdatePhase.downloading => switch (state.progress) {
        final double p => l10n.updateDownloading((p * 100).round()),
        null => l10n.updateDownloadingNoSize,
      },
      UpdatePhase.installing => l10n.updateInstalling,
      UpdatePhase.failed => switch (state.error) {
        UpdateError.check || null => l10n.updateErrorCheck,
        UpdateError.download => l10n.updateErrorDownload,
        UpdateError.verification => l10n.updateErrorVerification,
        UpdateError.install => l10n.updateErrorInstall,
        UpdateError.needsPermission => l10n.updateErrorPermission,
      },
    };

/// Opens the release page in the browser.
Future<void> openReleasePage(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object catch (e) {
    appLog.warning('update', 'Could not open the release page: $e');
  }
}
