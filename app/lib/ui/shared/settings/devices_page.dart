import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../state/providers.dart';
import '../../../sync/sync_api.dart';
import '../../../sync/sync_controller.dart';
import '../common/dialogs.dart';
import '../tasks/labels.dart';
import '../theme/tokens.dart';
import 'sync_section.dart';

/// Settings → Devices: every device signed in to the account (SPEC.md
/// section 3.4).
///
/// The main device (the first to sign in) manages the others: it can
/// rename and remove them and pass the role on. Any device can rename
/// itself, and can take the main role with the account password if the main
/// device is lost.
class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final devices = ref.watch(devicesProvider).value ?? const <Device>[];
    final thisId = ref.watch(deviceIdProvider);
    final now = ref.read(clockProvider)();
    final iAmMain = devices.any((d) => d.id == thisId && d.isMain);
    final controller = ref.read(syncControllerProvider.notifier);

    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
      } on SyncHttpException catch (e) {
        if (context.mounted) {
          _snack(
            context,
            e.code == 'wrong_password'
                ? l10n.deviceWrongPassword
                : l10n.signInErrorOther(e.message),
          );
        }
      } on SyncApiException {
        if (context.mounted) _snack(context, l10n.deviceActionFailed);
      }
    }

    String subtitle(Device device) => [
      if (device.isMain) l10n.deviceMain,
      if (device.id == thisId)
        l10n.deviceThis
      else if (device.lastSeenAt case final seen?)
        l10n.deviceLastSeen(l10n.timeAgo(seen, now)),
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devicesTitle)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => ListView(
            padding: centeredPadding(
              box.maxWidth,
              const EdgeInsets.symmetric(vertical: Spacing.sm),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg,
                  vertical: Spacing.sm,
                ),
                child: Text(
                  l10n.devicesMainHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final device in devices)
                ListTile(
                  leading: Icon(deviceTypeIcon(device.type)),
                  title: Text(device.name),
                  subtitle: Text(subtitle(device)),
                  trailing: device.id == thisId || iAmMain
                      ? PopupMenuButton<String>(
                          onSelected: (choice) async {
                            switch (choice) {
                              case 'rename':
                                final name = await showTextInputDialog(
                                  context,
                                  title: l10n.deviceRename,
                                  label: l10n.deviceName,
                                  initialValue: device.name,
                                );
                                if (name != null) {
                                  await run(
                                    () => controller.renameDevice(
                                      device.id,
                                      name,
                                    ),
                                  );
                                }
                              case 'main':
                                if (await _confirm(
                                  context,
                                  l10n.deviceMakeMainConfirm(device.name),
                                  l10n.deviceMakeMain,
                                )) {
                                  await run(
                                    () => controller.makeMain(device.id),
                                  );
                                }
                              case 'remove':
                                if (await _confirm(
                                  context,
                                  l10n.deviceRemoveConfirm(device.name),
                                  l10n.deviceRemove,
                                )) {
                                  await run(
                                    () => controller.removeDevice(device.id),
                                  );
                                }
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text(l10n.deviceRename),
                            ),
                            if (iAmMain && device.id != thisId) ...[
                              PopupMenuItem(
                                value: 'main',
                                child: Text(l10n.deviceMakeMain),
                              ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Text(l10n.deviceRemove),
                              ),
                            ],
                          ],
                        )
                      : null,
                ),
              if (!iAmMain && devices.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.deviceClaimMainHelp,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: Spacing.sm),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: Text(l10n.deviceClaimMain),
                        onPressed: () async {
                          final password = await _askPassword(context);
                          if (password != null) {
                            await run(() => controller.claimMain(password));
                          }
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _confirm(
    BuildContext context,
    String text,
    String action,
  ) async {
    final l10n = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(text),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _askPassword(BuildContext context) => showDialog<String>(
    context: context,
    builder: (_) => const _PasswordDialog(),
  );
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.isNotEmpty) {
      Navigator.of(context).pop(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.deviceClaimMain),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        decoration: InputDecoration(labelText: l10n.signInPassword),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.deviceClaimMain)),
      ],
    );
  }
}
