// dart format width=80
// ignore_for_file: unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  test('v1 to v3 keeps the data and queues synced rows for upload', () async {
    final schema = await verifier.schemaAt(1);
    final old = schema.rawDatabase;
    old
      ..execute(
        'INSERT INTO tasks (id, title, notes, priority, done, '
        'notify_all_devices, created_at, updated_at, deleted) '
        "VALUES ('t1', 'Old task', '', 'none', 0, 1, 1000, 2000, 0)",
      )
      ..execute(
        'INSERT INTO settings (id, value, synced, updated_at, deleted) '
        "VALUES ('week_start', 'monday', 1, 3000, 0), "
        "('theme', 'dark', 0, 3000, 0)",
      )
      ..execute(
        'INSERT INTO devices (id, name, type, updated_at, deleted) '
        "VALUES ('d1', 'Laptop', 'linux', 1000, 0)",
      );

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);

    final task = await db.select(db.tasks).getSingle();
    expect(task.title, 'Old task');
    Future<List<String>> outbox() async => [
      for (final row in await db.select(db.syncOutbox).get())
        '${row.recordType}:${row.recordId}@${row.updatedAt}',
    ];
    // Devices and device-only settings are not synced as records.
    expect(
      await outbox(),
      unorderedEquals(['task:t1@2000', 'setting:week_start@3000']),
    );

    // From now on the triggers queue every write.
    await db.customStatement('DELETE FROM sync_outbox');
    await (db.update(db.tasks)..where((t) => t.id.equals('t1'))).write(
      TasksCompanion(updatedAt: Value(DateTime.utc(2026, 11, 2))),
    );
    await db.customStatement(
      "UPDATE settings SET value = 'light', updated_at = 4000 WHERE id = 'theme'",
    );
    expect(await outbox(), [
      'task:t1@${DateTime.utc(2026, 11, 2).millisecondsSinceEpoch}',
    ]);
    await db.close();
  });

  test('v3 to v4 keeps reminders and adds an empty label', () async {
    final schema = await verifier.schemaAt(3);
    schema.rawDatabase.execute(
      'INSERT INTO reminders (id, task_id, kind, latitude, longitude, '
      'radius_meters, "trigger", updated_at, deleted) '
      "VALUES ('r1', 't1', 'location', 33.3, 44.4, 30, 'arrive', 1000, 0)",
    );
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 4);
    final row = await db.select(db.reminders).getSingle();
    expect(row.latitude, 33.3);
    expect(row.label, equals(null));
    await db.close();
  });
}
