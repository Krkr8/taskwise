import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../l10n/app_localizations.dart';
import '../../../state/providers.dart';
import '../../../sync/sync_controller.dart';
import '../tasks/labels.dart';
import '../theme/tokens.dart';
import 'devices_page.dart';
import 'sign_in_page.dart';

/// Settings → Sync: connect to a server, or the connection's status with
/// "Sync now", "Sign out" and the device list.
class SyncSection extends ConsumerWidget {
  const SyncSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sync = ref.watch(syncControllerProvider);
    final controller = ref.read(syncControllerProvider.notifier);
    if (!sync.loaded) return const SizedBox.shrink();

    if (!sync.connected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.syncNotConnectedHint, style: theme.textTheme.bodyMedium),
          const SizedBox(height: Spacing.md),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.cloud_outlined),
            label: Text(l10n.syncConnect),
            onPressed: () => showSignInPage(context),
          ),
        ],
      );
    }

    final signedOut = sync.phase == SyncPhase.signedOut;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: SyncStatusIcon.forState(sync, theme.colorScheme),
          title: Text(syncStatusText(l10n, sync, ref.read(clockProvider)())),
          subtitle: Text(
            [
              Uri.parse(sync.serverUrl!).host,
              if (sync.username case final user? when user.isNotEmpty)
                l10n.syncSignedInAs(user),
            ].join(' · '),
          ),
        ),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            if (signedOut)
              FilledButton.icon(
                icon: const Icon(Icons.login),
                label: Text(l10n.syncSignInAgain),
                onPressed: () => showSignInPage(context),
              )
            else
              FilledButton.tonalIcon(
                icon: const Icon(Icons.sync),
                label: Text(l10n.syncNow),
                onPressed: sync.phase == SyncPhase.syncing
                    ? null
                    : controller.syncNow,
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: Text(l10n.syncSignOut),
              onPressed: () => _confirmSignOut(context, ref, sync),
            ),
          ],
        ),
        if (!signedOut)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.devices_outlined),
            title: Text(l10n.devicesTitle),
            subtitle: Text(l10n.devicesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DevicesPage()),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
    SyncState sync,
  ) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.syncSignOutConfirm(Uri.parse(sync.serverUrl!).host)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.syncSignOut),
          ),
        ],
      ),
    );
    if (ok ?? false) await ref.read(syncControllerProvider.notifier).signOut();
  }
}

/// One line about the sync state: "Synced 2 min ago", "Offline...".
String syncStatusText(AppLocalizations l10n, SyncState sync, DateTime now) =>
    switch (sync.phase) {
      SyncPhase.syncing => l10n.syncStatusSyncing,
      SyncPhase.offline => l10n.syncStatusOffline,
      SyncPhase.signedOut => l10n.syncStatusSignedOut,
      SyncPhase.error => switch (sync.message) {
        final message? when message.isNotEmpty => l10n.syncStatusError(message),
        _ => l10n.actionFailed,
      },
      SyncPhase.idle => switch (sync.lastSyncedAt) {
        final at? => l10n.syncStatusSynced(l10n.timeAgo(at, now)),
        null => l10n.syncStatusNever,
      },
    };

/// The small cloud icon for a sync state. Tapping it syncs now; when the
/// device must sign in again it calls [onOpenSettings] instead.
class SyncStatusIcon extends ConsumerWidget {
  const SyncStatusIcon({super.key, this.onOpenSettings});

  final VoidCallback? onOpenSettings;

  static Widget forState(SyncState sync, ColorScheme scheme) =>
      switch (sync.phase) {
        SyncPhase.syncing => const Icon(Icons.cloud_sync_outlined),
        SyncPhase.offline => Icon(
          Icons.cloud_off_outlined,
          color: scheme.onSurfaceVariant,
        ),
        SyncPhase.signedOut || SyncPhase.error => Icon(
          Icons.sync_problem_outlined,
          color: scheme.error,
        ),
        SyncPhase.idle => Icon(
          Icons.cloud_done_outlined,
          color: scheme.primary,
        ),
      };

  /// What a tap on the sync status does: sync now, or open Settings when
  /// the device is signed out. Nothing while a sync is running.
  static VoidCallback? tapAction(
    WidgetRef ref,
    SyncState sync,
    VoidCallback? onOpenSettings,
  ) => switch (sync.phase) {
    SyncPhase.syncing => null,
    SyncPhase.signedOut => onOpenSettings,
    _ => ref.read(syncControllerProvider.notifier).syncNow,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncControllerProvider);
    if (!sync.connected) return const SizedBox.shrink();
    final text = syncStatusText(context.l10n, sync, ref.read(clockProvider)());
    return IconButton(
      tooltip: text,
      icon: forState(sync, Theme.of(context).colorScheme),
      onPressed: tapAction(ref, sync, onOpenSettings),
    );
  }
}

/// Icon for a device type.
IconData deviceTypeIcon(DeviceType type) => switch (type) {
  DeviceType.windows => Icons.desktop_windows_outlined,
  DeviceType.linux => Icons.laptop_outlined,
  DeviceType.ios => Icons.phone_iphone,
  DeviceType.android => Icons.phone_android,
  DeviceType.other => Icons.devices_other_outlined,
};
