import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../../state/providers.dart';
import '../common/hover_surface.dart';
import '../theme/tokens.dart';
import '../../../shared/tasks/labels.dart';
import '../../../shared/tasks/task_actions.dart';

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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: HoverSurface(
        selected: selected,
        onTap: onOpen,
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
                        color: task.done
                            ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
                            : scheme.onSurface,
                        fontWeight: task.done
                            ? FontWeight.w400
                            : FontWeight.w500,
                        fontSize: 14.5,
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
          ],
        ),
      ),
    );
  }
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
        child: done
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
  });

  final String label;
  final Color bgColor;
  final Color fgColor;
  final IconData? icon;

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
              fontWeight: FontWeight.w600,
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
