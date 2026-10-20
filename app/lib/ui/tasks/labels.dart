import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../../data/app_settings.dart';
import '../../l10n/app_localizations.dart';

/// Localised names and date/time formatting for the task UI.
extension TaskLabels on AppLocalizations {
  String groupName(TaskGroup group) => switch (group) {
    TaskGroup.overdue => groupOverdue,
    TaskGroup.today => groupToday,
    TaskGroup.tomorrow => groupTomorrow,
    TaskGroup.thisWeek => groupThisWeek,
    TaskGroup.later => groupLater,
    TaskGroup.noDate => groupNoDate,
    TaskGroup.completed => groupCompleted,
  };

  String priorityName(Priority priority) => switch (priority) {
    Priority.none => priorityNone,
    Priority.low => priorityLow,
    Priority.medium => priorityMedium,
    Priority.high => priorityHigh,
  };

  String sortName(TaskSort sort) => switch (sort) {
    TaskSort.dueDate => sortDueDate,
    TaskSort.priority => sortPriority,
    TaskSort.title => sortTitle,
    TaskSort.created => sortCreated,
  };

  String weekStartName(WeekStart weekStart) => switch (weekStart) {
    WeekStart.sunday => sunday,
    WeekStart.saturday => saturday,
    WeekStart.monday => monday,
  };

  /// "Today", "Tomorrow", "Yesterday", or a short date such as "Wed, Oct 21"
  /// (with the year when it isn't the current one).
  String relativeDate(LocalDate date, LocalDate today) {
    final days = date.differenceInDays(today);
    if (days == 0) return this.today;
    if (days == 1) return tomorrow;
    if (days == -1) return yesterday;
    final pattern = date.year == today.year
        ? DateFormat.MMMEd(localeName)
        : DateFormat.yMMMEd(localeName);
    return pattern.format(date.atLocalTime());
  }

  /// A clock time, e.g. "9:30 AM" or "09:30".
  String clockTime(int minutesAfterMidnight, TimeFormat format) {
    final at = DateTime(2000, 1, 1, 0, minutesAfterMidnight);
    final pattern = format == TimeFormat.h24
        ? DateFormat.Hm(localeName)
        : DateFormat('h:mm a', localeName);
    return pattern.format(at);
  }

  /// Due label for a task row: "Today, 9:30 AM", "Wed, Oct 21", ...
  String? dueLabel(Task task, LocalDate today, TimeFormat format) {
    final date = task.dueDate;
    if (date == null) return null;
    final day = relativeDate(date, today);
    final minutes = task.dueTimeMinutes;
    if (minutes == null) return day;
    final separator = localeName == 'ar' ? '، ' : ', ';
    return '$day$separator${clockTime(minutes, format)}';
  }
}

/// Short helper for `AppLocalizations.of(context)`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
