import Flutter
import Foundation

/// The `taskwise/assistant` method channel on the iPhone (see
/// lib/assistant/assistant_platform.dart): the app reads and clears Siri's
/// inbox and hands Siri a snapshot of what's due. Registered on the app's
/// engine and on the background-sync engine, like LocationRemindersPlugin.
final class AssistantPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel
  private var observer: NSObjectProtocol?

  private init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    // Siri added a task while this engine runs: let Dart take it in now.
    observer = NotificationCenter.default.addObserver(
      forName: AssistantStore.inboxChanged, object: nil, queue: .main
    ) { [weak self] _ in
      self?.channel.invokeMethod("inboxChanged", arguments: nil)
    }
  }

  deinit {
    if let observer { NotificationCenter.default.removeObserver(observer) }
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "taskwise/assistant", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(AssistantPlugin(channel: channel), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let store = AssistantStore.shared
    switch call.method {
    case "readInbox":
      result(store.inboxJSON())
    case "ackInbox":
      store.remove(ids: call.arguments as? [String] ?? [])
      result(nil)
    case "setSnapshot":
      guard let json = call.arguments as? String, store.setSnapshot(json: json) else {
        result(FlutterError(code: "bad_args", message: "Expected a snapshot", details: nil))
        return
      }
      result(nil)
    case "takeLaunchAction":
      // Android only: Siri never starts the app with an action.
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
