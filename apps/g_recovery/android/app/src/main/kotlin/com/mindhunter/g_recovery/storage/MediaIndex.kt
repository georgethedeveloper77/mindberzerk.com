package com.mindhunter.g_recovery.storage

import android.content.ContentUris
import android.content.Context
import android.database.Cursor
import android.os.Environment
import android.os.StatFs
import android.provider.MediaStore
import java.util.Calendar
import java.util.concurrent.TimeUnit

/**
 * Everything the Storage tab knows, read from MediaStore in ONE cursor pass.
 *
 * MediaStore rather than a directory walk, and the trade is worth stating. A
 * recursive walk of shared storage on a phone with sixty thousand files takes
 * tens of seconds and burns battery; this takes well under a second because the
 * OS already maintains the index. What it costs is coverage: MediaStore knows
 * about media and about anything an app registered, and never about another
 * app's private directory.
 *
 * That gap is reported rather than hidden. `indexedBytes` is what we can account
 * for, `usedBytes` is what the volume says, and the UI draws the difference as
 * its own segment. A cleaner app quietly folds the gap into a category to make
 * its numbers look bigger, which is how "1.2 GB of junk" gets invented.
 */
internal class MediaIndex(private val context: Context) {

    private val collection = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)

    private val projection = arrayOf(
        MediaStore.Files.FileColumns._ID,
        MediaStore.Files.FileColumns.DISPLAY_NAME,
        MediaStore.Files.FileColumns.SIZE,
        MediaStore.Files.FileColumns.MIME_TYPE,
        MediaStore.Files.FileColumns.MEDIA_TYPE,
        MediaStore.Files.FileColumns.RELATIVE_PATH,
        MediaStore.Files.FileColumns.DATE_MODIFIED,
        MediaStore.Files.FileColumns.DURATION,
    )

    fun volume(): VolumeInfo {
        val stat = try {
            StatFs(Environment.getDataDirectory().absolutePath)
        } catch (_: Throwable) {
            null
        }
        val total = stat?.let { it.blockCountLong * it.blockSizeLong } ?: 0L
        val free = stat?.let { it.availableBlocksLong * it.blockSizeLong } ?: 0L
        return VolumeInfo(
            totalBytes = total,
            freeBytes = free,
            usedBytes = (total - free).coerceAtLeast(0),
        )
    }

    fun overview(maxFolders: Int): StorageOverview {
        val kinds = LinkedHashMap<String, Agg>()
        val folders = LinkedHashMap<String, Agg>()
        val years = LinkedHashMap<Int, Agg>()
        var bytes = 0L
        var count = 0L

        query(null, null)?.use { cursor ->
            val sizeIndex = cursor.getColumnIndex(MediaStore.Files.FileColumns.SIZE)
            val pathIndex = cursor.getColumnIndex(MediaStore.Files.FileColumns.RELATIVE_PATH)
            val dateIndex = cursor.getColumnIndex(MediaStore.Files.FileColumns.DATE_MODIFIED)
            while (cursor.moveToNext()) {
                val size = if (sizeIndex >= 0) cursor.getLong(sizeIndex) else 0L
                if (size <= 0) continue
                bytes += size
                count++
                kinds.getOrPut(kindOf(cursor)) { Agg() }.add(size)
                val path = if (pathIndex >= 0) cursor.getString(pathIndex) else null
                folders.getOrPut(path ?: "Other/") { Agg() }.add(size)
                val seconds = if (dateIndex >= 0) cursor.getLong(dateIndex) else 0L
                years.getOrPut(yearOf(seconds)) { Agg() }.add(size)
            }
        }

        return StorageOverview(
            volume = volume(),
            kinds = kinds.entries
                .sortedByDescending { it.value.bytes }
                .map { KindUsage(it.key, it.value.count, it.value.bytes) },
            folders = folders.entries
                .sortedByDescending { it.value.bytes }
                .take(maxFolders)
                .map {
                    FolderUsage(
                        path = it.key,
                        label = label(it.key),
                        itemCount = it.value.count,
                        totalBytes = it.value.bytes,
                    )
                },
            ages = years.entries
                .filter { it.key > 1980 }
                .sortedBy { it.key }
                .map { AgeBucket(it.key.toLong(), it.value.count, it.value.bytes) },
            indexedBytes = bytes,
            indexedCount = count,
            complete = true,
        )
    }

    fun query(spec: StorageQuerySpec): StorageQueryResult {
        val where = StringBuilder()
        val args = mutableListOf<String>()

        // Size, age and name are pushed into SQL. Kind is filtered in Kotlin
        // because MEDIA_TYPE is an int set and expressing it as SQL for an
        // arbitrary subset is more fragile than one comparison per row.
        spec.minBytes?.let {
            where.append("${MediaStore.Files.FileColumns.SIZE} >= ?")
            args.add(it.toString())
        }
        spec.olderThanDays?.let {
            if (where.isNotEmpty()) where.append(" AND ")
            val cutoff = (System.currentTimeMillis() - TimeUnit.DAYS.toMillis(it)) / 1000
            where.append("${MediaStore.Files.FileColumns.DATE_MODIFIED} <= ?")
            args.add(cutoff.toString())
        }
        spec.folderPrefix?.let {
            if (where.isNotEmpty()) where.append(" AND ")
            where.append("${MediaStore.Files.FileColumns.RELATIVE_PATH} LIKE ?")
            args.add("${escape(it)}%")
        }
        spec.nameContains?.let {
            if (where.isNotEmpty()) where.append(" AND ")
            where.append("${MediaStore.Files.FileColumns.DISPLAY_NAME} LIKE ?")
            args.add("%${escape(it)}%")
        }

        val wanted = spec.kinds.toSet()
        val files = mutableListOf<StorageFile>()
        val folders = LinkedHashMap<String, Agg>()
        val years = LinkedHashMap<Int, Agg>()
        var matchCount = 0L
        var matchBytes = 0L

        query(
            where.toString().ifEmpty { null },
            args.toTypedArray().takeIf { it.isNotEmpty() },
            spec.sort,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val kind = kindOf(cursor)
                if (wanted.isNotEmpty() && kind !in wanted) continue
                val file = read(cursor, kind) ?: continue

                matchCount++
                matchBytes += file.sizeBytes
                folders.getOrPut(file.relativePath ?: "Other/") { Agg() }
                    .add(file.sizeBytes)
                years.getOrPut(yearOf((file.dateModifiedMillis ?: 0L) / 1000)) { Agg() }
                    .add(file.sizeBytes)

                // Counted for every match, collected only up to the limit. The
                // headline figure stays true even when the list is truncated,
                // which is the whole point of separating them.
                if (files.size < spec.limit) files.add(file)
            }
        }

        return StorageQueryResult(
            files = files,
            matchCount = matchCount,
            matchBytes = matchBytes,
            folders = folders.entries
                .sortedByDescending { it.value.bytes }
                .take(8)
                .map {
                    FolderUsage(it.key, label(it.key), it.value.count, it.value.bytes)
                },
            ages = years.entries
                .filter { it.key > 1980 }
                .sortedBy { it.key }
                .map { AgeBucket(it.key.toLong(), it.value.count, it.value.bytes) },
        )
    }

    fun mediaIdOf(fileId: String): Long? =
        fileId.removePrefix("file:").toLongOrNull()

    fun uriOf(mediaId: Long) = ContentUris.withAppendedId(collection, mediaId)

    private fun query(
        where: String?,
        args: Array<String>?,
        sort: String = "largest",
    ): Cursor? = try {
        context.contentResolver.query(
            collection,
            projection,
            where,
            args,
            orderFor(sort),
        )
    } catch (_: Throwable) {
        null
    }

    /**
     * SQL for a sort, and the default matters.
     *
     * An unknown value falls back to largest rather than throwing. This string
     * crosses a bridge from Dart, and a typo in a caller should give the wrong
     * order rather than an empty screen.
     *
     * The order is applied by the PROVIDER, over every matching row, not over
     * the page. Sorting after the limit would return the smallest of the largest.
     */
    private fun orderFor(sort: String): String = when (sort) {
        "newest" -> "${MediaStore.Files.FileColumns.DATE_MODIFIED} DESC"
        "oldest" -> "${MediaStore.Files.FileColumns.DATE_MODIFIED} ASC"
        "smallest" -> "${MediaStore.Files.FileColumns.SIZE} ASC"
        // COLLATE NOCASE, or every capitalised name sorts above every lowercase
        // one and the list looks shuffled to anyone who did not expect ASCII
        // ordering.
        "name" -> "${MediaStore.Files.FileColumns.DISPLAY_NAME} COLLATE NOCASE ASC"
        else -> "${MediaStore.Files.FileColumns.SIZE} DESC"
    }

    private fun read(cursor: Cursor, kind: String): StorageFile? {
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
        val size = longOrNull(MediaStore.Files.FileColumns.SIZE) ?: 0L
        if (size <= 0) return null

        return StorageFile(
            fileId = "file:$id",
            name = stringOrNull(MediaStore.Files.FileColumns.DISPLAY_NAME) ?: "Item $id",
            kind = kind,
            sizeBytes = size,
            relativePath = stringOrNull(MediaStore.Files.FileColumns.RELATIVE_PATH),
            mimeType = stringOrNull(MediaStore.Files.FileColumns.MIME_TYPE),
            dateModifiedMillis = longOrNull(MediaStore.Files.FileColumns.DATE_MODIFIED)
                ?.let { TimeUnit.SECONDS.toMillis(it) },
            durationMillis = longOrNull(MediaStore.Files.FileColumns.DURATION),
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

    private fun yearOf(epochSeconds: Long): Int {
        if (epochSeconds <= 0) return 0
        val calendar = Calendar.getInstance()
        calendar.timeInMillis = TimeUnit.SECONDS.toMillis(epochSeconds)
        return calendar.get(Calendar.YEAR)
    }

    /** "DCIM/Camera/" becomes "DCIM/Camera". Root files become "Internal". */
    private fun label(path: String): String {
        val trimmed = path.trim('/')
        return if (trimmed.isEmpty()) "Internal" else trimmed
    }

    /** LIKE wildcards stripped, so a query for "100%" cannot match everything. */
    private fun escape(term: String): String =
        term.replace("%", "").replace("_", " ")

    private class Agg {
        var bytes = 0L
        var count = 0L

        fun add(size: Long) {
            bytes += size
            count++
        }
    }
}
