package io.github.hik4.todorbit

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Play variant contains no APK installer, FileProvider or install permission. */
class AndroidUpdater(private val activity: Activity) {
    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "updateInfo" -> {
                val installed = activity.packageManager.getPackageInfo(activity.packageName, 0)
                result.success(mapOf("versionName" to installed.versionName,
                    "versionCode" to (if (Build.VERSION.SDK_INT >= 28) installed.longVersionCode else installed.versionCode.toLong()),
                    "distribution" to "play", "sdk" to Build.VERSION.SDK_INT,
                    "abis" to Build.SUPPORTED_ABIS.toList()))
            }
            "updatePlay" -> try {
                activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=${activity.packageName}")))
                result.success(null)
            } catch (_: Exception) { result.error("play", "Google Play could not open. Update from your Play Store library.", null) }
            else -> return false
        }
        return true
    }
    fun onActivityResult(request: Int, code: Int): Boolean = false
}
