import 'package:taskwise_shared/taskwise_shared.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';

/// Returns the current time. Injected so tests can control it.
typedef Clock = DateTime Function();

/// Shared plumbing for repositories: the database, the clock and this
/// device's id, which is stamped on every write as `updatedByDevice`.
abstract class RepositoryBase {
  RepositoryBase(this.db, {required this.deviceId, Clock? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final String deviceId;
  final Clock _clock;

  static const Uuid _uuid = Uuid();

  /// Current time in UTC.
  DateTime now() => _clock().toUtc();

  /// Today's date on this device.
  LocalDate today() => LocalDate.fromDateTime(_clock());

  /// A new time-ordered UUID (v7).
  String newId() => _uuid.v7();
}
