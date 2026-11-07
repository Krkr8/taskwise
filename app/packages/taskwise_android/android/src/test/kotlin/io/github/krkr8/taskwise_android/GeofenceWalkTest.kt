package io.github.krkr8.taskwise_android

import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Walk simulator for location reminders, a port of tools/geofence_sim
 * (main.swift). Runs the real GeofenceEngine over simulated walks: region
 * events come late (10 s - 3 min, like iOS and Android geofences), GPS fixes
 * are noisy (worse indoors). Each walk runs 300 times with different seeds,
 * and every run must fire exactly the expected reminders.
 *
 * `./gradlew :app:testDebugUnitTest --tests '*GeofenceWalkTest*' -i` prints
 * where the reminders fired.
 */
class GeofenceWalkTest {
  /** Seeded random numbers, the same generator as the Swift simulator. */
  private class Rng(seed: Long) {
    private var state: ULong = seed.toULong() * 2654435761UL + 12345UL

    fun next(): Double {
      state = state * 6364136223846793005UL + 1442695040888963407UL
      return (state shr 11).toDouble() / (1L shl 53).toDouble()
    }

    fun uniform(a: Double, b: Double) = a + (b - a) * next()

    fun gaussian(): Double {
      val u = max(next(), 1e-12)
      val v = next()
      return sqrt(-2 * ln(u)) * cos(2 * Math.PI * v)
    }
  }

  private data class Point(val x: Double, val y: Double)

  private sealed class Leg {
    data class Stay(val at: Point, val seconds: Int, val indoors: Boolean) : Leg()
    data class Move(val to: Point, val speed: Double) : Leg()
    object SetReminders : Leg()
    /** The system reports a wrong exit for every region, then an entry. */
    data class FalseExit(val backAfter: Int) : Leg()
  }

  private class Scenario(
    val name: String,
    val start: Point,
    val legs: List<Leg>,
    val expectArrive: Int,
    val expectLeave: Int,
  )

  private companion object {
    const val HOME_LAT = 33.3
    const val HOME_LON = 44.4
    const val M_PER_DEG = 111_195.0
    const val T0 = 1_800_000_000_000L

    fun toLatLon(x: Double, y: Double) = Pair(
      HOME_LAT + y / M_PER_DEG,
      HOME_LON + x / (M_PER_DEG * cos(HOME_LAT * Math.PI / 180)),
    )

    fun toXY(lat: Double, lon: Double) = Point(
      (lon - HOME_LON) * M_PER_DEG * cos(HOME_LAT * Math.PI / 180),
      (lat - HOME_LAT) * M_PER_DEG,
    )
  }

  private class Region(
    val id: String,
    val radius: Double,
    val center: Point,
    var inside: Boolean,
    var disagreeSince: Long? = null,
    var delay: Double = 0.0,
  )

  /** The simulated phone. */
  private class SimPhone(seed: Long) : GeofenceHost {
    val rng = Rng(seed)
    val engine = GeofenceEngine().also { it.host = this }
    var now = T0
    var pos = Point(0.0, 0.0)
    var indoors = false
    var precise = false
    var preciseSince: Long? = null
    val fired = mutableListOf<Pair<Boolean, Double>>()
    val regions = mutableListOf<Region>()

    fun dist(p: Point) = hypot(pos.x - p.x, pos.y - p.y)

    override fun startPreciseUpdates(): Boolean {
      precise = true
      preciseSince = now
      return true
    }

    override fun stopPreciseUpdates() {
      precise = false
      preciseSince = null
    }

    override fun watchNear(entry: GeofenceEntry) {
      val center = toXY(entry.latitude, entry.longitude)
      val r = GeofenceDecider.nearRadius(entry, 10_000.0)
      regions.add(Region("near:" + entry.id, r, center, dist(center) < r))
    }

    override fun stopWatchingNear(id: String) {
      regions.removeAll { it.id == "near:$id" }
    }

    override fun show(entry: GeofenceEntry, reason: String) {
      fired.add(entry.arrive to hypot(pos.x, pos.y))
    }

    override fun log(text: String) {}

    fun setReminders(entries: List<GeofenceEntry>) {
      engine.setEntries(entries)
      regions.clear()
      for (e in entries) {
        val center = toXY(e.latitude, e.longitude)
        val r = GeofenceDecider.outerRadius(e, 10_000.0)
        regions.add(Region(e.id, r, center, dist(center) < r))
      }
      for (r in regions.toList()) engine.determined(r.id, r.inside, now)
    }

    /** One second passes. */
    fun tick() {
      now += 1000
      var i = 0
      while (i < regions.size) {
        val r = regions[i]
        i++
        val d = dist(r.center)
        val truth = if (r.inside) d < r.radius + 25 else d < r.radius - 10
        if (truth == r.inside) {
          r.disagreeSince = null
          continue
        }
        if (r.disagreeSince == null) {
          r.disagreeSince = now
          r.delay = if (truth) rng.uniform(10.0, 180.0) else rng.uniform(20.0, 180.0)
        }
        if ((now - r.disagreeSince!!) / 1000.0 >= r.delay) {
          r.inside = truth
          r.disagreeSince = null
          if (r.id.startsWith("near:")) {
            if (truth) engine.enteredNear(r.id.removePrefix("near:"), now)
          } else if (truth) {
            engine.entered(r.id, now)
          } else {
            engine.exited(r.id, now)
          }
        }
      }
      engine.checkTimeout(now)
      if (precise) {
        val warm = (now - (preciseSince ?: now)) / 1000.0
        var acc = if (indoors) rng.uniform(25.0, 65.0) else rng.uniform(5.0, 16.0)
        if (warm < 4) acc = max(acc, rng.uniform(40.0, 100.0))
        val err = abs(rng.gaussian()) * acc / 1.5
        val angle = rng.uniform(0.0, 2 * Math.PI)
        val (lat, lon) = toLatLon(pos.x + err * cos(angle), pos.y + err * sin(angle))
        engine.fix(lat, lon, acc, now)
      }
    }

    fun falseExit(backAfter: Int) {
      val outer = regions.filter { it.inside && !it.id.startsWith("near:") }
      for (r in outer) engine.exited(r.id, now)
      repeat(backAfter) { tick() }
      for (r in outer) engine.entered(r.id, now)
    }
  }

  private fun reminders() = listOf(true, false).map { arrive ->
    GeofenceEntry(
      if (arrive) "arrive" else "leave", HOME_LAT, HOME_LON, 30.0, arrive,
      if (arrive) "Test: arrive home" else "Test: leave home", "", "{}",
      if (arrive) 1 else 2,
    )
  }

  private fun run(s: Scenario, seed: Long): SimPhone {
    val phone = SimPhone(seed)
    phone.pos = s.start
    for (leg in s.legs) {
      when (leg) {
        Leg.SetReminders -> phone.setReminders(reminders())
        is Leg.Stay -> {
          phone.pos = leg.at
          phone.indoors = leg.indoors
          repeat(leg.seconds) { phone.tick() }
        }
        is Leg.Move -> {
          phone.indoors = false
          val from = phone.pos
          val total = hypot(leg.to.x - from.x, leg.to.y - from.y)
          val steps = max(1, (total / leg.speed).toInt())
          for (i in 1..steps) {
            val f = i.toDouble() / steps
            phone.pos = Point(from.x + (leg.to.x - from.x) * f, from.y + (leg.to.y - from.y) * f)
            phone.tick()
          }
        }
        is Leg.FalseExit -> phone.falseExit(leg.backAfter)
      }
    }
    return phone
  }

  private val inside = Point(8.0, 6.0)
  private val door = Point(0.0, 0.0)
  private val street = Point(0.0, -20.0)
  private val shop = Point(400.0, -20.0)
  private val walk = 1.4
  private val car = 12.0
  private val set = Leg.SetReminders

  private val scenarios = listOf(
    Scenario(
      "1 Walk to the shop and back (reminders made at home)", inside,
      listOf(
        set, Leg.Stay(inside, 600, true), Leg.Move(street, walk), Leg.Move(shop, walk),
        Leg.Stay(shop, 1200, true), Leg.Move(street, walk), Leg.Move(door, walk),
        Leg.Stay(inside, 1800, true),
      ),
      1, 1,
    ),
    Scenario(
      "2 Drive away and back (made at home)", inside,
      listOf(
        set, Leg.Stay(inside, 600, true), Leg.Move(street, walk),
        Leg.Move(Point(3000.0, -20.0), car), Leg.Stay(Point(3000.0, -20.0), 3600, true),
        Leg.Move(street, car), Leg.Move(door, walk), Leg.Stay(inside, 1800, true),
      ),
      1, 1,
    ),
    Scenario(
      "3 Made while away, come home, later leave again", shop,
      listOf(
        set, Leg.Stay(shop, 300, true), Leg.Move(street, walk), Leg.Move(door, walk),
        Leg.Stay(inside, 3600, true), Leg.Move(street, walk), Leg.Move(shop, walk),
        Leg.Stay(shop, 600, true),
      ),
      1, 1,
    ),
    Scenario(
      "4 Stop 60 m from home for 10 min (chat), then go in", shop,
      listOf(
        set, Leg.Stay(shop, 300, true), Leg.Move(Point(60.0, -20.0), walk),
        Leg.Stay(Point(60.0, -20.0), 600, false), Leg.Move(street, walk),
        Leg.Move(door, walk), Leg.Stay(inside, 1800, true),
      ),
      1, 0,
    ),
    Scenario(
      "5 Walk past on a street 80 m away", Point(-600.0, -80.0),
      listOf(
        set, Leg.Move(Point(600.0, -80.0), walk), Leg.Stay(Point(600.0, -80.0), 600, true),
      ),
      0, 0,
    ),
    Scenario(
      "6 Home all day, a false exit once", inside,
      listOf(
        set, Leg.Stay(inside, 7200, true), Leg.FalseExit(120), Leg.Stay(inside, 7200, true),
      ),
      0, 0,
    ),
    Scenario(
      "7 Short errand: out for 10 min", inside,
      listOf(
        set, Leg.Stay(inside, 600, true), Leg.Move(street, walk),
        Leg.Move(Point(250.0, -20.0), walk), Leg.Stay(Point(250.0, -20.0), 300, true),
        Leg.Move(street, walk), Leg.Move(door, walk), Leg.Stay(inside, 1800, true),
      ),
      1, 1,
    ),
    Scenario(
      "8 Made at home, stay home (nothing should fire)", inside,
      listOf(set, Leg.Stay(inside, 3600, true)),
      0, 0,
    ),
  )

  @Test fun everyWalkFiresExactlyTheExpectedReminders() {
    val runs = 300
    val failures = mutableListOf<String>()
    for (s in scenarios) {
      var ok = 0
      val arrive = mutableListOf<Double>()
      val leave = mutableListOf<Double>()
      val bad = mutableListOf<Long>()
      for (seed in 1L..runs) {
        val phone = run(s, seed)
        val a = phone.fired.filter { it.first }
        val l = phone.fired.filter { !it.first }
        arrive += a.map { it.second }
        leave += l.map { it.second }
        if (a.size == s.expectArrive && l.size == s.expectLeave) ok++ else if (bad.size < 3) bad += seed
      }
      fun range(d: List<Double>): String {
        if (d.isEmpty()) return "-"
        val sorted = d.sorted()
        return "${sorted[sorted.size / 2].toInt()} m (${sorted.first().toInt()}-${sorted.last().toInt()})"
      }
      println(
        "${if (ok == runs) "PASS" else "FAIL"} ${"%5.1f".format(ok * 100.0 / runs)}%  ${s.name}\n" +
          "       arrive fired at ${range(arrive)}, leave fired at ${range(leave)}" +
          if (bad.isEmpty()) "" else "; wrong e.g. seeds $bad",
      )
      if (ok < runs) failures += "${s.name}: $ok/$runs (seeds $bad)"
    }
    assertTrue(failures.joinToString("\n"), failures.isEmpty())
  }
}
