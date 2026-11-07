package io.github.krkr8.taskwise_android

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofenceStatusCodes
import com.google.android.gms.location.GeofencingEvent

/**
 * Geofence entries and exits. Android may start Taskwise's process just for
 * this (no UI); [LocationReminderManager] handles it natively. Starting the
 * precise-check foreground service from here is allowed (Android 12+
 * exempts geofence transitions from the background-start limits).
 */
class GeofenceReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val manager = LocationReminderManager.get(context)
    val event = GeofencingEvent.fromIntent(intent) ?: return
    if (event.hasError()) {
      manager.log("area event error: ${GeofenceStatusCodes.getStatusCodeString(event.errorCode)}")
      return
    }
    val entered = when (event.geofenceTransition) {
      Geofence.GEOFENCE_TRANSITION_ENTER -> true
      Geofence.GEOFENCE_TRANSITION_EXIT -> false
      else -> return
    }
    for (fence in event.triggeringGeofences.orEmpty()) {
      manager.onTransition(fence.requestId, entered)
    }
  }
}
