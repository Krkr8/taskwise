import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../../state/providers.dart';
import '../../../shared/tasks/labels.dart';
import '../theme/brutal.dart';
import '../theme/tokens.dart';
import 'calendar_widgets.dart';

/// A 6-week month grid. Each day shows a few task chips (coloured dots on
/// narrow screens) and "+N" for the rest; tapping a day opens its agenda.
class MonthView extends ConsumerWidget {
  const MonthView({
    super.key,
    required this.month,
    required this.onOpenDay,
    this.selectedDay,
  });

  /// Any date in the month shown.
  final LocalDate month;
  final ValueChanged<LocalDate> onOpenDay;
  final LocalDate? selectedDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todayProvider);
    final weekStart = ref.watch(appSettingsProvider).weekStart;
    final days = monthGridDays(month, weekStart);
    final items =
        ref
            .watch(calendarItemsProvider((from: days.first, to: days.last)))
            .value ??
        const <LocalDate, List<CalendarItem>>{};
    final b = BrutalTheme.of(context);
    final grid = b.hairline;
    final phone = MediaQuery.sizeOf(context).width < Breakpoints.compact;

    final body = Column(
      children: [
        Row(
          children: [
            for (final day in days.take(7))
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: Spacing.sm,
                    horizontal: 2,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      l10n.weekdayName(day.weekday, short: true),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
        Divider(
          height: BrutalTheme.line,
          thickness: BrutalTheme.line,
          color: b.ink,
        ),
        Expanded(
          child: Column(
            children: [
              for (var week = 0; week < 6; week++)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: _DayCell(
                            day: days[week * 7 + i],
                            items:
                                items[days[week * 7 + i]] ??
                                const <CalendarItem>[],
                            inMonth: days[week * 7 + i].month == month.month,
                            isToday: days[week * 7 + i] == today,
                            selected: days[week * 7 + i] == selectedDay,
                            gridColor: grid,
                            onTap: () => onOpenDay(days[week * 7 + i]),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    // The grid sits in one card.
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        phone ? Spacing.xs : Spacing.xl,
        0,
        (phone ? Spacing.xs : Spacing.xl) + BrutalTheme.depth,
        (phone ? Spacing.xs : Spacing.lg) + BrutalTheme.depth,
      ),
      child: Container(
        decoration: ShapeDecoration(color: b.card, shape: b.border()),
        padding: const EdgeInsets.all(BrutalTheme.line),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Material(type: MaterialType.transparency, child: body),
        ),
      ),
    );
  }
}

class _DayCell extends ConsumerWidget {
  const _DayCell({
    required this.day,
    required this.items,
    required this.inMonth,
    required this.isToday,
    required this.selected,
    required this.gridColor,
    required this.onTap,
  });

  final LocalDate day;
  final List<CalendarItem> items;
  final bool inMonth;
  final bool isToday;
  final bool selected;
  final Color gridColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todayProvider);

    final b = BrutalTheme.of(context);
    final number = Container(
      width: 24,
      height: 22,
      alignment: Alignment.center,
      decoration: isToday
          ? BoxDecoration(
              color: b.yellow,
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(color: b.ink, width: 1.5),
            )
          : null,
      child: Text(
        DateFormat.d(l10n.localeName).format(day.atLocalTime()),
        style: theme.textTheme.labelMedium?.copyWith(
          color: isToday
              ? b.onAccent
              : inMonth
              ? scheme.onSurface
              : scheme.onSurfaceVariant.withValues(alpha: 0.6),
          fontWeight: isToday || inMonth ? FontWeight.w700 : null,
        ),
      ),
    );

    return Semantics(
      button: true,
      label: '${l10n.relativeDate(day, today)}, ${items.length}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? b.lilac.withValues(alpha: 0.45)
                : inMonth
                ? null
                : scheme.surfaceContainerHigh.withValues(alpha: 0.5),
            border: BorderDirectional(
              start: BorderSide(color: gridColor),
              bottom: BorderSide(color: gridColor),
            ),
          ),
          padding: const EdgeInsets.all(2),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Narrow cells (phones) show dots; wider ones show chips.
              final useDots = constraints.maxWidth < 72;
              const chipHeight = 18.0;
              final room = constraints.maxHeight - 28;
              final fit = math.max(0, (room / (chipHeight + 2)).floor());
              final shown = items.length > fit
                  ? math.max(0, fit - 1)
                  : items.length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(alignment: Alignment.topCenter, child: number),
                  const SizedBox(height: 2),
                  if (useDots)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 2,
                      runSpacing: 2,
                      children: [
                        for (final item in items.take(6))
                          Opacity(
                            opacity: item.projected || item.task.done ? 0.5 : 1,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: itemColor(ref, item, scheme),
                                border: Border.all(color: b.ink),
                              ),
                            ),
                          ),
                      ],
                    )
                  else ...[
                    for (final item in items.take(shown))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: SizedBox(
                          height: chipHeight,
                          child: CalendarChip(
                            item: item,
                            dense: true,
                            showTime: true,
                            onTap: onTap,
                          ),
                        ),
                      ),
                    if (shown < items.length)
                      Text(
                        l10n.moreTasks(items.length - shown),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
