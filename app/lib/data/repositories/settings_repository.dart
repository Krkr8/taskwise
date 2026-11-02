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
  static const defaultReminder = 'default_reminder';
  static const snoozeMinutes = 'snooze_minutes';
  static const allDayReminderMinutes = 'all_day_reminder_minutes';
  static const keepRunningInBackground = 'keep_running_in_background';
  static const startOnLogin = 'start_on_login';

  /// Active snoozes (JSON list of [Snooze]); device-only.
  static const snoozes = 'snoozes';

  /// When this device last checked for due reminders (ISO UTC). Desktop
  /// uses it to show reminders missed while the app wasn't running.
  static const remindersCheckedAt = 'reminders_checked_at';
  static const thisDeviceId = 'this_device_id';

  // Sync (all device-only).
  static const serverUrl = 'sync_server_url';
  static const syncUsername = 'sync_username';

  /// Change sequence number of the last pulled change (docs/sync-api.md).
  static const syncSeq = 'sync_seq';
  static const lastSyncedAt = 'sync_last_synced_at';
  static const syncBannerDismissed = 'sync_banner_dismissed';
}

/// The device-only sync bookkeeping kept in settings.
typedef SyncSettings = ({
  String? serverUrl,
  String? username,
  int seq,
  DateTime? lastSyncedAt,
  bool bannerDismissed,
});

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

  Future<void> setDefaultReminder(DefaultReminder value) =>
      _put(SettingKeys.defaultReminder, value.name, synced: true);

  /// Stores 1 to 3 snooze lengths (sorted, duplicates dropped).
  Future<void> setSnoozeMinutes(List<int> minutes) {
    final values = (minutes.toSet().toList()..sort()).take(3).toList();
    if (values.isEmpty) throw ArgumentError('At least one snooze length');
    return _put(SettingKeys.snoozeMinutes, values.join(','), synced: false);
  }

  Future<void> setAllDayReminderMinutes(int minutes) => _put(
    SettingKeys.allDayReminderMinutes,
    '${minutes.clamp(0, 24 * 60 - 1)}',
    synced: false,
  );

  Future<void> setKeepRunningInBackground(bool value) =>
      _put(SettingKeys.keepRunningInBackground, '$value', synced: false);

  Future<void> setStartOnLogin(bool value) =>
      _put(SettingKeys.startOnLogin, '$value', synced: false);

  // --------------------------------------------- reminder bookkeeping

  /// Active snoozes on this device.
  Stream<List<Snooze>> watchSnoozes() =>
      (db.select(db.settings)..where((s) => s.id.equals(SettingKeys.snoozes)))
          .watchSingleOrNull()
          .map((row) => Snooze.decodeList(row?.value));

  Future<List<Snooze>> getSnoozes() async => Snooze.decodeList(
    (await (db.select(
          db.settings,
        )..where((s) => s.id.equals(SettingKeys.snoozes))).getSingleOrNull())
        ?.value,
  );

  /// Adds a snooze, dropping ones that are already over.
  Future<void> addSnooze(Snooze snooze) async {
    final at = now();
    final kept = [
      for (final s in await getSnoozes())
        if (s.until.isAfter(at)) s,
      snooze,
    ];
    await _put(SettingKeys.snoozes, Snooze.encodeList(kept), synced: false);
  }

  Future<DateTime?> getRemindersCheckedAt() async {
    final row =
        await (db.select(db.settings)
              ..where((s) => s.id.equals(SettingKeys.remindersCheckedAt)))
            .getSingleOrNull();
    return row == null ? null : DateTime.tryParse(row.value);
  }

  Future<void> setRemindersCheckedAt(DateTime at) => _put(
    SettingKeys.remindersCheckedAt,
    at.toUtc().toIso8601String(),
    synced: false,
  );

  // ------------------------------------------------------------------ sync

  Future<SyncSettings> getSyncSettings() async {
    final rows =
        await (db.select(db.settings)..where(
              (s) => s.id.isIn([
                SettingKeys.serverUrl,
                SettingKeys.syncUsername,
                SettingKeys.syncSeq,
                SettingKeys.lastSyncedAt,
                SettingKeys.syncBannerDismissed,
              ]),
            ))
            .get();
    final values = {for (final row in rows) row.id: row.value};
    return (
      serverUrl: values[SettingKeys.serverUrl],
      username: values[SettingKeys.syncUsername],
      seq: int.tryParse(values[SettingKeys.syncSeq] ?? '') ?? 0,
      lastSyncedAt: DateTime.tryParse(values[SettingKeys.lastSyncedAt] ?? ''),
      bannerDismissed: values[SettingKeys.syncBannerDismissed] == 'true',
    );
  }

  /// Remembers the server this device signs in to, starting from the first
  /// change; or forgets it (signed out) when [serverUrl] is null.
  Future<void> setSyncAccount({String? serverUrl, String? username}) =>
      db.transaction(() async {
        if (serverUrl == null) {
          await (db.delete(db.settings)..where(
                (s) => s.id.isIn([
                  SettingKeys.serverUrl,
                  SettingKeys.syncUsername,
                  SettingKeys.lastSyncedAt,
                ]),
              ))
              .go();
        } else {
          await _put(SettingKeys.serverUrl, serverUrl, synced: false);
          await _put(SettingKeys.syncUsername, username ?? '', synced: false);
        }
        await setSyncSeq(0);
      });

  Future<void> setSyncSeq(int seq) =>
      _put(SettingKeys.syncSeq, '$seq', synced: false);

  Future<void> setLastSyncedAt(DateTime at) => _put(
    SettingKeys.lastSyncedAt,
    at.toUtc().toIso8601String(),
    synced: false,
  );

  Future<void> setSyncBannerDismissed() =>
      _put(SettingKeys.syncBannerDismissed, 'true', synced: false);

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
      defaultReminder:
          DefaultReminder.values
              .asNameMap()[values[SettingKeys.defaultReminder]] ??
          DefaultReminder.none,
      snoozeMinutes: _parseSnoozes(values[SettingKeys.snoozeMinutes]),
      allDayReminderMinutes:
          int.tryParse(values[SettingKeys.allDayReminderMinutes] ?? '') ??
          9 * 60,
      keepRunningInBackground:
          values[SettingKeys.keepRunningInBackground] != 'false',
      startOnLogin: values[SettingKeys.startOnLogin] == 'true',
    );
  }

  static List<int> _parseSnoozes(String? text) {
    final values = [
      for (final part in (text ?? '').split(','))
        if (int.tryParse(part) case final m? when m > 0) m,
    ];
    return values.isEmpty ? AppSettings.defaultSnoozeMinutes : values;
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
