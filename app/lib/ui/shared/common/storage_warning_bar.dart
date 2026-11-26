import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/storage_status.dart';
import '../tasks/labels.dart';
import '../theme/tokens.dart';

/// A bar above the design's shell when the browser can't keep the tasks
/// ([StorageStatus.temporary]), in every design. It can be closed for this
/// visit; otherwise it shows nothing. Wraps the shell (see app.dart).
class StorageWarningBar extends ConsumerStatefulWidget {
  const StorageWarningBar({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StorageWarningBar> createState() => _StorageWarningBarState();
}

class _StorageWarningBarState extends ConsumerState<StorageWarningBar> {
  bool _closed = false;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(storageStatusProvider);
    if (status == StorageStatus.persistent || _closed) return widget.child;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Material(
          color: scheme.errorContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: Spacing.lg,
                top: Spacing.xs,
                bottom: Spacing.xs,
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
                  IconButton(
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                    color: scheme.onErrorContainer,
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _closed = true),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          // The bar already keeps clear of the status bar.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
