import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../logging/app_log.dart';
import '../../../platform/web_shell.dart';
import '../../../state/providers.dart';

/// On the web: a tapped notification opens its task (the design's shell
/// shows `openTaskRequestProvider`'s task). The service worker focuses the
/// open app and sends the id, or opens the app at `#task=<id>`. Wraps the
/// design's shell (see app.dart); does nothing outside the browser.
class WebOpenTaskListener extends ConsumerStatefulWidget {
  const WebOpenTaskListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WebOpenTaskListener> createState() =>
      _WebOpenTaskListenerState();
}

class _WebOpenTaskListenerState extends ConsumerState<WebOpenTaskListener> {
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(webShellProvider).openTaskRequests.listen((taskId) {
      if (!mounted) return;
      appLog.info('web', 'Opening task $taskId from a notification');
      ref.read(openTaskRequestProvider.notifier).request(taskId);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
