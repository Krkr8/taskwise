import CoreLocation
import Foundation
import UIKit
import UserNotifications

/// Watches the places of location reminders and shows their notifications,
/// entirely natively: iOS may relaunch Taskwise in the background for a
/// region event without starting any Flutter UI, so no Dart runs here.
///
/// How it works (SPEC.md section 3.3):
/// 1. Each reminder gets an outer region (Core Location region monitoring,
///    ~150 m) because iOS geofences are unreliable below that.
/// 2. Entering an outer region starts precise location updates for a few
///    minutes; GeofenceDecider decides when the phone is within the
///    reminder's radius (default 30 m), then the updates stop.
/// 3. Leaving uses the precise fixes when they run, and the outer region's
///    exit as the backup trigger.
/// 4. iOS allows 20 regions per app: with more reminders, the 20 nearest
///    are monitored and significant location changes pick them again.
///
/// Created in AppDelegate's didFinishLaunching so region events reach it
/// after a background relaunch.
final class LocationReminderManager: NSObject, CLLocationManagerDelegate {
  static let shared = LocationReminderManager()

  /// iOS allows 20 monitored regions per app.
  private static let regionLimit = 20
  /// Longest precise-updates session after entering a region.
  private static let preciseTimeout: TimeInterval = 5 * 60
  private static let regionPrefix = "taskwise.loc."
  private static let eventLimit = 50

  private let manager = CLLocationManager()
  private let defaults = UserDefaults.standard
  private var entries: [GeofenceEntry] = []
  private var states: [String: GeofenceState] = [:]
  private var events: [String] = []

  /// Reminders still undecided in the running precise session.
  private var pendingIds = Set<String>()
  private var preciseActive = false
  private var preciseTimer: Timer?
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var lastFix: CLLocation?

  private var permissionCallbacks: [(String) -> Void] = []
  private var locationCallbacks: [([String: Any]?) -> Void] = []
  private var started = false

  private enum Keys {
    static let states = "taskwise.location.states"
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
    entries = loadEntries()
    states = loadStates()
    events = defaults.stringArray(forKey: Keys.events) ?? []
    refreshRegions()
  }

  /// Replaces the reminders (from Dart) and updates the monitored regions.
  func setEntries(_ newEntries: [GeofenceEntry]) {
    start()
    let changed = newEntries != entries
    entries = newEntries
    // Forget state of reminders that are gone or moved.
    let byId = Dictionary(uniqueKeysWithValues: newEntries.map { ($0.id, $0) })
    states = states.filter { byId[$0.key] != nil }
    saveEntries()
    saveStates()
    if changed { log("reminders: \(newEntries.count)") }
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
    let chosen = GeofenceDecider.nearest(entries, limit: Self.regionLimit, from: here)
    let wanted = Dictionary(uniqueKeysWithValues: chosen.map { (Self.regionPrefix + $0.id, $0) })

    for region in manager.monitoredRegions where region.identifier.hasPrefix(Self.regionPrefix) {
      guard let entry = wanted[region.identifier],
        let circle = region as? CLCircularRegion,
        sameRegion(circle, entry)
      else {
        manager.stopMonitoring(for: region)
        continue
      }
    }
    let monitored = Set(manager.monitoredRegions.map(\.identifier))
    for (identifier, entry) in wanted where !monitored.contains(identifier) {
      let region = makeRegion(entry)
      manager.startMonitoring(for: region)
      // Ask where we are now, so a reminder added while at the place knows.
      manager.requestState(for: region)
    }

    // More reminders than regions: re-pick the nearest as the phone moves.
    if entries.count > Self.regionLimit {
      manager.startMonitoringSignificantLocationChanges()
    } else {
      manager.stopMonitoringSignificantLocationChanges()
    }
  }

  private func makeRegion(_ entry: GeofenceEntry) -> CLCircularRegion {
    let region = CLCircularRegion(
      center: CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude),
      radius: GeofenceDecider.outerRadius(
        for: entry, maximum: manager.maximumRegionMonitoringDistance),
      identifier: Self.regionPrefix + entry.id
    )
    region.notifyOnEntry = true
    region.notifyOnExit = true
    return region
  }

  private func sameRegion(_ region: CLCircularRegion, _ entry: GeofenceEntry) -> Bool {
    let wanted = makeRegion(entry)
    return abs(region.center.latitude - wanted.center.latitude) < 1e-7
      && abs(region.center.longitude - wanted.center.longitude) < 1e-7
      && abs(region.radius - wanted.radius) < 0.5
  }

  private func entry(for region: CLRegion) -> GeofenceEntry? {
    guard region.identifier.hasPrefix(Self.regionPrefix) else { return nil }
    let id = String(region.identifier.dropFirst(Self.regionPrefix.count))
    return entries.first { $0.id == id }
  }

  // MARK: - Region events

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    guard let entry = entry(for: region) else { return }
    log("enter \(short(entry))")
    var state = states[entry.id] ?? GeofenceState()
    GeofenceDecider.enteredOuter(entry: entry, state: &state)
    states[entry.id] = state
    saveStates()
    startPrecise(for: [entry.id])
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    guard let entry = entry(for: region) else { return }
    log("exit \(short(entry))")
    var state = states[entry.id] ?? GeofenceState()
    let fire = GeofenceDecider.exitedOuter(entry: entry, state: &state, now: Date())
    states[entry.id] = state
    saveStates()
    pendingIds.remove(entry.id)
    if fire { notify(entry, reason: "left area") }
    if pendingIds.isEmpty { stopPrecise() }
  }

  func locationManager(
    _ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion
  ) {
    guard let entry = entry(for: region) else { return }
    switch state {
    case .inside:
      log("inside \(short(entry))")
      // E.g. a reminder added at the place: check how close we are.
      startPrecise(for: [entry.id])
    case .outside:
      var s = states[entry.id] ?? GeofenceState()
      if entry.arrive && !s.armed {
        s.armed = true
        states[entry.id] = s
        saveStates()
      }
    default:
      break
    }
  }

  func locationManager(
    _ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error
  ) {
    log("monitoring failed \(region?.identifier ?? "?"): \(error.localizedDescription)")
  }

  // MARK: - Precise updates

  private func startPrecise(for ids: [String]) {
    guard authorization() == .authorizedAlways || authorization() == .authorizedWhenInUse else {
      log("no permission for precise updates")
      return
    }
    pendingIds.formUnion(ids)
    preciseTimer?.invalidate()
    preciseTimer = Timer.scheduledTimer(withTimeInterval: Self.preciseTimeout, repeats: false) {
      [weak self] _ in
      self?.log("precise timeout")
      self?.pendingIds.removeAll()
      self?.stopPrecise()
    }
    if preciseActive { return }
    preciseActive = true
    if backgroundTask == .invalid {
      backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "taskwise.location") {
        [weak self] in self?.stopPrecise()
      }
    }
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = kCLDistanceFilterNone
    if authorization() == .authorizedAlways {
      manager.allowsBackgroundLocationUpdates = true
      manager.showsBackgroundLocationIndicator = false
    }
    manager.startUpdatingLocation()
    log("precise on")
  }

  private func stopPrecise() {
    preciseTimer?.invalidate()
    preciseTimer = nil
    if preciseActive {
      manager.stopUpdatingLocation()
      manager.allowsBackgroundLocationUpdates = false
      preciseActive = false
      log("precise off")
    }
    if backgroundTask != .invalid {
      UIApplication.shared.endBackgroundTask(backgroundTask)
      backgroundTask = .invalid
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let fix = locations.last else { return }
    lastFix = fix
    if !locationCallbacks.isEmpty {
      let callbacks = locationCallbacks
      locationCallbacks.removeAll()
      callbacks.forEach { $0(Self.describe(fix)) }
    }
    if !preciseActive {
      // A significant location change (more than 20 reminders): re-pick
      // the nearest regions.
      if entries.count > Self.regionLimit { refreshRegions() }
      return
    }
    let now = Date()
    for id in pendingIds {
      guard let entry = entries.first(where: { $0.id == id }) else {
        pendingIds.remove(id)
        continue
      }
      let distance = fix.distance(
        from: CLLocation(latitude: entry.latitude, longitude: entry.longitude))
      var state = states[id] ?? GeofenceState()
      let verdict = GeofenceDecider.evaluate(
        entry: entry, state: &state, distance: distance,
        accuracy: fix.horizontalAccuracy, now: now)
      states[id] = state
      switch verdict {
      case .fire:
        log("\(short(entry)) at \(Int(distance)) m ±\(Int(fix.horizontalAccuracy))")
        notify(entry, reason: entry.arrive ? "arrived" : "left")
        pendingIds.remove(id)
      case .settled:
        pendingIds.remove(id)
      case .pending:
        break
      }
    }
    saveStates()
    if pendingIds.isEmpty { stopPrecise() }
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
      guard let circle = region as? CLCircularRegion,
        region.identifier.hasPrefix(Self.regionPrefix)
      else { return nil }
      let id = String(region.identifier.dropFirst(Self.regionPrefix.count))
      let state = states[id]
      let entry = entries.first { $0.id == id }
      var label = "outside"
      if let entry = entry, let state = state {
        label = entry.arrive
          ? (state.armed ? "armed" : "waiting to leave")
          : (state.wasInside ? "inside" : "outside")
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
      "preciseActive": preciseActive,
    ]
    if let fix = lastFix ?? manager.location {
      result["lastFix"] = Self.describe(fix)
    }
    return result
  }

  private func log(_ text: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "MM-dd HH:mm:ss"
    events.append("\(formatter.string(from: Date())) \(text)")
    if events.count > Self.eventLimit {
      events.removeFirst(events.count - Self.eventLimit)
    }
    defaults.set(events, forKey: Keys.events)
  }

  private func short(_ entry: GeofenceEntry) -> String {
    "\(entry.arrive ? "arrive" : "leave") \"\(entry.title)\""
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
    guard let url = entriesURL, let data = try? JSONEncoder().encode(entries) else { return }
    // Readable after the first unlock, so a relaunch while locked works.
    try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }

  private func loadStates() -> [String: GeofenceState] {
    guard let data = defaults.data(forKey: Keys.states) else { return [:] }
    return (try? JSONDecoder().decode([String: GeofenceState].self, from: data)) ?? [:]
  }

  private func saveStates() {
    if let data = try? JSONEncoder().encode(states) {
      defaults.set(data, forKey: Keys.states)
    }
  }
}
