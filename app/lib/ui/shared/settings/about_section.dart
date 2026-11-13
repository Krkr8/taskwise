import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../update/update_controller.dart';
import '../../../version.dart';
import '../tasks/labels.dart';
import '../update/update_dialog.dart';
import 'logs_page.dart';

/// Settings → About: the version, updates and the logs. Shared by every
/// design.
class AboutSection extends ConsumerWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final updates = ref.watch(updateConfigProvider).enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.aboutVersion(appVersion)),
        ),
        if (updates) const _UpdateRows(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.receipt_long_outlined),
          title: Text(l10n.aboutViewLogs),
          subtitle: Text(l10n.aboutViewLogsSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => const LogsPage())),
        ),
      ],
    );
  }
}

/// "Check for updates" (with the result) and the automatic-check switch.
class _UpdateRows extends ConsumerWidget {
  const _UpdateRows();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(updateControllerProvider);
    final controller = ref.read(updateControllerProvider.notifier);
    final status = updateStatusText(l10n, state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: state.phase == UpdatePhase.checking
              ? const SizedBox.square(
                  dimension: 24,
                  child: Padding(
                    padding: EdgeInsets.all(2),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.system_update_alt),
          title: Text(l10n.updateCheck),
          subtitle: status.isEmpty ? null : Text(status),
          trailing: state.release != null
              ? const Icon(Icons.chevron_right)
              : null,
          onTap: state.phase == UpdatePhase.checking
              ? null
              : () async {
                  if (state.release == null) await controller.check();
                  if (!context.mounted) return;
                  if (ref.read(updateControllerProvider).release != null) {
                    await showUpdateDialog(context);
                  }
                },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.update),
          title: Text(l10n.updateAuto),
          subtitle: Text(l10n.updateAutoSubtitle),
          value: state.autoCheck,
          onChanged: controller.setAutoCheck,
        ),
      ],
    );
  }
}
