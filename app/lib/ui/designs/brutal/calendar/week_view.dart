import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../../state/providers.dart';
import '../../../shared/tasks/labels.dart';
import '../theme/brutal.dart';
import '../theme/tokens.dart';
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
    final b = BrutalTheme.of(context);
    final today = ref.watch(todayProvider);
    final items =
        ref
            .watch(calendarItemsProvider((from: days.first, to: days.last)))
            .value ??
        const <LocalDate, List<CalendarItem>>{};
    final grid = b.hairline;
    final phone = MediaQuery.sizeOf(context).width < Breakpoints.compact;

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        phone ? Spacing.xs : Spacing.xl,
        0,
        phone ? Spacing.xs + BrutalTheme.depth : Spacing.xl + BrutalTheme.depth,
        0,
      ),
      child: Row(
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
      ),
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

    final b = BrutalTheme.of(context);
    final header = Semantics(
      label: addLabel,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onAdd,
        child: Container(
          color: isToday ? b.yellow : null,
          padding: const EdgeInsets.symmetric(
            vertical: Spacing.sm,
            horizontal: 2,
          ),
          child: Column(
            children: [
              // Long Arabic day names shrink to fit narrow phone columns.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  l10n.weekdayName(day.weekday, short: true),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isToday ? b.onAccent : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                ),
              ),
              Text(
                DateFormat.d(l10n.localeName).format(day.atLocalTime()),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: isToday ? b.onAccent : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Divider(
          height: isToday ? BrutalTheme.line : 1,
          thickness: isToday ? BrutalTheme.line : 1,
          color: isToday ? b.ink : gridColor,
        ),
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
    );
    // Today's column stands up from the page like a card.
    return isToday
        ? Container(
            decoration: ShapeDecoration(
              color: b.card,
              shape: b.border(depth: BrutalTheme.depthSmall),
            ),
            padding: const EdgeInsets.all(BrutalTheme.line),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Material(type: MaterialType.transparency, child: column),
            ),
          )
        : Container(
            decoration: BoxDecoration(border: border),
            child: Material(type: MaterialType.transparency, child: column),
          );
  }
}
