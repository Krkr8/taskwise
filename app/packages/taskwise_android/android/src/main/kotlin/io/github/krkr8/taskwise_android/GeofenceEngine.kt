package io.github.krkr8.taskwise_android

import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

// Pure decision logic for location reminders (SPEC.md section 3.3), the
// Android twin of app/ios/Runner/GeofenceDecider.swift. Keep the two in
// step: the same rules, the same numbers, the same tests
// (GeofenceEngineTest.kt mirrors RunnerTests.swift, GeofenceWalkTest.kt the
// walk simulator in tools/geofence_sim). No Android classes here except
// org.json, so the JVM unit tests run the exact code the phone runs.
//
// Times are milliseconds since the epoch.

/** A location reminder as Dart hands it over (see location_platform.dart). */
data class GeofenceEntry(
  val id: String,
  val latitude: Double,
  val longitude: Double,
  /** The reminder's radius in metres (30-500). */
  val radius: Double,
  /** True for "on arrive", false for "on leave". */
  val arrive: Boolean,
  val title: String,
  val body: String,
  /** Notification payload, so taps, Done and Snooze go through Dart. */
  val payload: String,
  val notificationId: Int,
  /** The notification's buttons: action id to label (Done, Snooze …). */
  val actions: List<Pair<String, String>> = emptyList(),
) {
  fun toJson(): JSONObject = JSONObject()
    .put("id", id).put("latitude", latitude).put("longitude", longitude)
    .put("radius", radius).put("trigger", if (arrive) "arrive" else "leave")
    .put("title", title).put("body", body).put("payload", payload)
    .put("notificationId", notificationId)
    .put(
      "actions",
      JSONArray(actions.map { JSONObject().put("id", it.first).put("title", it.second) }),
    )

  companion object {
    /** From Dart's map (or the saved JSON); null when something is missing. */
    fun fromMap(map: Map<*, *>): GeofenceEntry? {
      val id = map["id"] as? String ?: return null
      val latitude = (map["latitude"] as? Number)?.toDouble() ?: return null
      val longitude = (map["longitude"] as? Number)?.toDouble() ?: return null
      val radius = (map["radius"] as? Number)?.toDouble() ?: return null
      val trigger = map["trigger"] as? String ?: return null
      return GeofenceEntry(
        id = id, latitude = latitude, longitude = longitude, radius = radius,
        arrive = trigger == "arrive",
        title = map["title"] as? String ?: "",
        body = map["body"] as? String ?: "",
        payload = map["payload"] as? String ?: "",
        notificationId = (map["notificationId"] as? Number)?.toInt() ?: 0,
        actions = (map["actions"] as? List<*>).orEmpty().mapNotNull { action ->
          val a = action as? Map<*, *> ?: return@mapNotNull null
          val actionId = a["id"] as? String ?: return@mapNotNull null
          actionId to (a["title"] as? String ?: actionId)
        },
      )
    }

    fun fromJson(json: JSONObject): GeofenceEntry? {
      val map = json.keys().asSequence().associateWith { json.get(it) }.toMutableMap()
      val actions = json.optJSONArray("actions")
      map["actions"] = if (actions == null) {
        emptyList<Map<String, Any?>>()
      } else {
        (0 until actions.length()).map { i ->
          val a = actions.getJSONObject(i)
          mapOf("id" to a.optString("id"), "title" to a.optString("title"))
        }
      }
      return fromMap(map)
    }
  }
}

/** What the phone remembers about one reminder between events. */
data class GeofenceState(
  /**
   * Arrive: the phone was seen outside the radius since the last reminder,
   * so arriving again counts. Starts false, so a reminder made while
   * already at the place doesn't fire right away.
   */
  var armed: Boolean = false,
  /** Leave: the phone was seen inside the radius, so leaving counts. */
  var wasInside: Boolean = false,
  /** When this reminder last fired (ms), or null. */
  var lastFired: Long? = null,
) {
  fun toJson(): JSONObject = JSONObject()
    .put("armed", armed).put("wasInside", wasInside)
    .apply { lastFired?.let { put("lastFired", it) } }

  companion object {
    fun fromJson(json: JSONObject) = GeofenceState(
      armed = json.optBoolean("armed"),
      wasInside = json.optBoolean("wasInside"),
      lastFired = if (json.has("lastFired")) json.getLong("lastFired") else null,
    )
  }
}

/** What a precise fix says about one reminder. */
enum class GeofenceVerdict {
  /** Show the notification. */
  FIRE,
  /** Nothing to do yet; keep checking while precise updates run. */
  PENDING,
  /** Settled for now; no need to keep precise updates running for it. */
  SETTLED,
}

/** Why precise updates run for a reminder. */
enum class GeofenceCheck {
  /** The phone came near the place: watch it come within the radius. */
  APPROACH,
  /** The system said the phone left the outer region; a fix confirms it. */
  CONFIRM_EXIT,
}

object GeofenceDecider {
  /** The same reminder doesn't fire again within this time. */
  const val DEBOUNCE_MS = 30 * 60 * 1000L

  /** A fix is good enough to say "inside" at least this accurate. */
  const val MIN_ACCURACY = 25.0

  /** Least distance beyond the radius before "outside" counts. */
  const val LEAVE_MARGIN = 20.0

  /** Rougher fixes never count as "outside". */
  const val MAX_OUTSIDE_ACCURACY = 50.0

  /** The monitored (outer) region is bigger than the reminder's radius. */
  fun outerRadius(entry: GeofenceEntry, maximum: Double): Double {
    val wanted = if (entry.arrive) max(150.0, entry.radius + 100) else max(100.0, entry.radius + 70)
    return min(wanted, maximum)
  }

  /** The small fallback region used after lingering near the place. */
  fun nearRadius(entry: GeofenceEntry, maximum: Double): Double =
    min(max(50.0, entry.radius + 20), maximum)

  /** Clearly inside the reminder's radius. */
  fun isInside(radius: Double, distance: Double, accuracy: Double): Boolean =
    accuracy >= 0 && accuracy <= max(radius, MIN_ACCURACY) && distance <= radius

  /** Clearly outside the reminder's radius (twice the accuracy as margin). */
  fun isOutside(radius: Double, distance: Double, accuracy: Double): Boolean =
    accuracy >= 0 && accuracy <= MAX_OUTSIDE_ACCURACY &&
      distance > radius + max(2 * accuracy, LEAVE_MARGIN)

  fun debounced(state: GeofenceState, now: Long): Boolean {
    val last = state.lastFired ?: return false
    return now - last < DEBOUNCE_MS
  }

  /** Feeds one precise fix for a reminder being checked for [check]. */
  fun evaluate(
    entry: GeofenceEntry,
    check: GeofenceCheck = GeofenceCheck.APPROACH,
    state: GeofenceState,
    distance: Double,
    accuracy: Double,
    now: Long,
  ): GeofenceVerdict {
    val inside = isInside(entry.radius, distance, accuracy)
    val outside = isOutside(entry.radius, distance, accuracy)
    return when {
      check == GeofenceCheck.APPROACH && entry.arrive -> {
        if (outside) {
          state.armed = true
          GeofenceVerdict.PENDING
        } else if (!inside) {
          GeofenceVerdict.PENDING
        } else if (fireArrive(state, now)) {
          GeofenceVerdict.FIRE
        } else {
          GeofenceVerdict.SETTLED
        }
      }
      check == GeofenceCheck.APPROACH -> {
        if (inside) {
          state.wasInside = true
          GeofenceVerdict.SETTLED
        } else if (!outside) {
          GeofenceVerdict.PENDING
        } else if (fireLeave(state, now)) {
          GeofenceVerdict.FIRE
        } else {
          // Not in the place yet (e.g. walking towards it): keep watching.
          GeofenceVerdict.PENDING
        }
      }
      entry.arrive -> {
        if (outside) state.armed = true
        if (inside || outside) GeofenceVerdict.SETTLED else GeofenceVerdict.PENDING
      }
      else -> {
        if (inside) {
          // A wrong exit: still here.
          state.wasInside = true
          GeofenceVerdict.SETTLED
        } else if (!outside) {
          GeofenceVerdict.PENDING
        } else if (fireLeave(state, now)) {
          GeofenceVerdict.FIRE
        } else {
          GeofenceVerdict.SETTLED
        }
      }
    }
  }

  /** No fix settled a confirmExit check in time: believe the system. */
  fun exitUnconfirmed(entry: GeofenceEntry, state: GeofenceState, now: Long): Boolean {
    if (entry.arrive) {
      state.armed = true
      return false
    }
    return fireLeave(state, now)
  }

  private fun fireArrive(state: GeofenceState, now: Long): Boolean {
    if (!state.armed || debounced(state, now)) return false
    state.armed = false
    state.lastFired = now
    return true
  }

  private fun fireLeave(state: GeofenceState, now: Long): Boolean {
    if (!state.wasInside) return false
    state.wasInside = false
    if (debounced(state, now)) return false
    state.lastFired = now
    return true
  }

  /** At most [limit] reminders: the nearest to [from], or the first ones. */
  fun nearest(
    entries: List<GeofenceEntry>,
    limit: Int,
    from: Pair<Double, Double>?,
  ): List<GeofenceEntry> {
    if (entries.size <= limit) return entries
    if (from == null) return entries.take(limit)
    return entries
      .sortedBy { distance(from.first, from.second, it.latitude, it.longitude) }
      .take(limit)
  }

  /** Great-circle distance in metres (haversine), matching Dart and Swift. */
  fun distance(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
    val earthRadius = 6_371_008.8
    fun rad(deg: Double) = deg * Math.PI / 180
    val dLat = rad(lat2 - lat1)
    val dLon = rad(lon2 - lon1)
    val a = sin(dLat / 2).pow(2) + cos(rad(lat1)) * cos(rad(lat2)) * sin(dLon / 2).pow(2)
    return 2 * earthRadius * asin(min(1.0, sqrt(a)))
  }
}

/**
 * What GeofenceEngine asks the platform to do. LocationReminderManager
 * implements it with Google Play services; the tests with simulated GPS.
 */
interface GeofenceHost {
  /** Starts precise location updates; false when that isn't allowed. */
  fun startPreciseUpdates(): Boolean
  fun stopPreciseUpdates()
  /** Starts or stops the small "near" region of a reminder. */
  fun watchNear(entry: GeofenceEntry)
  fun stopWatchingNear(id: String)
  /** Shows the reminder's notification. */
  fun show(entry: GeofenceEntry, reason: String)
  fun log(text: String)
}

/**
 * The location-reminder state machine: region events and precise fixes in,
 * notifications out. A line-by-line port of GeofenceEngine in
 * GeofenceDecider.swift; see there for the reasons behind each rule.
 */
class GeofenceEngine(
  entries: List<GeofenceEntry> = emptyList(),
  states: Map<String, GeofenceState> = emptyMap(),
  nearIds: Set<String> = emptySet(),
) {
  companion object {
    /** Longest precise-updates session after a region event. */
    const val PRECISE_TIMEOUT_MS = 5 * 60 * 1000L

    fun short(entry: GeofenceEntry) =
      "${if (entry.arrive) "arrive" else "leave"} \"${entry.title}\""
  }

  var entries: List<GeofenceEntry> = entries
    private set
  private val _states = HashMap<String, GeofenceState>()
  val states: Map<String, GeofenceState> get() = _states

  /** Reminders still undecided in the running precise session. */
  private val _pending = LinkedHashMap<String, GeofenceCheck>()
  val pending: Map<String, GeofenceCheck> get() = _pending

  /** Reminders whose near region is watched. */
  private val _nearIds = LinkedHashSet<String>()
  val nearIds: Set<String> get() = _nearIds

  /** When the running precise session ends; null when none runs. */
  var preciseUntil: Long? = null
    private set

  var host: GeofenceHost? = null

  val preciseActive: Boolean get() = preciseUntil != null

  init {
    val ids = entries.map { it.id }.toSet()
    states.filterKeys { it in ids }.forEach { (k, v) -> _states[k] = v.copy() }
    _nearIds.addAll(nearIds.intersect(ids))
  }

  fun entry(id: String): GeofenceEntry? = entries.firstOrNull { it.id == id }

  /** Replaces the reminders; true when they changed. */
  fun setEntries(newEntries: List<GeofenceEntry>): Boolean {
    val changed = newEntries != entries
    entries = newEntries
    val ids = newEntries.map { it.id }.toSet()
    _states.keys.retainAll(ids)
    _pending.keys.retainAll(ids)
    for (id in _nearIds.toList()) if (id !in ids) stopNear(id)
    if (preciseActive && _pending.isEmpty()) stopPrecise()
    return changed
  }

  /** The phone entered a reminder's outer region. */
  fun entered(id: String, now: Long) {
    val entry = entry(id) ?: return
    host?.log("enter ${short(entry)}")
    startPrecise(mapOf(id to GeofenceCheck.APPROACH), now)
  }

  /** The phone entered a reminder's near region. */
  fun enteredNear(id: String, now: Long) {
    val entry = entry(id) ?: return
    host?.log("near ${short(entry)}")
    startPrecise(mapOf(id to GeofenceCheck.APPROACH), now)
  }

  /** The phone left a reminder's outer region. */
  fun exited(id: String, now: Long) {
    val entry = entry(id) ?: return
    host?.log("exit ${short(entry)}")
    stopNear(id)
    startPrecise(mapOf(id to GeofenceCheck.CONFIRM_EXIT), now) {
      // No precise updates allowed: believe the system.
      exitUnconfirmed(entry, now)
    }
  }

  /** The system said where the phone is for a region (monitoring start). */
  fun determined(id: String, inside: Boolean, now: Long) {
    val entry = entry(id) ?: return
    if (inside) {
      host?.log("inside ${short(entry)}")
      startPrecise(mapOf(id to GeofenceCheck.APPROACH), now)
    } else if (entry.arrive) {
      update(id) { it.armed = true }
    }
  }

  /** A position fix while precise updates run. */
  fun fix(latitude: Double, longitude: Double, accuracy: Double, now: Long) {
    if (!preciseActive) return
    if (checkTimeout(now)) return
    for ((id, check) in _pending.entries.toList()) {
      val entry = entry(id)
      if (entry == null) {
        _pending.remove(id)
        continue
      }
      val distance = GeofenceDecider.distance(latitude, longitude, entry.latitude, entry.longitude)
      var verdict = GeofenceVerdict.PENDING
      update(id) {
        verdict = GeofenceDecider.evaluate(entry, check, it, distance, accuracy, now)
      }
      when (verdict) {
        GeofenceVerdict.FIRE -> {
          host?.log("${short(entry)} at ${distance.toInt()} m ±${accuracy.toInt()}")
          host?.show(entry, if (entry.arrive) "arrived" else "left")
          _pending.remove(id)
        }
        GeofenceVerdict.SETTLED -> {
          if (check == GeofenceCheck.CONFIRM_EXIT && !entry.arrive && _states[id]?.wasInside == true) {
            host?.log("wrong exit ${short(entry)} (${distance.toInt()} m ±${accuracy.toInt()})")
          }
          _pending.remove(id)
        }
        GeofenceVerdict.PENDING -> continue
      }
      // Within the radius (or reminded): the near region isn't needed.
      stopNear(id)
    }
    if (_pending.isEmpty()) stopPrecise()
  }

  /** Ends the precise session once its time is up; true when it did. */
  fun checkTimeout(now: Long): Boolean {
    val until = preciseUntil ?: return false
    if (now < until) return false
    host?.log("precise timeout")
    val undecided = LinkedHashMap(_pending)
    _pending.clear()
    stopPrecise()
    for ((id, check) in undecided) {
      val entry = entry(id) ?: continue
      when (check) {
        GeofenceCheck.CONFIRM_EXIT -> exitUnconfirmed(entry, now)
        GeofenceCheck.APPROACH ->
          // Still near but not within the radius: watch a smaller area.
          if (_nearIds.add(id)) host?.watchNear(entry)
      }
    }
    return true
  }

  private fun exitUnconfirmed(entry: GeofenceEntry, now: Long) {
    var fire = false
    update(entry.id) { fire = GeofenceDecider.exitUnconfirmed(entry, it, now) }
    if (fire) host?.show(entry, "left area")
  }

  private fun startPrecise(
    checks: Map<String, GeofenceCheck>,
    now: Long,
    otherwise: (() -> Unit)? = null,
  ) {
    if (!preciseActive) {
      if (host?.startPreciseUpdates() != true) {
        host?.log("no permission for precise updates")
        otherwise?.invoke()
        return
      }
      preciseUntil = now + PRECISE_TIMEOUT_MS
      host?.log("precise on")
    }
    _pending.putAll(checks)
    preciseUntil = now + PRECISE_TIMEOUT_MS
  }

  private fun stopPrecise() {
    if (!preciseActive) return
    preciseUntil = null
    _pending.clear()
    host?.stopPreciseUpdates()
    host?.log("precise off")
  }

  private fun stopNear(id: String) {
    if (!_nearIds.remove(id)) return
    host?.stopWatchingNear(id)
  }

  private fun update(id: String, change: (GeofenceState) -> Unit) {
    val state = _states.getOrPut(id) { GeofenceState() }
    change(state)
  }

  // Saving and loading, so the state survives Android ending the process.

  fun statesJson(): String = JSONObject().apply {
    for ((id, s) in _states) put(id, s.toJson())
  }.toString()

  fun nearJson(): String = JSONArray(_nearIds.toList()).toString()
}

/** Reads what [GeofenceEngine.statesJson] wrote. */
fun parseStates(json: String?): Map<String, GeofenceState> {
  if (json.isNullOrEmpty()) return emptyMap()
  return try {
    val obj = JSONObject(json)
    obj.keys().asSequence().associateWith { GeofenceState.fromJson(obj.getJSONObject(it)) }
  } catch (e: Exception) {
    emptyMap()
  }
}

fun parseStringList(json: String?): List<String> {
  if (json.isNullOrEmpty()) return emptyList()
  return try {
    val arr = JSONArray(json)
    (0 until arr.length()).map { arr.getString(it) }
  } catch (e: Exception) {
    emptyList()
  }
}

fun parseEntries(json: String?): List<GeofenceEntry> {
  if (json.isNullOrEmpty()) return emptyList()
  return try {
    val arr = JSONArray(json)
    (0 until arr.length()).mapNotNull { GeofenceEntry.fromJson(arr.getJSONObject(it)) }
  } catch (e: Exception) {
    emptyList()
  }
}

fun entriesJson(entries: List<GeofenceEntry>): String =
  JSONArray(entries.map { it.toJson() }).toString()
