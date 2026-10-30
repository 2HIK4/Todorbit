package io.github.hik4.todorbit

import android.Manifest
import android.app.Activity
import android.hardware.biometrics.BiometricPrompt
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import android.webkit.MimeTypeMap
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.ClearTokenRequest
import com.google.android.gms.common.api.Scope
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.api.ApiException
import android.accounts.Account

class MainActivity : FlutterActivity() {
    private lateinit var bridge: MethodChannel
    private var documentResult: MethodChannel.Result? = null
    private var exportPath: String? = null
    private var permissionResult: MethodChannel.Result? = null
    private var initialLink: String? = null
    private var googleResult: MethodChannel.Result? = null
    private var googleToken: String? = null
    private var googleResolutionOpen = false
    private var activityVisible = false
    private lateinit var updater: AndroidUpdater

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Apply the persisted policy before Flutter's first frame, including
        // startup failures or a slow database migration/restore review.
        if (AndroidSurfaces.privacy(this).optBoolean("enabled", true)) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun onStart() { super.onStart(); activityVisible=true }
    override fun onStop() { activityVisible=false; AndroidSurfaces.foregroundUnlocked=false; super.onStop() }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        initialLink = intent?.dataString
        bridge = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "todorbit/android")
        updater = AndroidUpdater(this)
        bridge.setMethodCallHandler { call, result ->
            if (updater.handle(call, result)) return@setMethodCallHandler
            when (call.method) {
                "dataRoot" -> result.success(filesDir.absolutePath)
                "initialLink" -> result.success(initialLink)
                "ackLink" -> { if(initialLink == call.arguments) {initialLink = null; intent.data = null}; result.success(null) }
                "notificationsAllowed" -> result.success(notificationsAllowed())
                "reminderReceipts" -> result.success(AndroidSurfaces.reminderReceipts(this))
                "requestNotifications" -> {
                    if (Build.VERSION.SDK_INT < 33 || notificationsAllowed()) result.success(notificationsAllowed())
                    else if (permissionResult != null) result.error("busy", "Permission request already open", null)
                    else { permissionResult = result; requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 700) }
                }
                "protectScreen" -> {
                    if (call.arguments == true) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                "uiUnlocked" -> {AndroidSurfaces.foregroundUnlocked=activityVisible && call.arguments == true; result.success(null)}
                "authenticate" -> authenticate(result)
                "googleAuthorize" -> googleAuthorize(result,call.argument<Boolean>("interactive") == true,call.argument<Boolean>("force") == true,call.argument<String>("account"))
                "googleCancel" -> { googleResult?.error("canceled","Google authorization canceled",null); googleResult=null; result.success(null) }
                "googleDisconnect" -> { googleToken?.let {Identity.getAuthorizationClient(this).clearToken(ClearTokenRequest.builder().setToken(it).build())}; googleToken=null; result.success(null) }
                "importDocument" -> document(result, null, call.arguments as? String ?: "*/*", null)
                "openPrivateFile" -> {
                    try {
                        val file=File(call.arguments as String).canonicalFile
                        val uri=FileProvider.getUriForFile(this,"$packageName.files",file)
                        val mime=MimeTypeMap.getSingleton().getMimeTypeFromExtension(file.extension.lowercase()) ?: "application/octet-stream"
                        startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri,mime).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
                        result.success(null)
                    } catch (_: Exception) {result.error("open","No application can open this attachment",null)}
                }
                "exportDocument" -> document(result, call.argument<String>("path"), call.argument<String>("mime") ?: "application/octet-stream", call.argument<String>("name"))
                "publish" -> {
                    try {
                        val source = call.arguments as String
                        require(source.length <= 2_000_000)
                        AndroidSurfaces.publish(this, source)
                        result.success(null)
                    } catch (_: Exception) { result.error("publish", "Android surfaces could not be updated", null) }
                }
                "notificationSettings" -> {
                    startActivity(Intent("android.settings.APP_NOTIFICATION_SETTINGS").putExtra("android.provider.extra.APP_PACKAGE", packageName)); result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        AndroidSurfaces.scheduleRefresh(this)
        ReminderRefreshJob.schedule(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.dataString?.let { initialLink = it; bridge.invokeMethod("openLink", it) }
    }

    private fun notificationsAllowed(): Boolean = getSystemService(NotificationManager::class.java).areNotificationsEnabled()

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 700) { permissionResult?.success(notificationsAllowed()); permissionResult = null }
    }

    private fun document(result: MethodChannel.Result, source: String?, mime: String, name: String?) {
        if (documentResult != null) { result.error("busy", "A document picker is already open", null); return }
        if (source != null) {
            val candidate = File(source).canonicalFile
            // Flutter's Directory.systemTemp uses getCodeCacheDir(), which is
            // app-private too. Keep canonical, separator-bounded checks for all
            // three roots so temporary SQLite/settings exports reach SAF.
            val privateRoots = listOf(filesDir, cacheDir, codeCacheDir)
            if (privateRoots.none { candidate.path.startsWith(it.canonicalPath + File.separator) }) {
                result.error("path", "Only app-private exports are supported", null); return
            }
        }
        documentResult = result
        exportPath = source
        val picker = Intent(if (source == null) Intent.ACTION_OPEN_DOCUMENT else Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE).setType(mime)
        if (source != null) picker.putExtra(Intent.EXTRA_TITLE, name ?: "Todorbit-backup.sqlite")
        try { startActivityForResult(picker, 701) }
        catch (_: Exception) { documentResult = null; exportPath = null; result.error("picker", "No document picker is available", null) }
    }

    @Deprecated("Android activity-result bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (updater.onActivityResult(requestCode, resultCode)) return
        if(requestCode == 702) {
            googleResolutionOpen = false
            val reply=googleResult ?: return
            googleResult=null
            try {
                if(resultCode != Activity.RESULT_OK || data==null) throw IllegalStateException()
                googleToken=Identity.getAuthorizationClient(this).getAuthorizationResultFromIntent(data).accessToken
                reply.success(googleToken)
            } catch (_: Exception) {reply.error("canceled","Google authorization was canceled or permission was denied. Your existing backups are unchanged.",null)}
            return
        }
        if (requestCode != 701) return
        val reply = documentResult ?: return
        val source = exportPath
        documentResult = null; exportPath = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { reply.success(if(source == null) null else false); return }
        Thread {
            try {
                if (source == null) {
                    var displayName="document.import"
                    contentResolver.query(uri,arrayOf(OpenableColumns.DISPLAY_NAME),null,null,null)?.use { cursor ->
                        if(cursor.moveToFirst()) displayName=cursor.getString(0) ?: displayName
                    }
                    displayName=displayName.replace(Regex("[^a-zA-Z0-9._ -]"),"_").takeLast(120)
                    if(displayName.isBlank() || displayName == "." || displayName == "..") displayName="document.import"
                    val directory=File(cacheDir,"imports/${UUID.randomUUID()}"); check(directory.mkdirs())
                    val target=File(directory,displayName)
                    try {
                        contentResolver.openInputStream(uri)!!.use { input ->
                            target.outputStream().use { out ->
                                val buffer = ByteArray(65536); var total = 0L
                                while (true) { val count = input.read(buffer); if(count < 0) break
                                    total += count; require(total <= 128L * 1024 * 1024) { "Document exceeds 128 MiB" }; out.write(buffer,0,count) }
                            }
                        }
                        runOnUiThread { reply.success(target.absolutePath) }
                    } catch (e: Exception) { target.delete(); throw e }
                } else {
                    contentResolver.openOutputStream(uri, "wt")!!.use { out -> File(source).inputStream().use { it.copyTo(out) } }
                    runOnUiThread { reply.success(true) }
                }
            } catch (_: Exception) { runOnUiThread { reply.error("document", "Document could not be read or written", null) } }
        }.start()
    }

    private fun authenticate(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 28) { result.success(false); return }
        var answered = false
        val builder = BiometricPrompt.Builder(this).setTitle("Unlock Todorbit")
        if (Build.VERSION.SDK_INT >= 30) builder.setAllowedAuthenticators(
            android.hardware.biometrics.BiometricManager.Authenticators.BIOMETRIC_STRONG or
                android.hardware.biometrics.BiometricManager.Authenticators.DEVICE_CREDENTIAL)
        else builder.setNegativeButton("Cancel", mainExecutor) { _, _ -> if(!answered) {answered=true; result.success(false)} }
        try {
            builder.build().authenticate(CancellationSignal(), mainExecutor, object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(value: BiometricPrompt.AuthenticationResult) { if(!answered) { answered=true; result.success(true) } }
                override fun onAuthenticationError(code: Int, message: CharSequence) { if(!answered) { answered=true; result.success(false) } }
            })
        } catch (_: Exception) { if(!answered) result.success(false) }
    }

    private fun googleAuthorize(result: MethodChannel.Result, interactive: Boolean, force: Boolean, account: String?) {
        if(googleResult!=null || googleResolutionOpen) {result.error("busy","Google authorization is already open. Close the Google account screen before trying again.",null); return}
        val availability = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(this)
        if (availability != ConnectionResult.SUCCESS) {
            result.error("services", "Google Drive needs installed and up-to-date Google Play services. Update Play services or use local backups on this device.", null); return
        }
        googleResult=result
        val client=Identity.getAuthorizationClient(this)
        fun request() {
            val builder=AuthorizationRequest.builder().setRequestedScopes(listOf(Scope("https://www.googleapis.com/auth/drive.appdata")))
            if(interactive) builder.setPrompt(AuthorizationRequest.Prompt.SELECT_ACCOUNT)
            else if (account != null && account.contains('@')) builder.setAccount(Account(account, "com.google"))
            client.authorize(builder.build()).addOnSuccessListener { authorization ->
                if(googleResult !== result) return@addOnSuccessListener
                if(authorization.hasResolution()) {
                    if(!interactive) {googleResult=null; result.error("reconnect","Google access expired or was revoked. Reconnect Google Drive to authorize again.",null)}
                    else try {googleResolutionOpen=true; startIntentSenderForResult(authorization.pendingIntent!!.intentSender,702,null,0,0,0)}
                    catch (_: Exception) {googleResolutionOpen=false; googleResult=null; result.error("google","Google sign-in could not open",null)}
                } else {googleToken=authorization.accessToken; googleResult=null; result.success(googleToken)}
            }.addOnFailureListener { failure ->
                if(googleResult === result) {
                    googleResult=null
                    val status=(failure as? ApiException)?.statusCode
                    result.error(if(status == 7) "network" else "reconnect",
                        if(status == 7) "No internet connection. Connect to the internet and try Google Drive again. Local backups remain available."
                        else "Google authorization unavailable or denied. Reconnect; if this persists, the publisher must verify the registered package and signing certificate.",null)
                }
            }
        }
        if(force && googleToken!=null) client.clearToken(ClearTokenRequest.builder().setToken(googleToken!!).build()).addOnCompleteListener {request()}
        else request()
    }
}
