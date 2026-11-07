import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../location/location_platform.dart';
import '../../../location/location_reminder_sync.dart';
import '../../../state/providers.dart';
import '../tasks/labels.dart';
import '../theme/tokens.dart';

/// Before the first location reminder on a phone: explains why Taskwise
/// needs location "Always" ("All the time" on Android), then lets the
/// phone ask. Does nothing on desktop or
/// when permission is already settled (the banner covers "denied").
Future<void> ensureLocationPermission(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!ref.read(locationPlatformProvider).supported) return;
  final notifier = ref.read(locationPermissionProvider.notifier);
  await notifier.refresh();
  if (ref.read(locationPermissionProvider) !=
          LocationPermission.notDetermined ||
      !context.mounted) {
    return;
  }
  final l10n = context.l10n;
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.location_on_outlined),
      title: Text(l10n.locPermDialogTitle),
      content: SingleChildScrollView(
        child: Text(
          Platform.isAndroid
              ? l10n.locPermDialogBodyAndroid
              : l10n.locPermDialogBody,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.locPermContinue),
        ),
      ],
    ),
  );
  if (go ?? false) await notifier.request();
}

/// "Location access: Always".
String locationPermissionLabel(BuildContext context, LocationPermission p) {
  final l10n = context.l10n;
  return switch (p) {
    LocationPermission.always =>
      Platform.isAndroid ? l10n.locPermAlwaysAndroid : l10n.locPermAlways,
    LocationPermission.whenInUse => l10n.locPermWhenInUse,
    LocationPermission.denied => l10n.locPermDenied,
    LocationPermission.restricted => l10n.locPermRestricted,
    LocationPermission.notDetermined ||
    LocationPermission.unsupported => l10n.locPermNotDetermined,
  };
}

/// On a phone, when there are location reminders but location access
/// isn't "Always": explains that they won't fire and offers a fix.
class LocationPermissionBanner extends ConsumerWidget {
  const LocationPermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = ref.watch(locationPlatformProvider);
    if (!platform.supported) return const SizedBox.shrink();
    final permission = ref.watch(locationPermissionProvider);
    final hasLocation = ref.watch(taskIdsWithLocationProvider).isNotEmpty;
    if (!hasLocation || permission == LocationPermission.always) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final off =
        permission == LocationPermission.denied ||
        permission == LocationPermission.restricted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.xs,
        Spacing.lg,
        Spacing.sm,
      ),
      child: Card.filled(
        margin: EdgeInsets.zero,
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.sm,
            Spacing.sm,
            Spacing.sm,
          ),
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Spacing.sm,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_off_outlined),
                  const SizedBox(width: Spacing.sm),
                  Flexible(
                    child: Text(
                      off
                          ? l10n.locBannerDenied
                          : Platform.isAndroid
                          ? l10n.locBannerNotAlwaysAndroid
                          : l10n.locBannerNotAlways,
                    ),
                  ),
                ],
              ),
              if (permission == LocationPermission.notDetermined)
                FilledButton.tonal(
                  onPressed: () => ensureLocationPermission(context, ref),
                  child: Text(l10n.locPermContinue),
                )
              else
                FilledButton.tonal(
                  onPressed: platform.openSettings,
                  child: Text(l10n.openSettings),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Android, in Settings → Location reminders: battery savers can stop
/// background location and delay reminders, so explain how to exempt
/// Taskwise. Nothing on other platforms.
class AndroidBatteryHint extends StatelessWidget {
  const AndroidBatteryHint({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.battery_alert_outlined),
      subtitle: Text(context.l10n.locBatteryHint),
    );
  }
}
