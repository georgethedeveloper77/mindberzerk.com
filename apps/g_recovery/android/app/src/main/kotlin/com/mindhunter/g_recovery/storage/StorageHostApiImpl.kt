package com.mindhunter.g_recovery.storage

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * The storage bridge.
 *
 * Same threading contract as the recovery bridge: a single worker, every Pigeon
 * callback posted back to the main looper. An overview walks the entire
 * MediaStore cursor, which is fast but never instant, and doing it on the
 * platform thread would drop frames on the tab it is drawing.
 */
internal class StorageHostApiImpl(context: Context) : StorageHostApi {

    private val app: Context = context.applicationContext
    private val worker: ExecutorService = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private val index = MediaIndex(app)
    private val thumbnailer = StorageThumbnailer(app)

    fun dispose() {
        worker.shutdownNow()
    }

    override fun overview(callback: (Result<StorageOverview>) -> Unit) {
        worker.execute {
            // Twelve folders. A phone can have hundreds, and a treemap of
            // hundreds of rectangles is a texture rather than information.
            reply(callback, index.overview(maxFolders = 12))
        }
    }

    override fun query(
        spec: StorageQuerySpec,
        callback: (Result<StorageQueryResult>) -> Unit,
    ) {
        worker.execute { reply(callback, index.query(spec)) }
    }

    override fun thumbnail(
        fileId: String,
        maxPixels: Long,
        callback: (Result<ByteArray?>) -> Unit,
    ) {
        worker.execute {
            val mediaId = index.mediaIdOf(fileId)
            if (mediaId == null) {
                reply(callback, null)
            } else {
                // Kind is not carried in the id, and asking MediaStore for it
                // would be a second query per thumbnail. "image" is passed
                // because the thumbnailer only uses it to reject audio and
                // documents, and loadThumbnail already returns null for those.
                reply(callback, thumbnailer.bytes(index.uriOf(mediaId), "image", maxPixels.toInt()))
            }
        }
    }

    override fun remove(
        fileIds: List<String>,
        permanent: Boolean,
        callback: (Result<List<StorageOutcome>>) -> Unit,
    ) {
        worker.execute {
            val out = fileIds.map { fileId ->
                val mediaId = index.mediaIdOf(fileId)
                if (mediaId == null) {
                    StorageOutcome(fileId, "notFound", "This file is no longer listed")
                } else {
                    apply(fileId, mediaId, permanent)
                }
            }
            reply(callback, out)
        }
    }

    /**
     * Trash by default, delete only when asked.
     *
     * The distinction is reported honestly in the status. Moving a file to the
     * OS trash gives the user thirty days to change their mind, and telling
     * them it was deleted when it was not would be the same overclaim this app
     * refuses to make in the other direction.
     */
    private fun apply(fileId: String, mediaId: Long, permanent: Boolean): StorageOutcome {
        val uri = index.uriOf(mediaId)
        return try {
            if (permanent) {
                val deleted = app.contentResolver.delete(uri, null)
                if (deleted > 0) {
                    StorageOutcome(fileId, "deleted", "Deleted permanently")
                } else {
                    StorageOutcome(fileId, "notFound", "Already gone")
                }
            } else {
                val values = android.content.ContentValues().apply {
                    put(MediaStore.Files.FileColumns.IS_TRASHED, 1)
                }
                val updated = app.contentResolver.update(uri, values, null)
                if (updated > 0) {
                    StorageOutcome(fileId, "trashed", "Moved to trash, 30 days to undo")
                } else {
                    StorageOutcome(fileId, "notFound", "Already gone")
                }
            }
        } catch (_: SecurityException) {
            StorageOutcome(fileId, "needsConsent", "Android wants you to confirm this one")
        } catch (error: Throwable) {
            StorageOutcome(fileId, "failed", error.message ?: "Could not change this file")
        }
    }

    private fun <T> reply(callback: (Result<T>) -> Unit, value: T) {
        main.post { callback(Result.success(value)) }
    }
}
