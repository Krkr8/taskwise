import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../state/providers.dart';
import '../../sync/sync_api.dart';
import '../../sync/sync_controller.dart';
import '../common/dialogs.dart';
import '../tasks/labels.dart';
import '../theme/tokens.dart';
import 'sync_section.dart';

/// Settings → Devices: every device signed in to the account (SPEC.md
/// section 3.4). Rename any; remove the others (revokes their sign-in).
class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devices = ref.watch(devicesProvider).value ?? const <Device>[];
    final thisId = ref.watch(deviceIdProvider);
    final now = ref.read(clockProvider)();

    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
      } on SyncApiException {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.deviceActionFailed)));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devicesTitle)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              children: [
                for (final device in devices)
                  ListTile(
                    leading: Icon(deviceTypeIcon(device.type)),
                    title: Text(device.name),
                    subtitle: Text(
                      device.id == thisId
                          ? l10n.deviceThis
                          : switch (device.lastSeenAt) {
                              final seen? => l10n.deviceLastSeen(
                                l10n.timeAgo(seen, now),
                              ),
                              null => '',
                            },
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (choice) async {
                        final controller = ref.read(
                          syncControllerProvider.notifier,
                        );
                        if (choice == 'rename') {
                          final name = await showTextInputDialog(
                            context,
                            title: l10n.deviceRename,
                            label: l10n.deviceName,
                            initialValue: device.name,
                          );
                          if (name != null) {
                            await run(
                              () => controller.renameDevice(device.id, name),
                            );
                          }
                        } else if (context.mounted &&
                            await _confirmRemove(context, device)) {
                          await run(() => controller.removeDevice(device.id));
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text(l10n.deviceRename),
                        ),
                        if (device.id != thisId)
                          PopupMenuItem(
                            value: 'remove',
                            child: Text(l10n.deviceRemove),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmRemove(BuildContext context, Device device) async {
    final l10n = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(l10n.deviceRemoveConfirm(device.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.deviceRemove),
              ),
            ],
          ),
        ) ??
        false;
  }
}
