import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../../../data/app_settings.dart';
import '../../../../state/providers.dart';
import '../../../shared/common/whole_words_text.dart';
import '../../../shared/common/dialogs.dart';
import '../../../shared/tasks/labels.dart';
import '../theme/tokens.dart';

/// The colour a calendar item is drawn in: its category, or the accent.
Color itemColor(WidgetRef ref, CalendarItem item, ColorScheme scheme) {
  final categoryId = item.task.categoryId;
  final category = categoryId == null
      ? null
      : ref.watch(categoriesByIdProvider)[categoryId];
  return category == null ? scheme.primary : Color(category.colorValue);
}

/// A compact, tappable task chip for the week and month grids.
///
/// Projected repeats are faded with a repeat icon; done tasks are struck
/// through.
class CalendarChip extends ConsumerWidget {
  const CalendarChip({
    super.key,
    required this.item,
    required this.onTap,
    this.showTime = false,
    this.dense = false,
    this.stacked = false,
  });

  final CalendarItem item;
  final VoidCallback onTap;
  final bool showTime;

  /// Time (and repeat icon) on a small first line, then the title on up to
  /// three lines. Used in the week view's narrow columns.
  final bool stacked;

  /// Smaller text, for month cells and narrow week columns.
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final color = itemColor(ref, item, scheme);
    final task = item.task;
    final timeFormat = ref.watch(appSettingsProvider).timeFormat;
    final style =
        (dense ? theme.textTheme.labelSmall : theme.textTheme.bodySmall)
            ?.copyWith(
              fontSize: dense ? 11 : null,
              color: scheme.onSurface,
              decoration: task.done ? TextDecoration.lineThrough : null,
              height: 1.2,
            );
    final label = showTime && item.timeMinutes != null
        ? '${l10n.clockTime(item.timeMinutes!, timeFormat)} ${task.title}'
        : task.title;

    return Semantics(
      button: true,
      label: item.projected ? l10n.upcomingOccurrence(task.title) : label,
      excludeSemantics: true,
      child: Opacity(
        opacity: item.projected || task.done ? 0.55 : 1,
        child: Material(
          color: Color.alphaBlend(
            color.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.24 : 0.13,
            ),
            scheme.surfaceContainerLow,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(color: color, width: 3),
                ),
              ),
              padding: EdgeInsetsDirectional.only(
                start: dense ? 3 : Spacing.sm,
                end: 3,
                top: 1,
                bottom: 1,
              ),
              child: stacked
                  ? _stackedContent(
                      context,
                      l10n.clockTime,
                      timeFormat,
                      style,
                      hasReminders: ref
                          .watch(taskIdsWithRemindersProvider)
                          .contains(task.id),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.projected || task.recurrenceRule != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 2),
                            child: Icon(
                              Icons.repeat,
                              size: dense ? 10 : 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            label,
                            style: style,
                            maxLines: dense ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: !dense,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stackedContent(
    BuildContext context,
    String Function(int, TimeFormat) clockTime,
    TimeFormat timeFormat,
    TextStyle? style, {
    required bool hasReminders,
  }) {
    final theme = Theme.of(context);
    final repeats = item.projected || item.task.recurrenceRule != null;
    final metaStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.2,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.timeMinutes != null || repeats || hasReminders)
            // Shrinks to fit narrow phone columns instead of cutting off.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasReminders)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 2),
                      child: Icon(
                        Icons.notifications_outlined,
                        size: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (repeats)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 2),
                      child: Icon(
                        Icons.repeat,
                        size: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (item.timeMinutes != null)
                    Text(
                      clockTime(item.timeMinutes!, timeFormat),
                      style: metaStyle,
                      maxLines: 1,
                    ),
                ],
              ),
            ),
          WholeWordsText(item.task.title, style: style, maxLines: 3),
        ],
      ),
    );
  }
}

/// Asks for a title and creates a task on [date] (at [timeMinutes], or
/// all-day when null). Returns the new task's id, or null if cancelled.
Future<String?> addTaskOnDate(
  BuildContext context,
  WidgetRef ref,
  LocalDate date, {
  int? timeMinutes,
}) async {
  final l10n = context.l10n;
  final today = ref.read(todayProvider);
  final timeFormat = ref.read(appSettingsProvider).timeFormat;
  final when = timeMinutes == null
      ? l10n.relativeDate(date, today)
      : '${l10n.relativeDate(date, today)}, '
            '${l10n.clockTime(timeMinutes, timeFormat)}';
  final title = await showTextInputDialog(
    context,
    title: l10n.addTaskOn(when),
    label: l10n.newTaskHint,
    confirmLabel: l10n.add,
  );
  if (title == null) return null;
  final task = await ref
      .read(taskRepositoryProvider)
      .createTask(title: title, dueDate: date, dueTimeMinutes: timeMinutes);
  return task.id;
}
