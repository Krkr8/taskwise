import 'package:drift/drift.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import '../app_settings.dart';
import '../db/app_database.dart';
import 'repository_base.dart';

/// Setting keys. The `synced` flag decides whether a key is shared across
/// devices (see [AppSettings]).
abstract final class SettingKeys {
  static const theme = 'theme';
  static const language = 'language';
  static const timeFormat = 'time_format';
  static const weekStart = 'week_start';
  static const thisDeviceId = 'this_device_id';
}

/// Reads and writes key/value settings.
class SettingsRepository extends RepositoryBase {
  SettingsRepository(super.db, {required super.deviceId, super.clock});

  Stream<AppSettings> watchSettings() =>
      _liveRows().watch().map(_parse).distinct();

  Future<AppSettings> loadSettings() async => _parse(await _liveRows().get());

  Future<void> setTheme(ThemePreference value) =>
      _put(SettingKeys.theme, value.name, synced: false);

  Future<void> setLanguage(AppLanguage value) =>
      _put(SettingKeys.language, value.name, synced: false);

  Future<void> setTimeFormat(TimeFormat value) =>
      _put(SettingKeys.timeFormat, value.name, synced: false);

  Future<void> setWeekStart(WeekStart value) =>
      _put(SettingKeys.weekStart, value.name, synced: true);

  SimpleSelectStatement<$SettingsTable, SettingRow> _liveRows() =>
      db.select(db.settings)..where((s) => s.deleted.not());

  Future<void> _put(String key, String value, {required bool synced}) => db
      .into(db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          id: key,
          value: value,
          synced: Value(synced),
          updatedAt: now(),
          deleted: const Value(false),
          updatedByDevice: Value(deviceId),
        ),
      );

  static AppSettings _parse(List<SettingRow> rows) {
    final values = {for (final row in rows) row.id: row.value};
    return AppSettings(
      theme:
          ThemePreference.values.asNameMap()[values[SettingKeys.theme]] ??
          ThemePreference.system,
      language: AppLanguage.values.asNameMap()[values[SettingKeys.language]],
      timeFormat:
          TimeFormat.values.asNameMap()[values[SettingKeys.timeFormat]] ??
          TimeFormat.h12,
      weekStart: WeekStart.fromName(values[SettingKeys.weekStart]),
    );
  }
}

/// Returns this install's device id, registering the device on first launch.
///
/// The id is stored as a device-only setting; the device record itself is a
/// normal synced row (device registration with the server comes in M6).
Future<String> ensureThisDevice(
  AppDatabase db, {
  required DeviceType type,
  required String name,
  Clock? clock,
}) => db.transaction(() async {
  final existing = await (db.select(
    db.settings,
  )..where((s) => s.id.equals(SettingKeys.thisDeviceId))).getSingleOrNull();
  if (existing != null) return existing.value;

  final base = _DeviceBootstrap(db, clock: clock);
  final id = base.newId();
  final at = base.now();
  await db
      .into(db.devices)
      .insert(
        DevicesCompanion.insert(
          id: id,
          name: name,
          type: type,
          lastSeenAt: Value(at),
          updatedAt: at,
          updatedByDevice: Value(id),
        ),
      );
  await db
      .into(db.settings)
      .insert(
        SettingsCompanion.insert(
          id: SettingKeys.thisDeviceId,
          value: id,
          updatedAt: at,
          updatedByDevice: Value(id),
        ),
      );
  return id;
});

/// Borrows [RepositoryBase]'s clock and id helpers before a device id exists.
class _DeviceBootstrap extends RepositoryBase {
  _DeviceBootstrap(super.db, {super.clock}) : super(deviceId: '');
}
