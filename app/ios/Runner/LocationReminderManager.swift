import CoreLocation
import Foundation
import UIKit
import UserNotifications

/// Watches the places of location reminders and shows their notifications,
/// entirely natively: iOS may relaunch Taskwise in the background for a
/// region event without starting any Flutter UI, so no Dart runs here.
///
/// The decisions are made by GeofenceEngine (GeofenceDecider.swift), which
/// the walk simulator in tools/geofence_sim also runs. This class connects
/// it to Core Location (SPEC.md section 3.3):
/// - each reminder gets an outer region (~150 m) because iOS geofences are
///   unreliable below that; region events start precise updates for a few
///   minutes, and the engine decides from the fixes;
/// - after lingering near a place, a small "near" region is watched;
/// - iOS allows 20 regions per app: with more reminders, the nearest are
///   monitored and significant location changes pick them again.
///
/// Created in AppDelegate's didFinishLaunching so region events reach it
/// after a background relaunch.
final class LocationReminderManager: NSObject, CLLocationManagerDelegate, GeofenceHost {
  static let shared = LocationReminderManager()

  /// iOS allows 20 monitored regions per app.
  private static let regionLimit = 20
  private static let regionPrefix = "taskwise.loc."
  private static let nearPrefix = "taskwise.near."
  private static let eventLimit = 50

  private let manager = CLLocationManager()
  private let defaults = UserDefaults.standard
  private var engine = GeofenceEngine()
  private var events: [String] = []

  private var preciseActive = false
  private var preciseTimer: Timer?
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var lastFix: CLLocation?

  private var permissionCallbacks: [(String) -> Void] = []
  private var locationCallbacks: [([String: Any]?) -> Void] = []
  private var started = false

  private var entries: [GeofenceEntry] { engine.entries }

  private enum Keys {
    static let states = "taskwise.location.states"
    static let near = "taskwise.location.near"
    static let events = "taskwise.location.events"
    static let askedAlways = "taskwise.location.askedAlways"
  }

  private override init() {
    super.init()
  }

  // MARK: - Start and entries

  /// Loads the saved reminders and (re)starts monitoring. Safe to call more
  /// than once.
  func start() {
    guard !started else { return }
    started = true
    manager.delegate = self
    manager.pausesLocationUpdatesAutomatically = false
    events = defaults.stringArray(forKey: Keys.events) ?? []
    engine = GeofenceEngine(
      entries: loadEntries(), states: loadStates(),
      nearIds: Set(defaults.stringArray(forKey: Keys.near) ?? []))
    engine.host = self
    refreshRegions()
  }

  /// Replaces the reminders (from Dart) and updates the monitored regions.
  func setEntries(_ newEntries: [GeofenceEntry]) {
    start()
    if engine.setEntries(newEntries) { log("reminders: \(newEntries.count)") }
    saveEntries()
    saveEngine()
    refreshRegions()
  }

  private func refreshRegions() {
    guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
      log("region monitoring not available")
      return
    }
    let here = (lastFix ?? manager.location).map {
      (latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
    }
    let nearEntries = entries.filter { engine.nearIds.contains($0.id) }
    let chosen = GeofenceDecider.nearest(
      entries, limit: max(0, Self.regionLimit - nearEntries.count), from: here)
    var wanted: [String: CLCircularRegion] = [:]
    for entry in chosen {
      let region = makeRegion(entry, near: false)
      wanted[region.identifier] = region
    }
    for entry in nearEntries {
      let region = makeRegion(entry, near: true)
      wanted[region.identifier] = region
    }

    for region in manager.monitoredRegions where isOurs(region.identifier) {
      guard let want = wanted[region.identifier],
        let circle = region as? CLCircularRegion,
        sameRegion(circle, want)
      else {
        manager.stopMonitoring(for: region)
        continue
      }
    }
    let monitored = Set(manager.monitoredRegions.map(\.identifier))
    for (identifier, region) in wanted where !monitored.contains(identifier) {
      manager.startMonitoring(for: region)
      // Ask where we are now, so a reminder added while at the place knows.
      // Not for near regions: only walking into one counts.
      if identifier.hasPrefix(Self.regionPrefix) { manager.requestState(for: region) }
    }

    // More reminders than regions: re-pick the nearest as the phone moves.
    if entries.count > Self.regionLimit - nearEntries.count {
      manager.startMonitoringSignificantLocationChanges()
    } else {
      manager.stopMonitoringSignificantLocationChanges()
    }
  }

  private func isOurs(_ identifier: String) -> Bool {
    identifier.hasPrefix(Self.regionPrefix) || identifier.hasPrefix(Self.nearPrefix)
  }

  private func makeRegion(_ entry: GeofenceEntry, near: Bool) -> CLCircularRegion {
    let maximum = manager.maximumRegionMonitoringDistance
    let region = CLCircularRegion(
      center: CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude),
      radius: near
        ? GeofenceDecider.nearRadius(for: entry, maximum: maximum)
        : GeofenceDecider.outerRadius(for: entry, maximum: maximum),
      identifier: (near ? Self.nearPrefix : Self.regionPrefix) + entry.id
    )
    region.notifyOnEntry = true
    region.notifyOnExit = !near
    return region
  }

  private func sameRegion(_ a: CLCircularRegion, _ b: CLCircularRegion) -> Bool {
    abs(a.center.latitude - b.center.latitude) < 1e-7
      && abs(a.center.longitude - b.center.longitude) < 1e-7
      && abs(a.radius - b.radius) < 0.5
  }

  /// The reminder id and whether it's a near region.
  private func parse(_ region: CLRegion) -> (id: String, near: Bool)? {
    if region.identifier.hasPrefix(Self.regionPrefix) {
      return (String(region.identifier.dropFirst(Self.regionPrefix.count)), false)
    }
    if region.identifier.hasPrefix(Self.nearPrefix) {
      return (String(region.identifier.dropFirst(Self.nearPrefix.count)), true)
    }
    return nil
  }

  // MARK: - Region events

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    guard let parsed = parse(region) else { return }
    if parsed.near {
      engine.enteredNear(id: parsed.id, now: Date())
    } else {
      engine.entered(id: parsed.id, now: Date())
    }
    saveEngine()
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    guard let parsed = parse(region), !parsed.near else { return }
    engine.exited(id: parsed.id, now: Date())
    saveEngine()
  }

  func locationManager(
    _ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion
  ) {
    guard let parsed = parse(region), !parsed.near, state != .unknown else { return }
    engine.determined(id: parsed.id, inside: state == .inside, now: Date())
    saveEngine()
  }

  func locationManager(
    _ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error
  ) {
    log("monitoring failed \(region?.identifier ?? "?"): \(error.localizedDescription)")
  }

  // MARK: - GeofenceHost

  func startPreciseUpdates() -> Bool {
    guard authorization() == .authorizedAlways || authorization() == .authorizedWhenInUse else {
      return false
    }
    preciseActive = true
    if backgroundTask == .invalid {
      backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "taskwise.location") {
        [weak self] in
        guard let self = self else { return }
        // iOS is about to suspend the app: end the check now.
        self.log("background time ended")
        self.endBackgroundTask()
      }
    }
    // Checks the engine's time limit even when no fixes arrive.
    preciseTimer?.invalidate()
    preciseTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      self.engine.checkTimeout(now: Date())
      self.saveEngine()
    }
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = kCLDistanceFilterNone
    if authorization() == .authorizedAlways {
      manager.allowsBackgroundLocationUpdates = true
      manager.showsBackgroundLocationIndicator = false
    }
    manager.startUpdatingLocation()
    return true
  }

  func stopPreciseUpdates() {
    preciseTimer?.invalidate()
    preciseTimer = nil
    if preciseActive {
      manager.stopUpdatingLocation()
      manager.allowsBackgroundLocationUpdates = false
      preciseActive = false
    }
    endBackgroundTask()
  }

  private func endBackgroundTask() {
    if backgroundTask != .invalid {
      UIApplication.shared.endBackgroundTask(backgroundTask)
      backgroundTask = .invalid
    }
  }

  func watchNear(_ entry: GeofenceEntry) {
    refreshRegions()
  }

  func stopWatchingNear(id: String) {
    for region in manager.monitoredRegions where region.identifier == Self.nearPrefix + id {
      manager.stopMonitoring(for: region)
    }
    refreshRegions()
  }

  func show(_ entry: GeofenceEntry, reason: String) {
    notify(entry, reason: reason)
  }

  // MARK: - Precise updates

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let fix = locations.last else { return }
    lastFix = fix
    if !locationCallbacks.isEmpty {
      let callbacks = locationCallbacks
      locationCallbacks.removeAll()
      callbacks.forEach { $0(Self.describe(fix)) }
    }
    if !engine.preciseActive {
      // A significant location change (more than 20 reminders): re-pick
      // the nearest regions.
      if entries.count > Self.regionLimit - engine.nearIds.count { refreshRegions() }
      return
    }
    engine.fix(
      latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
      accuracy: fix.horizontalAccuracy, now: Date())
    saveEngine()
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    if !locationCallbacks.isEmpty {
      let callbacks = locationCallbacks
      locationCallbacks.removeAll()
      callbacks.forEach { $0(nil) }
    }
    log("location error: \(error.localizedDescription)")
  }

  // MARK: - Notifications

  private func notify(_ entry: GeofenceEntry, reason: String) {
    log("notify \(reason): \(entry.title)")
    let content = UNMutableNotificationContent()
    content.title = entry.title
    content.body = entry.body
    content.sound = .default
    // The category and keys flutter_local_notifications uses, so Done,
    // Snooze and taps reach Dart like a time reminder's.
    content.categoryIdentifier = "task"
    content.userInfo = [
      "NotificationId": entry.notificationId,
      "presentAlert": true,
      "presentSound": true,
      "presentBadge": false,
      "presentBanner": true,
      "presentList": true,
      "payload": entry.payload,
    ]
    let request = UNNotificationRequest(
      identifier: "taskwise-location-\(entry.id)", content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { [weak self] error in
      if let error = error {
        DispatchQueue.main.async {
          self?.log("notification failed: \(error.localizedDescription)")
        }
      }
    }
  }

  // MARK: - Permission and current location

  private func authorization() -> CLAuthorizationStatus {
    manager.authorizationStatus
  }

  func permissionStatus() -> String {
    switch authorization() {
    case .authorizedAlways: return "always"
    case .authorizedWhenInUse: return "whenInUse"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "notDetermined"
    @unknown default: return "notDetermined"
    }
  }

  /// Asks for "While Using" first; after it's granted, for "Always" (iOS
  /// shows that prompt once). Calls back with the status after the first
  /// answer; Dart refreshes again when the app resumes.
  func requestPermission(_ completion: @escaping (String) -> Void) {
    start()
    switch authorization() {
    case .notDetermined:
      permissionCallbacks.append(completion)
      manager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse where !defaults.bool(forKey: Keys.askedAlways):
      defaults.set(true, forKey: Keys.askedAlways)
      permissionCallbacks.append(completion)
      manager.requestAlwaysAuthorization()
    default:
      completion(permissionStatus())
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    log("permission: \(permissionStatus())")
    if authorization() == .authorizedWhenInUse && !defaults.bool(forKey: Keys.askedAlways) {
      defaults.set(true, forKey: Keys.askedAlways)
      manager.requestAlwaysAuthorization()
    }
    if !permissionCallbacks.isEmpty, authorization() != .notDetermined {
      let callbacks = permissionCallbacks
      permissionCallbacks.removeAll()
      callbacks.forEach { $0(permissionStatus()) }
    }
    if !locationCallbacks.isEmpty {
      switch authorization() {
      case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
      case .denied, .restricted:
        let callbacks = locationCallbacks
        locationCallbacks.removeAll()
        callbacks.forEach { $0(nil) }
      default: break
      }
    }
    refreshRegions()
  }

  /// One position fix for the map picker ("Use my location").
  func currentLocation(_ completion: @escaping ([String: Any]?) -> Void) {
    start()
    locationCallbacks.append(completion)
    switch authorization() {
    case .notDetermined:
      manager.requestWhenInUseAuthorization()
    case .authorizedAlways, .authorizedWhenInUse:
      manager.desiredAccuracy = kCLLocationAccuracyBest
      manager.requestLocation()
    default:
      locationCallbacks.removeLast()
      completion(nil)
    }
  }

  private static func describe(_ fix: CLLocation) -> [String: Any] {
    [
      "latitude": fix.coordinate.latitude,
      "longitude": fix.coordinate.longitude,
      "accuracy": fix.horizontalAccuracy,
    ]
  }

  // MARK: - Debug screen

  func debugState() -> [String: Any] {
    start()
    let regions: [[String: Any]] = manager.monitoredRegions.compactMap { region in
      guard let circle = region as? CLCircularRegion, let parsed = parse(region) else {
        return nil
      }
      let id = parsed.id
      let near = parsed.near
      let state = engine.states[id]
      let entry = engine.entry(id: id)
      var label = near ? "near area" : "outside"
      if !near, let entry = entry, let state = state {
        label = entry.arrive
          ? (state.armed ? "armed" : "waiting to leave")
          : (state.wasInside ? "inside" : "outside")
      }
      if let check = engine.pending[id] {
        label += check == .confirmExit ? ", checking exit" : ", checking"
      }
      return [
        "id": entry.map { "\($0.title) (\($0.arrive ? "arrive" : "leave"), \(Int($0.radius)) m)" }
          ?? id,
        "latitude": circle.center.latitude,
        "longitude": circle.center.longitude,
        "radius": circle.radius,
        "state": label,
      ]
    }
    var result: [String: Any] = [
      "permission": permissionStatus(),
      "entries": entries.count,
      "regions": regions,
      "events": Array(events.reversed()),
      "preciseActive": engine.preciseActive,
    ]
    if let fix = lastFix ?? manager.location {
      result["lastFix"] = Self.describe(fix)
    }
    return result
  }

  func log(_ text: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "MM-dd HH:mm:ss"
    events.append("\(formatter.string(from: Date())) \(text)")
    if events.count > Self.eventLimit {
      events.removeFirst(events.count - Self.eventLimit)
    }
    defaults.set(events, forKey: Keys.events)
  }

  // MARK: - Storage

  private var entriesURL: URL? {
    guard
      let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first
    else { return nil }
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("location_reminders.json")
  }

  private func loadEntries() -> [GeofenceEntry] {
    guard let url = entriesURL, let data = try? Data(contentsOf: url) else { return [] }
    return (try? JSONDecoder().decode([GeofenceEntry].self, from: data)) ?? []
  }

  private func saveEntries() {
    guard let url = entriesURL, let data = try? JSONEncoder().encode(engine.entries) else {
      return
    }
    // Readable after the first unlock, so a relaunch while locked works.
    try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }

  private func loadStates() -> [String: GeofenceState] {
    guard let data = defaults.data(forKey: Keys.states) else { return [:] }
    return (try? JSONDecoder().decode([String: GeofenceState].self, from: data)) ?? [:]
  }

  /// Saves what the engine learned (after every event: iOS may suspend
  /// or end the app at any time).
  private func saveEngine() {
    if let data = try? JSONEncoder().encode(engine.states) {
      defaults.set(data, forKey: Keys.states)
    }
    defaults.set(Array(engine.nearIds), forKey: Keys.near)
  }
}
