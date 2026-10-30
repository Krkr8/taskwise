import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../data/app_settings.dart';
import '../../state/providers.dart';
import '../tasks/labels.dart';
import '../theme/tokens.dart';
import 'calendar_widgets.dart';

/// Seven day columns with an all-day row and an hour timeline.
///
/// Columns follow the week-start setting, and a [Row] puts them right to
/// left in Arabic. Today's column is outlined in the accent colour and a
/// line marks the current time.
class WeekView extends ConsumerStatefulWidget {
  const WeekView({
    super.key,
    required this.days,
    required this.onOpenItem,
    required this.onAdd,
  });

  /// The 7 dates shown, in order.
  final List<LocalDate> days;
  final ValueChanged<CalendarItem> onOpenItem;

  /// Add a task on a date, at a time (null = all-day).
  final void Function(LocalDate date, int? timeMinutes) onAdd;

  @override
  ConsumerState<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends ConsumerState<WeekView> {
  static const double _gutter = 52;
  static const double _hourHeight = 56;

  /// A timed task is drawn as a 30-minute block (tasks have no duration).
  static const int _blockMinutes = 30;

  late final ScrollController _scroll;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider)();
    // Open about an hour before now, so the time line is near the top.
    _scroll = ScrollController(
      initialScrollOffset: math.max(0, now.hour - 1) * _hourHeight,
    );
    // Move the time line once a minute.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todayProvider);
    final timeFormat = ref.watch(appSettingsProvider).timeFormat;
    final days = widget.days;
    final items =
        ref
            .watch(calendarItemsProvider((from: days.first, to: days.last)))
            .value ??
        const <LocalDate, List<CalendarItem>>{};
    final now = ref.read(clockProvider)();
    final nowMinutes = now.hour * 60 + now.minute;
    final grid = scheme.outlineVariant.withValues(alpha: 0.5);
    final todayIndex = days.indexOf(today);

    BorderDirectional todaySides({bool top = false, bool bottom = false}) {
      final side = BorderSide(color: scheme.primary, width: 2);
      return BorderDirectional(
        start: side,
        end: side,
        top: top ? side : BorderSide.none,
        bottom: bottom ? side : BorderSide.none,
      );
    }

    final allDay = [
      for (final day in days)
        [
          for (final item in items[day] ?? const <CalendarItem>[])
            if (item.timeMinutes == null) item,
        ],
    ];
    final maxAllDay = allDay.map((l) => l.length).fold(0, math.max);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = (constraints.maxWidth - _gutter) / 7;
        final dense = columnWidth < 90;
        final chipHeight = dense ? 18.0 : 22.0;

        Widget headerCell(int index) {
          final day = days[index];
          final isToday = index == todayIndex;
          final color = isToday ? scheme.primary : scheme.onSurfaceVariant;
          return Expanded(
            child: InkWell(
              onTap: () => widget.onAdd(day, null),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                decoration: BoxDecoration(
                  border: isToday
                      ? todaySides(top: true)
                      : BorderDirectional(start: BorderSide(color: grid)),
                ),
                child: Semantics(
                  label: l10n.addTaskOn(l10n.relativeDate(day, today)),
                  excludeSemantics: true,
                  button: true,
                  child: Column(
                    children: [
                      Text(
                        l10n.weekdayName(day.weekday, short: true),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: color,
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
            ),
          );
        }

        final header = Row(
          children: [
            const SizedBox(width: _gutter),
            for (var i = 0; i < 7; i++) headerCell(i),
          ],
        );

        final allDayRow = maxAllDay == 0
            ? null
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _gutter,
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.xs),
                      child: Text(
                        l10n.allDay,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Container(
                        // Up to 3 rows; the cell scrolls if there are more.
                        height: math.min(maxAllDay, 3) * (chipHeight + 2) + 4,
                        decoration: BoxDecoration(
                          border: i == todayIndex
                              ? todaySides()
                              : BorderDirectional(
                                  start: BorderSide(color: grid),
                                ),
                        ),
                        child: ListView(
                          padding: const EdgeInsets.all(2),
                          children: [
                            for (final item in allDay[i])
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: SizedBox(
                                  height: chipHeight,
                                  child: CalendarChip(
                                    item: item,
                                    dense: true,
                                    onTap: () => widget.onOpenItem(item),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              );

        final timeline = SingleChildScrollView(
          controller: _scroll,
          child: SizedBox(
            height: 24 * _hourHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _gutter,
                  child: _HourGutter(
                    hourHeight: _hourHeight,
                    timeFormat: timeFormat,
                    nowMinutes: todayIndex >= 0 ? nowMinutes : null,
                  ),
                ),
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _DayColumn(
                      items: [
                        for (final item
                            in items[days[i]] ?? const <CalendarItem>[])
                          if (item.timeMinutes != null) item,
                      ],
                      hourHeight: _hourHeight,
                      blockMinutes: _blockMinutes,
                      gridColor: grid,
                      border: i == todayIndex
                          ? todaySides(bottom: true)
                          : BorderDirectional(start: BorderSide(color: grid)),
                      nowMinutes: todayIndex >= 0 ? nowMinutes : null,
                      isToday: i == todayIndex,
                      dense: dense,
                      onOpenItem: widget.onOpenItem,
                      onTapSlot: (minutes) => widget.onAdd(days[i], minutes),
                    ),
                  ),
              ],
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            ?allDayRow,
            Divider(height: 1, color: grid),
            Expanded(child: timeline),
          ],
        );
      },
    );
  }
}

/// Hour labels down the side, with the current time in the accent colour.
class _HourGutter extends StatelessWidget {
  const _HourGutter({
    required this.hourHeight,
    required this.timeFormat,
    this.nowMinutes,
  });

  final double hourHeight;
  final TimeFormat timeFormat;

  /// Minutes after midnight, when today is in the visible week.
  final int? nowMinutes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final hourPattern = timeFormat == TimeFormat.h24
        ? DateFormat.Hm(l10n.localeName)
        : DateFormat.j(l10n.localeName);

    // Hide an hour label that the "now" label would overlap.
    bool nearNow(int hour) =>
        nowMinutes != null && (hour * 60 - nowMinutes!).abs() < 20;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var hour = 1; hour < 24; hour++)
          if (!nearNow(hour))
            PositionedDirectional(
              top: hour * hourHeight - 8,
              start: 0,
              end: Spacing.xs,
              child: Text(
                hourPattern.format(DateTime(2000, 1, 1, hour)),
                style: labelStyle,
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
        if (nowMinutes case final now?)
          PositionedDirectional(
            top: now / 60 * hourHeight - 8,
            start: 0,
            end: Spacing.xs,
            child: Text(
              l10n.clockTime(now, timeFormat),
              style: labelStyle?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
      ],
    );
  }
}

/// One day of the timeline: hour lines, timed chips and the time line.
class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.items,
    required this.hourHeight,
    required this.blockMinutes,
    required this.gridColor,
    required this.border,
    required this.isToday,
    required this.dense,
    required this.onOpenItem,
    required this.onTapSlot,
    this.nowMinutes,
  });

  final List<CalendarItem> items;
  final double hourHeight;
  final int blockMinutes;
  final Color gridColor;
  final BorderDirectional border;
  final bool isToday;
  final bool dense;
  final int? nowMinutes;
  final ValueChanged<CalendarItem> onOpenItem;

  /// Tapped an empty spot: the start of that hour, in minutes.
  final ValueChanged<int> onTapSlot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lanes = _layoutLanes(items, blockMinutes);
    final blockHeight = math.max(
      hourHeight * blockMinutes / 60,
      dense ? 20.0 : 24.0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => onTapSlot(
            (details.localPosition.dy / hourHeight).floor().clamp(0, 23) * 60,
          ),
          child: Container(
            decoration: BoxDecoration(border: border),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var hour = 1; hour < 24; hour++)
                  PositionedDirectional(
                    top: hour * hourHeight,
                    start: 0,
                    end: 0,
                    child: Divider(height: 1, color: gridColor),
                  ),
                for (final (item, lane, laneCount) in lanes)
                  PositionedDirectional(
                    top: item.timeMinutes! / 60 * hourHeight,
                    height: blockHeight,
                    start: width * lane / laneCount + 1,
                    width: width / laneCount - 2,
                    child: CalendarChip(
                      item: item,
                      dense: dense,
                      onTap: () => onOpenItem(item),
                    ),
                  ),
                if (nowMinutes case final now?)
                  PositionedDirectional(
                    top: now / 60 * hourHeight - (isToday ? 4 : 0.5),
                    start: isToday ? -4 : 0,
                    end: 0,
                    child: _NowLine(color: scheme.primary, isToday: isToday),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Side-by-side lanes for chips that overlap in time: (item, lane, lanes).
  static List<(CalendarItem, int, int)> _layoutLanes(
    List<CalendarItem> items,
    int blockMinutes,
  ) {
    final result = <(CalendarItem, int, int)>[];
    var cluster = <CalendarItem>[];
    var clusterEnd = -1;
    void flush() {
      for (final (i, item) in cluster.indexed) {
        result.add((item, i, cluster.length));
      }
      cluster = [];
    }

    for (final item in items) {
      final start = item.timeMinutes!;
      if (start >= clusterEnd) flush();
      cluster.add(item);
      clusterEnd = math.max(clusterEnd, start + blockMinutes);
    }
    flush();
    return result;
  }
}

/// The current-time marker: a dot and a strong line in today's column, a
/// faint line in the others.
class _NowLine extends StatelessWidget {
  const _NowLine({required this.color, required this.isToday});

  final Color color;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    if (!isToday) {
      return Container(height: 1, color: color.withValues(alpha: 0.5));
    }
    return SizedBox(
      height: 8,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(child: Container(height: 2, color: color)),
        ],
      ),
    );
  }
}
