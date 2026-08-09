package com.mindhunter.g_recovery.recovery

import android.content.ContentUris
import android.content.Context
import android.database.Cursor
import android.provider.MediaStore

/**
 * Name search over files that are still on the device.
 *
 * Backed by MediaStore's own index rather than a directory walk, which is the
 * only reason this can run on every keystroke. A recursive search of shared
 * storage on a phone with sixty thousand files takes seconds; this takes
 * milliseconds because the OS already built the index.
 *
 * The trade is that it only sees what MediaStore knows about, which is media
 * plus anything an app registered. Documents dropped into a folder by a file
 * manager are usually there; a file inside another app's private directory
 * never is. Phase 6 adds the tree walk for the cases this misses.
 */
internal class LiveFileSearcher(private val context: Context) {

    private val collection = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)

    private val projection = arrayOf(
        MediaStore.Files.FileColumns._ID,
        MediaStore.Files.FileColumns.DISPLAY_NAME,
        MediaStore.Files.FileColumns.SIZE,
        MediaStore.Files.FileColumns.MIME_TYPE,
        MediaStore.Files.FileColumns.MEDIA_TYPE,
        MediaStore.Files.FileColumns.RELATIVE_PATH,
        MediaStore.Files.FileColumns.DATE_MODIFIED,
        MediaStore.Files.FileColumns.WIDTH,
        MediaStore.Files.FileColumns.HEIGHT,
        MediaStore.Files.FileColumns.DURATION,
    )

    fun search(query: String, limit: Int): List<RecoverableItem> {
        val term = query.trim()
        if (term.length < 2) return emptyList()

        val cursor = try {
            context.contentResolver.query(
                collection,
                projection,
                "${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ?",
                // Escaping matters: a user searching for "100%" would otherwise
                // hand SQL a wildcard and match the entire device.
                arrayOf("%${escape(term)}%"),
                "${MediaStore.Files.FileColumns.DATE_MODIFIED} DESC",
            )
        } catch (_: Throwable) {
            null
        } ?: return emptyList()

        val out = mutableListOf<RecoverableItem>()
        cursor.use {
            while (it.moveToNext() && out.size < limit) {
                read(it)?.let(out::add)
            }
        }
        return out
    }

    /**
     * LIKE treats percent and underscore as wildcards. Without a backslash
     * escape and an ESCAPE clause the safest thing is to strip them, which is
     * what this does: a search for a literal percent sign is vanishingly rare
     * next to a search that accidentally matches everything.
     */
    private fun escape(term: String): String =
        term.replace("%", "").replace("_", " ")

    private fun read(cursor: Cursor): RecoverableItem? {
        fun index(name: String) = cursor.getColumnIndex(name)
        fun longOrNull(name: String): Long? {
            val i = index(name)
            return if (i >= 0 && !cursor.isNull(i)) cursor.getLong(i) else null
        }
        fun stringOrNull(name: String): String? {
            val i = index(name)
            return if (i >= 0 && !cursor.isNull(i)) cursor.getString(i) else null
        }

        val id = longOrNull(MediaStore.Files.FileColumns._ID) ?: return null
        val uri = ContentUris.withAppendedId(collection, id)
        val kind = when (
            index(MediaStore.Files.FileColumns.MEDIA_TYPE).let {
                if (it >= 0) cursor.getInt(it) else -1
            }
        ) {
            MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE -> "image"
            MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO -> "video"
            MediaStore.Files.FileColumns.MEDIA_TYPE_AUDIO -> "audio"
            MediaStore.Files.FileColumns.MEDIA_TYPE_DOCUMENT -> "document"
            else -> "other"
        }

        return RecoverableItem(
            itemId = "live:$id",
            // The discriminator. Search renders one homogeneous list, and the UI
            // refuses Restore on anything from this source because it was never
            // lost in the first place.
            sourceId = SourceIds.LIVE_FILES,
            name = stringOrNull(MediaStore.Files.FileColumns.DISPLAY_NAME) ?: "Item $id",
            kind = kind,
            fidelity = "full",
            sizeBytes = longOrNull(MediaStore.Files.FileColumns.SIZE) ?: 0L,
            relativePath = stringOrNull(MediaStore.Files.FileColumns.RELATIVE_PATH),
            mimeType = stringOrNull(MediaStore.Files.FileColumns.MIME_TYPE),
            dateDeletedMillis = null,
            dateAddedMillis = longOrNull(MediaStore.Files.FileColumns.DATE_MODIFIED)
                ?.let { it * 1000 },
            expiresInDays = null,
            previewUri = uri.toString(),
            width = longOrNull(MediaStore.Files.FileColumns.WIDTH),
            height = longOrNull(MediaStore.Files.FileColumns.HEIGHT),
            durationMillis = longOrNull(MediaStore.Files.FileColumns.DURATION),
            origin = null,
            role = null,
        )
    }
}
