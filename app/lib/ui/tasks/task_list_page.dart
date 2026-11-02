import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../state/providers.dart';
import '../../sync/sync_controller.dart';
import '../settings/sign_in_page.dart';
import '../settings/sync_section.dart';
import '../theme/tokens.dart';
import 'labels.dart';
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
                    position: Tween(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(animation),
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
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.lg,
              Spacing.lg,
              Spacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.navTasks,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                // Desktop shows it in the side rail instead.
                if (MediaQuery.sizeOf(context).width < Breakpoints.compact)
                  SyncStatusIcon(
                    onTap: () => ref
                        .read(shellTabProvider.notifier)
                        .select(ShellTabNotifier.settings),
                  ),
              ],
            ),
          ),
          const _SyncBanner(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: TaskToolbar(),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.sm,
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

/// Single-line "title + Enter" task creation. Keeps focus for rapid entry.
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
    await ref.read(taskRepositoryProvider).createTask(title: value);
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focus,
    onSubmitted: _submit,
    textInputAction: TextInputAction.done,
    decoration: InputDecoration(
      hintText: context.l10n.quickAddHint,
      prefixIcon: const Icon(Icons.add),
    ),
  );
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
              ? _Message(icon: Icons.task_alt, text: l10n.emptyTasks)
              : _Message(
                  icon: Icons.search_off,
                  text: l10n.emptyFiltered,
                  action: filter.activeFacetCount == 0
                      ? null
                      : TextButton(
                          onPressed: ref
                              .read(taskFilterProvider.notifier)
                              .clearFacets,
                          child: Text(l10n.clearFilters),
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
            Spacing.sm,
            0,
            Spacing.sm,
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
    final name = l10n.groupName(section.group);
    final color = section.group == TaskGroup.overdue
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return Semantics(
      button: true,
      expanded: !collapsed,
      label: l10n.groupHeaderSemantics(name, section.entries.length),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
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
                child: Icon(Icons.expand_more, size: 20, color: color),
              ),
              const SizedBox(width: Spacing.xs),
              Text(
                name,
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                '${section.entries.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: Spacing.md),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: Spacing.sm),
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

/// One-time invitation to connect to a sync server (owner's choice: sign-in
/// is optional, 2026-11-02).
class _SyncBanner extends ConsumerWidget {
  const _SyncBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncControllerProvider);
    if (!sync.loaded || sync.connected || sync.bannerDismissed) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.xs,
        Spacing.lg,
        Spacing.sm,
      ),
      child: Card.filled(
        margin: EdgeInsets.zero,
        child: Padding(
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
                  const Icon(Icons.cloud_outlined),
                  const SizedBox(width: Spacing.sm),
                  Flexible(child: Text(l10n.syncBannerText)),
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
      ),
    );
  }
}
