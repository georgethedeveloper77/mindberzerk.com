package com.mindhunter.g_recovery.storage

import android.content.Context
import android.content.Intent
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
    private val directories = DirectoryReader(app)

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
        kind: String,
        name: String?,
        mimeType: String?,
        callback: (Result<ByteArray?>) -> Unit,
    ) {
        worker.execute {
            val mediaId = index.mediaIdOf(fileId)
            if (mediaId == null) {
                reply(callback, null)
            } else {
                // The kind arrives from Dart, which already has it. Asking
                // MediaStore instead would be one extra cursor per cell of a
                // scrolling grid, and the previous version dodged that by
                // hardcoding "image", which quietly made audio artwork and PDF
                // pages unreachable.
                reply(
                    callback,
                    thumbnailer.bytes(
                        index.uriOf(mediaId),
                        kind,
                        maxPixels.toInt(),
                        name,
                        mimeType,
                    ),
                )
            }
        }
    }

    override fun contentUri(fileId: String, callback: (Result<String?>) -> Unit) {
        worker.execute {
            val mediaId = index.mediaIdOf(fileId)
            reply(callback, mediaId?.let { index.uriOf(it).toString() })
        }
    }

    /**
     * Bytes for the formats Dart renders itself.
     *
     * ─── THE CAP IS NOT A SUGGESTION ─────────────────────────────────────────
     *
     * Checked BEFORE reading, from the stream's own available length, so a
     * three hundred megabyte log is refused rather than pulled into memory and
     * then discarded. The caller already knows the file size and can tell "too
     * big" from "gone" without another round trip.
     */
    override fun readBytes(
        fileId: String,
        maxBytes: Long,
        callback: (Result<ByteArray?>) -> Unit,
    ) {
        worker.execute {
            val mediaId = index.mediaIdOf(fileId)
            if (mediaId == null) {
                reply(callback, null)
                return@execute
            }
            val bytes = runCatching {
                app.contentResolver.openInputStream(index.uriOf(mediaId))?.use { stream ->
                    if (stream.available() > maxBytes) return@use null
                    // readBytes on the stream rather than a manual loop: it
                    // honours available() growing mid read, which a fixed
                    // buffer sized once does not.
                    val read = stream.readBytes()
                    if (read.size > maxBytes) null else read
                }
            }.getOrNull()
            reply(callback, bytes)
        }
    }

    /**
     * Hands the file to another app.
     *
     * FLAG_GRANT_READ_URI_PERMISSION is what makes this work at all. Without
     * it the chooser opens and the target app is denied the URI it was just
     * given, which the user reads as a fault in this app rather than in the
     * one that failed.
     *
     * NEW_TASK because this is started from an application context, which has
     * no task of its own to place the activity in.
     */
    override fun volumes(callback: (Result<List<VolumeEntry>>) -> Unit) {
        worker.execute { reply(callback, directories.volumes()) }
    }

    override fun listDirectory(
        path: String?,
        callback: (Result<List<DirEntry>>) -> Unit,
    ) {
        worker.execute { reply(callback, directories.list(path)) }
    }

    override fun openExternally(fileId: String, callback: (Result<Boolean>) -> Unit) {
        val mediaId = index.mediaIdOf(fileId)
        if (mediaId == null) {
            main.post { callback(Result.success(false)) }
            return
        }

        val uri = index.uriOf(mediaId)
        val type = app.contentResolver.getType(uri) ?: "*/*"
        val view = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, type)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

        val chooser = Intent.createChooser(view, null)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

        val ok = runCatching {
            app.startActivity(chooser)
            true
        }.getOrDefault(false)
        main.post { callback(Result.success(ok)) }
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
