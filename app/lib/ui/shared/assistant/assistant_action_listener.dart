import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../assistant/assistant_platform.dart';
import '../../../assistant/assistant_sync.dart';
import '../../../logging/app_log.dart';
import '../../../state/providers.dart';
import '../tasks/labels.dart';

/// Carries out what Android asks from outside the app, in every design:
/// - the "New task" shortcut (long-press the app icon) goes to Tasks and
///   focuses the quick-add field;
/// - text shared to Taskwise becomes a task at once, with an "Added" message
///   whose Open button shows it.
///
/// Wraps the design's shell (see app.dart).
class AssistantActionListener extends ConsumerStatefulWidget {
  const AssistantActionListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AssistantActionListener> createState() =>
      _AssistantActionListenerState();
}

class _AssistantActionListenerState
    extends ConsumerState<AssistantActionListener> {
  StreamSubscription<AssistantAction?>? _events;

  @override
  void initState() {
    super.initState();
    final platform = ref.read(assistantPlatformProvider);
    _events = platform.events.listen((a) {
      if (a != null) unawaited(_handle(a));
    });
    unawaited(
      platform.takeLaunchAction().then((a) async {
        if (a != null) await _handle(a);
      }, onError: (Object e) => appLog.warning('assistant', '$e')),
    );
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    super.dispose();
  }

  Future<void> _handle(AssistantAction action) async {
    if (!mounted) return;
    switch (action) {
      case NewTaskAction():
        _showTasks();
        // The Tasks page may only now be built; focus after this frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(quickAddRequestProvider.notifier).request();
        });
      case SharedTextAction(:final text):
        await _addShared(text);
    }
  }

  void _showTasks() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    ref.read(shellTabProvider.notifier).select(ShellTabNotifier.tasks);
  }

  Future<void> _addShared(String text) async {
    final parsed = taskFromSharedText(text);
    if (parsed == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    try {
      final task = await ref
          .read(taskRepositoryProvider)
          .createTask(title: parsed.title, notes: parsed.notes);
      appLog.info('assistant', 'Added a task from shared text');
      if (!mounted) return;
      _showTasks();
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.sharedTaskAdded(task.title)),
            action: SnackBarAction(
              label: l10n.notifOpen,
              onPressed: () =>
                  ref.read(openTaskRequestProvider.notifier).request(task.id),
            ),
          ),
        );
    } on Object catch (e, stack) {
      appLog.error('assistant', e, stack, 'Adding a shared task failed');
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
