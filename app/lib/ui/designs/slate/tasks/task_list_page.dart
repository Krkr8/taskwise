import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../../state/providers.dart';
import '../../../../sync/sync_controller.dart';
import '../../../shared/location/location_permission.dart';
import '../../../shared/settings/sign_in_page.dart';
import '../../../shared/settings/sync_section.dart';
import '../theme/tokens.dart';
import '../../../shared/tasks/labels.dart';
import 'task_detail.dart';
import 'task_filters.dart';
import 'task_tile.dart';

/// The Tasks destination: list on the left, detail panel on the right when
/// there's room; otherwise details open full-screen.
class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Breakpoints.listDetail;
        final selectedId = wide ? ref.watch(selectedTaskIdProvider) : null;

        void open(String id) {
          if (wide) {
            ref.read(selectedTaskIdProvider.notifier).select(id);
          } else {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TaskDetailPage(taskId: id),
              ),
            );
          }
        }

        final list = _TaskListPane(selectedId: selectedId, onOpen: open);
        if (!wide) return list;
        return Row(
          children: [
            Expanded(child: list),
            const VerticalDivider(width: 1),
            SizedBox(
              width: Breakpoints.detailPanelWidth,
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.medium),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position:
                        Tween(
                          begin: const Offset(0.03, 0),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                    child: child,
                  ),
                ),
                child: selectedId == null
                    ? const _NoSelection()
                    : TaskDetailView(
                        key: ValueKey(selectedId),
                        taskId: selectedId,
                        onClose: () => ref
                            .read(selectedTaskIdProvider.notifier)
                            .select(null),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TaskListPane extends ConsumerWidget {
  const _TaskListPane({required this.selectedId, required this.onOpen});

  final String? selectedId;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todayProvider);
    final dateStr = DateFormat.MMMMEEEEd(l10n.localeName)
        .format(today.atLocalTime());

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.lg,
              Spacing.lg,
              Spacing.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.navTasks,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: Spacing.xxs),
                      Text(
                        dateStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Compact phone layout shows sync status in the header
                if (MediaQuery.sizeOf(context).width < Breakpoints.compact)
                  SyncStatusIcon(
                    onTap: () => ref
                        .read(shellTabProvider.notifier)
                        .select(ShellTabNotifier.settings),
                  ),
              ],
            ),
          ),
          const _TodayProgressCard(),
          const _SyncBanner(),
          const LocationPermissionBanner(),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.xs,
              Spacing.lg,
              Spacing.xs,
            ),
            child: TaskToolbar(),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.xs,
              Spacing.lg,
              Spacing.sm,
            ),
            child: QuickAddField(),
          ),
          Expanded(
            child: _Sections(selectedId: selectedId, onOpen: onOpen),
          ),
        ],
      ),
    );
  }
}

/// Subtle, delightful progress overview for today's tasks.
class _TodayProgressCard extends ConsumerWidget {
  const _TodayProgressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(taskSectionsProvider).value;
    if (sections == null || sections.isEmpty) return const SizedBox.shrink();

    // Look for today's section
    TaskSection? todaySection;
    for (final s in sections) {
      if (s.group == TaskGroup.today) {
        todaySection = s;
        break;
      }
    }

    if (todaySection == null || todaySection.entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = todaySection.entries.length;
    final done = todaySection.entries.where((e) => e.task.done).length;
    final progress = total > 0 ? done / total : 0.0;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.xs,
        Spacing.lg,
        Spacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  done == total ? Icons.check_circle : Icons.trending_up,
                  size: 16,
                  color: done == total ? scheme.primary : scheme.secondary,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    done == total
                        ? l10n.progressAllDone
                        : l10n.progressSummary(done, total),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: done == total ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xs + 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.full),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  done == total ? const Color(0xFF10B981) : scheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Elevated single-line "title + Enter" task creation. Keeps focus for rapid entry.
class QuickAddField extends ConsumerStatefulWidget {
  const QuickAddField({super.key});

  @override
  ConsumerState<QuickAddField> createState() => _QuickAddFieldState();
}

class _QuickAddFieldState extends ConsumerState<QuickAddField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit(String value) async {
    if (value.trim().isEmpty) return;
    _controller.clear();
    _focus.requestFocus();
    await ref.read(taskRepositoryProvider).createTask(title: value.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        onSubmitted: _submit,
        textInputAction: TextInputAction.done,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: l10n.quickAddHint,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 10),
            child: Icon(
              Icons.add_circle_outline_rounded,
              color: scheme.primary,
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 42,
            minHeight: 42,
          ),
          suffixIcon: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _controller.text.trim().isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: l10n.quickAddSubmitTooltip,
                    icon: Icon(
                      Icons.arrow_upward_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                    onPressed: () => _submit(_controller.text),
                  ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.md,
          ),
        ),
      ),
    );
  }
}

/// Flattened, collapsible list of task sections.
class _Sections extends ConsumerWidget {
  const _Sections({required this.selectedId, required this.onOpen});

  final String? selectedId;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sections = ref.watch(taskSectionsProvider);
    final collapsed = ref.watch(collapsedGroupsProvider);
    final filter = ref.watch(taskFilterProvider);

    return sections.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          _Message(icon: Icons.error_outline, text: l10n.loadError),
      data: (sections) {
        if (sections.isEmpty) {
          return filter.isEmpty
              ? _Message(
                  icon: Icons.task_alt_rounded,
                  text: l10n.emptyTasks,
                  headline: l10n.todayOverview,
                )
              : _Message(
                  icon: Icons.search_off_rounded,
                  text: l10n.emptyFiltered,
                  action: filter.activeFacetCount == 0
                      ? null
                      : TextButton.icon(
                          onPressed: ref
                              .read(taskFilterProvider.notifier)
                              .clearFacets,
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          label: Text(l10n.clearFilters),
                        ),
                );
        }
        final items = <Widget>[];
        for (final section in sections) {
          final isCollapsed = collapsed.contains(section.group);
          items.add(
            _SectionHeader(
              key: ValueKey(section.group),
              section: section,
              collapsed: isCollapsed,
            ),
          );
          if (!isCollapsed) {
            for (final entry in section.entries) {
              items.add(
                TaskTile(
                  key: ValueKey(entry.task.id),
                  entry: entry,
                  selected: entry.task.id == selectedId,
                  onOpen: () => onOpen(entry.task.id),
                ),
              );
            }
          }
        }
        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            0,
            Spacing.md,
            Spacing.xxl,
          ),
          children: items,
        );
      },
    );
  }
}

class _SectionHeader extends ConsumerWidget {
  const _SectionHeader({
    super.key,
    required this.section,
    required this.collapsed,
  });

  final TaskSection section;
  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = l10n.groupName(section.group);
    final isOverdue = section.group == TaskGroup.overdue;
    final isToday = section.group == TaskGroup.today;

    final color = isOverdue
        ? scheme.error
        : isToday
        ? scheme.primary
        : scheme.onSurface;

    final countBg = isOverdue
        ? scheme.errorContainer
        : isToday
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;

    final countFg = isOverdue
        ? scheme.onErrorContainer
        : isToday
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      expanded: !collapsed,
      label: l10n.groupHeaderSemantics(name, section.entries.length),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: () =>
            ref.read(collapsedGroupsProvider.notifier).toggle(section.group),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.sm,
            Spacing.lg,
            Spacing.sm,
            Spacing.xs,
          ),
          child: Row(
            children: [
              AnimatedRotation(
                turns: collapsed
                    ? (Directionality.of(context) == TextDirection.rtl
                          ? 0.25
                          : -0.25)
                    : 0,
                duration: Motion.of(context, Motion.fast),
                child: Icon(Icons.expand_more_rounded, size: 20, color: color),
              ),
              const SizedBox(width: Spacing.xs),
              Text(
                name,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: countBg,
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
                child: Text(
                  '${section.entries.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: countFg,
                    fontWeight: FontWeight.w700,
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

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.headline,
    this.action,
  });

  final IconData icon;
  final String text;
  final String? headline;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: Center(child: Icon(icon, size: 36, color: scheme.primary)),
            ),
            const SizedBox(height: Spacing.lg),
            if (headline != null) ...[
              Text(
                headline!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Spacing.xs),
            ],
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: Spacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _NoSelection extends StatelessWidget {
  const _NoSelection();

  @override
  Widget build(BuildContext context) => _Message(
    icon: Icons.touch_app_outlined,
    text: context.l10n.selectTaskHint,
  );
}

/// One-time invitation to connect to a sync server.
class _SyncBanner extends ConsumerWidget {
  const _SyncBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncControllerProvider);
    if (!sync.loaded || sync.connected || sync.bannerDismissed) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.xs,
        Spacing.lg,
        Spacing.sm,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          Spacing.md,
          Spacing.sm,
          Spacing.sm,
          Spacing.sm,
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Spacing.sm,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_outlined, color: scheme.primary, size: 20),
                const SizedBox(width: Spacing.sm),
                Flexible(
                  child: Text(
                    l10n.syncBannerText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () =>
                  ref.read(syncControllerProvider.notifier).dismissBanner(),
              child: Text(l10n.syncBannerLater),
            ),
            FilledButton.tonal(
              onPressed: () => showSignInPage(context),
              child: Text(l10n.syncBannerConnect),
            ),
          ],
        ),
      ),
    );
  }
}
