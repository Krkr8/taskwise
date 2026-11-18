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

/// One task row in the list.
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
    final hasSubtasks = entry.subtaskCount > 0;
    final expanded = ref.watch(expandedTasksProvider).contains(task.id);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todayProvider);
    final timeFormat = ref.watch(appSettingsProvider).timeFormat;
    final category = task.categoryId == null
        ? null
        : ref.watch(categoriesByIdProvider)[task.categoryId];
    final due = l10n.dueLabel(task, today, timeFormat);
    final overdue =
        !task.done && task.dueDate != null && task.dueDate!.isBefore(today);
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
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
      if (due != null)
        _Meta(
          icon: Icons.event_outlined,
          label: due,
          style: overdue ? metaStyle?.copyWith(color: scheme.error) : metaStyle,
        ),
      if (hasReminders)
        Tooltip(
          message: remindsHere ? l10n.hasReminders : l10n.notNotifiedHere,
          child: Icon(
            remindsHere
                ? Icons.notifications_outlined
                : Icons.notifications_off_outlined,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
        ),
      if (hasLocation)
        Tooltip(
          message: l10n.settingsLocation,
          child: Icon(
            Icons.place_outlined,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
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
          style: metaStyle,
        ),
      if (entry.subtaskCount > 0)
        _Meta(
          icon: Icons.checklist,
          label: l10n.subtaskProgress(entry.subtasksDone, entry.subtaskCount),
          style: metaStyle,
        ),
      if (task.notes.trim().isNotEmpty)
        Icon(Icons.notes, size: 16, color: scheme.onSurfaceVariant),
      if (task.skipped && task.done) const SkippedBadge(),
    ];

    return HoverSurface(
      selected: selected,
      onTap: () => handleTaskTap(
        ref,
        taskId: task.id,
        hasSubtasks: hasSubtasks,
        openDetails: onOpen,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.xs,
          2,
          Spacing.md,
          2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CompleteButton(task: task),
                const SizedBox(width: Spacing.xs),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: Motion.of(context, Motion.medium),
                          style: theme.textTheme.bodyLarge!.copyWith(
                            fontWeight: FontWeight.w500,
                            color: task.done
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                            decoration: task.done
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                          child: Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: Spacing.md,
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
                    padding: const EdgeInsetsDirectional.only(
                      start: Spacing.sm,
                    ),
                    child: Tooltip(
                      message:
                          '${l10n.priority}: ${l10n.priorityName(task.priority)}',
                      child: Icon(Icons.flag_rounded, size: 18, color: flag),
                    ),
                  ),
                if (showsDetailsArrow(ref, hasSubtasks: hasSubtasks))
                  DetailsArrowButton(onPressed: onOpen)
                else if (hasSubtasks &&
                    ref.watch(appSettingsProvider).taskTapAction !=
                        TaskTapAction.detailsOnly)
                  FoldChevron(expanded: expanded),
              ],
            ),
            if (expanded && hasSubtasks)
              SubtaskTree(
                taskId: task.id,
                style: lapisSubtaskTreeStyle(context),
              ),
          ],
        ),
      ),
    );
  }
}

/// The small bordered arrow at the end of a row that opens its details,
/// shown when a tap only unfolds the subtasks.
class DetailsArrowButton extends StatelessWidget {
  const DetailsArrowButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.l10n.openDetails,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.sm),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(color: LapisColors.of(context).line),
            ),
            child: Icon(
              Icons.chevron_right,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet arrow that shows whether a row's subtasks are unfolded. The row
/// itself takes the tap.
class FoldChevron extends StatelessWidget {
  const FoldChevron({super.key, required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Tooltip(
      message: expanded ? l10n.hideSubtasks : l10n.showSubtasks,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sm),
        child: Icon(
          expanded ? Icons.expand_more : Icons.chevron_right,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The warm rose "Skipped" badge that tells a skipped task from a done one.
class SkippedBadge extends StatelessWidget {
  const SkippedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = dark ? const Color(0xFFE0B3C4) : const Color(0xFF8A5A6A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF3A2630) : const Color(0xFFF3E5EC),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.redo, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            context.l10n.skippedLabel,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Round check button that animates before the task moves to Completed.
class CompleteButton extends ConsumerStatefulWidget {
  const CompleteButton({super.key, required this.task});

  final Task task;

  @override
  ConsumerState<CompleteButton> createState() => _CompleteButtonState();
}

class _CompleteButtonState extends ConsumerState<CompleteButton> {
  /// Shown immediately on tap so the check animates before the row moves.
  bool? _pending;
  bool _hovered = false;

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
    final skipped = done && widget.task.done && widget.task.skipped;
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final color = priorityColor(widget.task.priority, scheme) ?? scheme.outline;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: IconButton(
        tooltip: done
            ? l10n.markNotDone(widget.task.title)
            : l10n.markDone(widget.task.title),
        onPressed: _toggle,
        icon: AnimatedSwitcher(
          duration: Motion.of(context, Motion.medium),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
          child: skipped
              ? const SkippedRing(key: ValueKey('skipped'))
              : CheckRing(
                  key: ValueKey(done),
                  done: done,
                  hovered: _hovered,
                  color: color,
                  fill: scheme.primary,
                  onFill: scheme.onPrimary,
                ),
        ),
      ),
    );
  }
}

/// The round check: a ring in the priority colour, filled when done.
/// On hover a faint check previews the click.
class CheckRing extends StatelessWidget {
  const CheckRing({
    super.key,
    required this.done,
    required this.color,
    required this.fill,
    required this.onFill,
    this.hovered = false,
    this.size = 22,
  });

  final bool done;
  final bool hovered;
  final Color color;
  final Color fill;
  final Color onFill;
  final double size;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: Motion.of(context, Motion.fast),
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: done
          ? fill
          : hovered
          ? color.withValues(alpha: 0.12)
          : Colors.transparent,
      border: done ? null : Border.all(color: color, width: 2),
    ),
    child: done || hovered
        ? Icon(
            Icons.check_rounded,
            size: size * 0.7,
            color: done ? onFill : color,
          )
        : null,
  );
}

/// The muted warm tone that marks a skipped task (ring and arrows).
Color skippedColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFC9A39A)
    : const Color(0xFFA87C72);

/// The check ring of a skipped task: an empty ring in a muted warm tone
/// with a bent arrow, instead of the filled lapis circle of a done task.
class SkippedRing extends StatelessWidget {
  const SkippedRing({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    final color = skippedColor(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(Icons.redo, size: size * 0.6, color: color),
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
      if (icon != null) Icon(icon, size: 14, color: style?.color),
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
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
