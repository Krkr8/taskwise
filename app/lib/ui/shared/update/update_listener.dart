import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../update/update_controller.dart';
import '../tasks/labels.dart';
import 'update_dialog.dart';

/// Shows a banner at the top when a new Taskwise is out ("Taskwise 1.2.0 is
/// available · Later · See what's new"), in every design. Wraps the
/// design's shell (see app.dart).
class UpdateListener extends ConsumerStatefulWidget {
  const UpdateListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateListener> createState() => _UpdateListenerState();
}

class _UpdateListenerState extends ConsumerState<UpdateListener> {
  bool _showing = false;
  bool _dialogOpen = false;

  void _sync(UpdateState state) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final show = state.release != null && !state.dismissed;
    if (show == _showing) return;
    _showing = show;
    if (!show) {
      messenger.hideCurrentMaterialBanner();
      return;
    }
    final l10n = context.l10n;
    messenger.showMaterialBanner(
      MaterialBanner(
        leading: const Icon(Icons.system_update_alt),
        content: Text(l10n.updateAvailable(state.release!.version.toString())),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(updateControllerProvider.notifier).dismiss(),
            child: Text(l10n.updateLater),
          ),
          TextButton(
            onPressed: () {
              // The dialog takes over; the banner comes back if it's closed
              // without "Later".
              messenger.hideCurrentMaterialBanner();
              _showing = false;
              _dialogOpen = true;
              showUpdateDialog(context).then((_) {
                _dialogOpen = false;
                if (mounted) _sync(ref.read(updateControllerProvider));
              });
            },
            child: Text(l10n.updateSee),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(updateControllerProvider, (_, next) {
      // The dialog shows progress itself; keep the banner away meanwhile.
      if (next.busy || _dialogOpen) return;
      _sync(next);
    });
    return widget.child;
  }
}
