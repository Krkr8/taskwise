import 'dart:io';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import 'data/app_settings.dart';
import 'data/db/app_database.dart';
import 'data/repositories/settings_repository.dart';
import 'location/location_platform.dart';
import 'logging/app_log.dart';
import 'location/location_reminder_sync.dart';
import 'notifications/desktop_notifier.dart';
import 'notifications/ios_notifier.dart';
import 'notifications/notifier.dart';
import 'notifications/reminder_scheduler.dart';
import 'state/providers.dart';
import 'sync/sync_controller.dart';

/// What every start of Taskwise needs before the providers run: the open
/// database, this device's id and settings, and the platform services.
/// Shared by the app (`main`) and the iPhone's background sync.
final class AppBootstrap {
  AppBootstrap._({
    required this.db,
    required this.deviceId,
    required this.deviceType,
    required this.settings,
    required this.notifier,
    required this.location,
  });

  final AppDatabase db;
  final String deviceId;
  final DeviceType deviceType;
  final AppSettings settings;
  final ReminderNotifier notifier;
  final LocationPlatform location;

  static bool get isDesktop => Platform.isWindows || Platform.isLinux;

  static Future<AppBootstrap> start() async {
    configureIntl();
    await appLog.open(
      Directory('${(await getApplicationSupportDirectory()).path}/logs'),
    );
    final db = AppDatabase();
    final type = _detectDeviceType();
    final deviceId = await ensureThisDevice(
      db,
      type: type,
      name: _defaultDeviceName(type),
    );
    final settings = await SettingsRepository(
      db,
      deviceId: deviceId,
    ).loadSettings();
    return AppBootstrap._(
      db: db,
      deviceId: deviceId,
      deviceType: type,
      settings: settings,
      notifier: isDesktop
          ? DesktopNotifier()
          : Platform.isIOS
          ? IosNotifier()
          : NoopNotifier(),
      location: Platform.isIOS ? IosLocationPlatform() : NoLocationPlatform(),
    );
  }

  /// Provider overrides for this start.
  List<Override> get overrides => [
    databaseProvider.overrideWithValue(db),
    deviceIdProvider.overrideWithValue(deviceId),
    initialSettingsProvider.overrideWithValue(settings),
    reminderNotifierProvider.overrideWithValue(notifier),
    locationPlatformProvider.overrideWithValue(location),
    deviceTypeProvider.overrideWithValue(deviceType),
  ];
}

/// Global intl setup. Arabic uses Western digits (0-9), per the owner.
void configureIntl() {
  DateFormat.useNativeDigitsByDefaultFor('ar', false);
}

DeviceType _detectDeviceType() {
  if (Platform.isWindows) return DeviceType.windows;
  if (Platform.isLinux) return DeviceType.linux;
  if (Platform.isIOS) return DeviceType.ios;
  return DeviceType.other;
}

/// Pre-filled device name (SPEC.md section 3.4); changed when signing in
/// or in Settings → Devices.
String _defaultDeviceName(DeviceType type) => switch (type) {
  DeviceType.windows => 'Windows PC',
  DeviceType.ios => 'iPhone',
  DeviceType.linux => _isFedora() ? 'Fedora Laptop' : 'Linux PC',
  DeviceType.other => 'Device',
};

bool _isFedora() {
  try {
    return File('/etc/os-release').readAsStringSync().contains('ID=fedora');
  } on FileSystemException {
    return false;
  }
}
