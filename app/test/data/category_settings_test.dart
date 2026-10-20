import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskwise/data/app_settings.dart';
import 'package:taskwise/data/db/app_database.dart';
import 'package:taskwise/data/repositories/category_repository.dart';
import 'package:taskwise/data/repositories/settings_repository.dart';
import 'package:taskwise/data/repositories/task_repository.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import 'test_db.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;

  setUp(() {
    db = openTestDatabase();
    clock = FakeClock();
  });

  tearDown(() => db.close());

  group('categories', () {
    test('create, rename and recolour', () async {
      final repo = CategoryRepository(db, deviceId: 'd', clock: clock.call);
      final work = await repo.createCategory('Work', 0xFF1565C0);
      await repo.createCategory('home', 0xFF2E7D32);
      await repo.updateCategory(work.id, name: 'Office', colorValue: 1);

      final all = await repo.watchCategories().first;
      expect(all.map((c) => c.name), ['home', 'Office']);
      expect(all.last.colorValue, 1);
    });

    test('deleting a category leaves its tasks uncategorised', () async {
      final categories = CategoryRepository(db, deviceId: 'd');
      final tasks = TaskRepository(db, deviceId: 'd', clock: clock.call);
      final work = await categories.createCategory('Work', 0xFF1565C0);
      final task = await tasks.createTask(title: 'x', categoryId: work.id);

      clock.advance();
      await categories.deleteCategory(work.id);

      expect(await categories.watchCategories().first, isEmpty);
      final loaded = (await tasks.getTask(task.id))!;
      expect(loaded.categoryId, isNull);
      expect(loaded.updatedAt, isNot(task.updatedAt));
    });
  });

  group('settings', () {
    test('defaults when nothing is stored', () async {
      final repo = SettingsRepository(db, deviceId: 'd');
      expect(await repo.loadSettings(), const AppSettings());
    });

    test('stores values and marks only week start as synced', () async {
      final repo = SettingsRepository(db, deviceId: 'd');
      await repo.setTheme(ThemePreference.dark);
      await repo.setLanguage(AppLanguage.ar);
      await repo.setTimeFormat(TimeFormat.h24);
      await repo.setWeekStart(WeekStart.saturday);
      await repo.setWeekStart(WeekStart.monday);

      expect(
        await repo.loadSettings(),
        const AppSettings(
          theme: ThemePreference.dark,
          language: AppLanguage.ar,
          timeFormat: TimeFormat.h24,
          weekStart: WeekStart.monday,
        ),
      );
      final synced = await (db.select(
        db.settings,
      )..where((s) => s.synced)).get();
      expect(synced.map((s) => s.id), [SettingKeys.weekStart]);
    });
  });

  group('ensureThisDevice', () {
    test('registers once and returns the same id afterwards', () async {
      final id = await ensureThisDevice(
        db,
        type: DeviceType.linux,
        name: 'Fedora Laptop',
      );
      final again = await ensureThisDevice(
        db,
        type: DeviceType.linux,
        name: 'ignored',
      );
      expect(again, id);
      final device = await db.select(db.devices).getSingle();
      expect(device.id, id);
      expect(device.name, 'Fedora Laptop');
      expect(device.type, DeviceType.linux);
    });
  });

  group('schema', () {
    test('an exported schema file exists for the current version', () {
      // Bumping schemaVersion requires `dart run drift_dev make-migrations`.
      final file = File(
        'drift_schemas/taskwise/drift_schema_v${db.schemaVersion}.json',
      );
      expect(file.existsSync(), isTrue, reason: '${file.path} is missing');
      final exported = jsonEncode(jsonDecode(file.readAsStringSync()));
      for (final table in db.allTables) {
        expect(exported, contains('"${table.actualTableName}"'));
      }
    });
  });
}
