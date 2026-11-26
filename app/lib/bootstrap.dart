import 'dart:io';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import 'assistant/assistant_platform.dart';
import 'assistant/assistant_sync.dart';
import 'data/app_settings.dart';
import 'data/db/app_database.dart';
import 'data/repositories/settings_repository.dart';
import 'location/location_platform.dart';
import 'logging/app_log.dart';
import 'location/location_reminder_sync.dart';
import 'notifications/desktop_notifier.dart';
import 'notifications/mobile_notifier.dart';
import 'notifications/notifier.dart';
import 'notifications/reminder_scheduler.dart';
import 'state/providers.dart';
import 'sync/sync_controller.dart';
import 'update/update_controller.dart';
import 'update/update_installer.dart';
import 'platform/app_target.dart';

/// What every start of Taskwise needs before the providers run: the open
/// database, this device's id and settings, and the platform services.
/// Shared by the app (`main`) and the phones' background sync.
final class AppBootstrap {
  AppBootstrap._({
    required this.db,
    required this.deviceId,
    required this.deviceType,
    required this.settings,
    required this.notifier,
    required this.location,
    required this.assistant,
    required this.update,
  });

  final AppDatabase db;
  final String deviceId;
  final DeviceType deviceType;
  final AppSettings settings;
  final ReminderNotifier notifier;
  final LocationPlatform location;
  final AssistantPlatform assistant;
  final UpdateConfig update;

  static bool get isDesktop => appTarget.isDesktop;

  /// Phones: the system schedules reminders, and location reminders fire.
  static bool get isMobile => appTarget.isMobile;

  static Future<AppBootstrap> start() async {
    configureIntl();
    await appLog.open(
      Directory('${(await getApplicationSupportDirectory()).path}/logs'),
    );
    if (appTarget == AppTarget.windows) {
      // What the update helper did after the last "Update and restart".
      await importWindowsUpdateLog(
        '${(await getTemporaryDirectory()).path}\\$windowsUpdateLogName',
      );
    }
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
          : isMobile
          ? MobileNotifier()
          : NoopNotifier(),
      location: isMobile ? NativeLocationPlatform() : NoLocationPlatform(),
      // Siri's inbox is on the iPhone; Android only sends actions.
      assistant: isMobile
          ? NativeAssistantPlatform(hasInbox: appTarget == AppTarget.ios)
          : NoAssistantPlatform(),
      update: UpdateConfig(
        enabled: isDesktop || isMobile,
        installer: await detectUpdateInstaller(),
        isIos: appTarget == AppTarget.ios,
      ),
    );
  }

  /// Provider overrides for this start.
  List<Override> get overrides => [
    databaseProvider.overrideWithValue(db),
    deviceIdProvider.overrideWithValue(deviceId),
    initialSettingsProvider.overrideWithValue(settings),
    reminderNotifierProvider.overrideWithValue(notifier),
    locationPlatformProvider.overrideWithValue(location),
    assistantPlatformProvider.overrideWithValue(assistant),
    updateConfigProvider.overrideWithValue(update),
    deviceTypeProvider.overrideWithValue(deviceType),
  ];
}

/// Global intl setup. Arabic uses Western digits (0-9), per the owner.
void configureIntl() {
  DateFormat.useNativeDigitsByDefaultFor('ar', false);
}

DeviceType _detectDeviceType() {
  if (appTarget == AppTarget.windows) return DeviceType.windows;
  if (appTarget == AppTarget.linux) return DeviceType.linux;
  if (appTarget == AppTarget.ios) return DeviceType.ios;
  if (appTarget == AppTarget.android) return DeviceType.android;
  // Task 2 adds DeviceType.web.
  return DeviceType.other;
}

/// Pre-filled device name (SPEC.md section 3.4); changed when signing in
/// or in Settings → Devices.
String _defaultDeviceName(DeviceType type) => switch (type) {
  DeviceType.windows => 'Windows PC',
  DeviceType.ios => 'iPhone',
  DeviceType.android => 'Android phone',
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
