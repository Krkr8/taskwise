import 'package:drift/drift.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

/// Stores a [DateTime] as UTC milliseconds since the epoch.
///
/// Drift's default keeps whole seconds only, which is too coarse for
/// last-write-wins sync on `updatedAt`.
class UtcMillisConverter extends TypeConverter<DateTime, int> {
  const UtcMillisConverter();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMillisecondsSinceEpoch(fromDb, isUtc: true);

  @override
  int toSql(DateTime value) => value.toUtc().millisecondsSinceEpoch;
}

/// Stores a [LocalDate] as `YYYY-MM-DD` text, which also sorts correctly.
class LocalDateConverter extends TypeConverter<LocalDate, String> {
  const LocalDateConverter();

  @override
  LocalDate fromSql(String fromDb) => LocalDate.parse(fromDb);

  @override
  String toSql(LocalDate value) => value.toIso();
}
