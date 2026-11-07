package io.github.krkr8.taskwise_android

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * Taskwise's Android channels:
 * - `taskwise/location`: the same methods as LocationRemindersPlugin.swift
 *   on the iPhone (see app/lib/location/location_platform.dart), backed by
 *   [LocationReminderManager];
 * - `taskwise/files`: `saveFile`, the system "Save to" screen
 *   (app/lib/ui/shared/common/save_text_file.dart).
 *
 * Registered on every Flutter engine, including the background-sync engine,
 * which has no activity: there, requests that need one just report the
 * current state.
 */
class TaskwiseAndroidPlugin :
  FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
  PluginRegistry.RequestPermissionsResultListener, PluginRegistry.ActivityResultListener {

  private companion object {
    const val SAVE_REQUEST = 0x7a51
  }

  private lateinit var location: MethodChannel
  private lateinit var files: MethodChannel
  private lateinit var manager: LocationReminderManager
  private var binding: ActivityPluginBinding? = null
  private val activity: Activity? get() = binding?.activity

  /** The file waiting for the "Save to" screen's answer. */
  private var pendingSave: Pair<ByteArray, MethodChannel.Result>? = null

  override fun onAttachedToEngine(flutter: FlutterPlugin.FlutterPluginBinding) {
    manager = LocationReminderManager.get(flutter.applicationContext)
    location = MethodChannel(flutter.binaryMessenger, "taskwise/location")
    location.setMethodCallHandler(this)
    files = MethodChannel(flutter.binaryMessenger, "taskwise/files")
    files.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(flutter: FlutterPlugin.FlutterPluginBinding) {
    location.setMethodCallHandler(null)
    files.setMethodCallHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "setEntries" -> {
        val list = call.arguments as? List<*>
        if (list == null) {
          result.error("bad_args", "Expected a list", null)
          return
        }
        manager.setEntries(list.mapNotNull { (it as? Map<*, *>)?.let(GeofenceEntry::fromMap) })
        result.success(null)
      }
      "permissionStatus" -> result.success(manager.permissionStatus())
      "requestPermission" -> manager.requestPermission(activity) { result.success(it) }
      "openSettings" -> {
        openAppSettings()
        result.success(null)
      }
      "currentLocation" -> {
        var answered = false
        val finish: (Map<String, Any>?) -> Unit = { fix ->
          if (!answered) {
            answered = true
            result.success(fix)
          }
        }
        manager.currentLocation(activity, finish)
        // Don't leave the map picker waiting forever.
        Handler(Looper.getMainLooper()).postDelayed({ finish(null) }, 20_000)
      }
      "debugState" -> result.success(manager.debugState())
      "saveFile" -> saveFile(call, result)
      else -> result.notImplemented()
    }
  }

  private fun openAppSettings() {
    val context = activity ?: manager.context
    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
      .setData(Uri.fromParts("package", context.packageName, null))
      .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    context.startActivity(intent)
  }

  private fun saveFile(call: MethodCall, result: MethodChannel.Result) {
    val activity = activity
    val bytes = call.argument<ByteArray>("bytes")
    if (activity == null || bytes == null) {
      result.error("unavailable", "No screen to show the save dialog on", null)
      return
    }
    pendingSave?.second?.success(false)
    pendingSave = bytes to result
    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
      .addCategory(Intent.CATEGORY_OPENABLE)
      .setType(call.argument<String>("mimeType") ?: "application/octet-stream")
      .putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "taskwise.txt")
    activity.startActivityForResult(intent, SAVE_REQUEST)
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    if (requestCode != SAVE_REQUEST) return false
    val (bytes, result) = pendingSave ?: return true
    pendingSave = null
    val uri = data?.data
    if (resultCode != Activity.RESULT_OK || uri == null) {
      result.success(false)
      return true
    }
    try {
      manager.context.contentResolver.openOutputStream(uri, "wt")!!.use { it.write(bytes) }
      result.success(true)
    } catch (e: Exception) {
      result.error("write_failed", e.message, null)
    }
    return true
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray,
  ): Boolean = manager.onPermissionResult(requestCode, activity)

  // ActivityAware

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    this.binding = binding
    binding.addRequestPermissionsResultListener(this)
    binding.addActivityResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
    onAttachedToActivity(binding)

  override fun onDetachedFromActivity() {
    binding?.removeRequestPermissionsResultListener(this)
    binding?.removeActivityResultListener(this)
    binding = null
  }
}
