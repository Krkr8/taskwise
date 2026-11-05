import XCTest

@testable import Runner

/// Checks the location-reminder decisions (GeofenceDecider.swift). Run by
/// the "iOS unit tests" CI job on a simulator.
class GeofenceDeciderTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_800_000_000)

  private func entry(arrive: Bool, radius: Double = 30) -> GeofenceEntry {
    GeofenceEntry(
      id: "r1", latitude: 33.3, longitude: 44.4, radius: radius, arrive: arrive,
      title: "Buy bread", body: "You're at Home", payload: "{}", notificationId: 1)
  }

  private func feed(
    _ entry: GeofenceEntry, _ state: inout GeofenceState, distance: Double,
    accuracy: Double = 8, at time: Date? = nil
  ) -> GeofenceVerdict {
    GeofenceDecider.evaluate(
      entry: entry, state: &state, distance: distance, accuracy: accuracy, now: time ?? now)
  }

  func testArriveFiresInsideTheRadiusAfterBeingOutside() {
    let e = entry(arrive: true)
    var s = GeofenceState()
    XCTAssertEqual(feed(e, &s, distance: 120), .pending)
    XCTAssertTrue(s.armed)
    XCTAssertEqual(feed(e, &s, distance: 45), .pending)
    XCTAssertEqual(feed(e, &s, distance: 25), .fire)
    XCTAssertEqual(s.lastFired, now)
    // Staying there doesn't fire again.
    XCTAssertEqual(feed(e, &s, distance: 10), .settled)
  }

  func testArriveNeedsAnAccurateFix() {
    let e = entry(arrive: true)
    var s = GeofenceState(armed: true)
    XCTAssertEqual(feed(e, &s, distance: 20, accuracy: 65), .pending)
    XCTAssertEqual(feed(e, &s, distance: 20, accuracy: 12), .fire)
  }

  func testArriveDoesNotFireWhenAddedAtThePlace() {
    let e = entry(arrive: true)
    var s = GeofenceState()
    XCTAssertEqual(feed(e, &s, distance: 5), .settled)
  }

  func testArriveNeedsALeaveAndThirtyMinutesBetweenReminders() {
    let e = entry(arrive: true)
    var s = GeofenceState(armed: true)
    XCTAssertEqual(feed(e, &s, distance: 10), .fire)
    // Out and back in after 10 minutes: too soon.
    let soon = now.addingTimeInterval(10 * 60)
    XCTAssertEqual(feed(e, &s, distance: 200, at: soon), .pending)
    XCTAssertEqual(feed(e, &s, distance: 10, at: soon), .settled)
    // After 40 minutes, a new arrival counts.
    let later = now.addingTimeInterval(40 * 60)
    XCTAssertEqual(feed(e, &s, distance: 200, at: later), .pending)
    XCTAssertEqual(feed(e, &s, distance: 10, at: later), .fire)
  }

  func testLeaveFiresWhenClearlyOutsideAfterBeingInside() {
    let e = entry(arrive: false)
    var s = GeofenceState()
    XCTAssertEqual(feed(e, &s, distance: 70), .pending)
    XCTAssertEqual(feed(e, &s, distance: 10), .settled)
    XCTAssertTrue(s.wasInside)
    // Just past the radius isn't "clearly outside" yet.
    XCTAssertEqual(feed(e, &s, distance: 40), .pending)
    XCTAssertEqual(feed(e, &s, distance: 60), .fire)
    XCTAssertFalse(s.wasInside)
  }

  func testOneRoughFixAtHomeDoesNotCountAsOutside() {
    let e = entry(arrive: true)
    var s = GeofenceState()
    // 145 m off with ±56: an indoor Wi-Fi jump, not a walk.
    XCTAssertEqual(feed(e, &s, distance: 145, accuracy: 56), .pending)
    XCTAssertFalse(s.armed)
    // 60 m off with ±25 isn't clearly outside either (needs > 30 + 2×25).
    XCTAssertEqual(feed(e, &s, distance: 60, accuracy: 25), .pending)
    XCTAssertFalse(s.armed)
    XCTAssertEqual(feed(e, &s, distance: 85, accuracy: 25), .pending)
    XCTAssertTrue(s.armed)
  }

  func testAnExitIsConfirmedWithAFix() {
    let leave = entry(arrive: false)
    var s = GeofenceState(wasInside: true)
    // A wrong exit: the fix says we're still here.
    XCTAssertEqual(
      GeofenceDecider.evaluate(
        entry: leave, check: .confirmExit, state: &s, distance: 12, accuracy: 15, now: now),
      .settled)
    XCTAssertTrue(s.wasInside)
    // A real one.
    XCTAssertEqual(
      GeofenceDecider.evaluate(
        entry: leave, check: .confirmExit, state: &s, distance: 160, accuracy: 10, now: now),
      .fire)
    XCTAssertFalse(s.wasInside)
    // Arrive reminders are armed by a confirmed exit, without firing.
    let arrive = entry(arrive: true)
    var a = GeofenceState()
    XCTAssertEqual(
      GeofenceDecider.evaluate(
        entry: arrive, check: .confirmExit, state: &a, distance: 160, accuracy: 10, now: now),
      .settled)
    XCTAssertTrue(a.armed)
  }

  func testAnUnconfirmedExitIsBelieved() {
    var s = GeofenceState(wasInside: true)
    XCTAssertTrue(GeofenceDecider.exitUnconfirmed(entry: entry(arrive: false), state: &s, now: now))
    XCTAssertFalse(s.wasInside)
    // Never inside: no reminder.
    XCTAssertFalse(GeofenceDecider.exitUnconfirmed(entry: entry(arrive: false), state: &s, now: now))
  }

  func testOuterRadius() {
    XCTAssertEqual(GeofenceDecider.outerRadius(for: entry(arrive: true), maximum: 1000), 150)
    XCTAssertEqual(
      GeofenceDecider.outerRadius(for: entry(arrive: true, radius: 300), maximum: 1000), 400)
    XCTAssertEqual(GeofenceDecider.outerRadius(for: entry(arrive: false), maximum: 1000), 100)
    XCTAssertEqual(
      GeofenceDecider.outerRadius(for: entry(arrive: true, radius: 500), maximum: 200), 200)
  }

  func testNearestKeepsTheClosestRegions() {
    let far = GeofenceEntry(
      id: "far", latitude: 36.19, longitude: 44.01, radius: 30, arrive: true, title: "",
      body: "", payload: "", notificationId: 2)
    let near = entry(arrive: true)
    let picked = GeofenceDecider.nearest([far, near], limit: 1, from: (33.3, 44.4))
    XCTAssertEqual(picked.map(\.id), ["r1"])
    XCTAssertEqual(GeofenceDecider.nearest([far, near], limit: 5, from: nil).count, 2)
  }

  func testNearRadius() {
    XCTAssertEqual(GeofenceDecider.nearRadius(for: entry(arrive: true), maximum: 1000), 50)
    XCTAssertEqual(
      GeofenceDecider.nearRadius(for: entry(arrive: true, radius: 100), maximum: 1000), 120)
  }

  func testDistanceMatchesDart() {
    XCTAssertEqual(GeofenceDecider.distance(33.3, 44.4, 33.301, 44.4), 111.2, accuracy: 0.5)
  }
}

/// Checks GeofenceEngine's flow with a fake platform. The walk simulator
/// (tools/geofence_sim) runs many more scenarios with noisy GPS.
class GeofenceEngineTests: XCTestCase, GeofenceHost {
  private var t0 = Date(timeIntervalSince1970: 1_800_000_000)
  private var precise = false
  private var shown: [String] = []
  private var near: [String] = []

  func startPreciseUpdates() -> Bool {
    precise = true
    return true
  }
  func stopPreciseUpdates() { precise = false }
  func watchNear(_ entry: GeofenceEntry) { near.append(entry.id) }
  func stopWatchingNear(id: String) { near.removeAll { $0 == id } }
  func show(_ entry: GeofenceEntry, reason: String) { shown.append(entry.id) }
  func log(_ text: String) {}

  private let home = (lat: 33.3, lon: 44.4)
  private func entry(_ id: String, arrive: Bool) -> GeofenceEntry {
    GeofenceEntry(
      id: id, latitude: home.lat, longitude: home.lon, radius: 30, arrive: arrive,
      title: id, body: "", payload: "{}", notificationId: 1)
  }

  private func engine() -> GeofenceEngine {
    let e = GeofenceEngine()
    e.host = self
    e.setEntries([entry("a", arrive: true), entry("l", arrive: false)])
    return e
  }

  /// A fix [north] metres north of home.
  private func fix(_ e: GeofenceEngine, north: Double, accuracy: Double = 8, at s: Double) {
    e.fix(
      latitude: home.lat + north / 111_195, longitude: home.lon, accuracy: accuracy,
      now: t0.addingTimeInterval(s))
  }

  func testMadeAtHomeThenLeaveAndComeBack() {
    let e = engine()
    e.determined(id: "a", inside: true, now: t0)
    e.determined(id: "l", inside: true, now: t0)
    XCTAssertTrue(precise)
    fix(e, north: 5, at: 1)
    XCTAssertFalse(precise)  // both settled at home
    XCTAssertEqual(shown, [])

    e.exited(id: "l", now: t0.addingTimeInterval(600))
    e.exited(id: "a", now: t0.addingTimeInterval(610))
    XCTAssertTrue(precise)
    fix(e, north: 200, at: 611)
    XCTAssertEqual(shown, ["l"])
    XCTAssertFalse(precise)

    e.entered(id: "a", now: t0.addingTimeInterval(3000))
    e.entered(id: "l", now: t0.addingTimeInterval(3010))
    fix(e, north: 80, at: 3011)
    fix(e, north: 10, at: 3060)
    XCTAssertEqual(shown, ["l", "a"])
    XCTAssertFalse(precise)
  }

  func testAWrongExitAtHomeShowsNothing() {
    let e = engine()
    e.determined(id: "a", inside: true, now: t0)
    e.determined(id: "l", inside: true, now: t0)
    fix(e, north: 5, at: 1)
    e.exited(id: "a", now: t0.addingTimeInterval(600))
    e.exited(id: "l", now: t0.addingTimeInterval(600))
    fix(e, north: 140, accuracy: 60, at: 601)  // rough: ignored
    fix(e, north: 8, accuracy: 20, at: 602)
    XCTAssertFalse(precise)
    e.entered(id: "a", now: t0.addingTimeInterval(700))
    e.entered(id: "l", now: t0.addingTimeInterval(700))
    fix(e, north: 8, accuracy: 20, at: 701)
    XCTAssertEqual(shown, [])
  }

  func testLingeringNearbyWatchesTheNearArea() {
    let e = engine()
    e.determined(id: "a", inside: false, now: t0)
    e.entered(id: "a", now: t0.addingTimeInterval(10))
    fix(e, north: 60, at: 11)
    // Five minutes at 60 m: the check ends, the near area is watched.
    e.checkTimeout(now: t0.addingTimeInterval(10 + GeofenceEngine.preciseTimeout))
    XCTAssertFalse(precise)
    XCTAssertEqual(near, ["a"])
    e.enteredNear(id: "a", now: t0.addingTimeInterval(900))
    fix(e, north: 5, at: 901)
    XCTAssertEqual(shown, ["a"])
    XCTAssertEqual(near, [])
  }

  func testNoFixAfterAnExitBelievesIOS() {
    let e = engine()
    e.determined(id: "l", inside: true, now: t0)
    fix(e, north: 5, at: 1)
    e.exited(id: "l", now: t0.addingTimeInterval(600))
    e.checkTimeout(now: t0.addingTimeInterval(600 + GeofenceEngine.preciseTimeout))
    XCTAssertEqual(shown, ["l"])
  }
}
