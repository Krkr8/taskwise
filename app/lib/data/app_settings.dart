import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:taskwise_shared/taskwise_shared.dart';

import '../platform/app_target.dart';

/// Light/dark preference.
enum ThemePreference { system, light, dark }

/// The app's designs, picked per device in Settings (M8). Each has its own
/// screens under `lib/ui/designs/<name>/`.
enum AppDesign {
  classic,
  lapis,
  slate,
  brutal;

  static const fallback = AppDesign.brutal;
}

/// The designs a target offers. The web has Brutal and Lapis only.
List<AppDesign> availableDesigns(AppTarget target) =>
    target.isWeb ? const [AppDesign.brutal, AppDesign.lapis] : AppDesign.values;

/// The design to show: [stored] when [target] offers it, else Brutal.
AppDesign effectiveDesign(AppDesign stored, AppTarget target) =>
    availableDesigns(target).contains(stored) ? stored : AppDesign.fallback;

/// UI languages (SPEC.md section 3.5).
enum AppLanguage { en, ar }

/// Clock style for displayed times.
enum TimeFormat { h12, h24 }

/// What tapping a task that has subtasks does (device-only).
enum TaskTapAction {
  /// Opens the details and unfolds the subtasks under the task (default).
  detailsAndSubtasks,

  /// Unfolds or folds the subtasks; an arrow on the row opens the details.
  subtasksOnly,

  /// Opens the details only (as before 1.2.0).
  detailsOnly,
}

/// Reminder added when a task first gets a due time (SPEC.md section 3.5).
enum DefaultReminder {
  none(null),
  atDueTime(0),
  min15(15);

  const DefaultReminder(this.minutesBefore);

  /// Minutes before the due time, or null for no reminder.
  final int? minutesBefore;
}

/// User settings the app reads at runtime.
///
/// Device-only: theme, design, language, time format, snooze options, all-day
/// reminder time and the desktop background options. Synced (shared across
/// the owner's devices once sync lands in M6): week start and the default
/// reminder.
final class AppSettings {
  const AppSettings({
    this.theme = ThemePreference.system,
    this.design = AppDesign.fallback,
    this.language,
    this.weekStart = WeekStart.sunday,
    this.timeFormat = TimeFormat.h12,
    this.defaultReminder = DefaultReminder.none,
    this.defaultLocationRadius = Place.defaultRadiusMeters,
    this.snoozeMinutes = defaultSnoozeMinutes,
    this.allDayReminderMinutes = 9 * 60,
    this.keepRunningInBackground = true,
    this.startOnLogin = false,
    this.taskTapAction = TaskTapAction.detailsAndSubtasks,
  });

  static const defaultSnoozeMinutes = [5, 15, 60];

  /// Snooze lengths the user can pick from (up to three are offered).
  static const snoozeChoices = [5, 10, 15, 30, 60, 120];

  final ThemePreference theme;

  /// Which design the app uses (device-only).
  final AppDesign design;

  /// Null until the user picks one; the app then follows the system locale.
  final AppLanguage? language;
  final WeekStart weekStart;
  final TimeFormat timeFormat;
  final DefaultReminder defaultReminder;

  /// Radius new location reminders start with, in metres.
  final int defaultLocationRadius;

  /// Snooze lengths offered on notifications, in minutes (1 to 3, sorted).
  final List<int> snoozeMinutes;

  /// When all-day tasks remind, in minutes after midnight.
  final int allDayReminderMinutes;

  /// Desktop: closing the window keeps the app in the tray so reminders
  /// still fire.
  final bool keepRunningInBackground;

  /// Desktop: start (hidden in the tray) when the user logs in.
  final bool startOnLogin;

  /// What tapping a task with subtasks does (device-only).
  final TaskTapAction taskTapAction;

  AppSettings copyWith({
    ThemePreference? theme,
    AppDesign? design,
    AppLanguage? language,
    WeekStart? weekStart,
    TimeFormat? timeFormat,
    DefaultReminder? defaultReminder,
    int? defaultLocationRadius,
    List<int>? snoozeMinutes,
    int? allDayReminderMinutes,
    bool? keepRunningInBackground,
    bool? startOnLogin,
    TaskTapAction? taskTapAction,
  }) => AppSettings(
    theme: theme ?? this.theme,
    design: design ?? this.design,
    language: language ?? this.language,
    weekStart: weekStart ?? this.weekStart,
    timeFormat: timeFormat ?? this.timeFormat,
    defaultReminder: defaultReminder ?? this.defaultReminder,
    defaultLocationRadius: defaultLocationRadius ?? this.defaultLocationRadius,
    snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
    allDayReminderMinutes: allDayReminderMinutes ?? this.allDayReminderMinutes,
    keepRunningInBackground:
        keepRunningInBackground ?? this.keepRunningInBackground,
    startOnLogin: startOnLogin ?? this.startOnLogin,
    taskTapAction: taskTapAction ?? this.taskTapAction,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.theme == theme &&
      other.design == design &&
      other.language == language &&
      other.weekStart == weekStart &&
      other.timeFormat == timeFormat &&
      other.defaultReminder == defaultReminder &&
      other.defaultLocationRadius == defaultLocationRadius &&
      other.snoozeMinutes.join(',') == snoozeMinutes.join(',') &&
      other.allDayReminderMinutes == allDayReminderMinutes &&
      other.keepRunningInBackground == keepRunningInBackground &&
      other.startOnLogin == startOnLogin &&
      other.taskTapAction == taskTapAction;

  @override
  int get hashCode => Object.hash(
    theme,
    design,
    language,
    weekStart,
    timeFormat,
    defaultReminder,
    defaultLocationRadius,
    Object.hashAll(snoozeMinutes),
    allDayReminderMinutes,
    keepRunningInBackground,
    startOnLogin,
    taskTapAction,
  );
}

/// The UI locale for [AppSettings.language], following the system until
/// one is picked (Arabic systems get Arabic, others English). For texts
/// built outside the widget tree (notifications, tray menu).
Locale resolvedLocale(AppSettings settings) => switch (settings.language) {
  AppLanguage.ar => const Locale('ar'),
  AppLanguage.en => const Locale('en'),
  null =>
    PlatformDispatcher.instance.locales.any((l) => l.languageCode == 'ar')
        ? const Locale('ar')
        : const Locale('en'),
};
