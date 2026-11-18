import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../../data/app_settings.dart';

import '../../../../state/providers.dart';
import '../common/hover_surface.dart';
import '../theme/tokens.dart';
import '../../../shared/tasks/labels.dart';
import '../../../shared/tasks/subtask_tree.dart';
import '../../../shared/tasks/task_actions.dart';
import 'subtask_tree_style.dart';

/// One task row in the list with subtle hover elevation and tactile checkmark.
class TaskTile extends ConsumerWidget {
  const TaskTile({
    super.key,
    required this.entry,
    required this.onOpen,
    this.selected = false,
  });

  final TaskEntry entry;
  final VoidCallback onOpen;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = entry.task;
    final skipped = task.done && task.skipped;
    final hasSubtasks = entry.subtaskCount > 0;
    final expanded =
        hasSubtasks && ref.watch(expandedTasksProvider).contains(task.id);
    final detailsArrow = showsDetailsArrow(ref, hasSubtasks: hasSubtasks);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final skip = SkipColors.of(scheme);
    final today = ref.watch(todayProvider);
    final timeFormat = ref.watch(appSettingsProvider).timeFormat;
    final category = task.categoryId == null
        ? null
        : ref.watch(categoriesByIdProvider)[task.categoryId];
    final due = l10n.dueLabel(task, today, timeFormat);
    final overdue =
        !task.done && task.dueDate != null && task.dueDate!.isBefore(today);
    final isTodayDue =
        !task.done && task.dueDate != null && task.dueDate == today;

    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontSize: 12,
    );
    final flag = priorityColor(task.priority, scheme);
    final hasReminders = ref
        .watch(taskIdsWithRemindersProvider)
        .contains(task.id);
    final hasLocation = ref
        .watch(taskIdsWithLocationProvider)
        .contains(task.id);
    final remindsHere = notifiesHere(
      task,
      ref.watch(taskTargetsProvider).value ?? const {},
      ref.watch(deviceIdProvider),
    );

    final meta = <Widget>[
      if (skipped)
        _Badge(
          icon: Icons.skip_next_rounded,
          label: l10n.skippedLabel,
          bgColor: skip.container,
          fgColor: skip.text,
          bold: true,
        ),
      if (due != null)
        _Badge(
          icon: Icons.calendar_today_outlined,
          label: due,
          bgColor: overdue
              ? scheme.errorContainer.withValues(alpha: 0.5)
              : isTodayDue
              ? scheme.primaryContainer.withValues(alpha: 0.5)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          fgColor: overdue
              ? scheme.error
              : isTodayDue
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      if (hasReminders)
        Tooltip(
          message: remindsHere ? l10n.hasReminders : l10n.notNotifiedHere,
          child: Icon(
            remindsHere
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            size: 15,
            color: remindsHere ? scheme.primary : scheme.outline,
          ),
        ),
      if (hasLocation)
        Tooltip(
          message: l10n.settingsLocation,
          child: Icon(Icons.place_outlined, size: 16, color: scheme.secondary),
        ),
      if (task.recurrenceRule != null)
        Tooltip(
          message: l10n.repeatingTask,
          child: Icon(Icons.repeat, size: 16, color: scheme.onSurfaceVariant),
        ),
      if (category != null)
        _Meta(
          leading: _Dot(color: Color(category.colorValue)),
          label: category.name,
          style: metaStyle?.copyWith(fontWeight: FontWeight.w500),
        ),
      if (entry.subtaskCount > 0)
        _Meta(
          icon: Icons.checklist_rounded,
          label: l10n.subtaskProgress(entry.subtasksDone, entry.subtaskCount),
          style: metaStyle,
        ),
      if (task.notes.trim().isNotEmpty)
        Icon(Icons.notes_rounded, size: 15, color: scheme.onSurfaceVariant),
    ];

    final titleColor = skipped
        ? _skippedGrey
        : task.done
        ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
        : scheme.onSurface;

    final tile = HoverSurface(
      selected: selected,
      onTap: () => handleTaskTap(
        ref,
        taskId: task.id,
        hasSubtasks: hasSubtasks,
        openDetails: onOpen,
      ),
      borderRadius: BorderRadius.circular(Radii.md),
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.sm,
        Spacing.xs,
        Spacing.md,
        Spacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CompleteButton(task: task),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xs + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: Motion.of(context, Motion.medium),
                    curve: Curves.easeOutCubic,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: titleColor,
                      fontWeight: task.done ? FontWeight.w400 : FontWeight.w500,
                      fontSize: 14.5,
                      decoration: task.done
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationStyle: skipped
                          ? TextDecorationStyle.dashed
                          : TextDecorationStyle.solid,
                    ),
                    child: Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: Spacing.xs + 2),
                    Wrap(
                      spacing: Spacing.sm + 2,
                      runSpacing: Spacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: meta,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (flag != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: Spacing.sm),
              child: Tooltip(
                message:
                    '${l10n.priority}: ${l10n.priorityName(task.priority)}',
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: priorityBackgroundColor(task.priority, scheme),
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Icon(Icons.flag_rounded, size: 16, color: flag),
                ),
              ),
            ),
          if (hasSubtasks &&
              ref.watch(appSettingsProvider).taskTapAction !=
                  TaskTapAction.detailsOnly)
            _FoldButton(
              expanded: expanded,
              onPressed: () =>
                  ref.read(expandedTasksProvider.notifier).toggle(task.id),
            ),
          if (detailsArrow) _DetailsButton(onPressed: onOpen),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          skipped
              ? CustomPaint(
                  foregroundPainter: _DashedBorder(
                    color: scheme.outline.withValues(alpha: 0.6),
                    radius: Radii.md,
                  ),
                  child: tile,
                )
              : tile,
          if (expanded)
            SubtaskTree(taskId: task.id, style: slateSubtaskTreeStyle(context)),
        ],
      ),
    );
  }
}

/// Muted grey of a skipped task's title (same in both themes).
const _skippedGrey = Color(0xFF94A3B8);

/// The chevron that unfolds and folds a task's subtasks.
class _FoldButton extends StatelessWidget {
  const _FoldButton({required this.expanded, required this.onPressed});

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return IconButton(
      tooltip: expanded ? l10n.hideSubtasks : l10n.showSubtasks,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      iconSize: 20,
      icon: AnimatedRotation(
        turns: expanded ? 0.5 : 0,
        duration: Motion.of(context, Motion.fast),
        child: Icon(
          Icons.expand_more_rounded,
          color: expanded ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The small "open details" button of the "Show subtasks only" setting.
class _DetailsButton extends StatelessWidget {
  const _DetailsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: Spacing.xs),
      child: Tooltip(
        message: context.l10n.openDetails,
        child: Material(
          color: scheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
            side: BorderSide(color: scheme.primary.withValues(alpha: 0.3)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(Spacing.xs + 2),
              child: Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                size: 18,
                color: scheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dashed rounded border, drawn over a skipped task's tile.
class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(0.5),
      );
    for (final metric in path.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += 7) {
        canvas.drawPath(metric.extractPath(at, at + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}

/// Round check button that animates with elastic scale before the task moves.
class CompleteButton extends ConsumerStatefulWidget {
  const CompleteButton({super.key, required this.task});

  final Task task;

  @override
  ConsumerState<CompleteButton> createState() => _CompleteButtonState();
}

class _CompleteButtonState extends ConsumerState<CompleteButton> {
  /// Shown immediately on tap so the check animates before the row moves.
  bool? _pending;

  @override
  void didUpdateWidget(CompleteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.done != oldWidget.task.done) _pending = null;
  }

  Future<void> _toggle() async {
    final done = !(_pending ?? widget.task.done);
    setState(() => _pending = done);
    final delay = Motion.of(context, Motion.medium);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (!mounted) return;
    await setTaskDone(context, ref, widget.task, done: done);
  }

  @override
  Widget build(BuildContext context) {
    final done = _pending ?? widget.task.done;
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final pColor = priorityColor(widget.task.priority, scheme);
    final skip = SkipColors.of(scheme);

    return IconButton(
      tooltip: done
          ? l10n.markNotDone(widget.task.title)
          : l10n.markDone(widget.task.title),
      onPressed: _toggle,
      iconSize: 22,
      splashRadius: 20,
      icon: AnimatedSwitcher(
        duration: Motion.of(context, Motion.medium),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: child,
        ),
        child: done && widget.task.skipped && _pending == null
            ? Container(
                key: const ValueKey('skipped'),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: skip.container,
                  shape: BoxShape.circle,
                  border: Border.all(color: skip.accent, width: 1.8),
                ),
                child: Icon(
                  Icons.skip_next_rounded,
                  size: 14,
                  color: skip.text,
                ),
              )
            : done
            ? Container(
                key: const ValueKey(true),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              )
            : Container(
                key: const ValueKey(false),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: pColor ?? scheme.outline.withValues(alpha: 0.7),
                    width: 1.8,
                  ),
                ),
              ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.bgColor,
    required this.fgColor,
    this.icon,
    this.bold = false,
  });

  final String label;
  final Color bgColor;
  final Color fgColor;
  final IconData? icon;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(Radii.xs + 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fgColor),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, this.icon, this.leading, this.style});

  final String label;
  final IconData? icon;
  final Widget? leading;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ?leading,
      if (icon != null) Icon(icon, size: 13, color: style?.color),
      const SizedBox(width: Spacing.xs),
      Text(label, style: style),
    ],
  );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    margin: const EdgeInsetsDirectional.only(end: 2),
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 3),
      ],
    ),
  );
}
