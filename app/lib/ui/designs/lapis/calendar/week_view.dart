import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../../state/providers.dart';
import '../../../shared/tasks/labels.dart';
import '../theme/tokens.dart';
import 'calendar_widgets.dart';

/// Seven day columns, each a list of that day's tasks: all-day tasks first,
/// then timed ones in time order (the order [calendarItems] returns).
///
/// Columns follow the week-start setting, and a [Row] puts them right to
/// left in Arabic. Today's column is outlined in saffron, the colour that
/// means "today" everywhere in the app.
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
    final today = ref.watch(todayProvider);
    final items =
        ref
            .watch(calendarItemsProvider((from: days.first, to: days.last)))
            .value ??
        const <LocalDate, List<CalendarItem>>{};
    final grid = LapisColors.of(context).line;

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
    final lapis = LapisColors.of(context);

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
                  color: isToday ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: isToday ? FontWeight.w600 : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
              const SizedBox(height: 2),
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: isToday
                    ? BoxDecoration(color: lapis.today, shape: BoxShape.circle)
                    : null,
                child: Text(
                  DateFormat.d(l10n.localeName).format(day.atLocalTime()),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isToday ? lapis.onToday : scheme.onSurface,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: isToday ? lapis.todaySoft.withValues(alpha: 0.45) : null,
        border: isToday ? Border.all(color: lapis.today, width: 1.5) : border,
        borderRadius: isToday ? BorderRadius.circular(Radii.md) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Divider(height: 1, color: isToday ? lapis.today : gridColor),
          Expanded(
            // Tapping below the tasks adds one; the list scrolls when full.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAdd,
              child: ListView(
                // Bottom room so the + button doesn't cover the last task.
                padding: const EdgeInsets.fromLTRB(3, 5, 3, 72),
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: CalendarChip(
                        item: item,
                        stacked: true,
                        dense: true,
                        onTap: () => onOpenItem(item),
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
