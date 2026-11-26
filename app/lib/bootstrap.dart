import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import 'assistant/assistant_platform.dart';
import 'assistant/assistant_sync.dart';
import 'data/app_settings.dart';
import 'data/db/app_database.dart';
import 'data/repositories/settings_repository.dart';
import 'data/storage_status.dart';
import 'location/location_platform.dart';
import 'logging/app_log.dart';
import 'logging/browser_log_store.dart';
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
import 'platform/persistent_storage.dart';
import 'platform/web_device_name.dart';

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
    required this.storageStatus,
  });

  final AppDatabase db;
  final String deviceId;
  final DeviceType deviceType;
  final AppSettings settings;
  final ReminderNotifier notifier;
  final LocationPlatform location;
  final AssistantPlatform assistant;
  final UpdateConfig update;

  /// Whether the tasks survive a restart (only the browser may say no).
  final StorageStatus storageStatus;

  static bool get isDesktop => appTarget.isDesktop;

  /// Phones: the system schedules reminders, and location reminders fire.
  static bool get isMobile => appTarget.isMobile;

  /// Opens everything. [executor] replaces this device's database (tests).
  ///
  /// In the browser there are no files, tray, updates, Siri or background
  /// sync: the log is kept in the browser's storage, and the services are
  /// the ones that do nothing.
  static Future<AppBootstrap> start({QueryExecutor? executor}) async {
    configureIntl();
    if (appTarget.isWeb) {
      final store = browserLogStore();
      if (store != null) appLog.useStore(store);
    } else {
      await appLog.open(
        Directory('${(await getApplicationSupportDirectory()).path}/logs'),
      );
    }
    if (appTarget == AppTarget.windows) {
      // What the update helper did after the last "Update and restart".
      await importWindowsUpdateLog(
        '${(await getTemporaryDirectory()).path}\\$windowsUpdateLogName',
      );
    }
    var storageStatus = StorageStatus.persistent;
    // The browser picks its storage when the first query below runs.
    final db = AppDatabase(
      executor ??
          AppDatabase.openConnection(
            onWebStorage: (storage) =>
                storageStatus = storageStatusFor(storage),
          ),
    );
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
    if (appTarget.isWeb) unawaited(_keepBrowserStorage());
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
      storageStatus: storageStatus,
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
    storageStatusProvider.overrideWithValue(storageStatus),
  ];
}

/// Asks the browser not to clear the tasks when the disk gets full. Not
/// awaited: Firefox asks the user first.
Future<void> _keepBrowserStorage() async {
  final kept = await requestPersistentStorage();
  appLog.info('database', 'Persistent browser storage: ${kept ?? 'unknown'}');
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
  if (appTarget == AppTarget.web) return DeviceType.web;
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
  DeviceType.web => webDeviceName(browserUserAgent()),
};

bool _isFedora() {
  try {
    return File('/etc/os-release').readAsStringSync().contains('ID=fedora');
  } on FileSystemException {
    return false;
  }
}
