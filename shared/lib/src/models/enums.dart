/// Task priority, lowest to highest.
enum Priority {
  none,
  low,
  medium,
  high;

  /// Parses [Priority.name], falling back to [Priority.none].
  static Priority fromName(String? name) =>
      values.asNameMap()[name] ?? Priority.none;
}

/// The day a week starts on, used for the "This week" group and week view.
enum WeekStart {
  sunday(DateTime.sunday),
  saturday(DateTime.saturday),
  monday(DateTime.monday);

  const WeekStart(this.weekday);

  /// ISO weekday number ([DateTime.monday] = 1 ... [DateTime.sunday] = 7).
  final int weekday;

  /// Parses [WeekStart.name], falling back to [WeekStart.sunday].
  static WeekStart fromName(String? name) =>
      values.asNameMap()[name] ?? WeekStart.sunday;
}

/// What triggers a reminder.
enum ReminderKind { time, location }

/// When a location reminder fires.
enum LocationTrigger { arrive, leave }

/// Platform of a registered device.
enum DeviceType {
  windows,
  linux,
  ios,
  other;

  /// Parses [DeviceType.name], falling back to [DeviceType.other].
  static DeviceType fromName(String? name) =>
      values.asNameMap()[name] ?? DeviceType.other;
}
