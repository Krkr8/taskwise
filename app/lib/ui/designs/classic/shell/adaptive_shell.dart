import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../desktop/desktop_shell.dart';
import '../../../../state/providers.dart';
import '../calendar/calendar_page.dart';
import '../settings/settings_page.dart';
import '../../../shared/settings/sync_section.dart';
import '../../../shared/tasks/labels.dart';
import '../tasks/task_detail.dart';
import '../tasks/task_list_page.dart';
import '../../../shared/theme/tokens.dart';

/// Top-level navigation: bottom bar on phones, side rail on wider screens.
///
/// Also opens the task a notification asked for: switches to Tasks and
/// shows it in the side panel (wide) or full-screen (narrow).
class AdaptiveShell extends ConsumerStatefulWidget {
  const AdaptiveShell({super.key});

  @override
  ConsumerState<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends ConsumerState<AdaptiveShell> {
  void _select(int index) => ref.read(shellTabProvider.notifier).select(index);

  void _openRequested(String taskId) {
    ref.read(openTaskRequestProvider.notifier).clear();
    unawaited(DesktopShell.instance?.showWindow());
    _select(ShellTabNotifier.tasks);
    if (MediaQuery.sizeOf(context).width >= Breakpoints.listDetail) {
      ref.read(selectedTaskIdProvider.notifier).select(taskId);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => TaskDetailPage(taskId: taskId)),
      );
    }
  }

  static const _pages = [TaskListPage(), CalendarPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) {
    ref.listen(openTaskRequestProvider, (_, taskId) {
      if (taskId != null) _openRequested(taskId);
    });
    final l10n = context.l10n;
    final compact = MediaQuery.sizeOf(context).width < Breakpoints.compact;
    final index = ref.watch(shellTabProvider);
    final page = IndexedStack(index: index, children: _pages);
    final destinations = [
      (Icons.check_circle_outline, Icons.check_circle, l10n.navTasks),
      (Icons.calendar_month_outlined, Icons.calendar_month, l10n.navCalendar),
      (Icons.settings_outlined, Icons.settings, l10n.navSettings),
    ];

    if (compact) {
      return Scaffold(
        body: page,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: _select,
          destinations: [
            for (final (icon, selected, label) in destinations)
              NavigationDestination(
                icon: Icon(icon),
                selectedIcon: Icon(selected),
                label: label,
              ),
          ],
        ),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: _select,
            labelType: NavigationRailLabelType.all,
            groupAlignment: -1,
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: SyncStatusIcon(
                    onOpenSettings: () => _select(ShellTabNotifier.settings),
                  ),
                ),
              ),
            ),
            destinations: [
              for (final (icon, selected, label) in destinations)
                NavigationRailDestination(
                  icon: Icon(icon),
                  selectedIcon: Icon(selected),
                  label: Text(label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: page),
        ],
      ),
    );
  }
}
