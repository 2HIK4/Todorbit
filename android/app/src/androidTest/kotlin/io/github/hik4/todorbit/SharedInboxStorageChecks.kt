package io.github.hik4.todorbit

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.system.Os
import org.json.JSONArray
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.util.UUID
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

internal object SharedInboxStorageChecks {
    fun run(cache: File): Int {
        val root = File(cache, "inbox-check-" + UUID.randomUUID())
        try {
            concurrentOperations(File(root, "concurrent"))
            publicationFailure(File(root, "failed-publication"))
            interruptedImports(File(root, "interrupted-imports"))
            multipleStreams()
            return 4
        } finally {
            root.deleteRecursively()
        }
    }

    private fun <T> enqueue(action: () -> T): CompletableFuture<T> {
        val result = CompletableFuture<T>()
        SharedInboxWorker.enqueue {
            try {
                result.complete(action())
            } catch (error: Throwable) {
                result.completeExceptionally(error)
            }
        }
        return result
    }

    private fun <T> CompletableFuture<T>.await(): T = get(10, TimeUnit.SECONDS)

    private fun importText(storage: SharedInboxStorage, text: String) =
        storage.importFile("$text.txt", "text/plain") { text.byteInputStream() }

    private fun names(storage: SharedInboxStorage): Set<String> {
        val entries = JSONArray(storage.list())
        return (0 until entries.length()).map { entries.getJSONObject(it).getString("displayName") }.toSet()
    }

    private fun concurrentOperations(root: File) {
        val storage = SharedInboxStorage(root)
        val old = enqueue { importText(storage, "old") }.await().entry
        val started = CountDownLatch(1)
        val release = CountDownLatch(1)
        val first = enqueue {
            storage.importFile("first.txt", "text/plain") {
                started.countDown()
                check(release.await(10, TimeUnit.SECONDS))
                "first".byteInputStream()
            }
        }
        try {
            check(started.await(10, TimeUnit.SECONDS))
            val remove = enqueue { storage.delete(setOf(old.getString("id"))) }
            val cleanup = enqueue { storage.recover() }
            val second = enqueue { importText(storage, "second") }
            check(!remove.isDone && !cleanup.isDone && !second.isDone)
            release.countDown()
            check(!first.await().duplicate)
            remove.await()
            cleanup.await()
            check(!second.await().duplicate)
            check(enqueue { names(storage) }.await() == setOf("first.txt", "second.txt"))
            val duplicate = enqueue { importText(storage, "first") }.await()
            check(duplicate.duplicate && duplicate.entry.getString("id") == first.await().entry.getString("id"))
        } finally {
            release.countDown()
        }
    }

    private fun publicationFailure(root: File) {
        val storage = SharedInboxStorage(root)
        val original = enqueue { importText(storage, "original") }.await().entry
        val manifest = File(root, "shared_inbox.json")
        val prior = manifest.readBytes()
        val broken = SharedInboxStorage(root) { from, to ->
            if (to == manifest) throw IOException("Injected manifest publication failure")
            Os.rename(from.absolutePath, to.absolutePath)
        }
        check(runCatching { enqueue { importText(broken, "uncommitted") }.await() }.isFailure)
        check(manifest.readBytes().contentEquals(prior))
        check(runCatching { enqueue { broken.delete(setOf(original.getString("id"))) }.await() }.isFailure)
        check(File(root, original.getString("relativePath")).isFile)
        check(enqueue { names(SharedInboxStorage(root)) }.await() == setOf("original.txt"))
        check(File(root, "files").listFiles()?.size == 1)
    }

    private fun interruptedImports(root: File) {
        val storage = SharedInboxStorage(root)
        enqueue { importText(storage, "committed") }.await()
        check(runCatching {
            enqueue {
                storage.importFile("broken.txt", "text/plain") {
                    object : InputStream() {
                        override fun read(): Int = throw IOException("Injected stream interruption")
                    }
                }
            }.await()
        }.isFailure)
        val incomplete = File(root, "staging/" + UUID.randomUUID() + ".tmp")
        val unindexed = File(root, "files/" + UUID.randomUUID() + "_unindexed.txt")
        val stagedManifest = File(root, "shared_inbox.json.new")
        // Equivalent on-disk states after killing the process before manifest rename.
        listOf(incomplete, unindexed, stagedManifest).forEach { it.writeText("interrupted") }
        check(enqueue { names(SharedInboxStorage(root)) }.await() == setOf("committed.txt"))
        check(listOf(incomplete, unindexed, stagedManifest).none { it.exists() })
    }

    private fun multipleStreams() {
        val first = Uri.parse("content://sharing.example/first")
        val second = Uri.parse("content://sharing.example/second")
        val third = Uri.parse("content://sharing.example/third")
        val intent = Intent(Intent.ACTION_SEND_MULTIPLE)
            .putParcelableArrayListExtra(Intent.EXTRA_STREAM, arrayListOf(first, second))
        intent.clipData = ClipData.newRawUri("files", second).apply { addItem(ClipData.Item(third)) }
        check(sharedInboxUris(intent) == listOf(first, second, third))
    }
}
