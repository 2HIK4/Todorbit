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
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.RandomAccessFile
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

/**
 * Lightweight, translucent activity that receives Android share intents (ACTION_SEND and ACTION_SEND_MULTIPLE).
 *
 * Atomically captures incoming content URIs into Todorbit's app-private Shared Inbox storage,
 * updates the shared_inbox.json manifest, displays a brief confirmation toast, and immediately finishes
 * so the user stays in their sending application with minimal interruption.
 */
class ShareReceiverActivity : Activity() {

    companion object {
        private val manifestLock = Any()
    }

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

        val uris = extractUris(intent)
        if (uris.isEmpty()) {
            Toast.makeText(this, "No files found in share", Toast.LENGTH_SHORT).show()
            finish()
            return
        }

        Thread {
            processSharedUris(uris)
        }.start()
    }

    private fun extractUris(intent: Intent): List<Uri> {
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

    private fun processSharedUris(uris: List<Uri>) {
        val sharedInboxDir = File(filesDir, "TodoPilot/shared_inbox")
        val filesDir = File(sharedInboxDir, "files")
        val stagingDir = File(sharedInboxDir, "staging")

        if (!filesDir.exists()) filesDir.mkdirs()
        if (!stagingDir.exists()) stagingDir.mkdirs()

        val lockFile = File(sharedInboxDir, "shared_inbox.lock")
        val manifestFile = File(sharedInboxDir, "shared_inbox.json")
        var savedCount = 0
        var duplicateCount = 0
        val maxFileBytes = 32L * 1024 * 1024 // 32 MiB

        val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        dateFormat.timeZone = TimeZone.getTimeZone("UTC")

        try {
            RandomAccessFile(lockFile, "rw").use { raf ->
                val fileLock = raf.channel.lock()
                try {
                    val existingEntries = loadExistingManifest(manifestFile)
                    val entriesList = mutableListOf<JSONObject>()
                    for (i in 0 until existingEntries.length()) {
                        entriesList.add(existingEntries.getJSONObject(i))
                    }

                    for (uri in uris) {
                        // Security boundary (P2-01): only allow external content URIs.
                        // Reject non-content schemes and self-owned provider authorities to prevent
                        // confused deputy access to Todorbit's private data.
                        if (uri.scheme != "content") {
                            continue
                        }
                        val authority = uri.authority?.lowercase(Locale.US) ?: ""
                        val myPkg = packageName.lowercase(Locale.US)
                        if (authority.isEmpty() || authority == myPkg || authority.startsWith("$myPkg.") || authority == "$myPkg.files") {
                            continue
                        }

                        // Explicit read permission verification via Android framework
                        val hasPerm = checkUriPermission(
                            uri,
                            Process.myPid(),
                            Process.myUid(),
                            Intent.FLAG_GRANT_READ_URI_PERMISSION
                        )
                        if (hasPerm != PackageManager.PERMISSION_GRANTED) {
                            continue
                        }

                        var displayName = "shared_file"
                        try {
                            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                                if (cursor.moveToFirst()) {
                                    val name = cursor.getString(0)
                                    if (!name.isNullOrBlank()) displayName = name
                                }
                            }
                        } catch (_: Exception) {
                            val lastSegment = uri.lastPathSegment
                            if (!lastSegment.isNullOrBlank()) displayName = lastSegment
                        }

                        // Sanitize display name
                        displayName = displayName.replace(Regex("[^a-zA-Z0-9._ -]"), "_").takeLast(120)
                        if (displayName.isBlank() || displayName == "." || displayName == "..") {
                            displayName = "shared_file"
                        }

                        var mimeType = contentResolver.getType(uri) ?: intent.type
                        if (mimeType.isNullOrBlank() || mimeType == "*/*" || mimeType == "application/octet-stream") {
                            val ext = File(displayName).extension.lowercase()
                            mimeType = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: "application/octet-stream"
                        }

                        val id = UUID.randomUUID().toString()
                        val stagingFile = File(stagingDir, "$id.tmp")
                        val digest = MessageDigest.getInstance("SHA-256")
                        var totalBytes = 0L

                        try {
                            val inputStream = contentResolver.openInputStream(uri)
                                ?: throw IllegalStateException("Cannot open input stream for $uri")

                            inputStream.use { input ->
                                stagingFile.outputStream().use { output ->
                                    val buffer = ByteArray(65536)
                                    while (true) {
                                        val read = input.read(buffer)
                                        if (read < 0) break
                                        totalBytes += read
                                        if (totalBytes > maxFileBytes) {
                                            throw IllegalArgumentException("File exceeds 32 MiB limit")
                                        }
                                        digest.update(buffer, 0, read)
                                        output.write(buffer, 0, read)
                                    }
                                }
                            }

                            val sha256Hex = digest.digest().joinToString("") { "%02x".format(it) }

                            // Duplicate detection: check if content with identical sha256 and byteSize already exists
                            var isDuplicate = false
                            for (entry in entriesList) {
                                if (entry.optString("sha256") == sha256Hex && entry.optLong("byteSize") == totalBytes) {
                                    val existingRelative = entry.optString("relativePath")
                                    if (File(sharedInboxDir, existingRelative).exists()) {
                                        isDuplicate = true
                                        break
                                    }
                                }
                            }

                            if (isDuplicate) {
                                stagingFile.delete()
                                duplicateCount++
                                continue
                            }

                            val relativePath = "files/${id}_$displayName"
                            val targetFile = File(sharedInboxDir, relativePath)
                            try {
                                Files.move(
                                    stagingFile.toPath(),
                                    targetFile.toPath(),
                                    StandardCopyOption.ATOMIC_MOVE,
                                    StandardCopyOption.REPLACE_EXISTING
                                )
                            } catch (_: Exception) {
                                if (!stagingFile.renameTo(targetFile)) {
                                    stagingFile.copyTo(targetFile, overwrite = true)
                                    stagingFile.delete()
                                }
                            }
                            if (!targetFile.exists()) {
                                throw IllegalStateException("Failed to move staging file to target")
                            }

                            val newEntry = JSONObject().apply {
                                put("id", id)
                                put("displayName", displayName)
                                put("relativePath", relativePath)
                                put("mimeType", mimeType)
                                put("byteSize", totalBytes)
                                put("sha256", sha256Hex)
                                put("receivedAt", dateFormat.format(Date()))
                            }

                            // Prepend new entry so newest items appear first
                            entriesList.add(0, newEntry)
                            savedCount++
                        } catch (e: Exception) {
                            if (stagingFile.exists()) stagingFile.delete()
                            throw e
                        }
                    }

                    if (savedCount > 0) {
                        val updatedEntries = JSONArray()
                        for (entry in entriesList) {
                            updatedEntries.put(entry)
                        }
                        saveManifest(manifestFile, updatedEntries)
                    }
                } finally {
                    try {
                        fileLock.release()
                    } catch (_: Exception) {}
                }
            }

            runOnUiThread {
                val message = when {
                    savedCount > 0 && duplicateCount > 0 ->
                        "Saved $savedCount file(s) to Shared Inbox ($duplicateCount already present)"
                    savedCount > 0 ->
                        "Saved $savedCount file(s) to Todorbit Shared Inbox"
                    duplicateCount > 0 ->
                        "File(s) already in Todorbit Shared Inbox"
                    else -> "No files were saved"
                }
                Toast.makeText(applicationContext, message, Toast.LENGTH_SHORT).show()
                MainActivity.notifySharedInboxUpdated()
                finish()
            }
        } catch (e: Exception) {
            runOnUiThread {
                val errorMsg = e.message ?: "Failed to receive files"
                Toast.makeText(applicationContext, "Todorbit: $errorMsg", Toast.LENGTH_LONG).show()
                finish()
            }
        }
    }

    private fun loadExistingManifest(manifestFile: File): JSONArray {
        if (!manifestFile.exists()) return JSONArray()
        return try {
            val content = manifestFile.readText()
            val json = JSONObject(content)
            if (json.optInt("version") == 1) {
                json.optJSONArray("entries") ?: JSONArray()
            } else {
                JSONArray()
            }
        } catch (_: Exception) {
            JSONArray()
        }
    }

    private fun saveManifest(manifestFile: File, entries: JSONArray) {
        val root = JSONObject().apply {
            put("version", 1)
            put("entries", entries)
        }
        val uniqueStagingName = "${manifestFile.name}.${UUID.randomUUID()}.tmp"
        val staging = File(manifestFile.parentFile, uniqueStagingName)
        staging.writeText(root.toString())
        try {
            Files.move(
                staging.toPath(),
                manifestFile.toPath(),
                StandardCopyOption.ATOMIC_MOVE,
                StandardCopyOption.REPLACE_EXISTING
            )
        } catch (_: Exception) {
            if (!staging.renameTo(manifestFile)) {
                staging.copyTo(manifestFile, overwrite = true)
                staging.delete()
            }
        }
        if (!manifestFile.exists()) {
            throw IllegalStateException("Failed to publish manifest file")
        }
    }
}
