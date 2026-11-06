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

        final header = Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.xl,
            Spacing.lg,
            Spacing.md,
            Spacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      // Phones get the short month so the toggle fits.
                      (constraints.maxWidth < Breakpoints.compact
                              ? DateFormat.yMMM(l10n.localeName)
                              : DateFormat.yMMMM(l10n.localeName))
                          .format(titleDate.atLocalTime()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall,
                    ),
                    if (showsToday)
                      Text(
                        _mode == CalendarMode.week
                            ? l10n.groupThisWeek
                            : l10n.calendarThisMonth,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      // Same height as the "This week" line.
                      InkWell(
                        borderRadius: BorderRadius.circular(Radii.sm),
                        onTap: _goToday,
                        child: Text(
                          l10n.today,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _ModeToggle(mode: _mode, onChanged: _setMode),
              const SizedBox(width: Spacing.xs),
              IconButton(
                tooltip: _mode == CalendarMode.week
                    ? l10n.previousWeek
                    : l10n.previousMonth,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _move(-1),
              ),
              IconButton(
                tooltip: _mode == CalendarMode.week
                    ? l10n.nextWeek
                    : l10n.nextMonth,
                icon: const Icon(Icons.chevron_right),
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
            child: const Icon(Icons.add),
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Expanded(
                  // Swipe sideways to change period (mirrored in Arabic).
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
            Material(
              color: theme.colorScheme.surfaceContainerLow,
              child: Container(
                width: Breakpoints.detailPanelWidth,
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    start: BorderSide(color: LapisColors.of(context).line),
                  ),
                ),
                child: SafeArea(child: panel),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Week | Month, as two small segments in one pill.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final CalendarMode mode;
  final ValueChanged<CalendarMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget segment(CalendarMode value, String label) {
      final selected = value == mode;
      return Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.sm),
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.fast),
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: selected ? scheme.surfaceContainerLow : null,
              borderRadius: BorderRadius.circular(Radii.sm),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.08),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : const [],
            ),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.sm + 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment(CalendarMode.week, l10n.calendarWeek),
          segment(CalendarMode.month, l10n.calendarMonth),
        ],
      ),
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
    final today = ref.watch(todayProvider);
    final timeFormat = ref.watch(appSettingsProvider).timeFormat;
    final items =
        ref.watch(calendarItemsProvider((from: day, to: day))).value?[day] ??
        const <CalendarItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.lg,
            Spacing.sm,
            Spacing.sm,
            Spacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.relativeDate(day, today),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: l10n.addTask,
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final id = await addTaskOnDate(context, ref, day);
                  if (id != null) onOpen(id);
                },
              ),
              if (onClose != null)
                IconButton(
                  tooltip: l10n.close,
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text(l10n.noTasksThisDay))
              : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: Spacing.xl),
                  children: [
                    for (final item in items)
                      ListTile(
                        leading: item.projected
                            ? const Padding(
                                padding: EdgeInsets.all(Spacing.sm),
                                child: Icon(Icons.repeat),
                              )
                            : CompleteButton(task: item.task),
                        title: Text(
                          item.task.title,
                          style: item.task.done
                              ? const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                )
                              : null,
                        ),
                        subtitle: Text(
                          [
                            item.timeMinutes == null
                                ? l10n.allDay
                                : l10n.clockTime(item.timeMinutes!, timeFormat),
                            if (item.projected) l10n.repeatingTask,
                          ].join(' · '),
                        ),
                        onTap: () => onOpen(item.task.id),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
