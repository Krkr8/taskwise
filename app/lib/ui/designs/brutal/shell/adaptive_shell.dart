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
import '../common/brutal_widgets.dart';
import '../theme/brutal.dart';
import '../theme/tokens.dart';

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
        bottomNavigationBar: BrutalNavBar(
          selectedIndex: index,
          onSelected: _select,
          destinations: destinations,
        ),
      );
    }
    final b = BrutalTheme.of(context);
    return Scaffold(
      body: Row(
        children: [
          BrutalNavRail(
            selectedIndex: index,
            onSelected: _select,
            destinations: destinations,
            trailing: SyncStatusIcon(
              onTap: () => _select(ShellTabNotifier.settings),
            ),
          ),
          Container(width: BrutalTheme.line, color: b.ink),
          Expanded(child: page),
        ],
      ),
    );
  }
}

typedef NavDestination = (IconData icon, IconData selected, String label);

/// Desktop side rail: the Taskwise mark on top, one block per destination
/// (the current one yellow and raised), sync status at the bottom.
class BrutalNavRail extends StatelessWidget {
  const BrutalNavRail({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
    this.trailing,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavDestination> destinations;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      right: false,
      left: false,
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            const SizedBox(height: Spacing.lg),
            const TaskwiseMark(),
            const SizedBox(height: Spacing.xl),
            for (final (i, (icon, selected, label)) in destinations.indexed)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.sm + 2,
                  0,
                  Spacing.sm + 2,
                  Spacing.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: _NavItem(
                    icon: i == selectedIndex ? selected : icon,
                    label: label,
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
              ),
            const Spacer(),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.md),
                child: trailing,
              ),
          ],
        ),
      ),
    );
  }
}

/// Phone bottom bar: an ink rule on top, the current tab a raised yellow
/// block.
class BrutalNavBar extends StatelessWidget {
  const BrutalNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final b = BrutalTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: b.card,
        border: Border(
          top: BorderSide(color: b.ink, width: BrutalTheme.line),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.sm,
            Spacing.md,
            Spacing.sm + 2,
          ),
          child: Row(
            children: [
              for (final (i, (icon, selected, label)) in destinations.indexed)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.xs + 2,
                    ),
                    child: _NavItem(
                      icon: i == selectedIndex ? selected : icon,
                      label: label,
                      selected: i == selectedIndex,
                      onTap: () => onSelected(i),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = BrutalTheme.of(context);
    final fg = selected ? b.onAccent : b.ink;
    return BrutalPressable(
      onTap: onTap,
      semanticLabel: label,
      color: selected ? b.yellow : b.card,
      hoverColor: selected ? b.yellow : b.card,
      flat: !selected,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: fg,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Taskwise mark: a yellow block with a heavy check, like the app icon.
class TaskwiseMark extends StatelessWidget {
  const TaskwiseMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    final b = BrutalTheme.of(context);
    return Semantics(
      label: 'Taskwise',
      child: BrutalBox(
        color: b.yellow,
        depth: BrutalTheme.depthSmall,
        child: SizedBox.square(
          dimension: size,
          child: Icon(
            Icons.check,
            size: size * 0.7,
            color: b.onAccent,
            weight: 700,
          ),
        ),
      ),
    );
  }
}
