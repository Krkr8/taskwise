import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../../state/providers.dart';
import '../../../../sync/sync_controller.dart';
import '../common/brand_mark.dart';
import '../common/sheet_piece.dart';
import '../common/shortcut_focus.dart';
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
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Container(
                width: Breakpoints.detailPanelWidth,
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    start: BorderSide(color: LapisColors.of(context).line),
                  ),
                ),
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
  const _TaskListPane({required this.selectedId, required this.onOpen});

  final String? selectedId;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Spacing.xl,
              Spacing.xl,
              Spacing.lg,
              Spacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(child: _DateHeading()),
                const _TodayProgress(),
                // Desktop shows it in the side bar instead.
                if (MediaQuery.sizeOf(context).width < Breakpoints.compact)
                  SyncStatusIcon(
                    onOpenSettings: () => ref
                        .read(shellTabProvider.notifier)
                        .select(ShellTabNotifier.settings),
                  ),
              ],
            ),
          ),
          const _SyncBanner(),
          const LocationPermissionBanner(),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.xs,
              Spacing.lg,
              Spacing.sm,
            ),
            child: QuickAddField(),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.xs),
            child: TaskToolbar(),
          ),
          Expanded(
            child: _Sections(selectedId: selectedId, onOpen: onOpen),
          ),
        ],
      ),
    );
  }
}

/// "Friday" over "6 November": the list opens on the day it is.
class _DateHeading extends ConsumerWidget {
  const _DateHeading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locale = context.l10n.localeName;
    final today = ref.watch(todayProvider).atLocalTime();
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.EEEE(locale).format(today),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium?.copyWith(height: 1.15),
          ),
          Text(
            DateFormat.MMMMd(locale).format(today),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Today's tasks (due today or overdue, plus those finished today).
final _todayCountsProvider = Provider<({int done, int total})>((ref) {
  final today = ref.watch(todayProvider);
  final entries = ref.watch(taskEntriesProvider).value ?? const [];
  var done = 0;
  var open = 0;
  for (final e in entries) {
    final t = e.task;
    if (t.done) {
      final at = t.completedAt;
      if (at != null && LocalDate.fromDateTime(at.toLocal()) == today) done++;
    } else if (t.dueDate != null && !t.dueDate!.isAfter(today)) {
      open++;
    }
  }
  return (done: done, total: done + open);
});

/// A saffron ring that fills as today's tasks get done.
class _TodayProgress extends ConsumerWidget {
  const _TodayProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(_todayCountsProvider);
    if (counts.total == 0) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final lapis = LapisColors.of(context);
    final left = counts.total - counts.done;
    final value = counts.done / counts.total;
    return Semantics(
      label: l10n.todayProgressSemantics(counts.done, counts.total),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: Spacing.md,
          end: Spacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  left == 0 ? l10n.todayAllDone : l10n.todayLeft(left),
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  l10n.todayDone(counts.done),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(width: Spacing.md),
            TweenAnimationBuilder<double>(
              tween: Tween(end: value),
              duration: Motion.of(context, Motion.slow),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => CustomPaint(
                size: const Size.square(38),
                painter: _RingPainter(
                  value: v,
                  track: lapis.line,
                  color: lapis.today,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.track,
    required this.color,
  });

  final double value;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        paint..color = color,
      );
    }
    if (value >= 1) {
      final c = size.center(Offset.zero);
      final s = size.shortestSide;
      final check = Path()
        ..moveTo(c.dx - s * 0.17, c.dy + s * 0.01)
        ..lineTo(c.dx - s * 0.04, c.dy + s * 0.13)
        ..lineTo(c.dx + s * 0.18, c.dy - s * 0.12);
      canvas.drawPath(
        check,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

/// Single-line "title + Enter" task creation. Keeps focus for rapid entry.
class QuickAddField extends ConsumerStatefulWidget {
  const QuickAddField({super.key});

  @override
  ConsumerState<QuickAddField> createState() => _QuickAddFieldState();
}

class _QuickAddFieldState extends ConsumerState<QuickAddField> {
  final _controller = TextEditingController();
  late final FocusNode _focus = ref.read(quickAddFocusProvider);

  @override
  void initState() {
    super.initState();
    _focus.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_refresh);
    _controller.dispose();
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
    final scheme = Theme.of(context).colorScheme;
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: Motion.of(context, Motion.fast),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: [
          BoxShadow(
            color: (focused ? scheme.primary : scheme.shadow).withValues(
              alpha: focused ? 0.14 : 0.05,
            ),
            blurRadius: focused ? 14 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        onSubmitted: _submit,
        textInputAction: TextInputAction.done,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: context.l10n.quickAddHint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.lg,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.lg),
            borderSide: BorderSide(color: LapisColors.of(context).line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.lg),
            borderSide: BorderSide(color: LapisColors.of(context).line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.lg),
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: Spacing.md,
              end: Spacing.sm,
            ),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(Icons.add, size: 20, color: scheme.onPrimary),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minHeight: 28),
        ),
      ),
    );
  }
}

/// Flattened, collapsible list of task sections. Each section's tasks sit
/// on one sheet, like a page of a planner (one list item per row, so long
/// lists stay lazy).
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
              ? const _EmptyDay()
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
            final entries = section.entries;
            for (final (i, entry) in entries.indexed) {
              items.add(
                SheetPiece(
                  key: ValueKey(entry.task.id),
                  first: i == 0,
                  last: i == entries.length - 1,
                  dividerIndent: 52,
                  child: TaskTile(
                    entry: entry,
                    selected: entry.task.id == selectedId,
                    onOpen: () => onOpen(entry.task.id),
                  ),
                ),
              );
            }
          }
        }
        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            0,
            Spacing.lg,
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
    final lapis = LapisColors.of(context);
    final name = l10n.groupName(section.group);
    final (Color color, Color? dot) = switch (section.group) {
      TaskGroup.overdue => (scheme.error, scheme.error),
      TaskGroup.today => (scheme.onSurface, lapis.today),
      TaskGroup.completed => (scheme.onSurfaceVariant, null),
      _ => (scheme.onSurface, null),
    };
    final rtl = Directionality.of(context) == TextDirection.rtl;
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
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.sm,
            Spacing.xl,
            Spacing.sm,
            Spacing.sm,
          ),
          child: Row(
            children: [
              if (dot != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: Spacing.sm),
              ],
              Text(
                name,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                '${section.entries.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              AnimatedRotation(
                turns: collapsed ? (rtl ? 0.25 : -0.25) : 0,
                duration: Motion.of(context, Motion.fast),
                child: Icon(
                  Icons.expand_more,
                  size: 20,
                  color: scheme.onSurfaceVariant,
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
            Icon(icon, size: 40, color: theme.colorScheme.outline),
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

/// The empty list: a blank planner page and a nudge to write the first task.
class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BlankPage(),
            const SizedBox(height: Spacing.xl),
            Text(
              l10n.lapisEmptyTasksTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: Spacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                l10n.lapisEmptyTasks,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
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

/// A small drawing of an empty planner page with today's sun in the corner.
class _BlankPage extends StatelessWidget {
  const _BlankPage();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lapis = LapisColors.of(context);
    Widget line(double width) => Container(
      width: width,
      height: 6,
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: lapis.line,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    Widget ring() => Container(
      width: 14,
      height: 14,
      margin: const EdgeInsetsDirectional.only(end: 10, top: 6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: lapis.line, width: 2),
      ),
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: 150,
        height: 130,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              top: 14,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(Radii.lg),
                  border: Border.all(color: lapis.line, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final w in const [70.0, 50.0, 62.0])
                      Row(children: [ring(), line(w)]),
                  ],
                ),
              ),
            ),
            PositionedDirectional(
              end: -10,
              top: 0,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: lapis.today,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 4),
                ),
              ),
            ),
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
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(opacity: 0.35, child: const BrandMark(size: 44)),
            const SizedBox(height: Spacing.lg),
            Text(
              context.l10n.selectTaskHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.lg,
            Spacing.sm,
            Spacing.sm,
            Spacing.sm,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final text = Row(
                children: [
                  Icon(
                    Icons.cloud_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(child: Text(l10n.syncBannerText)),
                ],
              );
              final buttons = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => ref
                        .read(syncControllerProvider.notifier)
                        .dismissBanner(),
                    child: Text(l10n.syncBannerLater),
                  ),
                  const SizedBox(width: Spacing.xs),
                  FilledButton(
                    onPressed: () => showSignInPage(context),
                    child: Text(l10n.syncBannerConnect),
                  ),
                ],
              );
              if (constraints.maxWidth >= 520) {
                return Row(
                  children: [
                    Expanded(child: text),
                    const SizedBox(width: Spacing.sm),
                    buttons,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: Spacing.xs,
                      end: Spacing.sm,
                    ),
                    child: text,
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: buttons,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
