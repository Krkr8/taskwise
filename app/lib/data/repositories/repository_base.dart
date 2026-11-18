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

  /// Namespace for [derivedId] (a fixed random UUID; never change it).
  static const _derivedNamespace = 'b6f3c1de-5a0e-4c47-9a36-2f1d8e7c4b90';

  /// The same UUID (v5) for the same [name] on every device, for records
  /// two devices may create independently, such as a repeating task's next
  /// copy: both then write the same record instead of two.
  String derivedId(String name) => _uuid.v5(_derivedNamespace, name);
}
