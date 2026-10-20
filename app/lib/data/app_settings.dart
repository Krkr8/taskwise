import 'package:taskwise_shared/taskwise_shared.dart';

/// Light/dark preference.
enum ThemePreference { system, light, dark }

/// UI languages (SPEC.md section 3.5).
enum AppLanguage { en, ar }

/// Clock style for displayed times.
enum TimeFormat { h12, h24 }

/// User settings the app reads at runtime.
///
/// Device-only: theme, language, time format. Synced (shared across the
/// owner's devices once sync lands in M6): week start.
final class AppSettings {
  const AppSettings({
    this.theme = ThemePreference.system,
    this.language,
    this.weekStart = WeekStart.sunday,
    this.timeFormat = TimeFormat.h12,
  });

  final ThemePreference theme;

  /// Null until the user picks one; the app then follows the system locale.
  final AppLanguage? language;
  final WeekStart weekStart;
  final TimeFormat timeFormat;

  AppSettings copyWith({
    ThemePreference? theme,
    AppLanguage? language,
    WeekStart? weekStart,
    TimeFormat? timeFormat,
  }) => AppSettings(
    theme: theme ?? this.theme,
    language: language ?? this.language,
    weekStart: weekStart ?? this.weekStart,
    timeFormat: timeFormat ?? this.timeFormat,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.theme == theme &&
      other.language == language &&
      other.weekStart == weekStart &&
      other.timeFormat == timeFormat;

  @override
  int get hashCode => Object.hash(theme, language, weekStart, timeFormat);
}
