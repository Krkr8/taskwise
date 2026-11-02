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

  /// How long ago [at] was: "just now", "5 min ago", "2 hours ago"...
  String timeAgo(DateTime at, DateTime now) {
    final elapsed = now.difference(at);
    if (elapsed.inMinutes < 1) return timeJustNow;
    if (elapsed.inHours < 1) return timeMinutesAgo(elapsed.inMinutes);
    if (elapsed.inDays < 1) return timeHoursAgo(elapsed.inHours);
    return timeDaysAgo(elapsed.inDays);
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
    return '$day$_listSeparator${clockTime(minutes, format)}';
  }

  String get _listSeparator => localeName == 'ar' ? '، ' : ', ';

  /// Weekday name for an ISO weekday (1 = Monday), short ("Mon") or full.
  String weekdayName(int weekday, {bool short = false}) {
    // 2026-10-19 is a Monday.
    final date = LocalDate(2026, 10, 19).addDays(weekday - 1).atLocalTime();
    return (short ? DateFormat.E(localeName) : DateFormat.EEEE(localeName))
        .format(date);
  }

  /// "first" ... "fourth", or "last" for -1.
  String ordinal(int n) => switch (n) {
    1 => ordinal1,
    2 => ordinal2,
    3 => ordinal3,
    4 => ordinal4,
    _ => ordinalLast,
  };

  /// A one-line description, e.g. "Every 2 weeks on Mon, Wed, until Dec 1".
  String repeatSummary(RecurrenceRule rule) {
    final base = switch (rule.frequency) {
      Frequency.daily => everyNDays(rule.interval),
      Frequency.weekly => everyNWeeks(rule.interval),
      Frequency.monthly => everyNMonths(rule.interval),
      Frequency.yearly => everyNYears(rule.interval),
    };
    final weekdays = rule.weekdays.toList()..sort();
    var summary = switch (rule.frequency) {
      Frequency.weekly when rule.interval == 1 && weekdays.join() == '12345' =>
        repeatWeekdays,
      Frequency.weekly when weekdays.isNotEmpty => repeatOnDays(
        base,
        weekdays.map((w) => weekdayName(w, short: true)).join(_listSeparator),
      ),
      Frequency.weekly => repeatOnDays(base, weekdayName(rule.start.weekday)),
      Frequency.monthly when rule.nthWeekday != null => repeatOnNth(
        base,
        ordinal(rule.nthWeekday!.n),
        weekdayName(rule.nthWeekday!.weekday),
      ),
      Frequency.monthly => repeatOnMonthDay(
        base,
        rule.monthDay ?? rule.start.day,
      ),
      Frequency.yearly => repeatOnDate(
        base,
        DateFormat.MMMd(localeName).format(rule.start.atLocalTime()),
      ),
      Frequency.daily => base,
    };
    if (rule.until case final until?) {
      summary = repeatUntil(
        summary,
        DateFormat.yMMMd(localeName).format(until.atLocalTime()),
      );
    } else if (rule.count case final count?) {
      summary = repeatTimes(summary, count);
    }
    return summary;
  }
}

/// Short helper for `AppLocalizations.of(context)`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
