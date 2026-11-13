package io.github.krkr8.taskwise_android

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.provider.Settings
import java.io.File

/**
 * Installs a downloaded (and already verified) Taskwise APK with the system's
 * package installer, for app/lib/update/update_installer.dart. Android shows
 * its own "Update Taskwise?" screen and only accepts an APK signed with the
 * same key. When the update succeeds, Android stops this app and replaces it,
 * so the "success" answer usually never arrives.
 */
class AppUpdater(private val context: Context) {
  companion object {
    const val ACTION_STATUS = "io.github.krkr8.taskwise.UPDATE_STATUS"

    /** The answer for Dart, or null while Android still waits for the user. */
    fun statusName(status: Int): String? = when (status) {
      PackageInstaller.STATUS_PENDING_USER_ACTION -> null
      PackageInstaller.STATUS_SUCCESS -> "success"
      PackageInstaller.STATUS_FAILURE_ABORTED -> "cancelled"
      else -> "failed:$status"
    }
  }

  private var pending: ((String) -> Unit)? = null
  private var activity: Activity? = null

  private val receiver = object : BroadcastReceiver() {
    override fun onReceive(c: Context, intent: Intent) {
      val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, Int.MIN_VALUE)
      val name = statusName(status)
      if (name == null) {
        confirmIntent(intent)?.let { confirm ->
          val starter = activity
          if (starter != null) {
            starter.startActivity(confirm)
          } else {
            context.startActivity(confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
          }
        }
        return
      }
      finish(name)
    }
  }

  @Suppress("DEPRECATION")
  private fun confirmIntent(intent: Intent): Intent? =
    if (Build.VERSION.SDK_INT >= 33) {
      intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
    } else {
      intent.getParcelableExtra(Intent.EXTRA_INTENT)
    }

  fun install(activity: Activity?, path: String, done: (String) -> Unit) {
    this.activity = activity
    // Android 8+: the user allows installs from Taskwise once.
    if (!context.packageManager.canRequestPackageInstalls()) {
      val settings = Intent(
        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
        Uri.parse("package:${context.packageName}"),
      )
      if (activity != null) {
        activity.startActivity(settings)
      } else {
        context.startActivity(settings.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
      }
      done("needsPermission")
      return
    }
    pending?.invoke("cancelled")
    pending = done
    try {
      val file = File(path)
      val installer = context.packageManager.packageInstaller
      val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
      params.setAppPackageName(context.packageName)
      val id = installer.createSession(params)
      installer.openSession(id).use { session ->
        file.inputStream().use { input ->
          session.openWrite("taskwise.apk", 0, file.length()).use { out ->
            input.copyTo(out)
            session.fsync(out)
          }
        }
        register()
        val status = PendingIntent.getBroadcast(
          context,
          id,
          Intent(ACTION_STATUS).setPackage(context.packageName),
          PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
        session.commit(status.intentSender)
      }
    } catch (e: Exception) {
      finish("failed:${e.message}")
    }
  }

  private var registered = false

  private fun register() {
    if (registered) return
    val filter = IntentFilter(ACTION_STATUS)
    if (Build.VERSION.SDK_INT >= 33) {
      context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
    } else {
      context.registerReceiver(receiver, filter)
    }
    registered = true
  }

  private fun finish(status: String) {
    if (registered) {
      try {
        context.unregisterReceiver(receiver)
      } catch (_: IllegalArgumentException) {
      }
      registered = false
    }
    val done = pending
    pending = null
    activity = null
    done?.invoke(status)
  }
}
