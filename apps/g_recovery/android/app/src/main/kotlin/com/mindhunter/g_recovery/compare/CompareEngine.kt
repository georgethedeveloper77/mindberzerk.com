package com.mindhunter.g_recovery.compare

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max

/**
 * FINDING WHAT IS THE SAME AND WHAT IS SOFT.
 *
 * ─── THE ORDER IS THE OPTIMISATION ───────────────────────────────────────────
 *
 * Exact duplicates are found in three widening steps, and the order matters more
 * than any of the individual comparisons:
 *
 *   1. GROUP BY SIZE. Two files of different lengths cannot be identical, and
 *      this is free: MediaStore already knows every size. On a typical phone it
 *      eliminates upward of ninety percent of pairs before a single byte is
 *      read.
 *   2. HASH THE FIRST 64 KB. Cheap, and separates files that merely happen to
 *      share a length.
 *   3. HASH THE WHOLE FILE, only where the head already matched. This is the
 *      expensive step and it runs on almost nothing.
 *
 * Skipping straight to a full hash of every file would read the entire library
 * from disk to answer a question that size alone settles for most of it.
 *
 * ─── SIMILAR AND BLUR SHARE ONE DECODE ───────────────────────────────────────
 *
 * Both need the image decoded at a small size, which is the whole cost of the
 * scan. Doing them in separate passes would decode every photo twice for no
 * gain, so one pass computes both.
 *
 * ─── IT NEVER DELETES ────────────────────────────────────────────────────────
 *
 * Nothing here removes a file or marks one for removal. It reports groups and
 * suggests a keeper; every decision is the user's, made on a screen where they
 * can see what they are choosing between.
 */
internal class CompareEngine(context: Context) {

    private val app: Context = context.applicationContext
    private val collection =
        MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)

    /** Working size for the hash and the sharpness measure. */
    private val workingSize = 256

    /**
     * Under this many differing bits, two photos are the same picture.
     *
     * Ten out of sixty four. Chosen rather than derived: below about six only
     * re-encodings match, and above about sixteen a beach photo starts matching
     * a different beach photo. Ten catches the burst, the crop and the
     * re-export while leaving genuinely different pictures apart.
     */
    private val similarThreshold = 10

    fun run(
        maxImages: Int,
        blurThreshold: Double,
        cancelled: AtomicBoolean,
        onProgress: (Int, Int, Int) -> Unit,
    ): Triple<List<CompareGroup>, List<BlurredImage>, Int> {
        val rows = readRows(maxImages)
        val groups = mutableListOf<CompareGroup>()
        val blurred = mutableListOf<BlurredImage>()

        groups += exactGroups(rows, cancelled) { scanned ->
            onProgress(scanned, rows.size, groups.size)
        }
        if (cancelled.get()) {
            return Triple(groups, blurred, rows.size)
        }

        // Files already in an exact group are left out of the similar pass. Two
        // byte identical copies are trivially similar as well, and reporting
        // them twice would let a user free the same space in two places and
        // wonder why the total never dropped.
        val claimed = groups.flatMap { it.fileIds }.toHashSet()
        val remaining = rows.filter { it.fileId !in claimed && it.kind == "image" }

        val hashes = mutableListOf<Pair<Row, Long>>()
        var scanned = 0

        for (row in remaining) {
            if (cancelled.get()) break
            val bitmap = decode(row.uri) ?: continue

            hashes += row to Perceptual.dHash(bitmap)

            val sharp = Perceptual.sharpness(bitmap, workingSize)
            if (sharp < blurThreshold) {
                blurred += BlurredImage(
                    fileId = row.fileId,
                    sharpness = sharp,
                    sizeBytes = row.size,
                )
            }
            bitmap.recycle()

            scanned++
            if (scanned % 20 == 0) {
                onProgress(scanned, remaining.size, groups.size + blurred.size)
            }
        }

        groups += similarGroups(hashes)
        onProgress(remaining.size, remaining.size, groups.size + blurred.size)

        return Triple(groups, blurred, rows.size)
    }

    /**
     * Size, then head, then whole file.
     *
     * Each step only runs on what survived the last, which is why a library of
     * ten thousand photos reads a few dozen files in full rather than all of
     * them.
     */
    private fun exactGroups(
        rows: List<Row>,
        cancelled: AtomicBoolean,
        onProgress: (Int) -> Unit,
    ): List<CompareGroup> {
        val bySize = rows.groupBy { it.size }.filter { it.value.size > 1 }
        val out = mutableListOf<CompareGroup>()
        var seen = 0

        for ((_, candidates) in bySize) {
            if (cancelled.get()) return out

            val byHead = candidates.groupBy { digest(it.uri, HEAD_BYTES) }
            for ((head, sameHead) in byHead) {
                if (head == null || sameHead.size < 2) continue
                if (cancelled.get()) return out

                val byFull = sameHead.groupBy { digest(it.uri, Int.MAX_VALUE) }
                for ((full, identical) in byFull) {
                    if (full == null || identical.size < 2) continue

                    val sorted = identical.sortedByDescending { it.size }
                    val total = sorted.sumOf { it.size }
                    out += CompareGroup(
                        groupId = "exact:$full",
                        kind = "exact",
                        fileIds = sorted.map { it.fileId },
                        totalBytes = total,
                        // Everything but one copy. These are byte identical, so
                        // which one is kept genuinely does not matter and the
                        // saving is exact rather than an estimate.
                        wastedBytes = total - sorted.first().size,
                        keepFileId = sorted.first().fileId,
                        // Parallel to fileIds, same order. Appended last to
                        // match the schema, where a new field always goes
                        // at the end of the class.
                        sizes = sorted.map { it.size },
                    )
                }
            }
            seen += candidates.size
            onProgress(seen)
        }
        return out
    }

    /**
     * Near duplicates, by Hamming distance between hashes.
     *
     * Quadratic in the number of images, which sounds alarming and is not: the
     * comparison is one xor and a bit count, so a hundred thousand pairs cost
     * less than decoding a single photo. The decode is the scan; this is
     * rounding.
     */
    private fun similarGroups(hashes: List<Pair<Row, Long>>): List<CompareGroup> {
        val used = HashSet<String>()
        val out = mutableListOf<CompareGroup>()

        for (i in hashes.indices) {
            val (row, hash) = hashes[i]
            if (row.fileId in used) continue

            val cluster = mutableListOf(row)
            for (j in i + 1 until hashes.size) {
                val (other, otherHash) = hashes[j]
                if (other.fileId in used) continue
                if (Perceptual.distance(hash, otherHash) > similarThreshold) continue
                cluster += other
            }
            if (cluster.size < 2) continue

            cluster.forEach { used += it.fileId }
            val sorted = cluster.sortedByDescending { it.size }
            val total = sorted.sumOf { it.size }

            out += CompareGroup(
                groupId = "similar:${row.fileId}",
                kind = "similar",
                fileIds = sorted.map { it.fileId },
                totalBytes = total,
                wastedBytes = total - sorted.first().size,
                // The largest, because between two encodings of one photo the
                // bigger file carries more detail. A suggestion only: these are
                // NOT identical and the user may well prefer another.
                keepFileId = sorted.first().fileId,
                sizes = sorted.map { it.size },
            )
        }
        return out
    }

    private fun decode(uri: Uri): Bitmap? = try {
        app.contentResolver.openInputStream(uri)?.use { stream ->
            val bytes = stream.readBytes()
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            val longest = max(bounds.outWidth, bounds.outHeight)
            if (longest <= 0) {
                null
            } else {
                var sample = 1
                while (longest / (sample * 2) >= workingSize) sample *= 2
                BitmapFactory.decodeByteArray(
                    bytes,
                    0,
                    bytes.size,
                    BitmapFactory.Options().apply {
                        inSampleSize = sample
                        inPreferredConfig = Bitmap.Config.RGB_565
                    },
                )
            }
        }
    } catch (_: Throwable) {
        null
    }

    /** SHA-256 of the first [limit] bytes, or of everything. */
    private fun digest(uri: Uri, limit: Int): String? = try {
        app.contentResolver.openInputStream(uri)?.use { stream ->
            val md = MessageDigest.getInstance("SHA-256")
            val buffer = ByteArray(64 * 1024)
            var read = 0
            while (read < limit) {
                val wanted = minOf(buffer.size, limit - read)
                val got = stream.read(buffer, 0, wanted)
                if (got <= 0) break
                md.update(buffer, 0, got)
                read += got
            }
            md.digest().joinToString("") { "%02x".format(it) }
        }
    } catch (_: Throwable) {
        null
    }

    private fun readRows(maxImages: Int): List<Row> {
        val out = mutableListOf<Row>()
        val projection = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.MEDIA_TYPE,
        )
        // Images and video only. A duplicate spreadsheet is a real thing and not
        // what anyone opens this screen to find, and decoding is meaningless for
        // it anyway.
        val where = "${MediaStore.Files.FileColumns.MEDIA_TYPE} IN (?, ?) AND " +
            "${MediaStore.Files.FileColumns.SIZE} > 0"
        val args = arrayOf(
            MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString(),
            MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO.toString(),
        )

        app.contentResolver.query(
            collection,
            projection,
            where,
            args,
            "${MediaStore.Files.FileColumns.SIZE} DESC",
        )?.use { cursor ->
            val idAt = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns._ID)
            val sizeAt = cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
            val typeAt =
                cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.MEDIA_TYPE)

            while (cursor.moveToNext() && out.size < maxImages) {
                val id = cursor.getLong(idAt)
                out += Row(
                    fileId = "file:$id",
                    uri = android.content.ContentUris.withAppendedId(collection, id),
                    size = cursor.getLong(sizeAt),
                    kind = if (cursor.getInt(typeAt) ==
                        MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO
                    ) {
                        "video"
                    } else {
                        "image"
                    },
                )
            }
        }
        return out
    }

    /**
     * The id format is MediaIndex's, deliberately.
     *
     * "file:" plus the MediaStore id, so a group returned here can be handed
     * straight to remove, thumbnail or contentUri on the storage bridge without
     * a translation step that could drift.
     */
    private data class Row(
        val fileId: String,
        val uri: Uri,
        val size: Long,
        val kind: String,
    )

    private companion object {
        const val HEAD_BYTES = 64 * 1024
    }
}

/** The bridge for comparisons. */
internal class CompareHostApiImpl(context: Context) : CompareHostApi {

    private val engine = CompareEngine(context)
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val cancelled = AtomicBoolean(false)

    private var flutterApi: CompareFlutterApi? = null

    fun attachFlutterApi(api: CompareFlutterApi) {
        flutterApi = api
    }

    fun dispose() {
        cancelled.set(true)
        worker.shutdownNow()
        flutterApi = null
    }

    override fun scan(
        maxImages: Long,
        blurThreshold: Double,
        callback: (Result<CompareResult>) -> Unit,
    ) {
        cancelled.set(false)
        worker.execute {
            var lastPost = 0L
            val (groups, blurred, scanned) = engine.run(
                maxImages = maxImages.toInt(),
                blurThreshold = blurThreshold,
                cancelled = cancelled,
            ) { done, total, found ->
                // Throttled to about 4 Hz. A decode loop can finish a small
                // image in a few milliseconds, and posting every one would put
                // more work on the platform thread than the scan itself.
                val now = System.currentTimeMillis()
                if (now - lastPost >= 250) {
                    lastPost = now
                    emit(done, total, found, false)
                }
            }

            emit(scanned, scanned, groups.size + blurred.size, true)
            main.post {
                callback(
                    Result.success(
                        CompareResult(
                            groups = groups,
                            blurred = blurred,
                            scanned = scanned.toLong(),
                            cancelled = cancelled.get(),
                        ),
                    ),
                )
            }
        }
    }

    override fun cancel(callback: (Result<Unit>) -> Unit) {
        cancelled.set(true)
        main.post { callback(Result.success(Unit)) }
    }

    private fun emit(scanned: Int, total: Int, found: Int, done: Boolean) {
        val progress = CompareProgress(
            scanned = scanned.toLong(),
            total = total.toLong(),
            found = found.toLong(),
            done = done,
        )
        main.post { flutterApi?.onCompareProgress(progress) { } }
    }
}
