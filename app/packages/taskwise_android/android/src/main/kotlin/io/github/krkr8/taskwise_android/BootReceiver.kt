package io.github.krkr8.taskwise_android

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Android forgets all geofences on a reboot and when the app is updated:
 * add them again from the saved reminders. (Time reminders are restored
 * by flutter_local_notifications' own boot receiver.)
 */
class BootReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    when (intent.action) {
      Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED ->
        LocationReminderManager.get(context).restoreAfterReboot()
    }
  }
}
