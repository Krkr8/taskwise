import Foundation

// Pure decision logic for location reminders (SPEC.md section 3.3), kept
// apart from Core Location so RunnerTests can check it on a simulator.
// LocationReminderManager feeds it region events and precise fixes.

/// A location reminder as Dart hands it over (see location_platform.dart).
struct GeofenceEntry: Codable, Equatable {
  let id: String
  let latitude: Double
  let longitude: Double
  /// The reminder's radius in metres (30-500).
  let radius: Double
  /// True for "on arrive", false for "on leave".
  let arrive: Bool
  let title: String
  let body: String
  /// Notification payload, so taps, Done and Snooze go through Dart.
  let payload: String
  let notificationId: Int
}

/// What the phone remembers about one reminder between events.
struct GeofenceState: Codable, Equatable {
  /// Arrive: the phone was seen outside the radius since the last
  /// reminder, so arriving again counts. Starts false, so a reminder made
  /// while already at the place doesn't fire right away.
  var armed = false
  /// Leave: the phone was seen inside the radius, so leaving counts.
  var wasInside = false
  /// When this reminder last fired.
  var lastFired: Date?
}

/// What a precise fix says about one reminder.
enum GeofenceVerdict: Equatable {
  /// Show the notification.
  case fire
  /// Nothing to do yet; keep checking while precise updates run.
  case pending
  /// Settled for now (e.g. inside but already reminded); no need to keep
  /// precise updates running for this reminder.
  case settled
}

/// Why precise updates run for a reminder.
enum GeofenceCheck: String, Codable, Equatable {
  /// The phone came near the place (entered the outer region, or was
  /// inside it when monitoring started): watch it come within the radius.
  case approach
  /// iOS said the phone left the outer region. iOS sometimes reports a
  /// wrong exit (cell or Wi-Fi data jumps), so a fix confirms it first.
  case confirmExit
}

enum GeofenceDecider {
  /// The same reminder doesn't fire again within this time.
  static let debounce: TimeInterval = 30 * 60

  /// A fix is good enough to say "inside" when it's at least this accurate
  /// (or as accurate as the radius, for big radii).
  static let minAccuracy: Double = 25

  /// Least distance beyond the radius before "outside" counts.
  static let leaveMargin: Double = 20

  /// Rougher fixes never count as "outside" (indoor Wi-Fi fixes can be
  /// far off). Outdoors, walking or driving away, fixes are much better.
  static let maxOutsideAccuracy: Double = 50

  /// iOS geofences are unreliable below ~100-150 m, so the monitored
  /// (outer) region is bigger than the reminder's radius. Leave reminders
  /// use a smaller one so they fire sooner after leaving.
  static func outerRadius(for entry: GeofenceEntry, maximum: Double) -> Double {
    let wanted = entry.arrive ? max(150, entry.radius + 100) : max(100, entry.radius + 70)
    return min(wanted, maximum)
  }

  /// The small fallback region used after the phone lingered near the
  /// place without coming within the radius (see GeofenceEngine).
  static func nearRadius(for entry: GeofenceEntry, maximum: Double) -> Double {
    min(max(50, entry.radius + 20), maximum)
  }

  /// Clearly inside the reminder's radius.
  static func isInside(radius: Double, distance: Double, accuracy: Double) -> Bool {
    accuracy >= 0 && accuracy <= max(radius, minAccuracy) && distance <= radius
  }

  /// Clearly outside the reminder's radius. Indoor fixes can be off by
  /// more than their accuracy, so the margin is twice the accuracy and
  /// rough fixes don't count: one bad fix at home must not count as having
  /// left.
  static func isOutside(radius: Double, distance: Double, accuracy: Double) -> Bool {
    accuracy >= 0 && accuracy <= maxOutsideAccuracy
      && distance > radius + max(2 * accuracy, leaveMargin)
  }

  static func debounced(_ state: GeofenceState, now: Date) -> Bool {
    guard let last = state.lastFired else { return false }
    return now.timeIntervalSince(last) < debounce
  }

  /// Feeds one precise fix ([distance] from the place, [accuracy] of the
  /// fix, both in metres) for a reminder being checked for [check].
  /// Updates [state] and says what to do.
  static func evaluate(
    entry: GeofenceEntry,
    check: GeofenceCheck = .approach,
    state: inout GeofenceState,
    distance: Double,
    accuracy: Double,
    now: Date
  ) -> GeofenceVerdict {
    let inside = isInside(radius: entry.radius, distance: distance, accuracy: accuracy)
    let outside = isOutside(radius: entry.radius, distance: distance, accuracy: accuracy)
    switch (check, entry.arrive) {
    case (.approach, true):
      if outside {
        state.armed = true
        return .pending
      }
      guard inside else { return .pending }
      return fireArrive(&state, now: now) ? .fire : .settled
    case (.approach, false):
      if inside {
        state.wasInside = true
        return .settled
      }
      guard outside else { return .pending }
      // Left during the check: fire. Not in the place yet (e.g. walking
      // towards it): keep watching.
      return fireLeave(&state, now: now) ? .fire : .pending
    case (.confirmExit, true):
      if outside { state.armed = true }
      return inside || outside ? .settled : .pending
    case (.confirmExit, false):
      if inside {
        // A wrong exit: still here.
        state.wasInside = true
        return .settled
      }
      guard outside else { return .pending }
      return fireLeave(&state, now: now) ? .fire : .settled
    }
  }

  /// No fix settled a confirmExit check in time: believe iOS. True when
  /// the reminder fires.
  static func exitUnconfirmed(entry: GeofenceEntry, state: inout GeofenceState, now: Date) -> Bool {
    if entry.arrive {
      state.armed = true
      return false
    }
    return fireLeave(&state, now: now)
  }

  private static func fireArrive(_ state: inout GeofenceState, now: Date) -> Bool {
    guard state.armed, !debounced(state, now: now) else { return false }
    state.armed = false
    state.lastFired = now
    return true
  }

  private static func fireLeave(_ state: inout GeofenceState, now: Date) -> Bool {
    guard state.wasInside else { return false }
    state.wasInside = false
    guard !debounced(state, now: now) else { return false }
    state.lastFired = now
    return true
  }

  /// At most [limit] reminders can be monitored (iOS allows 20 regions per
  /// app): the nearest to [from], or the first ones when the position is
  /// unknown.
  static func nearest(
    _ entries: [GeofenceEntry],
    limit: Int,
    from: (latitude: Double, longitude: Double)?
  ) -> [GeofenceEntry] {
    guard entries.count > limit else { return entries }
    guard let from = from else { return Array(entries.prefix(limit)) }
    return Array(
      entries.sorted {
        distance(from.latitude, from.longitude, $0.latitude, $0.longitude)
          < distance(from.latitude, from.longitude, $1.latitude, $1.longitude)
      }.prefix(limit)
    )
  }

  /// Great-circle distance in metres (haversine), matching the Dart
  /// `distanceMeters` in shared/.
  static func distance(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
    let earthRadius = 6_371_008.8
    func rad(_ deg: Double) -> Double { deg * .pi / 180 }
    let dLat = rad(lat2 - lat1)
    let dLon = rad(lon2 - lon1)
    let a = pow(sin(dLat / 2), 2) + cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLon / 2), 2)
    return 2 * earthRadius * asin(min(1, sqrt(a)))
  }
}

// MARK: - Engine

/// What GeofenceEngine asks the platform to do. LocationReminderManager
/// implements it with Core Location; the walk simulator
/// (tools/geofence_sim) with simulated GPS.
protocol GeofenceHost: AnyObject {
  /// Starts precise location updates; false when that isn't allowed.
  func startPreciseUpdates() -> Bool
  func stopPreciseUpdates()
  /// Starts or stops the small "near" region of a reminder.
  func watchNear(_ entry: GeofenceEntry)
  func stopWatchingNear(id: String)
  /// Shows the reminder's notification.
  func show(_ entry: GeofenceEntry, reason: String)
  func log(_ text: String)
}

/// The location-reminder state machine: region events and precise fixes
/// in, notifications out. Pure Foundation, so the walk simulator runs the
/// exact code the iPhone runs.
///
/// - Entering a reminder's outer region (or being inside it when monitoring
///   starts) runs precise updates for up to 5 minutes (an approach check).
/// - Leaving the outer region is confirmed with precise fixes first, since
///   iOS sometimes reports wrong exits; without any fix in 5 minutes, iOS
///   is believed.
/// - When an approach check runs out while the phone is near but not yet
///   within the radius (e.g. chatting outside the house), a small "near"
///   region is watched so that walking in starts a new check.
final class GeofenceEngine {
  /// Longest precise-updates session after a region event.
  static let preciseTimeout: TimeInterval = 5 * 60

  private(set) var entries: [GeofenceEntry]
  private(set) var states: [String: GeofenceState]
  /// Reminders still undecided in the running precise session.
  private(set) var pending: [String: GeofenceCheck] = [:]
  /// Reminders whose near region is watched.
  private(set) var nearIds = Set<String>()
  /// When the running precise session ends; nil when none runs.
  private(set) var preciseUntil: Date?
  weak var host: GeofenceHost?

  var preciseActive: Bool { preciseUntil != nil }

  init(
    entries: [GeofenceEntry] = [], states: [String: GeofenceState] = [:],
    nearIds: Set<String> = []
  ) {
    self.entries = entries
    let ids = Set(entries.map(\.id))
    self.states = states.filter { ids.contains($0.key) }
    self.nearIds = nearIds.intersection(ids)
  }

  func entry(id: String) -> GeofenceEntry? { entries.first { $0.id == id } }

  /// Replaces the reminders; true when they changed. State of reminders
  /// that are gone is forgotten.
  @discardableResult
  func setEntries(_ newEntries: [GeofenceEntry]) -> Bool {
    let changed = newEntries != entries
    entries = newEntries
    let ids = Set(newEntries.map(\.id))
    states = states.filter { ids.contains($0.key) }
    pending = pending.filter { ids.contains($0.key) }
    for id in nearIds where !ids.contains(id) { stopNear(id) }
    if preciseActive && pending.isEmpty { stopPrecise() }
    return changed
  }

  /// The phone entered a reminder's outer region.
  func entered(id: String, now: Date) {
    guard let entry = entry(id: id) else { return }
    host?.log("enter \(Self.short(entry))")
    startPrecise([id: .approach], now: now)
  }

  /// The phone entered a reminder's near region.
  func enteredNear(id: String, now: Date) {
    guard let entry = entry(id: id) else { return }
    host?.log("near \(Self.short(entry))")
    startPrecise([id: .approach], now: now)
  }

  /// The phone left a reminder's outer region.
  func exited(id: String, now: Date) {
    guard let entry = entry(id: id) else { return }
    host?.log("exit \(Self.short(entry))")
    stopNear(id)
    startPrecise([id: .confirmExit], now: now) {
      // No precise updates allowed: believe iOS.
      self.exitUnconfirmed(entry, now: now)
    }
  }

  /// iOS answered "where am I" for a region (after monitoring starts).
  func determined(id: String, inside: Bool, now: Date) {
    guard let entry = entry(id: id) else { return }
    if inside {
      host?.log("inside \(Self.short(entry))")
      // E.g. a reminder added at the place: check how close we are.
      startPrecise([id: .approach], now: now)
    } else if entry.arrive {
      update(id) { $0.armed = true }
    }
  }

  /// A position fix while precise updates run.
  func fix(latitude: Double, longitude: Double, accuracy: Double, now: Date) {
    guard preciseActive else { return }
    if checkTimeout(now: now) { return }
    for (id, check) in pending {
      guard let entry = entry(id: id) else {
        pending[id] = nil
        continue
      }
      let distance = GeofenceDecider.distance(
        latitude, longitude, entry.latitude, entry.longitude)
      var verdict = GeofenceVerdict.pending
      update(id) {
        verdict = GeofenceDecider.evaluate(
          entry: entry, check: check, state: &$0, distance: distance, accuracy: accuracy,
          now: now)
      }
      switch verdict {
      case .fire:
        host?.log("\(Self.short(entry)) at \(Int(distance)) m ±\(Int(accuracy))")
        host?.show(entry, reason: entry.arrive ? "arrived" : "left")
        pending[id] = nil
      case .settled:
        if check == .confirmExit && !entry.arrive && states[id]?.wasInside == true {
          host?.log("wrong exit \(Self.short(entry)) (\(Int(distance)) m ±\(Int(accuracy)))")
        }
        pending[id] = nil
      case .pending:
        continue
      }
      // Within the radius (or reminded): the near region isn't needed.
      stopNear(id)
    }
    if pending.isEmpty { stopPrecise() }
  }

  /// Ends the precise session once its time is up; true when it did.
  @discardableResult
  func checkTimeout(now: Date) -> Bool {
    guard let until = preciseUntil, now >= until else { return false }
    host?.log("precise timeout")
    let undecided = pending
    pending.removeAll()
    stopPrecise()
    for (id, check) in undecided {
      guard let entry = entry(id: id) else { continue }
      switch check {
      case .confirmExit:
        exitUnconfirmed(entry, now: now)
      case .approach:
        // Still near but not within the radius: watch a smaller area so
        // walking in starts a new check.
        if !nearIds.contains(id) {
          nearIds.insert(id)
          host?.watchNear(entry)
        }
      }
    }
    return true
  }

  private func exitUnconfirmed(_ entry: GeofenceEntry, now: Date) {
    var fire = false
    update(entry.id) {
      fire = GeofenceDecider.exitUnconfirmed(entry: entry, state: &$0, now: now)
    }
    if fire { host?.show(entry, reason: "left area") }
  }

  private func startPrecise(
    _ checks: [String: GeofenceCheck], now: Date, otherwise: (() -> Void)? = nil
  ) {
    if !preciseActive {
      guard host?.startPreciseUpdates() == true else {
        host?.log("no permission for precise updates")
        otherwise?()
        return
      }
      preciseUntil = now.addingTimeInterval(Self.preciseTimeout)
      host?.log("precise on")
    }
    pending.merge(checks) { _, new in new }
    preciseUntil = now.addingTimeInterval(Self.preciseTimeout)
  }

  private func stopPrecise() {
    guard preciseActive else { return }
    preciseUntil = nil
    pending.removeAll()
    host?.stopPreciseUpdates()
    host?.log("precise off")
  }

  private func stopNear(_ id: String) {
    guard nearIds.remove(id) != nil else { return }
    host?.stopWatchingNear(id: id)
  }

  private func update(_ id: String, _ change: (inout GeofenceState) -> Void) {
    var state = states[id] ?? GeofenceState()
    change(&state)
    states[id] = state
  }

  static func short(_ entry: GeofenceEntry) -> String {
    "\(entry.arrive ? "arrive" : "leave") \"\(entry.title)\""
  }
}
