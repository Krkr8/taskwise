import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../../state/providers.dart';
import '../../../shared/tasks/labels.dart';
import '../../../shared/tasks/subtask_tree.dart';
import '../../../shared/tasks/task_actions.dart';
import '../tasks/subtask_tree_style.dart';
import '../../../shared/theme/tokens.dart';
import 'calendar_widgets.dart';

/// Seven day columns, each a list of that day's tasks: all-day tasks first,
/// then timed ones in time order (the order [calendarItems] returns).
///
/// Columns follow the week-start setting, and a [Row] puts them right to
/// left in Arabic. Today's column is outlined in the accent colour.
/// Tapping a day header or the empty part of a column adds a task that day.
class WeekView extends ConsumerWidget {
  const WeekView({
    super.key,
    required this.days,
    required this.onOpenItem,
    required this.onAdd,
  });

  /// The 7 dates shown, in order.
  final List<LocalDate> days;
  final ValueChanged<CalendarItem> onOpenItem;

  /// Add an all-day task on a date.
  final ValueChanged<LocalDate> onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final today = ref.watch(todayProvider);
    final items =
        ref
            .watch(calendarItemsProvider((from: days.first, to: days.last)))
            .value ??
        const <LocalDate, List<CalendarItem>>{};
    final grid = scheme.outlineVariant.withValues(alpha: 0.5);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, day) in days.indexed)
          Expanded(
            child: _DayColumn(
              day: day,
              items: items[day] ?? const <CalendarItem>[],
              isToday: day == today,
              gridColor: grid,
              // Every column draws its start edge; the last also its end.
              border: BorderDirectional(
                start: BorderSide(color: grid),
                end: i == 6 ? BorderSide(color: grid) : BorderSide.none,
              ),
              addLabel: l10n.addTaskOn(l10n.relativeDate(day, today)),
              onOpenItem: onOpenItem,
              onAdd: () => onAdd(day),
            ),
          ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.items,
    required this.isToday,
    required this.gridColor,
    required this.border,
    required this.addLabel,
    required this.onOpenItem,
    required this.onAdd,
  });

  final LocalDate day;
  final List<CalendarItem> items;
  final bool isToday;
  final Color gridColor;
  final BorderDirectional border;
  final String addLabel;
  final ValueChanged<CalendarItem> onOpenItem;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final header = Semantics(
      label: addLabel,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onAdd,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          child: Column(
            children: [
              Text(
                l10n.weekdayName(day.weekday, short: true),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isToday ? scheme.primary : scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
              Text(
                DateFormat.d(l10n.localeName).format(day.atLocalTime()),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isToday ? scheme.primary : scheme.onSurface,
                  fontWeight: isToday ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        border: isToday ? Border.all(color: scheme.primary, width: 2) : border,
        borderRadius: isToday ? BorderRadius.circular(6) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Divider(height: 1, color: gridColor),
          Expanded(
            // Tapping below the tasks adds one; the list scrolls when full.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAdd,
              child: ListView(
                // Bottom room so the + button doesn't cover the last task.
                padding: const EdgeInsets.fromLTRB(2, 4, 2, 72),
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: _WeekItem(
                        item: item,
                        onOpen: () => onOpenItem(item),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A task chip in a day column. A real task with subtasks follows the tap
/// setting and unfolds a compact subtask tree under the chip; a projected
/// repeat never does.
class _WeekItem extends ConsumerWidget {
  const _WeekItem({required this.item, required this.onOpen});

  final CalendarItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = item.task;
    final hasSubtasks =
        !item.projected && (ref.watch(subtaskCountsProvider)[task.id] ?? 0) > 0;
    final expanded =
        hasSubtasks && ref.watch(expandedTasksProvider).contains(task.id);
    final chip = CalendarChip(
      item: item,
      stacked: true,
      dense: true,
      onTap: hasSubtasks
          ? () => handleTaskTap(
              ref,
              taskId: task.id,
              hasSubtasks: true,
              openDetails: onOpen,
            )
          : onOpen,
    );
    if (!hasSubtasks) return chip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chip,
        if (expanded) ...[
          const SizedBox(height: 2),
          SubtaskTree(
            taskId: task.id,
            style: classicSubtaskTreeStyle(
              context,
              lineInset: 5,
              indent: 14,
              compact: true,
            ),
          ),
        ],
        if (showsDetailsArrow(ref, hasSubtasks: true))
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: IconButton(
              tooltip: context.l10n.openDetails,
              onPressed: onOpen,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              iconSize: 16,
              icon: const Icon(Icons.chevron_right),
            ),
          ),
      ],
    );
  }
}
