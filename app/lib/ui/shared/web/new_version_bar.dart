import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/web_shell.dart';
import '../tasks/labels.dart';

/// On the web: a banner at the top once the service worker has a new
/// version waiting ("A new version of Taskwise is ready. · Reload"), in the
/// update banner's style (`UpdateListener`), in every design. Wraps the
/// design's shell (see app.dart).
class NewVersionBar extends ConsumerStatefulWidget {
  const NewVersionBar({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NewVersionBar> createState() => _NewVersionBarState();
}

class _NewVersionBarState extends ConsumerState<NewVersionBar> {
  StreamSubscription<void>? _sub;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(webShellProvider).newVersionReady.listen((_) => _show());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _show() {
    if (!mounted || _showing) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    _showing = true;
    final l10n = context.l10n;
    messenger.showMaterialBanner(
      MaterialBanner(
        leading: const Icon(Icons.refresh),
        content: Text(l10n.newVersionReady),
        actions: [
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              ref.read(webShellProvider).reload();
            },
            child: Text(l10n.newVersionReload),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
