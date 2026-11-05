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

enum GeofenceDecider {
  /// The same reminder doesn't fire again within this time.
  static let debounce: TimeInterval = 30 * 60

  /// A fix is good enough to say "inside" when it's at least this accurate
  /// (or as accurate as the radius, for big radii).
  static let minAccuracy: Double = 25

  /// Extra distance beyond the radius before "outside" counts.
  static let leaveMargin: Double = 20

  /// iOS geofences are unreliable below ~100-150 m, so the monitored
  /// (outer) region is bigger than the reminder's radius. Leave reminders
  /// use a smaller one: their exit is the trigger when precise updates
  /// aren't running.
  static func outerRadius(for entry: GeofenceEntry, maximum: Double) -> Double {
    let wanted = entry.arrive ? max(150, entry.radius + 100) : max(100, entry.radius + 70)
    return min(wanted, maximum)
  }

  /// Clearly inside the reminder's radius.
  static func isInside(radius: Double, distance: Double, accuracy: Double) -> Bool {
    accuracy >= 0 && accuracy <= max(radius, minAccuracy) && distance <= radius
  }

  /// Clearly outside the reminder's radius.
  static func isOutside(radius: Double, distance: Double, accuracy: Double) -> Bool {
    accuracy >= 0 && distance > radius + max(accuracy, leaveMargin)
  }

  static func debounced(_ state: GeofenceState, now: Date) -> Bool {
    guard let last = state.lastFired else { return false }
    return now.timeIntervalSince(last) < debounce
  }

  /// Feeds one precise fix ([distance] from the place, [accuracy] of the
  /// fix, both in metres). Updates [state] and says what to do.
  static func evaluate(
    entry: GeofenceEntry,
    state: inout GeofenceState,
    distance: Double,
    accuracy: Double,
    now: Date
  ) -> GeofenceVerdict {
    let inside = isInside(radius: entry.radius, distance: distance, accuracy: accuracy)
    let outside = isOutside(radius: entry.radius, distance: distance, accuracy: accuracy)
    if entry.arrive {
      if outside {
        state.armed = true
        return .pending
      }
      guard inside else { return .pending }
      if state.armed && !debounced(state, now: now) {
        state.armed = false
        state.lastFired = now
        return .fire
      }
      return .settled
    } else {
      if inside {
        state.wasInside = true
        return .settled
      }
      guard outside else { return .pending }
      if state.wasInside && !debounced(state, now: now) {
        state.wasInside = false
        state.lastFired = now
        return .fire
      }
      // Not in the place yet (e.g. walking towards it): keep watching.
      return .pending
    }
  }

  /// The phone entered the outer region: it came from outside it, so it
  /// was outside the radius too. Precise updates follow.
  static func enteredOuter(entry: GeofenceEntry, state: inout GeofenceState) {
    if entry.arrive { state.armed = true }
  }

  /// The phone left the outer region. For a leave reminder whose place the
  /// phone was in, this is the backup trigger.
  static func exitedOuter(
    entry: GeofenceEntry,
    state: inout GeofenceState,
    now: Date
  ) -> Bool {
    if entry.arrive {
      state.armed = true
      return false
    }
    defer { state.wasInside = false }
    guard state.wasInside, !debounced(state, now: now) else { return false }
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
