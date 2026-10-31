import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:taskwise_shared/taskwise_shared.dart';

/// Light/dark preference.
enum ThemePreference { system, light, dark }

/// UI languages (SPEC.md section 3.5).
enum AppLanguage { en, ar }

/// Clock style for displayed times.
enum TimeFormat { h12, h24 }

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
/// Device-only: theme, language, time format, snooze options, all-day
/// reminder time and the desktop background options. Synced (shared across
/// the owner's devices once sync lands in M6): week start and the default
/// reminder.
final class AppSettings {
  const AppSettings({
    this.theme = ThemePreference.system,
    this.language,
    this.weekStart = WeekStart.sunday,
    this.timeFormat = TimeFormat.h12,
    this.defaultReminder = DefaultReminder.none,
    this.snoozeMinutes = defaultSnoozeMinutes,
    this.allDayReminderMinutes = 9 * 60,
    this.keepRunningInBackground = true,
    this.startOnLogin = false,
  });

  static const defaultSnoozeMinutes = [5, 15, 60];

  /// Snooze lengths the user can pick from (up to three are offered).
  static const snoozeChoices = [5, 10, 15, 30, 60, 120];

  final ThemePreference theme;

  /// Null until the user picks one; the app then follows the system locale.
  final AppLanguage? language;
  final WeekStart weekStart;
  final TimeFormat timeFormat;
  final DefaultReminder defaultReminder;

  /// Snooze lengths offered on notifications, in minutes (1 to 3, sorted).
  final List<int> snoozeMinutes;

  /// When all-day tasks remind, in minutes after midnight.
  final int allDayReminderMinutes;

  /// Desktop: closing the window keeps the app in the tray so reminders
  /// still fire.
  final bool keepRunningInBackground;

  /// Desktop: start (hidden in the tray) when the user logs in.
  final bool startOnLogin;

  AppSettings copyWith({
    ThemePreference? theme,
    AppLanguage? language,
    WeekStart? weekStart,
    TimeFormat? timeFormat,
    DefaultReminder? defaultReminder,
    List<int>? snoozeMinutes,
    int? allDayReminderMinutes,
    bool? keepRunningInBackground,
    bool? startOnLogin,
  }) => AppSettings(
    theme: theme ?? this.theme,
    language: language ?? this.language,
    weekStart: weekStart ?? this.weekStart,
    timeFormat: timeFormat ?? this.timeFormat,
    defaultReminder: defaultReminder ?? this.defaultReminder,
    snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
    allDayReminderMinutes: allDayReminderMinutes ?? this.allDayReminderMinutes,
    keepRunningInBackground:
        keepRunningInBackground ?? this.keepRunningInBackground,
    startOnLogin: startOnLogin ?? this.startOnLogin,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.theme == theme &&
      other.language == language &&
      other.weekStart == weekStart &&
      other.timeFormat == timeFormat &&
      other.defaultReminder == defaultReminder &&
      other.snoozeMinutes.join(',') == snoozeMinutes.join(',') &&
      other.allDayReminderMinutes == allDayReminderMinutes &&
      other.keepRunningInBackground == keepRunningInBackground &&
      other.startOnLogin == startOnLogin;

  @override
  int get hashCode => Object.hash(
    theme,
    language,
    weekStart,
    timeFormat,
    defaultReminder,
    Object.hashAll(snoozeMinutes),
    allDayReminderMinutes,
    keepRunningInBackground,
    startOnLogin,
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
