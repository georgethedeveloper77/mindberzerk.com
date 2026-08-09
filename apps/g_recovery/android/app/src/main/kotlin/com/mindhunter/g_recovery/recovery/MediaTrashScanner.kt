package com.mindhunter.g_recovery.recovery

import android.content.ContentUris
import android.content.Context
import android.database.Cursor
import android.os.Bundle
import android.provider.MediaStore
import java.util.concurrent.TimeUnit

/**
 * The OS trash, read through MediaStore.
 *
 * The highest fidelity source there is: these are the original files, byte for
 * byte, and restoring one puts it back exactly where it was. Everything else in
 * this app is a consolation prize by comparison.
 *
 * Queried through MediaStore.Files rather than per media type so images, video,
 * audio and documents come back in one pass with one cursor.
 */
internal class MediaTrashScanner(private val context: Context) {

    private val collection = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)

    private val projection = arrayOf(
        MediaStore.Files.FileColumns._ID,
        MediaStore.Files.FileColumns.DISPLAY_NAME,
        MediaStore.Files.FileColumns.SIZE,
        MediaStore.Files.FileColumns.MIME_TYPE,
        MediaStore.Files.FileColumns.MEDIA_TYPE,
        MediaStore.Files.FileColumns.RELATIVE_PATH,
        MediaStore.Files.FileColumns.DATE_ADDED,
        MediaStore.Files.FileColumns.DATE_EXPIRES,
        MediaStore.Files.FileColumns.WIDTH,
        MediaStore.Files.FileColumns.HEIGHT,
        MediaStore.Files.FileColumns.DURATION,
    )

    /**
     * Totals plus the per kind breakdown, in ONE cursor pass.
     *
     * Home labels six category tiles from this, and doing it here rather than in
     * a second query is what keeps the pre-scan a counting operation. It runs
     * while the user is picking a theme in onboarding, so it has to stay cheap
     * on a budget device.
     */
    fun count(): Tally {
        val tally = Tally()
        query()?.use { cursor ->
            val size = cursor.getColumnIndex(MediaStore.Files.FileColumns.SIZE)
            while (cursor.moveToNext()) {
                tally.items++
                if (size >= 0) tally.bytes += cursor.getLong(size)
                tally.add(kindOf(cursor))
            }
        }
        return tally
    }

    internal class Tally {
        var items = 0
        var bytes = 0L
        var images = 0
        var videos = 0
        var audio = 0
        var documents = 0
        var other = 0

        fun add(kind: String) {
            when (kind) {
                "image" -> images++
                "video" -> videos++
                "audio" -> audio++
                "document" -> documents++
                else -> other++
            }
        }
    }

    /**
     * Full walk. [onFound] is called per row so results stream: a user who spots
     * the photo they came for can restore it before the scan finishes.
     */
    fun scan(
        index: RecoveryIndex,
        sourceId: String,
        isCancelled: () -> Boolean,
        onFound: (scanned: Int, total: Int) -> Unit,
    ) {
        val cursor = query() ?: return
        cursor.use {
            val total = it.count
            var scanned = 0
            while (it.moveToNext()) {
                if (isCancelled()) return
                read(it)?.let { record -> index.put(sourceId, record) }
                scanned++
                onFound(scanned, total)
            }
        }
    }

    /**
     * MATCH_INCLUDE is the only way to see trashed rows at all.
     *
     * And it is worth being precise about what it buys: WITHOUT All Files Access
     * this returns only rows this app itself trashed, which for a recovery app is
     * always none. The permission is what makes the query meaningful, not what
     * makes it legal.
     */
    private fun query(): Cursor? {
        val args = Bundle().apply {
            putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_ONLY)
            putString(
                android.content.ContentResolver.QUERY_ARG_SQL_SORT_ORDER,
                "${MediaStore.Files.FileColumns.DATE_EXPIRES} ASC",
            )
        }
        return try {
            context.contentResolver.query(collection, projection, args, null)
        } catch (_: Throwable) {
            // SecurityException before the grant, and a handful of OEM providers
            // throw on unknown query args. Both mean no rows, not a crash.
            null
        }
    }

    private fun read(cursor: Cursor): RecoveryIndex.Record? {
        fun col(name: String) = cursor.getColumnIndex(name)
        fun longOrNull(name: String): Long? {
            val i = col(name)
            return if (i >= 0 && !cursor.isNull(i)) cursor.getLong(i) else null
        }
        fun stringOrNull(name: String): String? {
            val i = col(name)
            return if (i >= 0 && !cursor.isNull(i)) cursor.getString(i) else null
        }

        val id = longOrNull(MediaStore.Files.FileColumns._ID) ?: return null
        val size = longOrNull(MediaStore.Files.FileColumns.SIZE) ?: 0L
        val expires = longOrNull(MediaStore.Files.FileColumns.DATE_EXPIRES)
        val added = longOrNull(MediaStore.Files.FileColumns.DATE_ADDED)
        val uri = ContentUris.withAppendedId(collection, id)

        return RecoveryIndex.Record.Media(
            mediaId = id,
            item = RecoverableItem(
                itemId = "media:$id",
                sourceId = SourceIds.MEDIA_TRASH,
                name = stringOrNull(MediaStore.Files.FileColumns.DISPLAY_NAME)
                    ?: "Item $id",
                kind = kindOf(cursor),
                fidelity = "full",
                sizeBytes = size,
                relativePath = stringOrNull(MediaStore.Files.FileColumns.RELATIVE_PATH),
                mimeType = stringOrNull(MediaStore.Files.FileColumns.MIME_TYPE),
                // DATE_EXPIRES is when the OS will remove it. Working backwards
                // from it is more accurate than DATE_ADDED plus an assumed
                // retention, because retention is per OEM and this is the number
                // the system will actually act on.
                dateDeletedMillis = expires?.let {
                    TimeUnit.SECONDS.toMillis(it) - TimeUnit.DAYS.toMillis(30)
                },
                dateAddedMillis = added?.let(TimeUnit.SECONDS::toMillis),
                expiresInDays = expires?.let {
                    val remaining = TimeUnit.SECONDS.toMillis(it) - System.currentTimeMillis()
                    if (remaining <= 0) 0L else TimeUnit.MILLISECONDS.toDays(remaining)
                },
                previewUri = uri.toString(),
                width = longOrNull(MediaStore.Files.FileColumns.WIDTH),
                height = longOrNull(MediaStore.Files.FileColumns.HEIGHT),
                durationMillis = longOrNull(MediaStore.Files.FileColumns.DURATION),
                // Null: the relative path already says where it came from, and
                // an OS trash item is always role trash.
                origin = null,
                role = "trash",
            ),
        )
    }

    private fun kindOf(cursor: Cursor): String {
        val i = cursor.getColumnIndex(MediaStore.Files.FileColumns.MEDIA_TYPE)
        return when (if (i >= 0) cursor.getInt(i) else -1) {
            MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE -> "image"
            MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO -> "video"
            MediaStore.Files.FileColumns.MEDIA_TYPE_AUDIO -> "audio"
            MediaStore.Files.FileColumns.MEDIA_TYPE_DOCUMENT -> "document"
            else -> "other"
        }
    }
}

internal object SourceIds {
    const val MEDIA_TRASH = "media_trash"
    const val APP_TRASH = "app_trash"
    const val THUMBNAILS = "thumbnails"

    /**
     * Files that were never deleted, returned by search.
     *
     * Shares RecoverableItem with the sources above so search renders one list.
     * The UI branches on this id to hide Restore, because offering to recover a
     * file that is sitting exactly where the user left it is the kind of thing
     * that makes an app feel like it is guessing.
     */
    const val LIVE_FILES = "live_files"
}
