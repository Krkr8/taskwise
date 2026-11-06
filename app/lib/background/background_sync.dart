import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../bootstrap.dart';
import '../location/location_reminder_sync.dart';
import '../notifications/reminder_scheduler.dart';
import '../state/providers.dart';
import '../sync/sync_api.dart';
import '../sync/sync_controller.dart';
import '../sync/sync_engine.dart';
import '../logging/app_log.dart';

/// The iPhone's background sync task. The same id is listed under
/// `BGTaskSchedulerPermittedIdentifiers` in `ios/Runner/Info.plist` and
/// registered in `AppDelegate.swift`.
const backgroundSyncTask = 'io.github.krkr8.taskwise.sync';

/// Asks iOS to run [backgroundSyncTask] now and then. iOS decides when
/// (often a few times a day, depending on how much Taskwise is used), and
/// never while Taskwise is open. Does nothing on desktop.
Future<void> registerBackgroundSync() async {
  if (!Platform.isIOS) return;
  try {
    await Workmanager().initialize(backgroundDispatcher);
    await Workmanager().registerPeriodicTask(
      backgroundSyncTask,
      backgroundSyncTask,
      // On iOS this is the earliest start; later runs are scheduled by
      // AppDelegate.swift's registration.
      initialDelay: const Duration(minutes: 15),
    );
  } on Object catch (e) {
    appLog.warning('background', 'Background sync not available: $e');
  }
}

/// Entry point of the background engine iOS starts for the task.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, _) async {
    try {
      await runBackgroundSync();
      return true;
    } on Object catch (e) {
      appLog.error('background', e, null, 'Background sync failed');
      return false;
    }
  });
}

/// One background run: sync with the server (if signed in), then bring the
/// scheduled notifications and the watched places up to date.
Future<void> runBackgroundSync() async {
  WidgetsFlutterBinding.ensureInitialized();
  final boot = await AppBootstrap.start();
  final container = ProviderContainer(overrides: boot.overrides);
  try {
    await syncOnceInBackground(container);
    await refreshReminders(container);
  } finally {
    container.dispose();
    await boot.db.close();
  }
}

/// Pushes and pulls once, if this device is signed in. Errors (offline,
/// signed out) are left for the app to show the next time it opens.
Future<void> syncOnceInBackground(ProviderContainer container) async {
  final settings = container.read(settingsRepositoryProvider);
  final saved = await settings.getSyncSettings();
  final url = saved.serverUrl;
  if (url == null) return;
  final token = await container.read(tokenStoreProvider).read();
  if (token == null) return;
  final engine = SyncEngine(
    db: container.read(databaseProvider),
    api: SyncApi(
      baseUrl: url,
      token: token,
      client: container.read(syncHttpClientProvider),
    ),
    deviceId: container.read(deviceIdProvider),
  );
  try {
    final report = await engine.sync();
    await settings.setLastSyncedAt(container.read(clockProvider)().toUtc());
    appLog.info('background', 'Synced: $report');
  } on SyncApiException catch (e) {
    appLog.warning('background', 'Sync failed: ${e.runtimeType}: $e');
  }
}

/// Re-plans time notifications and location reminders from the database.
Future<void> refreshReminders(ProviderContainer container) async {
  // Riverpod pauses providers nobody listens to, so keep these alive while
  // the background run uses them.
  final subscriptions = [
    container.listen(reminderSchedulerProvider, (_, _) {}),
    container.listen(locationReminderSyncProvider, (_, _) {}),
  ];
  try {
    await _refresh(container);
  } finally {
    for (final s in subscriptions) {
      s.close();
    }
  }
}

Future<void> _refresh(ProviderContainer container) async {
  await Future.wait([
    container.read(taskEntriesProvider.future),
    container.read(timeRemindersProvider.future),
    container.read(locationRemindersProvider.future),
    container.read(placesProvider.future),
    container.read(taskTargetsProvider.future),
    container.read(snoozesProvider.future),
  ]);
  await container.read(reminderSchedulerProvider).replanNow();
  await container.read(locationReminderSyncProvider).apply();
}
