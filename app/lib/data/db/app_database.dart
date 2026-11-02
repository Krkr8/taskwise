import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import 'app_database.steps.dart';
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
    SyncOutbox,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the database file, or uses [executor] (e.g. in-memory for tests).
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createSyncTriggers();
    },
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.createTable(schema.syncOutbox);
        await _createSyncTriggers();
        // Queue everything made before sync existed, so it's uploaded (and
        // merged with the other devices) on the first connect.
        await queueAllForSync();
      },
      from2To3: (m, schema) async {
        await m.addColumn(schema.devices, schema.devices.isMain);
      },
    ),
  );

  /// Synced tables: (SQL table, sync record type, row filter).
  static const syncedTables = <(String, String, String?)>[
    ('tasks', 'task', null),
    ('subtasks', 'subtask', null),
    ('categories', 'category', null),
    ('tags', 'tag', null),
    ('task_tags', 'taskTag', null),
    ('reminders', 'reminder', null),
    ('places', 'place', null),
    ('task_target_devices', 'taskTargetDevice', null),
    // Device-only settings (theme, language...) stay on this device.
    ('settings', 'setting', ' WHERE synced = 1'),
  ];

  /// Triggers that queue every insert and update of a synced row in
  /// [SyncOutbox]. Devices aren't synced as records (the server owns them).
  static Iterable<String> get syncTriggers sync* {
    for (final (table, type, where) in syncedTables) {
      final when = where == null ? '' : ' WHEN NEW.synced = 1';
      for (final event in ['INSERT', 'UPDATE']) {
        // An upsert, not INSERT OR REPLACE: inside a trigger SQLite lets
        // the outer statement's conflict clause override OR REPLACE, so a
        // second write of a row would fail.
        yield 'CREATE TRIGGER IF NOT EXISTS ${table}_outbox_${event.toLowerCase()} '
            'AFTER $event ON $table$when BEGIN '
            'INSERT INTO sync_outbox (record_type, record_id, updated_at) '
            "VALUES ('$type', NEW.id, NEW.updated_at) "
            'ON CONFLICT (record_type, record_id) '
            'DO UPDATE SET updated_at = excluded.updated_at; END';
      }
    }
  }

  /// Queues every synced row for upload, e.g. when signing in to a server
  /// that may not have them yet. Rows it already has come back `stale`.
  Future<void> queueAllForSync() async {
    for (final (table, type, where) in syncedTables) {
      await customStatement(
        'INSERT OR REPLACE INTO sync_outbox '
        '(record_type, record_id, updated_at) '
        "SELECT '$type', id, updated_at FROM $table${where ?? ''}",
      );
    }
  }

  Future<void> _createSyncTriggers() async {
    for (final statement in syncTriggers) {
      await customStatement(statement);
    }
  }

  static QueryExecutor _openConnection() => driftDatabase(
    name: 'taskwise',
    native: const DriftNativeOptions(
      // App-support dir (e.g. ~/.local/share/<app id> on Linux) rather than
      // the default Documents folder.
      databaseDirectory: getApplicationSupportDirectory,
    ),
  );
}
