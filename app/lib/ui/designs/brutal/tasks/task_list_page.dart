import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../../state/providers.dart';
import '../../../../sync/sync_controller.dart';
import '../common/brutal_widgets.dart';
import '../../../shared/location/location_permission.dart';
import '../../../shared/settings/sign_in_page.dart';
import '../../../shared/settings/sync_section.dart';
import '../theme/brutal.dart';
import '../theme/tokens.dart';
import '../../../shared/tasks/labels.dart';
import '../../../shared/tasks/task_rows.dart';
import 'task_detail.dart';
import 'task_filters.dart';
import 'task_tile.dart';

/// True on Linux and Windows, where keyboard shortcuts are shown.
bool get _isDesktop => Platform.isLinux || Platform.isWindows;

/// The Tasks destination: list on the left, detail panel on the right when
/// there's room; otherwise details open full-screen.
///
/// On desktop: Ctrl+N jumps to quick add, Ctrl+F to search, and Esc closes
/// the task panel.
class TaskListPage extends ConsumerStatefulWidget {
  const TaskListPage({super.key});

  @override
  ConsumerState<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends ConsumerState<TaskListPage> {
  final _quickAddFocus = FocusNode(debugLabel: 'quick add');
  final _searchFocus = FocusNode(debugLabel: 'search');
  bool _wide = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _quickAddFocus.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    if (ref.read(shellTabProvider) != ShellTabNotifier.tasks) return false;
    // Not while a dialog, menu or another page is on top.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final keys = HardwareKeyboard.instance;
    final ctrl = keys.isControlPressed || keys.isMetaPressed;
    final key = event.logicalKey;
    if (ctrl && key == LogicalKeyboardKey.keyN) {
      _quickAddFocus.requestFocus();
      return true;
    }
    if (ctrl && key == LogicalKeyboardKey.keyF) {
      _searchFocus.requestFocus();
      return true;
    }
    if (key == LogicalKeyboardKey.escape &&
        _wide &&
        ref.read(selectedTaskIdProvider) != null) {
      ref.read(selectedTaskIdProvider.notifier).select(null);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Breakpoints.listDetail;
        _wide = wide;
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

        final list = _TaskListPane(
          selectedId: selectedId,
          onOpen: open,
          quickAddFocus: _quickAddFocus,
          searchFocus: _searchFocus,
        );
        if (!wide) return list;
        final b = BrutalTheme.of(context);
        return Row(
          children: [
            Expanded(child: list),
            Container(width: BrutalTheme.line, color: b.ink),
            SizedBox(
              width: Breakpoints.detailPanelWidth,
              child: Material(
                color: b.card,
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
            ),
          ],
        );
      },
    );
  }
}

class _TaskListPane extends ConsumerWidget {
  const _TaskListPane({
    required this.selectedId,
    required this.onOpen,
    required this.quickAddFocus,
    required this.searchFocus,
  });

  final String? selectedId;
  final ValueChanged<String> onOpen;
  final FocusNode quickAddFocus;
  final FocusNode searchFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final phone = MediaQuery.sizeOf(context).width < Breakpoints.compact;
    final side = phone ? Spacing.lg : Spacing.xl;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              side,
              phone ? Spacing.md : Spacing.xl,
              side,
              Spacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  l10n.navTasks,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(width: Spacing.md),
                const Expanded(child: _Stats()),
                // Desktop shows it in the side rail instead.
                if (phone)
                  SyncStatusIcon(
                    onOpenSettings: () => ref
                        .read(shellTabProvider.notifier)
                        .select(ShellTabNotifier.settings),
                  ),
              ],
            ),
          ),
          _SyncBanner(side: side),
          const LocationPermissionBanner(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: side),
            child: TaskToolbar(searchFocus: searchFocus),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              side,
              Spacing.md,
              side + BrutalTheme.depth,
              Spacing.sm,
            ),
            child: QuickAddField(focusNode: quickAddFocus),
          ),
          Expanded(
            child: _Sections(
              selectedId: selectedId,
              onOpen: onOpen,
              side: side,
            ),
          ),
        ],
      ),
    );
  }
}

/// "10 open" and "2 overdue" stickers next to the page title.
class _Stats extends ConsumerWidget {
  const _Stats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final b = BrutalTheme.of(context);
    final sections =
        ref.watch(taskSectionsProvider).value ?? const <TaskSection>[];
    var open = 0;
    var overdue = 0;
    for (final s in sections) {
      if (s.group == TaskGroup.completed) continue;
      open += s.entries.length;
      if (s.group == TaskGroup.overdue) overdue += s.entries.length;
    }
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.xs,
      children: [
        if (open > 0) Sticker(label: l10n.statOpen(open), depth: 2),
        if (overdue > 0)
          Sticker(label: l10n.statOverdue(overdue), color: b.tomato, depth: 2),
      ],
    );
  }
}

/// Single-line "title + Enter" task creation. Keeps focus for rapid entry.
class QuickAddField extends ConsumerStatefulWidget {
  const QuickAddField({super.key, this.focusNode});

  final FocusNode? focusNode;

  @override
  ConsumerState<QuickAddField> createState() => _QuickAddFieldState();
}

class _QuickAddFieldState extends ConsumerState<QuickAddField> {
  final _controller = TextEditingController();
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void dispose() {
    _controller.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  Future<void> _submit(String value) async {
    if (value.trim().isEmpty) return;
    _controller.clear();
    _focus.requestFocus();
    await ref.read(taskRepositoryProvider).createTask(title: value);
  }

  @override
  Widget build(BuildContext context) {
    // Android's "New task" shortcut.
    ref.listen(quickAddRequestProvider, (_, _) => _focus.requestFocus());
    final b = BrutalTheme.of(context);
    final wideDesktop =
        _isDesktop && MediaQuery.sizeOf(context).width >= Breakpoints.compact;
    return ShadowBehind(
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        onSubmitted: _submit,
        textInputAction: TextInputAction.done,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: context.l10n.quickAddHint,
          prefixIcon: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: Spacing.sm,
              end: Spacing.sm,
            ),
            child: Center(
              widthFactor: 1,
              child: BrutalBox(
                color: b.yellow,
                depth: 0,
                radius: Radii.sm,
                child: SizedBox.square(
                  dimension: 30,
                  child: Icon(Icons.add, color: b.onAccent, size: 20),
                ),
              ),
            ),
          ),
          suffixIcon: wideDesktop
              ? const Padding(
                  padding: EdgeInsetsDirectional.only(end: Spacing.md),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [KeyCap('Ctrl'), SizedBox(width: 4), KeyCap('N')],
                  ),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.lg,
          ),
        ),
      ),
    );
  }
}

/// The list entries: a sticker per section, then its tasks as one card.
///
/// The card is split into slices, one per task, so the list stays lazy.
class _Sections extends ConsumerWidget {
  const _Sections({
    required this.selectedId,
    required this.onOpen,
    required this.side,
  });

  final String? selectedId;
  final ValueChanged<String> onOpen;
  final double side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final b = BrutalTheme.of(context);
    final rows = ref.watch(taskListRowsProvider);
    final collapsed = ref.watch(collapsedGroupsProvider);
    final filter = ref.watch(taskFilterProvider);

    return rows.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Message(
        icon: Icons.error_outline,
        color: b.tomato,
        text: l10n.loadError,
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return filter.isEmpty
              ? _Message(
                  icon: Icons.check,
                  color: b.yellow,
                  title: l10n.brutalEmptyTasksTitle,
                  text: l10n.emptyTasks,
                )
              : _Message(
                  icon: Icons.search_off,
                  color: b.lilac,
                  text: l10n.emptyFiltered,
                  action: filter.activeFacetCount == 0
                      ? null
                      : OutlinedButton(
                          onPressed: ref
                              .read(taskFilterProvider.notifier)
                              .clearFacets,
                          child: Text(l10n.clearFilters),
                        ),
                );
        }
        return ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            side,
            0,
            side + BrutalTheme.depth,
            Spacing.xxl + BrutalTheme.depth,
          ),
          itemCount: rows.length,
          findChildIndexCallback: rows.indexOf,
          itemBuilder: (context, i) {
            final row = rows[i];
            if (row.isHeader) {
              return _SectionHeader(
                key: row.key,
                section: row.section,
                collapsed: collapsed.contains(row.section.group),
              );
            }
            final entry = row.entry;
            return CardSlice(
              key: row.key,
              first: row.first,
              last: row.last,
              child: TaskTile(
                entry: entry,
                divider: !row.first,
                selected: entry.task.id == selectedId,
                onOpen: () => onOpen(entry.task.id),
              ),
            );
          },
        );
      },
    );
  }
}

/// The colour of a section's sticker.
Color sectionColor(TaskGroup group, BrutalTheme b) => switch (group) {
  TaskGroup.overdue => b.tomato,
  TaskGroup.today => b.yellow,
  TaskGroup.tomorrow => b.lilac,
  TaskGroup.thisWeek => b.mint,
  TaskGroup.later => b.cobalt,
  TaskGroup.noDate || TaskGroup.completed => b.card,
};

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
    final b = BrutalTheme.of(context);
    final name = l10n.groupName(section.group);
    final color = sectionColor(section.group, b);
    final plain = color == b.card;
    final fg = plain
        ? b.ink
        : section.group == TaskGroup.later &&
              theme.brightness == Brightness.light
        ? Colors.white
        : b.onAccent;
    return Semantics(
      button: true,
      expanded: !collapsed,
      label: l10n.groupHeaderSemantics(name, section.entries.length),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: Spacing.xl, bottom: Spacing.md),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: BrutalPressable(
            color: color,
            depth: 2,
            radius: Radii.sm,
            padding: const EdgeInsetsDirectional.fromSTEB(4, 3, 4, 3),
            onTap: () => ref
                .read(collapsedGroupsProvider.notifier)
                .toggle(section.group),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedRotation(
                  turns: collapsed
                      ? (Directionality.of(context) == TextDirection.rtl
                            ? 0.25
                            : -0.25)
                      : 0,
                  duration: Motion.of(context, Motion.fast),
                  child: Icon(Icons.expand_more, size: 18, color: fg),
                ),
                const SizedBox(width: 2),
                Text(
                  name.toUpperCase(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: b.ink,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    '${section.entries.length}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: b.paper,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A big tilted block with an icon, a line of text and maybe a button.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.color,
    required this.text,
    this.title,
    this.action,
    this.footer,
  });

  final IconData icon;
  final Color color;
  final String? title;
  final String text;
  final Widget? action;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = BrutalTheme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: -0.07,
              child: BrutalBox(
                color: color,
                depth: 6,
                child: SizedBox.square(
                  dimension: 84,
                  child: Icon(icon, size: 48, color: b.onAccent),
                ),
              ),
            ),
            const SizedBox(height: Spacing.xl),
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: Spacing.sm),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: Spacing.lg),
              action!,
            ],
            ?footer,
          ],
        ),
      ),
    );
  }
}

class _NoSelection extends StatelessWidget {
  const _NoSelection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final b = BrutalTheme.of(context);
    return _Message(
      icon: Icons.touch_app_outlined,
      color: b.lilac,
      text: l10n.selectTaskHint,
      footer: _isDesktop ? const _ShortcutList() : null,
    );
  }
}

/// The keyboard shortcuts, shown in the empty task panel on desktop.
class _ShortcutList extends StatelessWidget {
  const _ShortcutList();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    Widget row(String label, List<String> keys) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          for (final (i, k) in keys.indexed) ...[
            if (i > 0) const SizedBox(width: 4),
            KeyCap(k),
          ],
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.xxl),
      child: SizedBox(
        width: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrutalLabel(l10n.shortcutsTitle),
            row(l10n.shortcutNewTask, const ['Ctrl', 'N']),
            row(l10n.shortcutSearch, const ['Ctrl', 'F']),
            row(l10n.shortcutCloseTask, const ['Esc']),
          ],
        ),
      ),
    );
  }
}

/// One-time invitation to connect to a sync server (owner's choice: sign-in
/// is optional, 2026-11-02).
class _SyncBanner extends ConsumerWidget {
  const _SyncBanner({required this.side});

  final double side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncControllerProvider);
    if (!sync.loaded || sync.connected || sync.bannerDismissed) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final b = BrutalTheme.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        side,
        Spacing.xs,
        side + BrutalTheme.depth,
        Spacing.lg,
      ),
      child: BrutalBox(
        color: b.lilac,
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.md,
          Spacing.sm,
          Spacing.sm,
          Spacing.sm,
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Spacing.sm,
          runSpacing: Spacing.xs,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_outlined, color: b.onAccent),
                  const SizedBox(width: Spacing.sm),
                  Flexible(
                    child: Text(
                      l10n.syncBannerText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: b.onAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: b.onAccent),
                  onPressed: () =>
                      ref.read(syncControllerProvider.notifier).dismissBanner(),
                  child: Text(l10n.syncBannerLater),
                ),
                const SizedBox(width: Spacing.xs),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: b.yellow,
                    foregroundColor: b.onAccent,
                  ),
                  onPressed: () => showSignInPage(context),
                  child: Text(l10n.syncBannerConnect),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
