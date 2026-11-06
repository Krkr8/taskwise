import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../desktop/desktop_shell.dart';
import '../../../../state/providers.dart';
import '../../../../sync/sync_controller.dart';
import '../calendar/calendar_page.dart';
import '../common/brand_mark.dart';
import '../common/shortcut_focus.dart';
import '../settings/settings_page.dart';
import '../../../shared/common/lazy_indexed_stack.dart';
import '../../../shared/settings/sync_section.dart';
import '../../../shared/tasks/labels.dart';
import '../tasks/task_detail.dart';
import '../tasks/task_list_page.dart';
import '../theme/tokens.dart';

/// Top-level navigation: bottom bar on phones, a side bar on wider screens
/// (icons only until the window is wide enough for labels).
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

  void _focusField(FocusNode node) {
    _select(ShellTabNotifier.tasks);
    // The Tasks page may only now be visible; focus after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => node.requestFocus());
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts() {
    final map = <ShortcutActivator, VoidCallback>{};
    void both(LogicalKeyboardKey key, VoidCallback action) {
      map[SingleActivator(key, control: true)] = action;
      map[SingleActivator(key, meta: true)] = action;
    }

    both(
      LogicalKeyboardKey.keyN,
      () => _focusField(ref.read(quickAddFocusProvider)),
    );
    both(
      LogicalKeyboardKey.keyF,
      () => _focusField(ref.read(searchFocusProvider)),
    );
    both(LogicalKeyboardKey.digit1, () => _select(ShellTabNotifier.tasks));
    both(LogicalKeyboardKey.digit2, () => _select(1));
    both(LogicalKeyboardKey.digit3, () => _select(ShellTabNotifier.settings));
    map[const SingleActivator(LogicalKeyboardKey.escape)] = () {
      if (ref.read(selectedTaskIdProvider) != null) {
        ref.read(selectedTaskIdProvider.notifier).select(null);
      }
    };
    return map;
  }

  static const _pages = [TaskListPage(), CalendarPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) {
    ref.listen(openTaskRequestProvider, (_, taskId) {
      if (taskId != null) _openRequested(taskId);
    });
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < Breakpoints.compact;
    final index = ref.watch(shellTabProvider);
    final page = LazyIndexedStack(index: index, children: _pages);
    final destinations = [
      (Icons.check_circle_outline, Icons.check_circle, l10n.navTasks),
      (Icons.calendar_month_outlined, Icons.calendar_month, l10n.navCalendar),
      (Icons.settings_outlined, Icons.settings, l10n.navSettings),
    ];

    final Widget body;
    if (compact) {
      body = Scaffold(
        body: page,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: LapisColors.of(context).line),
            ),
          ),
          child: NavigationBar(
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
        ),
      );
    } else {
      body = Scaffold(
        body: Row(
          children: [
            AppSidebar(
              expanded: width >= Breakpoints.sidebar,
              selectedIndex: index,
              onSelect: _select,
              destinations: destinations,
            ),
            Expanded(child: page),
          ],
        ),
      );
    }
    return CallbackShortcuts(
      bindings: _shortcuts(),
      child: Focus(autofocus: true, child: body),
    );
  }
}

/// The desktop side bar: the brand, the three destinations, and the sync
/// state at the bottom. [expanded] shows labels; otherwise icons only.
class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.expanded,
    required this.selectedIndex,
    required this.onSelect,
    required this.destinations,
  });

  final bool expanded;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<(IconData, IconData, String)> destinations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final lapis = LapisColors.of(context);
    final openCount = ref.watch(_openTodayCountProvider);
    final width = expanded ? Breakpoints.sidebarWidth : Breakpoints.railWidth;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: lapis.sidebar,
        border: BorderDirectional(end: BorderSide(color: lapis.line)),
      ),
      child: SafeArea(
        right: false,
        left: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? Spacing.md : Spacing.sm,
            vertical: Spacing.lg,
          ),
          child: Column(
            crossAxisAlignment: expanded
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: expanded ? Spacing.sm : 0,
                  bottom: Spacing.xl,
                ),
                child: Row(
                  mainAxisAlignment: expanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    const BrandMark(size: 30),
                    if (expanded) ...[
                      const SizedBox(width: Spacing.md),
                      Text(
                        l10n.appTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              for (final (i, (icon, selectedIcon, label))
                  in destinations.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xs),
                  child: _SidebarItem(
                    icon: icon,
                    selectedIcon: selectedIcon,
                    label: label,
                    expanded: expanded,
                    selected: i == selectedIndex,
                    count: i == ShellTabNotifier.tasks && openCount > 0
                        ? openCount
                        : null,
                    onTap: () => onSelect(i),
                  ),
                ),
              const Spacer(),
              _SidebarSync(
                expanded: expanded,
                onOpenSettings: () => onSelect(ShellTabNotifier.settings),
              ),
              if (expanded) ...[
                const SizedBox(height: Spacing.md),
                _ShortcutHint(keyLabel: 'N', label: l10n.shortcutNewTask),
                const SizedBox(height: Spacing.xs),
                _ShortcutHint(keyLabel: 'F', label: l10n.shortcutSearch),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Open tasks due today or earlier, shown next to "Tasks" in the side bar.
final _openTodayCountProvider = Provider<int>((ref) {
  final today = ref.watch(todayProvider);
  final entries = ref.watch(taskEntriesProvider).value ?? const [];
  return entries
      .where(
        (e) =>
            !e.task.done &&
            e.task.dueDate != null &&
            !e.task.dueDate!.isAfter(today),
      )
      .length;
});

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.expanded,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = widget.selected;
    final fg = selected ? scheme.primary : scheme.onSurfaceVariant;
    final bg = selected
        ? scheme.surfaceContainerLow
        : _hovered
        ? scheme.onSurface.withValues(alpha: 0.05)
        : scheme.onSurface.withValues(alpha: 0);
    final radius = BorderRadius.circular(Radii.md);
    final icon = Icon(
      selected ? widget.selectedIcon : widget.icon,
      color: fg,
      size: 22,
    );

    final Widget content = widget.expanded
        ? Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: 10,
            ),
            child: Row(
              children: [
                icon,
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Text(
                    widget.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected ? scheme.onSurface : fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (widget.count case final count?)
                  Text(
                    '$count',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(height: 2),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );

    return Semantics(
      selected: selected,
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          curve: Curves.easeOut,
          width: widget.expanded ? null : 64,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radius,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.06),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : const [],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: widget.onTap,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// The sync state at the foot of the side bar; a tap syncs now.
class _SidebarSync extends ConsumerWidget {
  const _SidebarSync({required this.expanded, required this.onOpenSettings});

  final bool expanded;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncControllerProvider);
    if (!sync.connected) return const SizedBox.shrink();
    if (!expanded) return SyncStatusIcon(onOpenSettings: onOpenSettings);
    final theme = Theme.of(context);
    final text = syncStatusText(context.l10n, sync, ref.read(clockProvider)());
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.md),
      onTap: SyncStatusIcon.tapAction(ref, sync, onOpenSettings),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        child: Row(
          children: [
            IconTheme.merge(
              data: const IconThemeData(size: 20),
              child: SyncStatusIcon.forState(sync, theme.colorScheme),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Ctrl N  New task": a quiet reminder of a keyboard shortcut.
class _ShortcutHint extends StatelessWidget {
  const _ShortcutHint({required this.keyLabel, required this.label});

  final String keyLabel;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget cap(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: LapisColors.of(context).line, width: 1.2),
        color: theme.colorScheme.surfaceContainerLow,
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(color: muted),
      ),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: Spacing.md),
      child: Row(
        children: [
          // Key names stay left to right in Arabic too.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [cap('Ctrl'), const SizedBox(width: 3), cap(keyLabel)],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
