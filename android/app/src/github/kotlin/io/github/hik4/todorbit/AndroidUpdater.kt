package io.github.hik4.todorbit

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import com.android.apksig.ApkVerifier
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.zip.ZipFile

/** Only GitHub builds contain this user-initiated, app-private installer. */
class AndroidUpdater(private val activity: Activity) {
    private val root get() = File(activity.cacheDir, "update-apks").apply { mkdirs() }.canonicalFile
    private var permissionReply: MethodChannel.Result? = null
    private var installReply: MethodChannel.Result? = null
    private var installedBefore = 0L
    init {
        // Clean abandoned large downloads on ordinary app startup too.
        root.listFiles()?.filter { it.isFile && System.currentTimeMillis() - it.lastModified() > 7L * 24 * 60 * 60 * 1000 }
            ?.forEach { it.delete() }
    }
    private fun version(info: PackageInfo) = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
    private fun installed(): PackageInfo = activity.packageManager.getPackageInfo(activity.packageName, PackageManager.GET_SIGNATURES)
    private fun digest(bytes: ByteArray) = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }

    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "updateInfo" -> result.success(mapOf("versionName" to installed().versionName,
                "versionCode" to version(installed()), "distribution" to "github",
                "sdk" to Build.VERSION.SDK_INT, "abis" to Build.SUPPORTED_ABIS.toList(),
                "directory" to root.path, "freeBytes" to root.usableSpace,
                "canInstall" to activity.packageManager.canRequestPackageInstalls()))
            "updateVerify", "updateInstall" -> {
                if (installReply != null) { result.error("busy", "An installation is already open.", null); return true }
                Thread {
                    try {
                        val file = verify(call)
                        activity.runOnUiThread {
                            if (call.method == "updateVerify") result.success(null)
                            else if (!activity.packageManager.canRequestPackageInstalls()) result.error("permission", "Allow installation from Todorbit, then tap Install Update again.", null)
                            else try {
                                val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", file)
                                installedBefore = version(installed()); installReply = result
                                activity.startActivityForResult(Intent(Intent.ACTION_INSTALL_PACKAGE)
                                    .setDataAndType(uri, "application/vnd.android.package-archive")
                                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    .putExtra(Intent.EXTRA_RETURN_RESULT, true), 703)
                            } catch (_: Exception) { installReply = null; result.error("installer", "Android package installer could not open.", null) }
                        }
                    } catch (failure: Exception) {
                        activity.runOnUiThread { result.error("verification", failure.message ?: "APK verification failed.", null) }
                    }
                }.start()
            }
            "updatePermission" -> {
                if (permissionReply != null) result.error("busy", "Installation settings are already open.", null)
                else if (activity.packageManager.canRequestPackageInstalls()) result.success(true)
                else try {
                    permissionReply = result
                    activity.startActivityForResult(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}")), 704)
                } catch (_: Exception) { permissionReply = null; result.error("permission", "Open Android Settings > Special app access > Install unknown apps > Todorbit.", null) }
            }
            else -> return false
        }
        return true
    }

    private fun verify(call: MethodCall): File {
        val file = File(requireNotNull(call.argument<String>("path"))).canonicalFile
        require(file.parentFile == root && file.extension == "apk" && file.isFile) { "Update must be an app-private APK." }
        val expectedSize = requireNotNull(call.argument<Number>("size")).toLong()
        require(file.length() == expectedSize && expectedSize in 1..1_073_741_824) { "APK download is incomplete." }
        val expectedDigest = requireNotNull(call.argument<String>("sha256"))
        val sha = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input -> val buffer = ByteArray(65536); while (true) { val count = input.read(buffer); if (count < 0) break; sha.update(buffer, 0, count) } }
        require(sha.digest().joinToString("") { "%02x".format(it) } == expectedDigest) { "APK checksum changed. Download it again." }
        // Package archive metadata alone does not establish APK signature integrity.
        val signature = ApkVerifier.Builder(file).setMinCheckedPlatformVersion(Build.VERSION.SDK_INT)
            .setMaxCheckedPlatformVersion(Build.VERSION.SDK_INT).build().verify()
        require(signature.isVerified) { "APK signature integrity verification failed." }
        val signers = signature.signerCertificates.map { digest(it.encoded) }.toSet()
        val current = installed()
        val installedSigners = current.signatures?.map { digest(it.toByteArray()) }?.toSet() ?: emptySet()
        require(signers.isNotEmpty() && signers == installedSigners) { "APK signing certificate differs from this installation. Keep your data and contact the publisher; do not uninstall to fix this." }
        val archive = requireNotNull(activity.packageManager.getPackageArchiveInfo(file.path, 0)) { "APK metadata is unreadable." }
        require(archive.packageName == "io.github.hik4.todorbit" && archive.packageName == activity.packageName) { "APK package identity is incorrect." }
        require(version(archive) > version(current) && version(archive) == requireNotNull(call.argument<Number>("versionCode")).toLong()) { "APK version code is not the expected newer version." }
        require(archive.versionName == call.argument<String>("versionName")) { "APK version name differs from release metadata." }
        require(archive.applicationInfo!!.minSdkVersion <= Build.VERSION.SDK_INT) { "APK requires a newer Android version." }
        val abis = ZipFile(file).use { zip -> zip.entries().asSequence().map { it.name }
            .filter { it.matches(Regex("lib/[^/]+/libflutter\\.so")) }.map { it.split('/')[1] }.toSet() }
        require(abis.isNotEmpty() && Build.SUPPORTED_ABIS.any { it in abis }) { "APK architecture is incompatible with this device." }
        return file
    }

    fun onActivityResult(request: Int, code: Int): Boolean {
        if (request == 704) { permissionReply?.success(activity.packageManager.canRequestPackageInstalls()); permissionReply = null; return true }
        if (request == 703) {
            installReply?.success(if (version(installed()) > installedBefore) "installed" else if (code == Activity.RESULT_CANCELED) "canceled" else "failed")
            installReply = null; return true
        }
        return false
    }
}
