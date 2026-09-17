package com.texiol.crixx.groundar

import android.app.Activity
import android.content.Context
import android.content.Intent
import com.google.ar.core.ArCoreApk
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class GroundArPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var binding: ActivityPluginBinding? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.texiol.crixx/ground_ar")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "availability" -> result.success(availability())
            "openGround" -> {
                val activity = binding?.activity
                if (activity == null) {
                    result.error("no_activity", "Open Ground AR from the foreground app.", null)
                    return
                }
                if (pendingResult != null) {
                    result.error("already_open", "Ground AR is already open.", null)
                    return
                }
                if (availability() == "unsupported") {
                    result.error("unsupported", "ARCore is unavailable on this device. Use the ground preview.", null)
                    return
                }
                val layout = GroundLayout.fromMap(call.arguments as? Map<*, *>)
                pendingResult = result
                try {
                    activity.startActivityForResult(
                        Intent(activity, GroundArActivity::class.java)
                            .putExtra(GroundArActivity.LAYOUT_EXTRA, layout.toJson()),
                        REQUEST_GROUND,
                    )
                } catch (error: Exception) {
                    pendingResult = null
                    result.error("launch_failed", "Ground AR could not open: ${error.localizedMessage}", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun availability(): String = try {
        when (ArCoreApk.getInstance().checkAvailability(context)) {
            ArCoreApk.Availability.SUPPORTED_INSTALLED -> "supported"
            ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED,
            ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD -> "installRequired"
            ArCoreApk.Availability.UNKNOWN_CHECKING,
            ArCoreApk.Availability.UNKNOWN_TIMED_OUT,
            ArCoreApk.Availability.UNKNOWN_ERROR -> "checking"
            else -> "unsupported"
        }
    } catch (_: Exception) {
        "unsupported"
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_GROUND) return false
        val result = pendingResult
        pendingResult = null
        val raw = data?.getStringExtra(GroundArActivity.LAYOUT_EXTRA)
        result?.success(if (resultCode == Activity.RESULT_OK && raw != null) {
            GroundLayout.fromJson(raw).asMap()
        } else null)
        return true
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        binding?.removeActivityResultListener(this)
        binding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        onDetachedFromActivityForConfigChanges()
        pendingResult?.success(null)
        pendingResult = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        pendingResult?.success(null)
        pendingResult = null
    }

    private companion object { const val REQUEST_GROUND = 0xC712 }
}
