/// Fields every synced record carries (see SPEC.md section 4).
abstract interface class SyncRecord {
  /// UUID (v7 for records created by Taskwise).
  String get id;

  /// When the record last changed, in UTC.
  DateTime get updatedAt;

  /// Tombstone flag: deleted records are kept so the deletion can sync.
  bool get deleted;

  /// Id of the device that made the last change, if known.
  String? get updatedByDevice;
}

/// JSON helpers shared by the model classes.
abstract final class JsonFields {
  static String? dateTime(DateTime? value) => value?.toUtc().toIso8601String();

  static DateTime? parseDateTime(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toUtc();

  static DateTime parseRequiredDateTime(Object? value) =>
      DateTime.parse(value! as String).toUtc();
}
