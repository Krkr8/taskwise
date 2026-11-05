import Foundation

// Walk simulator for location reminders. Runs the iPhone's real
// GeofenceEngine (app/ios/Runner/GeofenceDecider.swift) over simulated
// walks: iOS region events come with iOS-like delays, GPS fixes with noise
// (worse indoors). Each scenario runs many times with different random
// seeds and reports how often and where the reminders fired.
//
// Run: tools/geofence_sim/run.sh   (Swift in a podman container)

// MARK: - Random numbers (seeded, so runs are repeatable)

struct Rng {
  var state: UInt64
  mutating func next() -> Double {
    state = state &* 6364136223846793005 &+ 1442695040888963407
    return Double(state >> 11) / Double(1 << 53)
  }
  mutating func uniform(_ a: Double, _ b: Double) -> Double { a + (b - a) * next() }
  mutating func gaussian() -> Double {
    let u = max(next(), 1e-12), v = next()
    return sqrt(-2 * log(u)) * cos(2 * .pi * v)
  }
}

// MARK: - Places in metres around Home

let homeLat = 33.3, homeLon = 44.4
let metersPerDegLat = 111_195.0
func toLatLon(_ x: Double, _ y: Double) -> (Double, Double) {
  (homeLat + y / metersPerDegLat,
   homeLon + x / (metersPerDegLat * cos(homeLat * .pi / 180)))
}
func toXY(_ lat: Double, _ lon: Double) -> (Double, Double) {
  ((lon - homeLon) * metersPerDegLat * cos(homeLat * .pi / 180),
   (lat - homeLat) * metersPerDegLat)
}

// MARK: - Scenario: a path of legs

struct Point { var x: Double; var y: Double }

enum Leg {
  /// Stay at a spot for some seconds (indoors or not).
  case stay(Point, seconds: Double, indoors: Bool)
  /// Move in a straight line at a speed (m/s).
  case move(to: Point, speed: Double)
  /// The reminders are handed to the phone now.
  case setReminders
  /// iOS reports a wrong exit (and enter again after some seconds) for
  /// every region, as it sometimes does when cell or Wi-Fi data jumps.
  case falseExit(backAfter: Double)
}

struct Scenario {
  let name: String
  let start: Point
  let legs: [Leg]
  /// What should happen: (arrive fires, leave fires).
  let expectArrive: Int
  let expectLeave: Int
}

// MARK: - The simulated iPhone

final class SimPhone: GeofenceHost {
  var rng: Rng
  let engine: GeofenceEngine
  var now = Date(timeIntervalSince1970: 1_800_000_000)
  var pos = Point(x: 0, y: 0)
  var indoors = false
  var precise = false
  var preciseSince: Date?
  var fired: [(arrive: Bool, distance: Double, at: Date)] = []
  var logLines: [String] = []
  let verbose: Bool

  /// What iOS believes per region: inside or not, and since when the
  /// true position disagrees (the event fires after a delay).
  struct Region { let id: String; let radius: Double; let center: Point
    var inside: Bool; var disagreeSince: Date?; var delay: Double }
  var regions: [Region] = []

  init(seed: UInt64, verbose: Bool) {
    rng = Rng(state: seed &* 2654435761 &+ 12345)
    engine = GeofenceEngine()
    self.verbose = verbose
    engine.host = self
  }

  func startPreciseUpdates() -> Bool {
    precise = true
    preciseSince = now
    return true
  }
  func stopPreciseUpdates() { precise = false; preciseSince = nil }
  func watchNear(_ entry: GeofenceEntry) {
    let (x, y) = toXY(entry.latitude, entry.longitude)
    let center = Point(x: x, y: y)
    let r = GeofenceDecider.nearRadius(for: entry, maximum: 10_000)
    // No requestState for near regions: only a real entry counts.
    regions.append(Region(id: "near:" + entry.id, radius: r, center: center,
                          inside: dist(center) < r, disagreeSince: nil, delay: 0))
  }
  func stopWatchingNear(id: String) { regions.removeAll { $0.id == "near:" + id } }
  func show(_ entry: GeofenceEntry, reason: String) {
    let d = hypot(pos.x, pos.y)
    fired.append((entry.arrive, d, now))
  }
  func log(_ text: String) {
    if verbose { logLines.append("\(clock()) \(text)  [true \(Int(hypot(pos.x, pos.y))) m]") }
  }
  func clock() -> String {
    let t = Int(now.timeIntervalSince1970 - 1_800_000_000)
    return String(format: "%02d:%02d:%02d", t / 3600, t / 60 % 60, t % 60)
  }

  func setReminders(_ entries: [GeofenceEntry]) {
    engine.setEntries(entries)
    regions = entries.map { e in
      let (x, y) = toXY(e.latitude, e.longitude)
      let r = GeofenceDecider.outerRadius(for: e, maximum: 10_000)
      let center = Point(x: x, y: y)
      return Region(id: e.id, radius: r, center: center,
                    inside: dist(center) < r, disagreeSince: nil, delay: 0)
    }
    // requestState answers after a moment.
    for r in regions { engine.determined(id: r.id, inside: r.inside, now: now) }
  }

  func dist(_ p: Point) -> Double { hypot(pos.x - p.x, pos.y - p.y) }

  /// One second passes.
  func tick() {
    now = now.addingTimeInterval(1)
    // Region events: iOS needs the phone a bit past the edge for a while.
    for i in regions.indices where i < regions.count {
      let d = dist(regions[i].center)
      let truth = regions[i].inside ? d < regions[i].radius + 25 : d < regions[i].radius - 10
      if truth == regions[i].inside {
        regions[i].disagreeSince = nil
        continue
      }
      if regions[i].disagreeSince == nil {
        regions[i].disagreeSince = now
        // Typical iOS delays: entering 10 s - 3 min, exiting 20 s - 3 min.
        regions[i].delay = truth ? rng.uniform(10, 180) : rng.uniform(20, 180)
      }
      if now.timeIntervalSince(regions[i].disagreeSince!) >= regions[i].delay {
        regions[i].inside = truth
        regions[i].disagreeSince = nil
        let id = regions[i].id
        if id.hasPrefix("near:") {
          if truth { engine.enteredNear(id: String(id.dropFirst(5)), now: now) }
        } else if truth {
          engine.entered(id: id, now: now)
        } else {
          engine.exited(id: id, now: now)
        }
      }
    }
    // The manager's timer.
    engine.checkTimeout(now: now)
    // One precise fix per second while updates run.
    if precise {
      let warm = now.timeIntervalSince(preciseSince ?? now)
      var acc = indoors ? rng.uniform(25, 65) : rng.uniform(5, 16)
      if warm < 4 { acc = max(acc, rng.uniform(40, 100)) }  // first fixes
      let err = abs(rng.gaussian()) * acc / 1.5
      let angle = rng.uniform(0, 2 * .pi)
      let (lat, lon) = toLatLon(pos.x + err * cos(angle), pos.y + err * sin(angle))
      engine.fix(latitude: lat, longitude: lon, accuracy: acc, now: now)
    }
  }

  func falseExit(backAfter: Double) {
    let outer = regions.filter { $0.inside && !$0.id.hasPrefix("near:") }
    for r in outer { engine.exited(id: r.id, now: now) }
    for _ in 0..<Int(backAfter) { tick() }
    for r in outer { engine.entered(id: r.id, now: now) }
  }
}

func reminders() -> [GeofenceEntry] {
  // Home's pin is the front door at (0, 0); 30 m radius.
  [true, false].map { arrive in
    GeofenceEntry(
      id: arrive ? "arrive" : "leave", latitude: homeLat, longitude: homeLon, radius: 30,
      arrive: arrive, title: arrive ? "Test: arrive home" : "Test: leave home",
      body: "", payload: "{}", notificationId: arrive ? 1 : 2)
  }
}

func run(_ s: Scenario, seed: UInt64, verbose: Bool = false) -> SimPhone {
  let phone = SimPhone(seed: seed, verbose: verbose)
  phone.pos = s.start
  for leg in s.legs {
    switch leg {
    case .setReminders:
      phone.setReminders(reminders())
    case let .stay(p, seconds, indoors):
      phone.pos = p
      phone.indoors = indoors
      for _ in 0..<Int(seconds) { phone.tick() }
    case let .move(to, speed):
      phone.indoors = false
      let from = phone.pos
      let total = hypot(to.x - from.x, to.y - from.y)
      let steps = max(1, Int(total / speed))
      for i in 1...steps {
        let f = Double(i) / Double(steps)
        phone.pos = Point(x: from.x + (to.x - from.x) * f, y: from.y + (to.y - from.y) * f)
        phone.tick()
      }
    case let .falseExit(backAfter):
      phone.falseExit(backAfter: backAfter)
    }
  }
  return phone
}

// MARK: - Scenarios

let inside = Point(x: 8, y: 6)       // a room, 10 m from the front door
let door = Point(x: 0, y: 0)
let street = Point(x: 0, y: -20)
let shop = Point(x: 400, y: -20)
let walk = 1.4, car = 12.0

let scenarios: [Scenario] = [
  Scenario(
    name: "1 Walk to the shop and back (reminders made at home)",
    start: inside,
    legs: [.setReminders, .stay(inside, seconds: 600, indoors: true),
           .move(to: street, speed: walk), .move(to: shop, speed: walk),
           .stay(shop, seconds: 1200, indoors: true),
           .move(to: street, speed: walk), .move(to: door, speed: walk),
           .stay(inside, seconds: 1800, indoors: true)],
    expectArrive: 1, expectLeave: 1),
  Scenario(
    name: "2 Drive away and back (made at home)",
    start: inside,
    legs: [.setReminders, .stay(inside, seconds: 600, indoors: true),
           .move(to: street, speed: walk), .move(to: Point(x: 3000, y: -20), speed: car),
           .stay(Point(x: 3000, y: -20), seconds: 3600, indoors: true),
           .move(to: street, speed: car), .move(to: door, speed: walk),
           .stay(inside, seconds: 1800, indoors: true)],
    expectArrive: 1, expectLeave: 1),
  Scenario(
    name: "3 Made while away, come home, later leave again",
    start: shop,
    legs: [.setReminders, .stay(shop, seconds: 300, indoors: true),
           .move(to: street, speed: walk), .move(to: door, speed: walk),
           .stay(inside, seconds: 3600, indoors: true),
           .move(to: street, speed: walk), .move(to: shop, speed: walk),
           .stay(shop, seconds: 600, indoors: true)],
    expectArrive: 1, expectLeave: 1),
  Scenario(
    name: "4 Stop 60 m from home for 10 min (chat), then go in",
    start: shop,
    legs: [.setReminders, .stay(shop, seconds: 300, indoors: true),
           .move(to: Point(x: 60, y: -20), speed: walk),
           .stay(Point(x: 60, y: -20), seconds: 600, indoors: false),
           .move(to: street, speed: walk), .move(to: door, speed: walk),
           .stay(inside, seconds: 1800, indoors: true)],
    expectArrive: 1, expectLeave: 0),
  Scenario(
    name: "5 Walk past on a street 80 m away",
    start: Point(x: -600, y: -80),
    legs: [.setReminders, .move(to: Point(x: 600, y: -80), speed: walk),
           .stay(Point(x: 600, y: -80), seconds: 600, indoors: true)],
    expectArrive: 0, expectLeave: 0),
  Scenario(
    name: "6 Home all day, iOS reports a false exit once",
    start: inside,
    legs: [.setReminders, .stay(inside, seconds: 7200, indoors: true),
           .falseExit(backAfter: 120), .stay(inside, seconds: 7200, indoors: true)],
    expectArrive: 0, expectLeave: 0),
  Scenario(
    name: "7 Short errand: out for 10 min",
    start: inside,
    legs: [.setReminders, .stay(inside, seconds: 600, indoors: true),
           .move(to: street, speed: walk), .move(to: Point(x: 250, y: -20), speed: walk),
           .stay(Point(x: 250, y: -20), seconds: 300, indoors: true),
           .move(to: street, speed: walk), .move(to: door, speed: walk),
           .stay(inside, seconds: 1800, indoors: true)],
    expectArrive: 1, expectLeave: 1),
  Scenario(
    name: "8 Made at home, stay home (nothing should fire)",
    start: inside,
    legs: [.setReminders, .stay(inside, seconds: 3600, indoors: true)],
    expectArrive: 0, expectLeave: 0),
]

// MARK: - Run

let args = CommandLine.arguments
let runs = 300
if args.count >= 3, args[1] == "trace", let n = Int(args[2]) {
  // Print one run's event log: geofence_sim trace <scenario> [seed]
  let seed = args.count >= 4 ? UInt64(args[3]) ?? 1 : 1
  let phone = run(scenarios[n - 1], seed: seed, verbose: true)
  print(scenarios[n - 1].name)
  phone.logLines.forEach { print("  " + $0) }
  for f in phone.fired {
    print("  FIRED \(f.arrive ? "arrive" : "leave") at \(Int(f.distance)) m")
  }
  exit(0)
}

var allGood = true
for s in scenarios {
  var ok = 0
  var arriveDist: [Double] = [], leaveDist: [Double] = []
  var badSeeds: [UInt64] = []
  for seed in 1...UInt64(runs) {
    let phone = run(s, seed: seed)
    let a = phone.fired.filter(\.arrive), l = phone.fired.filter { !$0.arrive }
    arriveDist += a.map(\.distance)
    leaveDist += l.map(\.distance)
    if a.count == s.expectArrive && l.count == s.expectLeave { ok += 1 }
    else if badSeeds.count < 3 { badSeeds.append(seed) }
  }
  func range(_ d: [Double]) -> String {
    guard !d.isEmpty else { return "-" }
    let s = d.sorted()
    return "\(Int(s[s.count / 2])) m (\(Int(s.first!))-\(Int(s.last!)))"
  }
  let pct = Double(ok) * 100 / Double(runs)
  if ok < runs { allGood = false }
  print(String(format: "%@ %5.1f%%  %@", ok == runs ? "PASS" : "FAIL", pct, s.name))
  print("       arrive fired at \(range(arriveDist)), leave fired at \(range(leaveDist))"
        + (badSeeds.isEmpty ? "" : "; wrong e.g. seeds \(badSeeds)"))
}
exit(allGood ? 0 : 1)
