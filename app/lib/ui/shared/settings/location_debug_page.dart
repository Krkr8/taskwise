import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../location/location_platform.dart';
import '../../../location/location_reminder_sync.dart';
import '../tasks/labels.dart';
import '../theme/tokens.dart';
import '../location/location_permission.dart';

/// iPhone only: what the phone watches for location reminders and what
/// happened lately, for the real-world tests (SPEC.md M7).
class LocationDebugPage extends ConsumerStatefulWidget {
  const LocationDebugPage({super.key});

  @override
  ConsumerState<LocationDebugPage> createState() => _LocationDebugPageState();
}

class _LocationDebugPageState extends ConsumerState<LocationDebugPage> {
  LocationDebugState? _state;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final state = await ref.read(locationPlatformProvider).debugState();
    if (!mounted) return;
    setState(() {
      _state = state;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = _state;
    final fix = state?.lastFix;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.locDebugTitle),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading && state == null
          ? const Center(child: CircularProgressIndicator())
          : state == null
          ? Center(child: Text(l10n.locOnlyIphone))
          : ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.my_location),
                  title: Text(l10n.locPermissionStatus),
                  trailing: Text(
                    locationPermissionLabel(context, state.permission),
                  ),
                ),
                Text(l10n.locDebugEntries(state.entries)),
                if (fix != null)
                  Text(l10n.locDebugLastFix(fix.accuracy.round())),
                if (state.preciseActive)
                  Text(
                    l10n.locDebugPrecise,
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                const SizedBox(height: Spacing.lg),
                Text(l10n.locDebugRegions, style: theme.textTheme.titleSmall),
                for (final r in state.regions)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      r.state == 'inside'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(
                      '${r.latitude.toStringAsFixed(5)}, '
                      '${r.longitude.toStringAsFixed(5)} · '
                      '${l10n.meters(r.radius.round())} · ${r.state}',
                    ),
                    subtitle: fix == null
                        ? Text(r.id)
                        : Text(
                            '${l10n.locDebugAway(distanceMeters(fix.latitude, fix.longitude, r.latitude, r.longitude).round())}'
                            ' · ${r.id}',
                          ),
                  ),
                const SizedBox(height: Spacing.lg),
                Text(l10n.locDebugEvents, style: theme.textTheme.titleSmall),
                const SizedBox(height: Spacing.xs),
                if (state.events.isEmpty) Text(l10n.locDebugNoEvents),
                for (final e in state.events)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: SelectableText(
                      e,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
