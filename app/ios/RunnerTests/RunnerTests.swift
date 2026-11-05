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
    GeofenceDecider.enteredOuter(entry: e, state: &s)
    XCTAssertEqual(feed(e, &s, distance: 120), .pending)
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

  func testLeaveUsesTheOuterExitAsBackup() {
    let e = entry(arrive: false)
    var s = GeofenceState(wasInside: true)
    XCTAssertTrue(GeofenceDecider.exitedOuter(entry: e, state: &s, now: now))
    XCTAssertFalse(s.wasInside)
    // Never inside: no reminder.
    XCTAssertFalse(GeofenceDecider.exitedOuter(entry: e, state: &s, now: now))
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

  func testDistanceMatchesDart() {
    XCTAssertEqual(GeofenceDecider.distance(33.3, 44.4, 33.301, 44.4), 111.2, accuracy: 0.5)
  }
}
