package io.github.krkr8.taskwise_android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Checks the location-reminder decisions (GeofenceEngine.kt). A port of
 * app/ios/RunnerTests/RunnerTests.swift: keep the two in step.
 */
class GeofenceDeciderTest {
  private val now = 1_800_000_000_000L

  private fun entry(arrive: Boolean, radius: Double = 30.0) = GeofenceEntry(
    id = "r1", latitude = 33.3, longitude = 44.4, radius = radius, arrive = arrive,
    title = "Buy bread", body = "You're at Home", payload = "{}", notificationId = 1,
  )

  private fun feed(
    e: GeofenceEntry, s: GeofenceState, distance: Double, accuracy: Double = 8.0,
    at: Long = now,
  ) = GeofenceDecider.evaluate(e, GeofenceCheck.APPROACH, s, distance, accuracy, at)

  @Test fun arriveFiresInsideTheRadiusAfterBeingOutside() {
    val e = entry(arrive = true)
    val s = GeofenceState()
    assertEquals(GeofenceVerdict.PENDING, feed(e, s, 120.0))
    assertTrue(s.armed)
    assertEquals(GeofenceVerdict.PENDING, feed(e, s, 45.0))
    assertEquals(GeofenceVerdict.FIRE, feed(e, s, 25.0))
    assertEquals(now, s.lastFired)
    // Staying there doesn't fire again.
    assertEquals(GeofenceVerdict.SETTLED, feed(e, s, 10.0))
  }

  @Test fun arriveNeedsAnAccurateFix() {
    val e = entry(arrive = true)
    val s = GeofenceState(armed = true)
    assertEquals(GeofenceVerdict.PENDING, feed(e, s, 20.0, accuracy = 65.0))
    assertEquals(GeofenceVerdict.FIRE, feed(e, s, 20.0, accuracy = 12.0))
  }

  @Test fun arriveDoesNotFireWhenAddedAtThePlace() {
    assertEquals(GeofenceVerdict.SETTLED, feed(entry(arrive = true), GeofenceState(), 5.0))
  }

  @Test fun arriveNeedsALeaveAndThirtyMinutesBetweenReminders() {
    val e = entry(arrive = true)
    val s = GeofenceState(armed = true)
    assertEquals(GeofenceVerdict.FIRE, feed(e, s, 10.0))
    // Out and back in after 10 minutes: too soon.
    val soon = now + 10 * 60_000
    assertEquals(GeofenceVerdict.PENDING, feed(e, s, 200.0, at = soon))
    assertEquals(GeofenceVerdict.SETTLED, feed(e, s, 10.0, at = soon))
    // After 40 minutes, a new arrival counts.
    val later = now + 40 * 60_000
    assertEquals(GeofenceVerdict.PENDING, feed(e, s, 200.0, at = later))
    assertEquals(GeofenceVerdict.FIRE, feed(e, s, 10.0, at = later))
  }

  @Test fun leaveFiresWhenClearlyOutsideAfterBeingInside() {
    val e = entry(arrive = false)
    val s = GeofenceState()
    assertEquals(GeofenceVerdict.PENDING, feed(e, s, 70.0))
    assertEquals(GeofenceVerdict.SETTLED, feed(e, s, 10.0))
    assertTrue(s.wasInside)
    // Just past the radius isn't "clearly outside" yet.
    assertEquals(GeofenceVerdict.PENDING, feed(e, s, 40.0))
    assertEquals(GeofenceVerdict.FIRE, feed(e, s, 60.0))
    assertFalse(s.wasInside)
  }

  @Test fun oneRoughFixAtHomeDoesNotCountAsOutside() {
    val e = entry(arrive = true)
    val s = GeofenceState()
    assertEquals(GeofenceVerdict.PENDING, feed(e, s, 145.0, accuracy = 56.0))
    assertFalse(s.armed)
    assertEquals(GeofenceVerdict.PENDING, feed(e, s, 60.0, accuracy = 25.0))
    assertFalse(s.armed)
    assertEquals(GeofenceVerdict.PENDING, feed(e, s, 85.0, accuracy = 25.0))
    assertTrue(s.armed)
  }

  @Test fun anExitIsConfirmedWithAFix() {
    val leave = entry(arrive = false)
    val s = GeofenceState(wasInside = true)
    // A wrong exit: the fix says we're still here.
    assertEquals(
      GeofenceVerdict.SETTLED,
      GeofenceDecider.evaluate(leave, GeofenceCheck.CONFIRM_EXIT, s, 12.0, 15.0, now),
    )
    assertTrue(s.wasInside)
    // A real one.
    assertEquals(
      GeofenceVerdict.FIRE,
      GeofenceDecider.evaluate(leave, GeofenceCheck.CONFIRM_EXIT, s, 160.0, 10.0, now),
    )
    assertFalse(s.wasInside)
    // Arrive reminders are armed by a confirmed exit, without firing.
    val a = GeofenceState()
    assertEquals(
      GeofenceVerdict.SETTLED,
      GeofenceDecider.evaluate(entry(arrive = true), GeofenceCheck.CONFIRM_EXIT, a, 160.0, 10.0, now),
    )
    assertTrue(a.armed)
  }

  @Test fun anUnconfirmedExitIsBelieved() {
    val s = GeofenceState(wasInside = true)
    assertTrue(GeofenceDecider.exitUnconfirmed(entry(arrive = false), s, now))
    assertFalse(s.wasInside)
    // Never inside: no reminder.
    assertFalse(GeofenceDecider.exitUnconfirmed(entry(arrive = false), s, now))
  }

  @Test fun outerRadius() {
    assertEquals(150.0, GeofenceDecider.outerRadius(entry(arrive = true), 1000.0), 0.0)
    assertEquals(400.0, GeofenceDecider.outerRadius(entry(arrive = true, radius = 300.0), 1000.0), 0.0)
    assertEquals(100.0, GeofenceDecider.outerRadius(entry(arrive = false), 1000.0), 0.0)
    assertEquals(200.0, GeofenceDecider.outerRadius(entry(arrive = true, radius = 500.0), 200.0), 0.0)
  }

  @Test fun nearestKeepsTheClosestRegions() {
    val far = GeofenceEntry("far", 36.19, 44.01, 30.0, true, "", "", "", 2)
    val near = entry(arrive = true)
    assertEquals(listOf("r1"), GeofenceDecider.nearest(listOf(far, near), 1, 33.3 to 44.4).map { it.id })
    assertEquals(2, GeofenceDecider.nearest(listOf(far, near), 5, null).size)
  }

  @Test fun nearRadius() {
    assertEquals(50.0, GeofenceDecider.nearRadius(entry(arrive = true), 1000.0), 0.0)
    assertEquals(120.0, GeofenceDecider.nearRadius(entry(arrive = true, radius = 100.0), 1000.0), 0.0)
  }

  @Test fun distanceMatchesDart() {
    assertEquals(111.2, GeofenceDecider.distance(33.3, 44.4, 33.301, 44.4), 0.5)
  }

  @Test fun entriesAndStatesSurviveSaving() {
    val e = entry(arrive = false).copy(actions = listOf("done" to "Done", "snooze:15" to "Snooze 15 min"))
    assertEquals(listOf(e), parseEntries(entriesJson(listOf(e))))
    val engine = GeofenceEngine(listOf(e), mapOf("r1" to GeofenceState(wasInside = true, lastFired = now)))
    assertEquals(GeofenceState(wasInside = true, lastFired = now), parseStates(engine.statesJson())["r1"])
    assertEquals(emptyMap<String, GeofenceState>(), parseStates("not json"))
  }
}

/** GeofenceEngine's flow with a fake platform (GeofenceEngineTests in Swift). */
class GeofenceEngineTest : GeofenceHost {
  private val t0 = 1_800_000_000_000L
  private var precise = false
  private val shown = mutableListOf<String>()
  private val near = mutableListOf<String>()

  override fun startPreciseUpdates(): Boolean {
    precise = true
    return true
  }
  override fun stopPreciseUpdates() { precise = false }
  override fun watchNear(entry: GeofenceEntry) { near.add(entry.id) }
  override fun stopWatchingNear(id: String) { near.removeAll { it == id } }
  override fun show(entry: GeofenceEntry, reason: String) { shown.add(entry.id) }
  override fun log(text: String) {}

  private val homeLat = 33.3
  private val homeLon = 44.4
  private fun entry(id: String, arrive: Boolean) =
    GeofenceEntry(id, homeLat, homeLon, 30.0, arrive, id, "", "{}", 1)

  private fun engine() = GeofenceEngine().also {
    it.host = this
    it.setEntries(listOf(entry("a", true), entry("l", false)))
  }

  private fun s(seconds: Int) = t0 + seconds * 1000L

  /** A fix [north] metres north of home. */
  private fun fix(e: GeofenceEngine, north: Double, accuracy: Double = 8.0, at: Int) =
    e.fix(homeLat + north / 111_195, homeLon, accuracy, s(at))

  @Test fun madeAtHomeThenLeaveAndComeBack() {
    val e = engine()
    e.determined("a", true, t0)
    e.determined("l", true, t0)
    assertTrue(precise)
    fix(e, 5.0, at = 1)
    assertFalse(precise) // both settled at home
    assertEquals(emptyList<String>(), shown)

    e.exited("l", s(600))
    e.exited("a", s(610))
    assertTrue(precise)
    fix(e, 200.0, at = 611)
    assertEquals(listOf("l"), shown)
    assertFalse(precise)

    e.entered("a", s(3000))
    e.entered("l", s(3010))
    fix(e, 80.0, at = 3011)
    fix(e, 10.0, at = 3060)
    assertEquals(listOf("l", "a"), shown)
    assertFalse(precise)
  }

  @Test fun aWrongExitAtHomeShowsNothing() {
    val e = engine()
    e.determined("a", true, t0)
    e.determined("l", true, t0)
    fix(e, 5.0, at = 1)
    e.exited("a", s(600))
    e.exited("l", s(600))
    fix(e, 140.0, accuracy = 60.0, at = 601) // rough: ignored
    fix(e, 8.0, accuracy = 20.0, at = 602)
    assertFalse(precise)
    e.entered("a", s(700))
    e.entered("l", s(700))
    fix(e, 8.0, accuracy = 20.0, at = 701)
    assertEquals(emptyList<String>(), shown)
  }

  @Test fun lingeringNearbyWatchesTheNearArea() {
    val e = engine()
    e.determined("a", false, t0)
    e.entered("a", s(10))
    fix(e, 60.0, at = 11)
    // Five minutes at 60 m: the check ends, the near area is watched.
    e.checkTimeout(s(10) + GeofenceEngine.PRECISE_TIMEOUT_MS)
    assertFalse(precise)
    assertEquals(listOf("a"), near)
    e.enteredNear("a", s(900))
    fix(e, 5.0, at = 901)
    assertEquals(listOf("a"), shown)
    assertEquals(emptyList<String>(), near)
  }

  @Test fun noFixAfterAnExitBelievesTheSystem() {
    val e = engine()
    e.determined("l", true, t0)
    fix(e, 5.0, at = 1)
    e.exited("l", s(600))
    e.checkTimeout(s(600) + GeofenceEngine.PRECISE_TIMEOUT_MS)
    assertEquals(listOf("l"), shown)
  }
}
