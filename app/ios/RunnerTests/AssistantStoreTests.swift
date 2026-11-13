import Foundation
import XCTest

@testable import Runner

/// Checks Siri's inbox and snapshot (AssistantStore.swift). Runs on the iOS
/// simulator in CI and on Linux with tools/geofence_sim/run.sh test.
class AssistantStoreTests: XCTestCase {
  private var directory: URL!
  private var store: AssistantStore!
  /// 2026-11-12 09:30:00 UTC.
  private let now = Date(timeIntervalSince1970: 1_794_475_800)
  private var utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }()

  override func setUp() {
    super.setUp()
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("assistant-\(UUID().uuidString)")
    store = AssistantStore(directory: directory)
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: directory)
    super.tearDown()
  }

  func testAddKeepsEntriesInOrder() throws {
    let milk = try store.add(title: "  Buy milk ", now: now)
    let mum = try store.add(
      title: "Call mum", due: AssistantDue(date: "2026-11-13", minutes: 17 * 60), now: now)
    XCTAssertEqual(milk.title, "Buy milk")
    XCTAssertEqual(milk.createdAt, "2026-11-12T09:30:00Z")
    XCTAssertNil(milk.dueDate)
    XCTAssertEqual(store.inbox().map(\.id), [milk.id, mum.id])
    XCTAssertEqual(store.inbox()[1].dueTimeMinutes, 17 * 60)
    // A second store on the same folder (the app after a relaunch) sees them.
    XCTAssertEqual(AssistantStore(directory: directory).inbox().count, 2)
  }

  func testEmptyTitleIsRefused() {
    XCTAssertThrowsError(try store.add(title: "  \n ", now: now)) { error in
      XCTAssertEqual(error as? AssistantStoreError, .emptyTitle)
    }
    XCTAssertTrue(store.inbox().isEmpty)
  }

  func testInboxJsonMatchesTheAppsShape() throws {
    XCTAssertEqual(store.inboxJSON(), "[]")
    try store.add(title: "Bins", due: AssistantDue(date: "2026-11-14", minutes: nil), now: now)
    let json = store.inboxJSON()
    let list = try XCTUnwrap(
      try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]])
    XCTAssertEqual(list.count, 1)
    XCTAssertEqual(list[0]["title"] as? String, "Bins")
    XCTAssertEqual(list[0]["dueDate"] as? String, "2026-11-14")
    XCTAssertEqual(list[0]["createdAt"] as? String, "2026-11-12T09:30:00Z")
    // Missing values are left out, not null.
    XCTAssertNil(list[0]["dueTimeMinutes"])
    XCTAssertNil(list[0]["notes"])
  }

  func testRemoveKeepsEntriesAddedSinceTheAppRead() throws {
    let first = try store.add(title: "One", now: now)
    let second = try store.add(title: "Two", now: now)
    store.remove(ids: [first.id, "unknown"])
    XCTAssertEqual(store.inbox().map(\.id), [second.id])
  }

  func testSnapshotIsStoredOnlyWhenReadable() {
    XCTAssertFalse(store.setSnapshot(json: "not json"))
    XCTAssertNil(store.snapshot())
    XCTAssertTrue(
      store.setSnapshot(
        json: #"{"version":1,"tasks":[{"title":"Dentist","dueDate":"2026-11-12","dueTimeMinutes":600}]}"#
      ))
    XCTAssertEqual(store.snapshot()?.tasks.first?.dueTimeMinutes, 600)
  }

  func testAgendaUsesTodayAndAddsSirisNewTasks() throws {
    store.setSnapshot(
      json: """
        {"version":1,"tasks":[
          {"title":"Old bill","dueDate":"2026-11-10"},
          {"title":"Dentist","dueDate":"2026-11-12","dueTimeMinutes":600},
          {"title":"Bins","dueDate":"2026-11-12"},
          {"title":"Party","dueDate":"2026-11-15"}
        ]}
        """)
    try store.add(
      title: "Call mum", due: AssistantDue(date: "2026-11-12", minutes: 9 * 60), now: now)
    try store.add(title: "No date", now: now)
    // Already taken in by the app and in the snapshot: listed once.
    try store.add(title: "Bins", due: AssistantDue(date: "2026-11-12", minutes: nil), now: now)

    let agenda = store.agenda(today: now, calendar: utc)
    XCTAssertEqual(agenda.today, ["Bins", "Call mum", "Dentist"])
    XCTAssertEqual(agenda.overdue, ["Old bill"])

    // Three days later the same snapshot still answers correctly.
    let later = store.agenda(today: now.addingTimeInterval(3 * 86_400), calendar: utc)
    XCTAssertEqual(later.today, ["Party"])
    XCTAssertEqual(later.overdue, ["Old bill", "Bins", "Call mum", "Dentist"])
  }

  func testDueFromWhatSiriHeard() {
    func due(_ c: DateComponents) -> AssistantDue? { AssistantStore.due(from: c) }
    XCTAssertEqual(
      due(DateComponents(year: 2026, month: 11, day: 13)),
      AssistantDue(date: "2026-11-13", minutes: nil))
    XCTAssertEqual(
      due(DateComponents(year: 2026, month: 11, day: 13, hour: 17, minute: 30)),
      AssistantDue(date: "2026-11-13", minutes: 17 * 60 + 30))
    XCTAssertEqual(
      due(DateComponents(year: 2026, month: 11, day: 13, hour: 9)),
      AssistantDue(date: "2026-11-13", minutes: 9 * 60))
    // Midnight means "no time said".
    XCTAssertEqual(
      due(DateComponents(year: 2026, month: 11, day: 13, hour: 0, minute: 0)),
      AssistantDue(date: "2026-11-13", minutes: nil))
    XCTAssertNil(due(DateComponents(hour: 9)))
    XCTAssertNil(due(DateComponents(month: 11, day: 13)))
  }

  func testIsoDateFollowsTheCalendarsTimeZone() {
    var baghdad = Calendar(identifier: .gregorian)
    baghdad.timeZone = TimeZone(secondsFromGMT: 3 * 3600)!
    // 22:00 UTC on the 12th is already the 13th at UTC+3.
    let late = Date(timeIntervalSince1970: 1_794_520_800)
    XCTAssertEqual(AssistantStore.isoDate(late, calendar: utc), "2026-11-12")
    XCTAssertEqual(AssistantStore.isoDate(late, calendar: baghdad), "2026-11-13")
  }

  func testUuidV7() {
    let id = AssistantStore.uuidV7(now: now, random: { 0xff })
    XCTAssertEqual(id.count, 36)
    let parts = id.split(separator: "-").map(String.init)
    XCTAssertEqual(parts.map(\.count), [8, 4, 4, 4, 12])
    // The first 48 bits are the milliseconds.
    XCTAssertEqual(UInt64(parts[0] + parts[1], radix: 16), 1_794_475_800_000)
    XCTAssertEqual(parts[2].first, "7")
    XCTAssertEqual(parts[3].first, "b")  // 0xff & 0x3f | 0x80
    // Later ids sort after earlier ones.
    XCTAssertLessThan(id, AssistantStore.uuidV7(now: now.addingTimeInterval(1), random: { 0 }))
  }
}
