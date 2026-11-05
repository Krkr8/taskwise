import Flutter
import UIKit

/// The `taskwise/location` method channel (see
/// lib/location/location_platform.dart). Registered on the app's engine and
/// on the background-sync engine; both talk to the one
/// LocationReminderManager.
final class LocationRemindersPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "taskwise/location", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(LocationRemindersPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let manager = LocationReminderManager.shared
    switch call.method {
    case "setEntries":
      guard let list = call.arguments as? [[String: Any]] else {
        result(FlutterError(code: "bad_args", message: "Expected a list", details: nil))
        return
      }
      manager.setEntries(list.compactMap(Self.entry))
      result(nil)
    case "permissionStatus":
      result(manager.permissionStatus())
    case "requestPermission":
      manager.requestPermission { result($0) }
    case "openSettings":
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
      }
      result(nil)
    case "currentLocation":
      var answered = false
      let finish: ([String: Any]?) -> Void = { fix in
        guard !answered else { return }
        answered = true
        result(fix)
      }
      manager.currentLocation(finish)
      // Don't leave the map picker waiting forever.
      DispatchQueue.main.asyncAfter(deadline: .now() + 20) { finish(nil) }
    case "debugState":
      result(manager.debugState())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func entry(_ map: [String: Any]) -> GeofenceEntry? {
    guard let id = map["id"] as? String,
      let latitude = (map["latitude"] as? NSNumber)?.doubleValue,
      let longitude = (map["longitude"] as? NSNumber)?.doubleValue,
      let radius = (map["radius"] as? NSNumber)?.doubleValue,
      let trigger = map["trigger"] as? String
    else { return nil }
    return GeofenceEntry(
      id: id,
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      arrive: trigger != "leave",
      title: map["title"] as? String ?? "",
      body: map["body"] as? String ?? "",
      payload: map["payload"] as? String ?? "",
      notificationId: (map["notificationId"] as? NSNumber)?.intValue ?? 0
    )
  }
}
