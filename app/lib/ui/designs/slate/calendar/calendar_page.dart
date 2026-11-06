import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../../state/providers.dart';
import '../../../shared/tasks/labels.dart';
import '../tasks/task_detail.dart';
import '../tasks/task_tile.dart';
import '../theme/tokens.dart';
import 'calendar_widgets.dart';
import 'month_view.dart';
import 'week_view.dart';

enum CalendarMode { week, month }

/// The Calendar destination: a week or month view with a header for moving
/// between periods. On wide screens tasks and day agendas open in a side
/// panel; on phones they open full-screen or in a bottom sheet.
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  CalendarMode _mode = CalendarMode.week;

  /// A date inside the period shown.
  late LocalDate _focus = ref.read(todayProvider);

  /// The day whose agenda is open (month view).
  LocalDate? _agendaDay;

  void _move(int step) => setState(() {
    _focus = _mode == CalendarMode.week
        ? _focus.addDays(7 * step)
        : addMonths(_focus, step);
    _agendaDay = null;
  });

  void _goToday() => setState(() {
    _focus = ref.read(todayProvider);
    _agendaDay = null;
  });

  void _setMode(CalendarMode mode) => setState(() {
    _mode = mode;
    _agendaDay = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todayProvider);
    final weekStart = ref.watch(appSettingsProvider).weekStart;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final week = weekDays(_focus, weekStart);

    final showsToday = _mode == CalendarMode.week
        ? week.contains(today)
        : _focus.year == today.year && _focus.month == today.month;
    // A week spanning two months is named after its middle day.
    final titleDate = _mode == CalendarMode.week ? week[3] : _focus;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Breakpoints.listDetail;
        final selectedId = wide
            ? ref.watch(calendarSelectedTaskIdProvider)
            : null;

        void openTask(String id) {
          if (wide) {
            ref.read(calendarSelectedTaskIdProvider.notifier).select(id);
            setState(() => _agendaDay = null);
          } else {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TaskDetailPage(taskId: id),
              ),
            );
          }
        }

        Future<void> add(LocalDate date, int? minutes) async {
          final id = await addTaskOnDate(
            context,
            ref,
            date,
            timeMinutes: minutes,
          );
          if (id != null && wide) openTask(id);
        }

        void openDay(LocalDate day) {
          if (wide) {
            ref.read(calendarSelectedTaskIdProvider.notifier).select(null);
            setState(() => _agendaDay = day);
          } else {
            setState(() => _agendaDay = day);
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (sheetContext) => DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.5,
                maxChildSize: 0.9,
                builder: (_, scroll) => DayAgenda(
                  day: day,
                  scrollController: scroll,
                  onOpen: (id) {
                    Navigator.of(sheetContext).pop();
                    openTask(id);
                  },
                ),
              ),
            ).whenComplete(() {
              if (mounted) setState(() => _agendaDay = null);
            });
          }
        }

        final header = Container(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.md,
            Spacing.md,
            Spacing.sm,
            Spacing.xs,
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: scheme.outlineVariant, width: 1),
                ),
                child: IconButton(
                  tooltip: _mode == CalendarMode.week
                      ? l10n.calendarMonth
                      : l10n.calendarWeek,
                  icon: Icon(
                    _mode == CalendarMode.week
                        ? Icons.calendar_view_month_rounded
                        : Icons.calendar_view_week_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                  onPressed: () => _setMode(
                    _mode == CalendarMode.week
                        ? CalendarMode.month
                        : CalendarMode.week,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: DateFormat.yMMMM(l10n.localeName)
                        .format(titleDate.atLocalTime()),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    children: [
                      if (showsToday)
                        TextSpan(
                          text:
                              ' · ${_mode == CalendarMode.week ? l10n.groupThisWeek : l10n.calendarThisMonth}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!showsToday)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: Spacing.xs),
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _goToday,
                    child: Text(l10n.today),
                  ),
                ),
              IconButton(
                tooltip: _mode == CalendarMode.week
                    ? l10n.previousWeek
                    : l10n.previousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _move(-1),
              ),
              IconButton(
                tooltip: _mode == CalendarMode.week
                    ? l10n.nextWeek
                    : l10n.nextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => _move(1),
              ),
            ],
          ),
        );

        final view = switch (_mode) {
          CalendarMode.week => WeekView(
            key: ValueKey(week.first),
            days: week,
            onOpenItem: (item) => openTask(item.task.id),
            onAdd: (date) => add(date, null),
          ),
          CalendarMode.month => MonthView(
            key: ValueKey((_focus.year, _focus.month)),
            month: _focus,
            selectedDay: _agendaDay,
            onOpenDay: openDay,
          ),
        };

        final calendar = Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton(
            tooltip: l10n.addTask,
            onPressed: () =>
                add(_agendaDay ?? (showsToday ? today : week.first), null),
            child: const Icon(Icons.add_rounded),
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) {
                      final v = details.primaryVelocity ?? 0;
                      if (v.abs() < 300) return;
                      _move((v < 0) != rtl ? 1 : -1);
                    },
                    child: view,
                  ),
                ),
              ],
            ),
          ),
        );

        final Widget? panel = !wide
            ? null
            : selectedId != null
            ? TaskDetailView(
                key: ValueKey(selectedId),
                taskId: selectedId,
                onClose: () => ref
                    .read(calendarSelectedTaskIdProvider.notifier)
                    .select(null),
              )
            : _agendaDay != null
            ? DayAgenda(
                key: ValueKey(_agendaDay),
                day: _agendaDay!,
                onOpen: openTask,
                onClose: () => setState(() => _agendaDay = null),
              )
            : null;
        if (panel == null) return calendar;
        return Row(
          children: [
            Expanded(child: calendar),
            const VerticalDivider(width: 1),
            SizedBox(
              width: Breakpoints.detailPanelWidth,
              child: SafeArea(child: panel),
            ),
          ],
        );
      },
    );
  }
}

/// The tasks on one day, with an Add button. Real tasks can be ticked off
/// here; upcoming repeats open their repeating task.
class DayAgenda extends ConsumerWidget {
  const DayAgenda({
    super.key,
    required this.day,
    required this.onOpen,
    this.onClose,
    this.scrollController,
  });

  final LocalDate day;
  final ValueChanged<String> onOpen;
  final VoidCallback? onClose;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todayProvider);
    final timeFormat = ref.watch(appSettingsProvider).timeFormat;
    final items =
        ref.watch(calendarItemsProvider((from: day, to: day))).value?[day] ??
        const <CalendarItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.lg,
            Spacing.md,
            Spacing.sm,
            Spacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.7),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.relativeDate(day, today),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.addTask,
                icon: const Icon(Icons.add_rounded),
                onPressed: () async {
                  final id = await addTaskOnDate(context, ref, day);
                  if (id != null) onOpen(id);
                },
              ),
              if (onClose != null)
                IconButton(
                  tooltip: l10n.close,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClose,
                ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    l10n.noTasksThisDay,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: Spacing.sm,
                  ),
                  children: [
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Material(
                          color: scheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Radii.md),
                            side: BorderSide(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.7,
                              ),
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            leading: item.projected
                                ? const Padding(
                                    padding: EdgeInsets.all(Spacing.sm),
                                    child: Icon(Icons.repeat_rounded),
                                  )
                                : CompleteButton(task: item.task),
                            title: Text(
                              item.task.title,
                              style: item.task.done
                                  ? const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                    )
                                  : const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                            ),
                            subtitle: Text(
                              [
                                item.timeMinutes == null
                                    ? l10n.allDay
                                    : l10n.clockTime(
                                        item.timeMinutes!,
                                        timeFormat,
                                      ),
                                if (item.projected) l10n.repeatingTask,
                              ].join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            onTap: () => onOpen(item.task.id),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
