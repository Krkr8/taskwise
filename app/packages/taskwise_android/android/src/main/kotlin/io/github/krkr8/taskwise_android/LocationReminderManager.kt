package io.github.krkr8.taskwise_android

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Watches the places of location reminders and shows their notifications,
 * entirely natively: Android may start Taskwise in the background for a
 * geofence event without any Flutter UI, so no Dart runs here. The Android
 * twin of app/ios/Runner/LocationReminderManager.swift (SPEC.md section
 * 3.3):
 * - each reminder gets an outer geofence (~150 m); entering or leaving it
 *   starts precise updates for a few minutes in [PreciseLocationService],
 *   and [GeofenceEngine] decides from the fixes;
 * - after lingering near a place, a small "near" geofence is watched;
 * - Android allows 100 geofences per app: with more reminders, the nearest
 *   are watched, plus one big "re-pick" geofence around the phone whose
 *   exit picks them again (instead of iOS significant location changes).
 *
 * Everything the engine learns is saved after each event, because Android
 * can end the process at any time. All calls happen on the main thread.
 */
class LocationReminderManager private constructor(val context: Context) : GeofenceHost {
  companion object {
    private const val TAG = "TaskwiseLocation"

    /** Android's limit is 100 per app; one is kept for the re-pick area. */
    private const val REGION_LIMIT = 90
    private const val REGION_PREFIX = "taskwise.loc."
    private const val NEAR_PREFIX = "taskwise.near."
    private const val REPICK_ID = "taskwise.repick"
    private const val REPICK_RADIUS = 2000f
    private const val EVENT_LIMIT = 50

    /** Same channel as the time reminders (MobileNotifier in Dart). */
    const val REMINDER_CHANNEL = "reminders"

    // Must match flutter_local_notifications (FlutterLocalNotificationsPlugin
    // .java), so taps, Done and Snooze reach Dart like a time reminder's.
    private const val SELECT_NOTIFICATION = "SELECT_NOTIFICATION"
    private const val SELECT_FOREGROUND_ACTION = "SELECT_FOREGROUND_NOTIFICATION"

    const val PERMISSION_REQUEST = 0x7a50

    @SuppressLint("StaticFieldLeak") // The application context.
    @Volatile
    private var instance: LocationReminderManager? = null

    fun get(context: Context): LocationReminderManager =
      instance ?: synchronized(this) {
        instance ?: LocationReminderManager(context.applicationContext).also {
          instance = it
          it.start()
        }
      }
  }

  private object Keys {
    const val ENTRIES = "entries"
    const val STATES = "states"
    const val NEAR = "near"
    const val EVENTS = "events"
    /** Geofences we registered: id → "lat,lon,radius" (Android can't list them). */
    const val REGISTERED = "registered"
    const val LAST_FIX = "lastFix"
    const val ASKED_FINE = "askedFine"
    const val ASKED_BACKGROUND = "askedBackground"
  }

  private val prefs: SharedPreferences =
    context.getSharedPreferences("taskwise.location", Context.MODE_PRIVATE)
  private val geofencing: GeofencingClient by lazy { LocationServices.getGeofencingClient(context) }
  private var engine = GeofenceEngine()
  private val events = ArrayList<String>()
  private var lastFix: Location? = null

  private var permissionCallback: ((String) -> Unit)? = null
  private val locationCallbacks = ArrayList<(Map<String, Any>?) -> Unit>()

  private val entries: List<GeofenceEntry> get() = engine.entries

  // MARK: Start and entries

  private fun start() {
    events.addAll(parseStringList(prefs.getString(Keys.EVENTS, null)))
    engine = GeofenceEngine(
      parseEntries(prefs.getString(Keys.ENTRIES, null)),
      parseStates(prefs.getString(Keys.STATES, null)),
      parseStringList(prefs.getString(Keys.NEAR, null)).toSet(),
    )
    engine.host = this
    lastFix = prefs.getString(Keys.LAST_FIX, null)?.let(::parseFix)
  }

  /** Replaces the reminders (from Dart) and updates the geofences. */
  fun setEntries(newEntries: List<GeofenceEntry>) {
    if (engine.setEntries(newEntries)) log("reminders: ${newEntries.size}")
    prefs.edit().putString(Keys.ENTRIES, entriesJson(newEntries)).apply()
    saveEngine()
    refreshRegions()
  }

  /** After a reboot or an app update: Android dropped all geofences. */
  fun restoreAfterReboot() {
    log("re-adding areas after restart")
    prefs.edit().remove(Keys.REGISTERED).apply()
    refreshRegions()
  }

  private fun playServicesAvailable(): Boolean =
    GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(context) ==
      ConnectionResult.SUCCESS

  private fun hasFine() = granted(Manifest.permission.ACCESS_FINE_LOCATION)

  private fun hasBackground() =
    Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
      granted(Manifest.permission.ACCESS_BACKGROUND_LOCATION)

  private fun granted(permission: String) =
    ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED

  private fun geofencePendingIntent(): PendingIntent = PendingIntent.getBroadcast(
    context, 0, Intent(context, GeofenceReceiver::class.java),
    // Geofencing fills in the event, so it must be mutable.
    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
  )

  private data class Wanted(
    val id: String,
    val latitude: Double,
    val longitude: Double,
    val radius: Float,
    val transitions: Int,
  ) {
    val key get() = "%.7f,%.7f,%.1f,%d".format(Locale.ROOT, latitude, longitude, radius, transitions)
  }

  /** Brings the registered geofences in line with the reminders. */
  @SuppressLint("MissingPermission") // Checked first.
  private fun refreshRegions() {
    if (!playServicesAvailable()) {
      log("Google Play services not available: no location reminders")
      return
    }
    if (!hasFine() || !hasBackground()) {
      // Geofences need "Allow all the time"; they're added once it's given.
      if (entries.isNotEmpty()) log("no \"all the time\" location access")
      return
    }
    val here = lastFix?.let { it.latitude to it.longitude }
    val nearEntries = entries.filter { it.id in engine.nearIds }
    val limit = maxOf(0, REGION_LIMIT - nearEntries.size)
    val chosen = GeofenceDecider.nearest(entries, limit, here)
    val wanted = LinkedHashMap<String, Wanted>()
    for (e in chosen) {
      val id = REGION_PREFIX + e.id
      wanted[id] = Wanted(
        id, e.latitude, e.longitude,
        GeofenceDecider.outerRadius(e, 100_000.0).toFloat(),
        Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT,
      )
    }
    for (e in nearEntries) {
      val id = NEAR_PREFIX + e.id
      wanted[id] = Wanted(
        id, e.latitude, e.longitude,
        GeofenceDecider.nearRadius(e, 100_000.0).toFloat(), Geofence.GEOFENCE_TRANSITION_ENTER,
      )
    }
    // More reminders than geofences: re-pick the nearest when the phone
    // leaves the area around where it is now.
    if (entries.size > limit && here != null) {
      wanted[REPICK_ID] = Wanted(
        REPICK_ID, here.first, here.second, REPICK_RADIUS, Geofence.GEOFENCE_TRANSITION_EXIT,
      )
    }

    val registered = registeredMap()
    val remove = registered.filter { (id, key) -> wanted[id]?.key != key }.keys.toList()
    val add = wanted.values.filter { registered[it.id] != it.key }
    if (remove.isEmpty() && add.isEmpty()) return

    if (remove.isNotEmpty()) {
      geofencing.removeGeofences(remove)
        .addOnFailureListener { log("removing areas failed: ${it.message}") }
    }
    val next = HashMap(registered).apply { remove.forEach { this.remove(it) } }
    if (add.isNotEmpty()) {
      val request = GeofencingRequest.Builder()
        // No initial trigger: where the phone is now is worked out below,
        // from a fix (like iOS's requestState).
        .setInitialTrigger(0)
        .addGeofences(
          add.map {
            Geofence.Builder()
              .setRequestId(it.id)
              .setCircularRegion(it.latitude, it.longitude, it.radius)
              .setExpirationDuration(Geofence.NEVER_EXPIRE)
              .setTransitionTypes(it.transitions)
              .build()
          },
        )
        .build()
      geofencing.addGeofences(request, geofencePendingIntent())
        .addOnSuccessListener {
          log("watching ${add.size} new area(s)")
          determineNewRegions(add.filter { it.id.startsWith(REGION_PREFIX) })
        }
        .addOnFailureListener {
          val code = (it as? com.google.android.gms.common.api.ApiException)?.statusCode
          log(
            if (code == com.google.android.gms.location.GeofenceStatusCodes.GEOFENCE_NOT_AVAILABLE) {
              // Seen when "Google Location Accuracy" is off.
              "can't watch areas: turn on Location Accuracy (Settings → Location → Location services)"
            } else {
              "watching areas failed: ${it.message}"
            },
          )
          // Try again next time.
          val failed = registeredMap().apply { add.forEach { a -> remove(a.id) } }
          saveRegistered(failed)
        }
      add.forEach { next[it.id] = it.key }
    }
    saveRegistered(next)
  }

  /**
   * Tells the engine whether the phone is inside the newly added outer
   * areas, so a reminder made at the place checks how close it is, and an
   * arrive reminder made elsewhere is armed.
   */
  @SuppressLint("MissingPermission")
  private fun determineNewRegions(added: List<Wanted>) {
    if (added.isEmpty()) return
    LocationServices.getFusedLocationProviderClient(context)
      .getCurrentLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, CancellationTokenSource().token)
      .addOnSuccessListener { fix ->
        if (fix == null) return@addOnSuccessListener
        remember(fix)
        val now = System.currentTimeMillis()
        for (w in added) {
          val d = GeofenceDecider.distance(fix.latitude, fix.longitude, w.latitude, w.longitude)
          engine.determined(w.id.removePrefix(REGION_PREFIX), d < w.radius, now)
        }
        saveEngine()
      }
  }

  private fun registeredMap(): MutableMap<String, String> {
    val json = prefs.getString(Keys.REGISTERED, null) ?: return HashMap()
    return try {
      val obj = JSONObject(json)
      obj.keys().asSequence().associateWith { obj.getString(it) }.toMutableMap()
    } catch (e: Exception) {
      HashMap()
    }
  }

  private fun saveRegistered(map: Map<String, String>) {
    prefs.edit().putString(Keys.REGISTERED, JSONObject(map).toString()).apply()
  }

  // MARK: Geofence events (from GeofenceReceiver)

  fun onTransition(requestId: String, entered: Boolean) {
    val now = System.currentTimeMillis()
    when {
      requestId == REPICK_ID -> {
        log("moved away: picking the nearest areas")
        refreshAfterMove()
      }
      requestId.startsWith(NEAR_PREFIX) ->
        if (entered) engine.enteredNear(requestId.removePrefix(NEAR_PREFIX), now)
      requestId.startsWith(REGION_PREFIX) -> {
        val id = requestId.removePrefix(REGION_PREFIX)
        if (entered) engine.entered(id, now) else engine.exited(id, now)
      }
    }
    saveEngine()
  }

  @SuppressLint("MissingPermission")
  private fun refreshAfterMove() {
    if (!hasFine()) return
    LocationServices.getFusedLocationProviderClient(context)
      .getCurrentLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, CancellationTokenSource().token)
      .addOnSuccessListener { fix ->
        if (fix != null) remember(fix)
        refreshRegions()
      }
  }

  // MARK: GeofenceHost

  override fun startPreciseUpdates(): Boolean {
    if (!hasFine()) return false
    return try {
      ContextCompat.startForegroundService(context, Intent(context, PreciseLocationService::class.java))
      true
    } catch (e: Exception) {
      // E.g. Android refused a foreground service from the background.
      log("precise updates refused: ${e.javaClass.simpleName}")
      false
    }
  }

  override fun stopPreciseUpdates() {
    context.stopService(Intent(context, PreciseLocationService::class.java))
  }

  override fun watchNear(entry: GeofenceEntry) = refreshRegions()

  override fun stopWatchingNear(id: String) = refreshRegions()

  override fun show(entry: GeofenceEntry, reason: String) = notify(entry, reason)

  /** A fix from [PreciseLocationService]. */
  fun onPreciseFix(fix: Location) {
    remember(fix)
    engine.fix(fix.latitude, fix.longitude, fix.accuracy.toDouble(), System.currentTimeMillis())
    saveEngine()
  }

  /** Every few seconds while precise updates run, fixes or not. */
  fun onPreciseTick() {
    engine.checkTimeout(System.currentTimeMillis())
    saveEngine()
  }

  /** The service stopped (by us, or by Android). */
  fun onPreciseStopped() {
    if (engine.preciseActive) {
      log("precise updates ended by Android")
      // End the session now, as if its time were up.
      val until = engine.preciseUntil ?: return
      engine.checkTimeout(maxOf(System.currentTimeMillis(), until))
      saveEngine()
    }
  }

  val preciseActive: Boolean get() = engine.preciseActive

  // MARK: Notifications

  private fun notify(entry: GeofenceEntry, reason: String) {
    log("notify $reason: ${entry.title}")
    ensureReminderChannel()
    val builder = NotificationCompat.Builder(context, REMINDER_CHANNEL)
      .setSmallIcon(notificationIcon())
      .setContentTitle(entry.title)
      .setContentText(entry.body)
      .setPriority(NotificationCompat.PRIORITY_HIGH)
      .setCategory(NotificationCompat.CATEGORY_REMINDER)
      .setAutoCancel(true)
      .setContentIntent(launchIntent(entry, SELECT_NOTIFICATION, null, 0))
    entry.actions.forEachIndexed { i, (actionId, title) ->
      builder.addAction(0, title, launchIntent(entry, SELECT_FOREGROUND_ACTION, actionId, i + 1))
    }
    try {
      NotificationManagerCompat.from(context).notify(entry.notificationId, builder.build())
    } catch (e: SecurityException) {
      log("notifications are off")
    }
  }

  /** Opens Taskwise the way flutter_local_notifications does. */
  private fun launchIntent(entry: GeofenceEntry, action: String, actionId: String?, n: Int): PendingIntent {
    val intent = (context.packageManager.getLaunchIntentForPackage(context.packageName) ?: Intent())
      .setAction(action)
      .putExtra("notificationId", entry.notificationId)
      .putExtra("payload", entry.payload)
    if (actionId != null) {
      intent.putExtra("actionId", actionId).putExtra("cancelNotification", true)
    }
    return PendingIntent.getActivity(
      context, entry.notificationId * 16 + n, intent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
  }

  private fun ensureReminderChannel() {
    val manager = context.getSystemService(NotificationManager::class.java)
    if (manager.getNotificationChannel(REMINDER_CHANNEL) == null) {
      manager.createNotificationChannel(
        NotificationChannel(
          REMINDER_CHANNEL, context.getString(R.string.taskwise_reminders_channel),
          NotificationManager.IMPORTANCE_HIGH,
        ),
      )
    }
  }

  fun notificationIcon(): Int {
    val id = context.resources.getIdentifier("ic_notification", "drawable", context.packageName)
    return if (id != 0) id else context.applicationInfo.icon
  }

  // MARK: Permission and current location

  fun permissionStatus(): String = when {
    !playServicesAvailable() -> "unsupported"
    hasFine() || granted(Manifest.permission.ACCESS_COARSE_LOCATION) ->
      if (hasFine() && hasBackground()) "always" else "whenInUse"
    !prefs.getBoolean(Keys.ASKED_FINE, false) -> "notDetermined"
    else -> "denied"
  }

  /**
   * Asks for "While using the app" (precise) first; once given, for "Allow
   * all the time" (Android 11+ shows the settings page for that, once).
   * Calls back with the status after the first answer; Dart refreshes again
   * when the app resumes.
   */
  fun requestPermission(activity: Activity?, completion: (String) -> Unit) {
    if (activity == null || !playServicesAvailable()) {
      completion(permissionStatus())
      return
    }
    when {
      !hasFine() -> {
        prefs.edit().putBoolean(Keys.ASKED_FINE, true).apply()
        permissionCallback = completion
        ActivityCompat.requestPermissions(
          activity,
          arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
          PERMISSION_REQUEST,
        )
      }
      !hasBackground() && !prefs.getBoolean(Keys.ASKED_BACKGROUND, false) -> {
        askBackground(activity)
        completion(permissionStatus())
      }
      else -> completion(permissionStatus())
    }
  }

  private fun askBackground(activity: Activity) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
    prefs.edit().putBoolean(Keys.ASKED_BACKGROUND, true).apply()
    ActivityCompat.requestPermissions(
      activity, arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION), PERMISSION_REQUEST,
    )
  }

  /** The answer to [requestPermission]; true when it was ours. */
  fun onPermissionResult(requestCode: Int, activity: Activity?): Boolean {
    if (requestCode != PERMISSION_REQUEST) return false
    log("permission: ${permissionStatus()}")
    if (hasFine() && !hasBackground() && !prefs.getBoolean(Keys.ASKED_BACKGROUND, false) &&
      activity != null
    ) {
      askBackground(activity)
    }
    permissionCallback?.invoke(permissionStatus())
    permissionCallback = null
    if (locationCallbacks.isNotEmpty()) {
      if (hasFine() || granted(Manifest.permission.ACCESS_COARSE_LOCATION)) {
        fetchLocation()
      } else {
        answerLocation(null)
      }
    }
    refreshRegions()
    return true
  }

  /** One position fix for the map picker ("Use my location"). */
  fun currentLocation(activity: Activity?, completion: (Map<String, Any>?) -> Unit) {
    locationCallbacks.add(completion)
    when {
      hasFine() || granted(Manifest.permission.ACCESS_COARSE_LOCATION) -> fetchLocation()
      activity != null && !prefs.getBoolean(Keys.ASKED_FINE, false) -> {
        prefs.edit().putBoolean(Keys.ASKED_FINE, true).apply()
        ActivityCompat.requestPermissions(
          activity,
          arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
          PERMISSION_REQUEST,
        )
      }
      else -> answerLocation(null)
    }
  }

  @SuppressLint("MissingPermission")
  private fun fetchLocation() {
    if (!playServicesAvailable()) {
      answerLocation(null)
      return
    }
    LocationServices.getFusedLocationProviderClient(context)
      .getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, CancellationTokenSource().token)
      .addOnSuccessListener { fix ->
        if (fix != null) remember(fix)
        answerLocation(fix?.let(::describe))
      }
      .addOnFailureListener { answerLocation(null) }
  }

  private fun answerLocation(fix: Map<String, Any>?) {
    val callbacks = locationCallbacks.toList()
    locationCallbacks.clear()
    callbacks.forEach { it(fix) }
  }

  private fun remember(fix: Location) {
    lastFix = fix
    prefs.edit().putString(Keys.LAST_FIX, JSONObject(describe(fix)).toString()).apply()
  }

  private fun describe(fix: Location): Map<String, Any> = mapOf(
    "latitude" to fix.latitude,
    "longitude" to fix.longitude,
    "accuracy" to fix.accuracy.toDouble(),
  )

  private fun parseFix(json: String): Location? = try {
    val obj = JSONObject(json)
    Location("saved").apply {
      latitude = obj.getDouble("latitude")
      longitude = obj.getDouble("longitude")
      accuracy = obj.getDouble("accuracy").toFloat()
    }
  } catch (e: Exception) {
    null
  }

  // MARK: Debug screen

  fun debugState(): Map<String, Any> {
    val regions = registeredMap().mapNotNull { (requestId, key) ->
      val parts = key.split(",")
      if (parts.size < 3) return@mapNotNull null
      val near = requestId.startsWith(NEAR_PREFIX)
      val id = requestId.removePrefix(NEAR_PREFIX).removePrefix(REGION_PREFIX)
      val entry = engine.entry(id)
      val state = engine.states[id]
      var label = when {
        requestId == REPICK_ID -> "re-pick area"
        near -> "near area"
        entry != null && state != null ->
          if (entry.arrive) {
            if (state.armed) "armed" else "waiting to leave"
          } else {
            if (state.wasInside) "inside" else "outside"
          }
        else -> "outside"
      }
      engine.pending[id]?.let {
        label += if (it == GeofenceCheck.CONFIRM_EXIT) ", checking exit" else ", checking"
      }
      mapOf(
        "id" to (
          entry?.let { "${it.title} (${if (it.arrive) "arrive" else "leave"}, ${it.radius.toInt()} m)" }
            ?: requestId
          ),
        "latitude" to parts[0].toDouble(),
        "longitude" to parts[1].toDouble(),
        "radius" to parts[2].toDouble(),
        "state" to label,
      )
    }
    val result = mutableMapOf<String, Any>(
      "permission" to permissionStatus(),
      "entries" to entries.size,
      "regions" to regions,
      "events" to events.reversed(),
      "preciseActive" to engine.preciseActive,
    )
    lastFix?.let { result["lastFix"] = describe(it) }
    return result
  }

  override fun log(text: String) {
    Log.i(TAG, text)
    val time = SimpleDateFormat("MM-dd HH:mm:ss", Locale.ROOT).format(Date())
    events.add("$time $text")
    while (events.size > EVENT_LIMIT) events.removeAt(0)
    prefs.edit().putString(Keys.EVENTS, org.json.JSONArray(events).toString()).apply()
  }

  /** Saves what the engine learned (after every event). */
  private fun saveEngine() {
    prefs.edit()
      .putString(Keys.STATES, engine.statesJson())
      .putString(Keys.NEAR, engine.nearJson())
      .apply()
  }
}
