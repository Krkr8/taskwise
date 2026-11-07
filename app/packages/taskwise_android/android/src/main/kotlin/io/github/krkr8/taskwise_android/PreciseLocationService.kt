package io.github.krkr8.taskwise_android

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

/**
 * The precise check after a geofence event: high-accuracy fixes every
 * second for up to 5 minutes (GeofenceEngine decides when to stop). Android
 * only gives an app in the background location this often from a
 * foreground service, which must show a notification while it runs; it is
 * a quiet, low-importance one ("Checking your location").
 */
class PreciseLocationService : Service() {
  private companion object {
    const val CHANNEL = "location_check"
    const val NOTIFICATION_ID = 0x7a52
    const val TICK_MS = 15_000L
  }

  private lateinit var manager: LocationReminderManager
  private lateinit var fused: FusedLocationProviderClient
  private val handler = Handler(Looper.getMainLooper())
  private var running = false

  private val callback = object : LocationCallback() {
    override fun onLocationResult(result: LocationResult) {
      result.lastLocation?.let { manager.onPreciseFix(it) }
      stopIfDone()
    }
  }

  private val tick = object : Runnable {
    override fun run() {
      manager.onPreciseTick()
      if (!stopIfDone()) handler.postDelayed(this, TICK_MS)
    }
  }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onCreate() {
    super.onCreate()
    manager = LocationReminderManager.get(this)
    fused = LocationServices.getFusedLocationProviderClient(this)
  }

  @SuppressLint("MissingPermission") // Checked before the service starts.
  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    showNotification()
    if (!running) {
      running = true
      val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1000)
        .setMinUpdateIntervalMillis(1000)
        .setWaitForAccurateLocation(false)
        .build()
      try {
        fused.requestLocationUpdates(request, callback, Looper.getMainLooper())
      } catch (e: SecurityException) {
        manager.log("no location permission for precise updates")
        stopSelf()
        return START_NOT_STICKY
      }
      handler.postDelayed(tick, TICK_MS)
    }
    // If Android ends the process, the next geofence event starts over.
    return START_NOT_STICKY
  }

  private fun stopIfDone(): Boolean {
    if (manager.preciseActive) return false
    stopSelf()
    return true
  }

  private fun showNotification() {
    val nm = getSystemService(NotificationManager::class.java)
    if (nm.getNotificationChannel(CHANNEL) == null) {
      nm.createNotificationChannel(
        NotificationChannel(
          CHANNEL, getString(R.string.taskwise_location_check_channel),
          NotificationManager.IMPORTANCE_LOW,
        ),
      )
    }
    val notification = NotificationCompat.Builder(this, CHANNEL)
      .setSmallIcon(manager.notificationIcon())
      .setContentTitle(getString(R.string.taskwise_location_check))
      .setOngoing(true)
      .setSilent(true)
      .setPriority(NotificationCompat.PRIORITY_LOW)
      .build()
    ServiceCompat.startForeground(
      this, NOTIFICATION_ID, notification,
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
      } else {
        0
      },
    )
  }

  override fun onDestroy() {
    handler.removeCallbacks(tick)
    if (running) fused.removeLocationUpdates(callback)
    running = false
    manager.onPreciseStopped()
    super.onDestroy()
  }
}
