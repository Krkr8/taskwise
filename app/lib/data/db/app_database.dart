import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import 'converters.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The app's local SQLite database (local-first: the app works fully offline).
///
/// Schema changes: edit `tables.dart`, bump [schemaVersion], run
/// `dart run drift_dev make-migrations` from `app/`, then add a `fromXToY`
/// step in [migration] and fill in the generated migration test.
@DriftDatabase(
  tables: [
    Tasks,
    Subtasks,
    Categories,
    Tags,
    TaskTags,
    Reminders,
    Places,
    Devices,
    TaskTargetDevices,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the database file, or uses [executor] (e.g. in-memory for tests).
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());

  static QueryExecutor _openConnection() => driftDatabase(
    name: 'taskwise',
    native: const DriftNativeOptions(
      // App-support dir (e.g. ~/.local/share/<app id> on Linux) rather than
      // the default Documents folder.
      databaseDirectory: getApplicationSupportDirectory,
    ),
  );
}
