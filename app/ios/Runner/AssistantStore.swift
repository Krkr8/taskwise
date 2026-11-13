import Foundation

// Siri's side of Taskwise, without Apple-only frameworks so it also builds
// and is tested on Linux (tools/geofence_sim/run.sh test).
//
// - Siri adds tasks to an inbox file while Taskwise may be closed. The app
//   moves them into its database (app/lib/assistant/assistant_sync.dart),
//   so they sync like any other task.
// - The app writes a snapshot of what's due; Siri reads it to answer
//   "What's on my list".
//
// The JSON shapes are shared with shared/lib/src/logic/assistant.dart.

/// A task Siri added, waiting for the app.
struct AssistantInboxEntry: Codable, Equatable {
  /// A UUID v7, which becomes the task's id.
  var id: String
  var title: String
  var notes: String?
  /// "2026-11-12", or nil for no due date.
  var dueDate: String?
  /// Minutes after local midnight; nil means all-day (or no due date).
  var dueTimeMinutes: Int?
  /// UTC, ISO 8601 ("2026-11-12T09:30:00Z").
  var createdAt: String
}

/// One task in the app's snapshot.
struct AssistantSnapshotTask: Codable, Equatable {
  var title: String
  var dueDate: String
  var dueTimeMinutes: Int?
}

struct AssistantSnapshot: Codable, Equatable {
  var version: Int
  var tasks: [AssistantSnapshotTask]
}

/// What's due, for Siri to read out. Titles in schedule order.
struct AssistantAgenda: Equatable {
  var today: [String]
  var overdue: [String]
}

/// A due date as the app stores it: a calendar date and an optional time.
struct AssistantDue: Equatable {
  var date: String
  var minutes: Int?
}

enum AssistantStoreError: Error, Equatable {
  case emptyTitle
}

final class AssistantStore: @unchecked Sendable {
  /// The app's store, in Application Support (next to the database).
  static let shared = AssistantStore(
    directory: FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first ?? FileManager.default.temporaryDirectory)

  /// Posted after Siri adds a task, so a running app takes it in at once.
  static let inboxChanged = Notification.Name("TaskwiseAssistantInboxChanged")

  private let directory: URL
  /// Siri and the app's channel run on different threads of one process.
  private let lock = NSLock()

  init(directory: URL) {
    self.directory = directory
  }

  private var inboxURL: URL { directory.appendingPathComponent("assistant_inbox.json") }
  private var snapshotURL: URL { directory.appendingPathComponent("assistant_snapshot.json") }

  // MARK: Inbox

  /// Adds a task to the inbox and returns it.
  @discardableResult
  func add(title: String, due: AssistantDue? = nil, now: Date = Date()) throws
    -> AssistantInboxEntry
  {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw AssistantStoreError.emptyTitle }
    let entry = AssistantInboxEntry(
      id: Self.uuidV7(now: now),
      title: trimmed,
      notes: nil,
      dueDate: due?.date,
      dueTimeMinutes: due == nil ? nil : due?.minutes,
      createdAt: Self.isoTimestamp(now))
    try locked {
      var entries = readInboxUnlocked()
      entries.append(entry)
      try write(entries, to: inboxURL)
    }
    NotificationCenter.default.post(name: Self.inboxChanged, object: nil)
    return entry
  }

  /// The inbox's entries, oldest first.
  func inbox() -> [AssistantInboxEntry] {
    locked { readInboxUnlocked() }
  }

  /// The inbox as a JSON list, for the app.
  func inboxJSON() -> String {
    let entries = inbox()
    guard let data = try? Self.encoder.encode(entries) else { return "[]" }
    return String(decoding: data, as: UTF8.self)
  }

  /// Removes the entries the app has taken in. Entries Siri added since the
  /// app read the inbox stay.
  func remove(ids: [String]) {
    let gone = Set(ids)
    locked {
      let entries = readInboxUnlocked()
      let kept = entries.filter { !gone.contains($0.id) }
      if kept.count != entries.count { try? write(kept, to: inboxURL) }
    }
  }

  private func readInboxUnlocked() -> [AssistantInboxEntry] {
    guard let data = try? Data(contentsOf: inboxURL) else { return [] }
    return (try? JSONDecoder().decode([AssistantInboxEntry].self, from: data)) ?? []
  }

  // MARK: Snapshot

  /// Stores the app's snapshot (JSON). Returns false if it can't be read.
  @discardableResult
  func setSnapshot(json: String) -> Bool {
    let data = Data(json.utf8)
    guard let snapshot = try? JSONDecoder().decode(AssistantSnapshot.self, from: data)
    else { return false }
    return (try? locked { try write(snapshot, to: snapshotURL) }) != nil
  }

  func snapshot() -> AssistantSnapshot? {
    locked {
      guard let data = try? Data(contentsOf: snapshotURL) else { return nil }
      return try? JSONDecoder().decode(AssistantSnapshot.self, from: data)
    }
  }

  /// What's due today and what's overdue on [today], from the snapshot and
  /// the tasks Siri added that the app hasn't taken in yet.
  func agenda(today: Date, calendar: Calendar) -> AssistantAgenda {
    let day = Self.isoDate(today, calendar: calendar)
    var tasks = snapshot()?.tasks ?? []
    let known = Set(tasks.map { "\($0.dueDate)|\($0.title)" })
    for entry in inbox() {
      guard let date = entry.dueDate else { continue }
      // Imported meanwhile and already in the snapshot.
      if known.contains("\(date)|\(entry.title)") { continue }
      tasks.append(
        AssistantSnapshotTask(
          title: entry.title, dueDate: date, dueTimeMinutes: entry.dueTimeMinutes))
    }
    tasks.sort {
      ($0.dueDate, $0.dueTimeMinutes ?? -1, $0.title)
        < ($1.dueDate, $1.dueTimeMinutes ?? -1, $1.title)
    }
    return AssistantAgenda(
      today: tasks.filter { $0.dueDate == day }.map(\.title),
      overdue: tasks.filter { $0.dueDate < day }.map(\.title))
  }

  // MARK: Helpers

  private func locked<T>(_ body: () throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try body()
  }

  private func write<T: Encodable>(_ value: T, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true)
    try Self.encoder.encode(value).write(to: url, options: .atomic)
  }

  private static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }()

  /// A due date from what Siri heard. A date without a spoken time (no
  /// hour, or exactly midnight) is all-day. Returns nil without a full date.
  static func due(from components: DateComponents) -> AssistantDue? {
    guard let year = components.year, let month = components.month,
      let day = components.day
    else { return nil }
    let date = String(format: "%04d-%02d-%02d", year, month, day)
    guard let hour = components.hour, (0..<24).contains(hour) else {
      return AssistantDue(date: date, minutes: nil)
    }
    let minute = min(max(components.minute ?? 0, 0), 59)
    if hour == 0 && minute == 0 { return AssistantDue(date: date, minutes: nil) }
    return AssistantDue(date: date, minutes: hour * 60 + minute)
  }

  /// "2026-11-12" for [date] in [calendar]'s time zone.
  static func isoDate(_ date: Date, calendar: Calendar) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
  }

  /// "2026-11-12T09:30:00Z".
  static func isoTimestamp(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter.string(from: date)
  }

  /// A UUID v7: 48 bits of Unix milliseconds, then random bits, like the
  /// ids the app makes (package:uuid's v7).
  static func uuidV7(now: Date, random: () -> UInt8 = { UInt8.random(in: 0...255) })
    -> String
  {
    var bytes = (0..<16).map { _ in random() }
    let ms = UInt64(max(0, now.timeIntervalSince1970 * 1000))
    for i in 0..<6 {
      bytes[i] = UInt8((ms >> (8 * UInt64(5 - i))) & 0xff)
    }
    bytes[6] = (bytes[6] & 0x0f) | 0x70  // version 7
    bytes[8] = (bytes[8] & 0x3f) | 0x80  // RFC 4122 variant
    let hex = bytes.map { String(format: "%02x", $0) }.joined()
    let s = Array(hex)
    return [s[0..<8], s[8..<12], s[12..<16], s[16..<20], s[20..<32]]
      .map { String($0) }.joined(separator: "-")
  }
}
