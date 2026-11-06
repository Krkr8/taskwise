import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../state/providers.dart';
import '../settings/sync_section.dart';
import '../theme/tokens.dart';
import 'labels.dart';

/// "Notify on": all devices (the default, which also covers devices added
/// later) or chosen ones (SPEC.md section 3.1). Hidden until there is more
/// than one device to choose from.
class DeviceTargetsEditor extends ConsumerWidget {
  const DeviceTargetsEditor({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devices = ref.watch(devicesProvider).value ?? const <Device>[];
    if (devices.length < 2) return const SizedBox.shrink();
    final all = task.notifyAllDevices;
    final chosen = ref.watch(taskTargetsProvider).value?[task.id] ?? const {};
    final repo = ref.read(taskRepositoryProvider);
    final thisId = ref.watch(deviceIdProvider);

    void choose(Set<String> ids) =>
        repo.setTaskTargets(task.id, all: false, deviceIds: ids);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.notifyOn, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            ChoiceChip(
              showCheckmark: false,
              avatar: const Icon(Icons.devices_outlined),
              label: Text(l10n.notifyAllDevices),
              selected: all,
              onSelected: (_) => repo.setTaskTargets(task.id, all: true),
            ),
            for (final device in devices)
              FilterChip(
                showCheckmark: false,
                avatar: Icon(deviceTypeIcon(device.type)),
                label: Text(
                  device.id == thisId
                      ? '${device.name} (${l10n.deviceThis})'
                      : device.name,
                ),
                selected: all || chosen.contains(device.id),
                onSelected: (on) {
                  // From "all", untick one device: keep all the others.
                  final current = all
                      ? {for (final d in devices) d.id}
                      : {...chosen};
                  on ? current.add(device.id) : current.remove(device.id);
                  choose(current);
                },
              ),
          ],
        ),
        if (!all && chosen.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.sm),
            child: Text(
              l10n.notifyNoDevice,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}
