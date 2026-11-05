import Flutter
import UIKit
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Background sync task (also in Info.plist and background_sync.dart).
  static let syncTask = "io.github.krkr8.taskwise.sync"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets flutter_local_notifications receive notification taps and
    // Done/Snooze presses (as its README requires).
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate

    // Location reminders run natively, so region events are handled even
    // when iOS relaunches Taskwise in the background without its UI.
    LocationReminderManager.shared.start()

    // Background sync (workmanager). The background engine gets the same
    // plugins as the app, plus the location channel.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
      if let registrar = registry.registrar(forPlugin: "LocationRemindersPlugin") {
        LocationRemindersPlugin.register(with: registrar)
      }
    }
    // Scenes register plugins after this method returns, so the task's
    // launch handler must be registered here (workmanager_apple docs).
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: Self.syncTask, earliestBeginInSeconds: NSNumber(value: 30 * 60))
    WorkmanagerPlugin.registerLaunchHandlers()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LocationRemindersPlugin") {
      LocationRemindersPlugin.register(with: registrar)
    }
  }
}
