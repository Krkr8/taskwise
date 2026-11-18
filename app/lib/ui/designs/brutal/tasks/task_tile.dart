import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../../data/app_settings.dart';

import '../../../../state/providers.dart';
import '../common/brutal_widgets.dart';
import '../theme/brutal.dart';
import '../theme/tokens.dart';
import '../../../shared/tasks/labels.dart';
import '../../../shared/tasks/task_actions.dart';
import '../../../shared/tasks/subtask_tree.dart';
import 'subtask_tree_style.dart';

/// One task row in the list.
class TaskTile extends ConsumerWidget {
  const TaskTile({
    super.key,
    required this.entry,
    required this.onOpen,
    this.selected = false,
    this.divider = false,
  });

  final TaskEntry entry;
  final VoidCallback onOpen;
  final bool selected;

  /// Draws a hairline above the row (every row of a card but the first).
  final bool divider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = entry.task;
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
    final b = BrutalTheme.of(context);
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final flag = priorityColor(task.priority, scheme);
    final hasSubtasks = entry.subtaskCount > 0;
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
          style: overdue
              ? metaStyle?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                )
              : metaStyle,
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
          leading: Swatch(color: Color(category.colorValue)),
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
      if (task.skipped) const SkippedSticker(),
    ];

    final rtl = Directionality.of(context) == TextDirection.rtl;
    final dark = theme.brightness == Brightness.dark;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => handleTaskTap(
          ref,
          taskId: task.id,
          hasSubtasks: hasSubtasks,
          openDetails: onOpen,
        ),
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          decoration: BoxDecoration(
            color: selected
                ? Color.alphaBlend(
                    b.yellow.withValues(alpha: dark ? 0.1 : 0.5),
                    b.card,
                  )
                : null,
            border: Border(
              top: divider ? BorderSide(color: b.hairline) : BorderSide.none,
              left: selected && !rtl
                  ? BorderSide(color: dark ? b.yellow : b.ink, width: 5)
                  : BorderSide.none,
              right: selected && rtl
                  ? BorderSide(color: dark ? b.yellow : b.ink, width: 5)
                  : BorderSide.none,
            ),
          ),
          padding: EdgeInsetsDirectional.fromSTEB(
            selected ? 0 : 5,
            Spacing.xs,
            Spacing.md,
            Spacing.xs,
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
                      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: AnimatedDefaultTextStyle(
                                  duration: Motion.of(context, Motion.medium),
                                  style: theme.textTheme.bodyLarge!.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: task.done
                                        ? scheme.onSurfaceVariant
                                        : scheme.onSurface,
                                    decoration: task.done
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                    // A skipped task is struck with a
                                    // dashed line, a done one with a solid
                                    // line.
                                    decorationStyle: task.skipped
                                        ? TextDecorationStyle.dashed
                                        : TextDecorationStyle.solid,
                                    decorationThickness: 2,
                                  ),
                                  child: Text(
                                    task.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              if (hasSubtasks &&
                                  ref
                                          .watch(appSettingsProvider)
                                          .taskTapAction !=
                                      TaskTapAction.detailsOnly)
                                ExcludeSemantics(
                                  child: Icon(
                                    expanded
                                        ? Icons.expand_more
                                        : Icons.chevron_right,
                                    size: 20,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          if (meta.isNotEmpty) ...[
                            const SizedBox(height: Spacing.xs),
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
                        child: PriorityFlag(color: flag, size: 24),
                      ),
                    ),
                  if (showsDetailsArrow(ref, hasSubtasks: hasSubtasks))
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: Spacing.sm,
                      ),
                      child: BrutalIconButton(
                        flat: true,
                        size: 34,
                        tooltip: l10n.openDetails,
                        onPressed: onOpen,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ),
                ],
              ),
              if (expanded && hasSubtasks)
                SubtaskTree(
                  taskId: task.id,
                  style: brutalSubtaskTreeStyle(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A priority marker: a small flag on a flat block of the priority colour.
class PriorityFlag extends StatelessWidget {
  const PriorityFlag({super.key, required this.color, this.size = 20});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final b = BrutalTheme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: b.ink, width: 1.5),
      ),
      child: Icon(Icons.flag, size: size * 0.6, color: b.onAccent),
    );
  }
}

/// The "⊘ SKIPPED" tag of a skipped task: neutral hairline colour, unlike
/// the mint of a done one.
class SkippedSticker extends StatelessWidget {
  const SkippedSticker({super.key});

  @override
  Widget build(BuildContext context) {
    final b = BrutalTheme.of(context);
    return Sticker(
      label: context.l10n.skippedLabel,
      color: b.hairline,
      foreground: b.ink,
      dense: true,
      leading: const Icon(Icons.not_interested, size: 12),
    );
  }
}

/// Square check box that animates before the task moves to Completed.
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
    final skipped = done && widget.task.skipped && _pending == null;
    final b = BrutalTheme.of(context);
    final l10n = context.l10n;
    final duration = Motion.of(context, Motion.medium);
    return IconButton(
      tooltip: done
          ? l10n.markNotDone(widget.task.title)
          : l10n.markDone(widget.task.title),
      onPressed: _toggle,
      icon: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOut,
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: skipped
              ? b.hairline
              : done
              ? b.mint
              : b.card,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: b.ink, width: BrutalTheme.line),
        ),
        child: AnimatedScale(
          scale: done ? 1 : 0,
          duration: duration,
          curve: Curves.easeOutBack,
          child: Icon(
            skipped ? Icons.not_interested : Icons.check,
            size: 18,
            color: skipped ? b.ink : b.onAccent,
            weight: 700,
          ),
        ),
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
      if (icon != null) Icon(icon, size: 14, color: style?.color),
      const SizedBox(width: Spacing.xs),
      Text(label, style: style),
    ],
  );
}
