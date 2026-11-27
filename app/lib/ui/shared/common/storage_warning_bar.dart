import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/storage_status.dart';
import '../tasks/labels.dart';
import '../theme/tokens.dart';

/// A bar above the design's shell while the browser can't keep the tasks
/// ([StorageStatus.temporary]), in every design. It stays for the whole
/// visit; otherwise it shows nothing. Wraps the shell (see app.dart).
///
/// The tree has the same shape either way, so the shell keeps its state
/// (tab, scroll, typed text) when the bar comes or goes.
class StorageWarningBar extends ConsumerWidget {
  const StorageWarningBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final temporary =
        ref.watch(storageStatusProvider) == StorageStatus.temporary;
    return Column(
      children: [
        if (temporary) const _Bar() else const SizedBox.shrink(),
        Expanded(
          // The bar already keeps clear of the status bar.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: temporary,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_outlined,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Text(
                  context.l10n.storageTemporaryWarning,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
