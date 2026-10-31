import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:taskwise_shared/taskwise_shared.dart';

import 'app.dart';
import 'data/db/app_database.dart';
import 'data/repositories/settings_repository.dart';
import 'desktop/desktop_shell.dart';
import 'notifications/desktop_notifier.dart';
import 'notifications/ios_notifier.dart';
import 'notifications/notifier.dart';
import 'notifications/reminder_scheduler.dart';
import 'state/providers.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  configureIntl();

  final desktop = Platform.isWindows || Platform.isLinux;
  if (desktop) {
    // A second launch just shows the running Taskwise.
    final shell = await DesktopShell.start(
      hidden: args.contains(DesktopShell.hiddenArg),
    );
    if (shell == null) exit(0);
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
  await DesktopShell.instance?.apply(settings);

  final ReminderNotifier notifier = desktop
      ? DesktopNotifier()
      : Platform.isIOS
      ? IosNotifier()
      : NoopNotifier();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue(deviceId),
        initialSettingsProvider.overrideWithValue(settings),
        reminderNotifierProvider.overrideWithValue(notifier),
      ],
      child: const TaskwiseApp(),
    ),
  );
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

/// Pre-filled device name (SPEC.md section 3.4); editable from M6.
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
