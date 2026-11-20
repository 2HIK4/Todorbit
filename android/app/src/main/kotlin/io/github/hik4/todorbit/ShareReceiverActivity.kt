package io.github.hik4.todorbit

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.Process
import android.provider.OpenableColumns
import android.view.WindowManager
import android.webkit.MimeTypeMap
import android.widget.Toast
import java.io.File
import java.util.Locale

/**
 * Lightweight, translucent activity that receives Android share intents (ACTION_SEND and ACTION_SEND_MULTIPLE).
 *
 * Atomically captures incoming content URIs into Todorbit's app-private Shared Inbox storage,
 * updates the shared_inbox.json manifest, displays a brief confirmation toast, and immediately finishes
 * so the user stays in their sending application with minimal interruption.
 */
class ShareReceiverActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Apply FLAG_SECURE if privacy screen protection is active
        try {
            if (AndroidSurfaces.privacy(this).optBoolean("enabled", true)) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        } catch (_: Exception) {}

        val action = intent?.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) {
            finish()
            return
        }

        val uris = sharedInboxUris(intent)
        if (uris.isEmpty()) {
            Toast.makeText(this, "No files found in share", Toast.LENGTH_SHORT).show()
            finish()
            return
        }

        SharedInboxWorker.enqueue { processSharedUris(uris) }
    }

    private fun processSharedUris(uris: List<Uri>) {
        val storage = SharedInboxStorage(File(filesDir, "TodoPilot/shared_inbox"))
        var saved = 0
        var duplicates = 0
        var failed = 0
        for (uri in uris) {
            try {
                if (!canRead(uri)) {
                    failed++
                    continue
                }
                val name = displayName(uri)
                val suppliedMime = contentResolver.getType(uri) ?: intent.type
                val mime = if (suppliedMime.isNullOrBlank() ||
                    suppliedMime == "*/*" || suppliedMime == "application/octet-stream"
                ) {
                    MimeTypeMap.getSingleton().getMimeTypeFromExtension(File(name).extension.lowercase())
                        ?: "application/octet-stream"
                } else {
                    suppliedMime
                }
                val imported = storage.importFile(name, mime) {
                    contentResolver.openInputStream(uri) ?: error("Shared file could not be opened")
                }
                if (imported.duplicate) duplicates++ else saved++
            } catch (_: Exception) {
                // Each successful file already has a durable manifest entry.
                failed++
            }
        }

        runOnUiThread {
            val message = buildList {
                if (saved > 0) add("Saved $saved file(s) to Shared Inbox")
                if (duplicates > 0) add("$duplicates already present")
                if (failed > 0) add("$failed could not be saved")
            }.joinToString(". ")
            Toast.makeText(applicationContext, message, Toast.LENGTH_SHORT).show()
            if (saved > 0) MainActivity.notifySharedInboxUpdated()
            finish()
        }
    }

    private fun canRead(uri: Uri): Boolean {
        if (uri.scheme != "content") return false
        val authority = uri.authority?.lowercase(Locale.US).orEmpty()
        val own = packageName.lowercase(Locale.US)
        if (authority.isEmpty() || authority == own || authority.startsWith("$own.")) {
            return false
        }
        return checkUriPermission(
            uri,
            Process.myPid(),
            Process.myUid(),
            Intent.FLAG_GRANT_READ_URI_PERMISSION,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun displayName(uri: Uri): String {
        val columns = arrayOf(OpenableColumns.DISPLAY_NAME)
        val name = try {
            contentResolver.query(uri, columns, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
        } catch (_: Exception) {
            uri.lastPathSegment
        }
        return name?.takeUnless { it.isBlank() } ?: "shared_file"
    }
}

internal fun sharedInboxUris(intent: Intent): List<Uri> {
    val result = mutableListOf<Uri>()
    if (intent.action == Intent.ACTION_SEND) {
        val streamUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            ?: intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri
            ?: intent.data
        if (streamUri != null) result.add(streamUri)
    } else if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
        val list = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
        if (list != null && list.isNotEmpty()) {
            for (u in list) {
                if (u != null && !result.contains(u)) result.add(u)
            }
        }
        val clipData = intent.clipData
        if (clipData != null) {
            for (i in 0 until clipData.itemCount) {
                val item = clipData.getItemAt(i).uri
                if (item != null && !result.contains(item)) {
                    result.add(item)
                }
            }
        }
    }
    return result
}
