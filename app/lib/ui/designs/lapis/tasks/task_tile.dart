import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../../state/providers.dart';
import '../common/hover_surface.dart';
import '../theme/tokens.dart';
import '../../../shared/tasks/labels.dart';
import '../../../shared/tasks/task_actions.dart';

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
    ];

    return HoverSurface(
      selected: selected,
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.xs,
          2,
          Spacing.md,
          2,
        ),
        child: Row(
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
                padding: const EdgeInsetsDirectional.only(start: Spacing.sm),
                child: Tooltip(
                  message:
                      '${l10n.priority}: ${l10n.priorityName(task.priority)}',
                  child: Icon(Icons.flag_rounded, size: 18, color: flag),
                ),
              ),
          ],
        ),
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
          child: CheckRing(
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
