package io.github.hik4.todorbit

import android.system.Os
import android.system.OsConstants
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.InputStream
import java.security.MessageDigest
import java.time.Instant
import java.util.UUID
import java.util.concurrent.Executors

// Both activities run in the same process. Manifest reads, publication and
// recovery share this worker, including when Flutter is not running.
internal object SharedInboxWorker {
    private val executor = Executors.newSingleThreadExecutor()

    fun enqueue(action: () -> Unit) {
        executor.execute(action)
    }
}

internal class SharedInboxStorage(
    private val root: File,
    private val rename: (File, File) -> Unit = { from, to ->
        Os.rename(from.absolutePath, to.absolutePath)
    },
) {
    companion object {
        private const val MAX_FILE_BYTES = 32L * 1024 * 1024
        private val managedFile = Regex("[0-9a-fA-F-]{36}_.+")
        private val stagingFile = Regex("[0-9a-fA-F-]{36}[.]tmp")
    }

    data class Import(val entry: JSONObject, val duplicate: Boolean)

    private val files = File(root, "files")
    private val staging = File(root, "staging")
    private val manifest = File(root, "shared_inbox.json")
    private val nextManifest = File(root, "shared_inbox.json.new")

    private fun ensureDirectory(directory: File) {
        if (directory.isDirectory) return
        ensureDirectory(checkNotNull(directory.parentFile))
        check(directory.mkdir() || directory.isDirectory) { "Cannot create Shared Inbox directory" }
        syncDirectory(checkNotNull(directory.parentFile))
    }

    private fun syncDirectory(directory: File) {
        val fd = Os.open(directory.absolutePath, OsConstants.O_RDONLY, 0)
        try {
            Os.fsync(fd)
        } finally {
            Os.close(fd)
        }
    }

    private fun entryFile(entry: JSONObject): File {
        val relativePath = entry.getString("relativePath")
        require(relativePath.startsWith("files/"))
        val name = relativePath.removePrefix("files/")
        require(name.isNotBlank() && name != "." && name != ".." && !name.contains('/'))
        return File(files, name).also { require(it.canonicalFile.parentFile == files.canonicalFile) }
    }

    private fun entries(): List<JSONObject> {
        if (!manifest.exists()) return emptyList()
        val contents = JSONObject(manifest.readText())
        check(contents.getInt("version") == 1) { "Unsupported Shared Inbox manifest" }
        val array = contents.getJSONArray("entries")
        return List(array.length()) { array.getJSONObject(it).also { entry -> entryFile(entry) } }
    }

    private fun publish(entries: List<JSONObject>) {
        ensureDirectory(root)
        val contents = JSONObject().put("version", 1).put("entries", JSONArray(entries))
        try {
            nextManifest.outputStream().use { output ->
                output.write(contents.toString().toByteArray(Charsets.UTF_8))
                output.fd.sync()
            }
            rename(nextManifest, manifest)
            syncDirectory(root)
        } finally {
            nextManifest.delete()
        }
    }

    fun list(): String {
        val entries = entries()
        recover(entries)
        return JSONArray(entries.filter { entryFile(it).isFile }).toString()
    }

    fun importFile(name: String, mimeType: String, open: () -> InputStream): Import {
        val entries = entries()
        ensureDirectory(files)
        ensureDirectory(staging)

        val id = UUID.randomUUID().toString()
        val safeName = name.replace(Regex("[^a-zA-Z0-9._ -]"), "_")
            .trim().takeLast(120).takeUnless { it.isBlank() || it == "." || it == ".." }
            ?: "shared_file"
        val staged = File(staging, "$id.tmp")
        val digest = MessageDigest.getInstance("SHA-256")
        var size = 0L
        try {
            open().use { input ->
                staged.outputStream().use { output ->
                    val buffer = ByteArray(65536)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        size += count
                        require(size <= MAX_FILE_BYTES) { "File exceeds 32 MiB limit" }
                        digest.update(buffer, 0, count)
                        output.write(buffer, 0, count)
                    }
                    output.fd.sync()
                }
            }
            val sha = digest.digest().joinToString("") { "%02x".format(it) }
            entries.firstOrNull {
                it.optString("sha256") == sha && it.optLong("byteSize") == size &&
                    entryFile(it).isFile
            }?.let {
                syncDirectory(root)
                return Import(it, true)
            }

            val relative = "files/" + id + "_" + safeName
            rename(staged, File(root, relative))
            syncDirectory(files)
            val entry = JSONObject()
                .put("id", id)
                .put("displayName", safeName)
                .put("relativePath", relative)
                .put("mimeType", mimeType)
                .put("byteSize", size)
                .put("sha256", sha)
                .put("receivedAt", Instant.now().toString())
            // Recovery uses the durable manifest, including when publication
            // failed after the rename and before the directory fsync.
            publish(listOf(entry) + entries)
            return Import(entry, false)
        } finally {
            staged.delete()
        }
    }

    fun delete(ids: Set<String>?) {
        val current = entries()
        val (removed, kept) = current.partition { ids == null || it.getString("id") in ids }
        if (removed.isEmpty()) return
        publish(kept)
        removed.forEach { entryFile(it).delete() }
    }

    fun recover() = recover(entries())

    private fun recover(entries: List<JSONObject>) {
        val retained = entries.map { entryFile(it).name }.toSet()
        // Make the current manifest durable before collecting omitted files.
        if (root.isDirectory) syncDirectory(root)
        nextManifest.delete()
        staging.listFiles()?.filter { it.isFile && stagingFile.matches(it.name) }?.forEach { it.delete() }
        files.listFiles()?.filter {
            it.isFile && managedFile.matches(it.name) && it.name !in retained
        }?.forEach { it.delete() }
    }
}
