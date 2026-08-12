package com.mindhunter.g_recovery.compress

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.exifinterface.media.ExifInterface
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * MAKING PHOTOS SMALLER WITHOUT LOSING THEM.
 *
 * ─── EVERY NUMBER IS MEASURED ────────────────────────────────────────────────
 *
 * Compressibility depends on the picture, not its size: a screenshot of flat
 * colour loses 90 percent, a photograph of foliage loses 5. Every cleaner on
 * Play predicts from a formula and is therefore wrong, so this re-encodes into
 * memory and reports what it got.
 *
 * ─── EXIF IS COPIED, OR PEOPLE LOSE THEIR DATES ──────────────────────────────
 *
 * A bitmap decode drops every tag. Re-encoding without restoring them turns a
 * photo taken in Mombasa in 2019 into a file dated today with no location, and
 * the gallery reorders someone's entire library. This is the single most common
 * way compression tools quietly destroy something.
 *
 * ─── AND ORIENTATION IS THE TRAP INSIDE THAT TRAP ────────────────────────────
 *
 * Most phone photos are stored landscape with an EXIF rotation tag. Copy the
 * pixels and drop the tag and every portrait photo comes back on its side.
 *
 * ─── THE OUTPUT FORMAT FOLLOWS THE INPUT, AND THAT IS A FIX ──────────────────
 *
 * This class used to encode everything as JPEG while accepting PNG as a source.
 * For a screenshot that is the wrong codec twice over. JPEG is a photographic
 * codec: it throws away high frequency detail, and a screenshot is nothing but
 * high frequency detail, so every letter of text came back with a halo around
 * it. Worse, JPEG has no alpha channel, so any PNG carrying transparency had it
 * flattened to black, silently, with the original then sent to the trash.
 *
 * A PNG now becomes lossless WebP. Not a single pixel changes, it is still
 * meaningfully smaller than PNG, and the whole question of quality loss stops
 * applying to the category where quality loss was most visible.
 */
internal class ImageCompressor(
    context: Context,
    private val ledger: CompressLedger,
    private val video: VideoCompressor,
) {

    private val app: Context = context.applicationContext
    private val collection =
        MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)

    /** Counts and bytes only, with nothing encoded. */
    fun summary(minBytes: Long): CompressSummary {
        var shotCount = 0L
        var shotBytes = 0L
        var photoCount = 0L
        var photoBytes = 0L

        app.contentResolver.query(
            collection,
            arrayOf(
                MediaStore.Images.Media._ID,
                MediaStore.Images.Media.SIZE,
                MediaStore.Images.Media.BUCKET_DISPLAY_NAME,
                MediaStore.Images.Media.DISPLAY_NAME,
                MediaStore.Images.Media.MIME_TYPE,
            ),
            "${MediaStore.Images.Media.SIZE} >= ? AND " +
                "${MediaStore.Images.Media.MIME_TYPE} IN (?, ?)",
            arrayOf(minBytes.toString(), "image/jpeg", "image/png"),
            null,
        )?.use { cursor ->
            val idAt = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            val sizeAt = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.SIZE)
            val bucketAt = cursor.getColumnIndexOrThrow(
                MediaStore.Images.Media.BUCKET_DISPLAY_NAME,
            )
            val nameAt = cursor.getColumnIndexOrThrow(
                MediaStore.Images.Media.DISPLAY_NAME,
            )

            while (cursor.moveToNext()) {
                val size = cursor.getLong(sizeAt)
                // A file proven not to shrink is not "stored in a format that
                // takes more room than it needs", so counting it in the
                // headline would be a claim we have already disproved.
                if (ledger.isNoGain("file:${cursor.getLong(idAt)}")) continue
                // Same exclusion as candidates, or the headline on the scope
                // screen would keep counting the files this app already made
                // and never go down after a run.
                if (isOurOutput(cursor.getString(nameAt))) continue
                if (isShot(cursor.getString(bucketAt), cursor.getString(nameAt))) {
                    shotCount++
                    shotBytes += size
                } else {
                    photoCount++
                    photoBytes += size
                }
            }
        }

        // Video counted by the class that owns the codec test, because
        // eligibility here is not a size or a mime type: it is what the track
        // header says, and duplicating that rule would mean two places to get
        // it wrong.
        val (videoCount, videoBytes) = runCatching {
            video.summary(minBytes)
        }.getOrDefault(0L to 0L)

        return CompressSummary(
            screenshotCount = shotCount,
            screenshotBytes = shotBytes,
            photoCount = photoCount,
            photoBytes = photoBytes,
            videoCount = videoCount,
            videoBytes = videoBytes,
        )
    }

    /** Images worth offering, largest first. */
    fun candidates(kind: String, minBytes: Long, limit: Int): List<CompressCandidate> {
        val out = mutableListOf<CompressCandidate>()

        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.SIZE,
            MediaStore.Images.Media.WIDTH,
            MediaStore.Images.Media.HEIGHT,
            MediaStore.Images.Media.MIME_TYPE,
            MediaStore.Images.Media.BUCKET_DISPLAY_NAME,
            MediaStore.Images.Media.DATE_TAKEN,
            MediaStore.Images.Media.DATE_MODIFIED,
            MediaStore.Images.Media.RELATIVE_PATH,
        )

        // JPEG and PNG only. A HEIC re-encoded to JPEG usually gets BIGGER,
        // because HEIC is already the better codec, and offering that would be
        // the app making a file worse while claiming to help.
        val where = "${MediaStore.Images.Media.SIZE} >= ? AND " +
            "${MediaStore.Images.Media.MIME_TYPE} IN (?, ?)"
        val args = arrayOf(minBytes.toString(), "image/jpeg", "image/png")

        app.contentResolver.query(
            collection,
            projection,
            where,
            args,
            // No LIMIT here any more. The kind filter runs in the loop, so a
            // LIMIT in SQL would cut the list before filtering and could return
            // nothing at all for screenshots on a phone whose largest images
            // are all photos.
            "${MediaStore.Images.Media.SIZE} DESC",
        )?.use { cursor ->
            val idAt = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            val nameAt =
                cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
            val sizeAt =
                cursor.getColumnIndexOrThrow(MediaStore.Images.Media.SIZE)
            val wAt = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.WIDTH)
            val hAt = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.HEIGHT)
            val mimeAt =
                cursor.getColumnIndexOrThrow(MediaStore.Images.Media.MIME_TYPE)
            val bucketAt = cursor.getColumnIndexOrThrow(
                MediaStore.Images.Media.BUCKET_DISPLAY_NAME,
            )
            val takenAt = cursor.getColumnIndexOrThrow(
                MediaStore.Images.Media.DATE_TAKEN,
            )
            val modAt = cursor.getColumnIndexOrThrow(
                MediaStore.Images.Media.DATE_MODIFIED,
            )
            val pathAt = cursor.getColumnIndexOrThrow(
                MediaStore.Images.Media.RELATIVE_PATH,
            )

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idAt)
                val name = cursor.getString(nameAt) ?: "image_$id"

                // Sorted in the query and filtered here, deliberately.
                //
                // A screenshot is recognised by folder OR by file name, and the
                // second one cannot be expressed as an indexed comparison
                // without a LIKE over every row. Reading a few hundred rows and
                // choosing in Kotlin is faster than making SQLite do it, and it
                // is the only way Samsung's Screenshot_2026... files in DCIM get
                // caught at all.
                // ─── NEVER OFFER WHAT THIS APP ITSELF WROTE ──────────────
                //
                // A compressed photo is still a large JPEG, so without this it
                // comes straight back as a candidate and the app offers to
                // re-encode the file it produced ten seconds earlier. The
                // result is a grid of rows correctly reporting no gain, which
                // reads as the feature being broken.
                //
                // Two tests, and the second is not redundant. The ledger is
                // exact and survives a rename; the suffix catches everything
                // written before a reinstall, when the ledger is gone and the
                // files are not.
                val fileId = "file:$id"
                if (ledger.contains(fileId)) continue
                if (ledger.isNoGain(fileId)) continue
                if (isOurOutput(name)) continue

                val shot = isShot(cursor.getString(bucketAt), name)
                if (kind == "screenshot" && !shot) continue
                if (kind == "photo" && shot) continue

                out += CompressCandidate(
                    fileId = fileId,
                    name = name,
                    sizeBytes = cursor.getLong(sizeAt),
                    widthPx = cursor.getLong(wAt),
                    heightPx = cursor.getLong(hAt),
                    mimeType = cursor.getString(mimeAt) ?: "image/jpeg",
                    kind = if (shot) "screenshot" else "photo",
                    // DATE_TAKEN is milliseconds, DATE_MODIFIED is seconds.
                    // Mixing the two silently is how a 1970 date ends up at the
                    // top of a newest first list.
                    dateMillis = if (!cursor.isNull(takenAt)) {
                        cursor.getLong(takenAt)
                    } else {
                        cursor.getLong(modAt) * 1000
                    },
                    folder = cursor.getString(pathAt)?.trim('/'),
                )
                if (out.size >= limit) break
            }
        }
        return out
    }

    /** Re-encodes into memory and reports the real size. */
    fun preview(fileIds: List<String>, quality: Int): List<CompressPreview> {
        val out = mutableListOf<CompressPreview>()

        for (fileId in fileIds) {
            val id = fileId.removePrefix("file:").toLongOrNull() ?: continue
            val uri = ContentUris.withAppendedId(collection, id)

            val encoded = runCatching { encode(uri, quality) }.getOrNull()
                ?: continue
            val original = runCatching {
                app.contentResolver.openAssetFileDescriptor(uri, "r")
                    ?.use { it.length }
            }.getOrNull() ?: continue

            out += CompressPreview(
                fileId = fileId,
                originalBytes = original,
                newBytes = encoded.bytes.size.toLong(),
                quality = quality.toLong(),
                outputMime = encoded.mime,
                lossless = encoded.lossless,
            )
        }
        return out
    }

    /**
     * Writes the smaller version and trashes the original.
     *
     * ─── NEW FILE FIRST, ALWAYS ──────────────────────────────────────────────
     *
     * The replacement is written and confirmed readable BEFORE the original is
     * touched. A crash between the two leaves two copies, which costs space. The
     * other order leaves none, which costs the photograph.
     */
    fun compress(
        fileIds: List<String>,
        quality: Int,
        cancelled: AtomicBoolean,
        onProgress: (Int, String?, Long) -> Unit,
    ): List<CompressOutcome> {
        val out = mutableListOf<CompressOutcome>()
        var saved = 0L

        for ((index, fileId) in fileIds.withIndex()) {
            if (cancelled.get()) break

            val id = fileId.removePrefix("file:").toLongOrNull()
            if (id == null) {
                out += CompressOutcome(fileId, "failed", 0)
                continue
            }
            val uri = ContentUris.withAppendedId(collection, id)

            val name = runCatching { displayName(uri) }.getOrNull()
            onProgress(index, name, saved)

            val result = runCatching {
                replace(uri, id, quality)
            }.getOrDefault(-1L)

            when {
                result > 0 -> {
                    saved += result
                    out += CompressOutcome(fileId, "replaced", result)
                }
                // Zero means it came back no smaller. That is a success for the
                // user, not an error, and the picture is left exactly as it was.
                result == 0L -> out += CompressOutcome(fileId, "skipped", 0)
                else -> out += CompressOutcome(fileId, "failed", 0)
            }
        }
        onProgress(fileIds.size, null, saved)
        return out
    }

    /** Both versions of one file, from a single decode. */
    fun comparison(fileId: String, quality: Int): CompressComparison? {
        val id = fileId.removePrefix("file:").toLongOrNull() ?: return null
        val uri = ContentUris.withAppendedId(collection, id)

        val encoded = runCatching { encode(uri, quality) }.getOrNull()
            ?: return null

        // Read from disk rather than re-rendering.
        //
        // The point of the screen this feeds is to show what is actually there.
        // Decoding the original and re-encoding it just to display it would be
        // comparing the encoder against itself, and both sides would carry the
        // same artefacts.
        val original = runCatching {
            app.contentResolver.openInputStream(uri)?.use { it.readBytes() }
        }.getOrNull() ?: return null

        return CompressComparison(
            fileId = fileId,
            original = original,
            encoded = encoded.bytes,
            originalBytes = original.size.toLong(),
            newBytes = encoded.bytes.size.toLong(),
            lossless = encoded.lossless,
        )
    }


    /**
     * A file this app wrote, by its name.
     *
     * The ledger is the exact test and this is the one that survives a
     * reinstall, when the record is gone and the files are not. It can be wrong
     * about somebody's own file called holiday_small.jpg, and being wrong costs
     * them one file not being offered rather than a file being harmed.
     */
    private fun isOurOutput(name: String?): Boolean {
        val stem = (name ?: return false).substringBeforeLast('.', name)
        return stem.endsWith("_small")
    }

    private fun replace(
        uri: android.net.Uri,
        id: Long,
        quality: Int,
    ): Long {
        val encoded = encode(uri, quality) ?: return -1
        val original = app.contentResolver
            .openAssetFileDescriptor(uri, "r")?.use { it.length } ?: return -1

        // ─── TWO THRESHOLDS, BECAUSE THEY GUARD DIFFERENT THINGS ─────────────
        //
        // The 20 percent floor exists to stop trading a permanent quality loss
        // for a saving nobody would notice on a storage screen. That trade is
        // real for a photo and does not exist at all for a lossless re-encode,
        // where the pixels are identical and the only cost is the time already
        // spent. So lossless only has to beat the noise: below about 3 percent
        // it is not worth rewriting the file and disturbing the gallery.
        val floor = if (encoded.lossless) 0.97 else 0.8
        if (encoded.bytes.size >= original * floor) return 0

        val name = displayName(uri) ?: "image_$id"
        val values = ContentValues().apply {
            put(
                MediaStore.Images.Media.DISPLAY_NAME,
                compressedName(name, encoded.mime),
            )
            put(MediaStore.Images.Media.MIME_TYPE, encoded.mime)
            put(
                MediaStore.Images.Media.RELATIVE_PATH,
                relativePath(uri) ?: "Pictures",
            )
            // ─── THE DATE, CARRIED ACROSS EXPLICITLY ─────────────────────────
            //
            // Not the same problem as EXIF, and not solved by it. A screenshot
            // has no EXIF date to copy, and MediaStore does not re-derive
            // DATE_TAKEN for a file inserted through ContentValues. Without
            // these two lines every compressed file arrives dated today and the
            // gallery reorders itself around a picture nobody took today.
            takenAt(uri)?.let { put(MediaStore.Images.Media.DATE_TAKEN, it) }
            put(
                MediaStore.Images.Media.DATE_MODIFIED,
                modifiedAt(uri) ?: (System.currentTimeMillis() / 1000),
            )
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }

        val target = app.contentResolver.insert(collection, values)
            ?: return -1

        val written = runCatching {
            app.contentResolver.openOutputStream(target)?.use { stream ->
                stream.write(encoded.bytes)
                true
            } ?: false
        }.getOrDefault(false)

        if (!written) {
            runCatching { app.contentResolver.delete(target, null, null) }
            return -1
        }

        // Tags copied while the file is still pending, so nothing ever sees it
        // without its date.
        runCatching { copyExif(uri, target) }

        app.contentResolver.update(
            target,
            ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) },
            null,
            null,
        )

        // Only now. The replacement exists, is complete, and carries its tags.
        val trashed = runCatching {
            app.contentResolver.update(
                uri,
                ContentValues().apply {
                    put(MediaStore.Images.Media.IS_TRASHED, 1)
                },
                null,
                null,
            ) > 0
        }.getOrDefault(false)

        if (!trashed) {
            // The original survives and so does the copy. Reporting a saving
            // that did not happen would be the worse outcome, so this reports
            // failure and leaves both.
            return -1
        }

        // Recorded only here, after the trash succeeded, so the ledger can
        // never claim a file was replaced when both versions are still sitting
        // there.
        ledger.record(
            CompressedEntry(
                fileId = "file:${ContentUris.parseId(target)}",
                name = compressedName(name, encoded.mime),
                originalBytes = original,
                newBytes = encoded.bytes.size.toLong(),
                whenMillis = System.currentTimeMillis(),
                lossless = encoded.lossless,
                quality = quality.toLong(),
            ),
        )

        return original - encoded.bytes.size
    }

    /** What came out, and whether anything was lost getting there. */
    private class Encoded(
        val bytes: ByteArray,
        val mime: String,
        val lossless: Boolean,
    )

    /**
     * Decode and re-encode, in whichever codec suits what went in.
     *
     * ─── THE CODEC IS CHOSEN BY THE SOURCE, NOT BY THE SETTING ───────────────
     *
     * A JPEG is a photograph, so it is re-encoded as JPEG at the chosen quality
     * and loses a little to save a lot. A PNG is almost always a screenshot or
     * a graphic, so it becomes lossless WebP: still smaller, and not one pixel
     * different.
     *
     * Encoding a PNG as JPEG, which is what this did before, is wrong twice.
     * JPEG discards high frequency detail and a screenshot is entirely high
     * frequency detail, so text came back haloed. And JPEG has no alpha, so any
     * transparency was flattened to black on the way through.
     *
     * ─── inSampleSize IS STILL NEVER USED ────────────────────────────────────
     *
     * The point is to re-encode, not to shrink the picture. Halving the
     * dimensions would save far more and would be a different product, one that
     * quietly reduces what a person can print or crop.
     */
    private fun encode(uri: android.net.Uri, quality: Int): Encoded? {
        val png = (mimeOf(uri) ?: "").equals("image/png", ignoreCase = true)

        val bitmap = app.contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(
                it,
                null,
                BitmapFactory.Options().apply {
                    // Never RGB_565. On a screenshot that would crush gradients
                    // into visible banding before the encoder had a say, and it
                    // would throw away alpha in the one path that exists to
                    // keep it.
                    inPreferredConfig = Bitmap.Config.ARGB_8888
                },
            )
        } ?: return null

        return try {
            val buffer = ByteArrayOutputStream()
            if (png) {
                bitmap.compress(losslessWebp(), 100, buffer)
                Encoded(buffer.toByteArray(), "image/webp", lossless = true)
            } else {
                bitmap.compress(Bitmap.CompressFormat.JPEG, quality, buffer)
                Encoded(buffer.toByteArray(), "image/jpeg", lossless = false)
            }
        } finally {
            bitmap.recycle()
        }
    }

    /**
     * Lossless WebP, on every version this app runs on.
     *
     * WEBP_LOSSLESS arrived at API 30 and this app supports 24. The older WEBP
     * constant is lossy at any quality below 100 and lossless at exactly 100,
     * which is the documented behaviour rather than a coincidence, so the
     * fallback produces an identical file rather than an approximation.
     */
    @Suppress("DEPRECATION")
    private fun losslessWebp(): Bitmap.CompressFormat =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Bitmap.CompressFormat.WEBP_LOSSLESS
        } else {
            Bitmap.CompressFormat.WEBP
        }

    /**
     * A screenshot, by folder or by name.
     *
     * Both, because neither alone is enough. Most phones put them in a folder
     * called Screenshots, and Samsung also names the files Screenshot_ while
     * sometimes leaving them in DCIM. Matching only the folder misses those;
     * matching only the name misses everything renamed by a file manager.
     *
     * Wrong in the harmless direction when it is wrong: a photo misread as a
     * screenshot gets encoded losslessly, which saves less and damages nothing.
     */
    private fun isShot(bucket: String?, name: String?): Boolean {
        val folder = bucket.orEmpty().lowercase()
        val file = name.orEmpty().lowercase()
        return folder.contains("screenshot") ||
            folder.contains("screen shot") ||
            file.startsWith("screenshot") ||
            file.startsWith("screen_shot") ||
            file.startsWith("scrn")
    }

    private fun mimeOf(uri: android.net.Uri): String? =
        app.contentResolver.query(
            uri,
            arrayOf(MediaStore.Images.Media.MIME_TYPE),
            null,
            null,
            null,
        )?.use { if (it.moveToFirst()) it.getString(0) else null }

    private fun takenAt(uri: android.net.Uri): Long? =
        app.contentResolver.query(
            uri,
            arrayOf(MediaStore.Images.Media.DATE_TAKEN),
            null,
            null,
            null,
        )?.use {
            if (it.moveToFirst() && !it.isNull(0)) it.getLong(0) else null
        }

    private fun modifiedAt(uri: android.net.Uri): Long? =
        app.contentResolver.query(
            uri,
            arrayOf(MediaStore.Images.Media.DATE_MODIFIED),
            null,
            null,
            null,
        )?.use {
            if (it.moveToFirst() && !it.isNull(0)) it.getLong(0) else null
        }

    /**
     * Every tag that survives a re-encode.
     *
     * Orientation first in the list because it is the one that ruins a library:
     * most phone photos are stored landscape with a rotation tag, and dropping
     * it puts every portrait shot on its side.
     */
    private fun copyExif(from: android.net.Uri, to: android.net.Uri) {
        val source = app.contentResolver.openInputStream(from)?.use {
            ExifInterface(it)
        } ?: return

        val descriptor = app.contentResolver.openFileDescriptor(to, "rw")
            ?: return

        descriptor.use { fd ->
            val target = ExifInterface(fd.fileDescriptor)
            for (tag in TAGS) {
                val value = source.getAttribute(tag) ?: continue
                target.setAttribute(tag, value)
            }
            target.saveAttributes()
        }
    }

    private fun displayName(uri: android.net.Uri): String? =
        app.contentResolver.query(
            uri,
            arrayOf(MediaStore.Images.Media.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { if (it.moveToFirst()) it.getString(0) else null }

    private fun relativePath(uri: android.net.Uri): String? =
        app.contentResolver.query(
            uri,
            arrayOf(MediaStore.Images.Media.RELATIVE_PATH),
            null,
            null,
            null,
        )?.use { if (it.moveToFirst()) it.getString(0) else null }

    /**
     * The new name keeps the old one recognisable.
     *
     * "beach.jpg" becomes "beach_small.jpg" rather than a timestamp, so someone
     * searching their gallery a year later finds it under the name they
     * remember. A PNG changes extension as well as suffix, because the file
     * really is a WebP now and lying about that in the name would break
     * anything that trusts it.
     */
    private fun compressedName(name: String, mime: String): String {
        val stem = name.substringBeforeLast('.', name)
        val extension = if (mime == "image/webp") "webp" else "jpg"
        return "${stem}_small.$extension"
    }

    private companion object {
        // A few hundred is generous. Beyond that every extra row documents a
        // file whose original left the trash months ago.
        const val MAX_ENTRIES = 400

        val TAGS = listOf(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.TAG_DATETIME,
            ExifInterface.TAG_DATETIME_ORIGINAL,
            ExifInterface.TAG_DATETIME_DIGITIZED,
            ExifInterface.TAG_GPS_LATITUDE,
            ExifInterface.TAG_GPS_LATITUDE_REF,
            ExifInterface.TAG_GPS_LONGITUDE,
            ExifInterface.TAG_GPS_LONGITUDE_REF,
            ExifInterface.TAG_GPS_ALTITUDE,
            ExifInterface.TAG_GPS_ALTITUDE_REF,
            ExifInterface.TAG_GPS_TIMESTAMP,
            ExifInterface.TAG_GPS_DATESTAMP,
            ExifInterface.TAG_MAKE,
            ExifInterface.TAG_MODEL,
            ExifInterface.TAG_F_NUMBER,
            ExifInterface.TAG_EXPOSURE_TIME,
            ExifInterface.TAG_ISO_SPEED_RATINGS,
            ExifInterface.TAG_FOCAL_LENGTH,
            ExifInterface.TAG_WHITE_BALANCE,
            ExifInterface.TAG_FLASH,
        )
    }
}

/** The bridge for compression. */
internal class CompressHostApiImpl(context: Context) : CompressHostApi {

    // One ledger, two compressors. Each holding its own would mean two caches
    // over one preferences file, and the second to save would flatten the first.
    private val app: Context = context.applicationContext
    private val ledger = CompressLedger(context)
    private val video = VideoCompressor(context, ledger)
    private val compressor = ImageCompressor(context, ledger, video)
    private val main = Handler(Looper.getMainLooper())

    /**
     * TORN DOWN WITH THE ENGINE, AND THAT USED TO END A RUNNING ENCODE.
     *
     * ─── WHAT THIS IS AND IS NOT ALLOWED TO STOP ─────────────────────────────
     *
     * Flutter calls this when the engine detaches, which happens when the user
     * leaves the app. Cancelling here was right while the only work was a photo
     * re-encode measured in milliseconds. It is wrong for video, where leaving
     * the app during a twenty minute job is the normal thing to do and killing
     * it is the opposite of what the notification promises.
     *
     * So a running job is left alone. It has a foreground service holding the
     * process up and it reports into state that outlives this object, so the
     * next engine finds it still going.
     */
    fun dispose() {
        if (!state.running) cancelled.set(true)
    }

    override fun summary(
        minBytes: Long,
        callback: (Result<CompressSummary>) -> Unit,
    ) {
        worker.execute { reply(callback, compressor.summary(minBytes)) }
    }

    override fun candidates(
        kind: String,
        minBytes: Long,
        limit: Long,
        callback: (Result<List<CompressCandidate>>) -> Unit,
    ) {
        worker.execute {
            reply(callback, compressor.candidates(kind, minBytes, limit.toInt()))
        }
    }

    override fun preview(
        fileIds: List<String>,
        quality: Long,
        callback: (Result<List<CompressPreview>>) -> Unit,
    ) {
        worker.execute {
            reply(callback, compressor.preview(fileIds, quality.toInt()))
        }
    }

    override fun compress(
        fileIds: List<String>,
        quality: Long,
        callback: (Result<List<CompressOutcome>>) -> Unit,
    ) {
        cancelled.set(false)
        worker.execute {
            state = CompressProgress(
                running = true,
                done = 0L,
                total = fileIds.size.toLong(),
                savedBytes = 0L,
                currentName = null,
            )

            val outcomes = compressor.compress(
                fileIds,
                quality.toInt(),
                cancelled,
            ) { done, name, saved ->
                state = state.copy(
                    done = done.toLong(),
                    currentName = name,
                    savedBytes = saved,
                )
            }

            state = state.copy(running = false, currentName = null)
            reply(callback, outcomes)
        }
    }

    override fun compressVideo(
        fileIds: List<String>,
        preset: String,
        callback: (Result<List<CompressOutcome>>) -> Unit,
    ) {
        cancelled.set(false)
        worker.execute {
            state = CompressProgress(
                running = true,
                done = 0L,
                total = fileIds.size.toLong(),
                savedBytes = 0L,
                currentName = null,
            )

            // The notification goes up before the first encode and comes down
            // in a finally. A service left running under a notification that
            // says it is working is worse than no notification at all, and an
            // encoder that threw is exactly when it would happen.
            VideoService.show(app, 0, fileIds.size, null)
            try {
                val outcomes = video.compress(
                    fileIds,
                    preset,
                    cancelled,
                ) { done, name, saved ->
                    state = state.copy(
                        done = done.toLong(),
                        currentName = name,
                        savedBytes = saved,
                    )
                    VideoService.show(app, done, fileIds.size, name)
                }

                state = state.copy(running = false, currentName = null)

                // Said out loud, because the person who started this is very
                // likely not looking at the app any more.
                VideoService.finished(
                    app,
                    outcomes.count { it.status == "replaced" },
                    outcomes.sumOf { it.savedBytes },
                )

                reply(callback, outcomes)
            } finally {
                // Belt and braces. finished() stops the service itself, and
                // this catches the path where the encoder threw before it ran.
                VideoService.hide(app)
            }
        }
    }

    override fun videoCandidates(
        minBytes: Long,
        limit: Long,
        callback: (Result<List<VideoCandidate>>) -> Unit,
    ) {
        worker.execute {
            reply(callback, video.candidates(minBytes, limit.toInt()))
        }
    }

    override fun estimateVideo(
        fileId: String,
        preset: String,
        callback: (Result<VideoEstimate?>) -> Unit,
    ) {
        worker.execute { reply(callback, video.estimate(fileId, preset)) }
    }

    override fun markNoGain(
        fileIds: List<String>,
        callback: (Result<Unit>) -> Unit,
    ) {
        worker.execute {
            ledger.markNoGain(fileIds)
            reply(callback, Unit)
        }
    }

    override fun clearNoGain(callback: (Result<Unit>) -> Unit) {
        worker.execute {
            ledger.clearNoGain()
            reply(callback, Unit)
        }
    }

    override fun history(
        limit: Long,
        callback: (Result<List<CompressedEntry>>) -> Unit,
    ) {
        worker.execute { reply(callback, ledger.history(limit.toInt())) }
    }

    override fun comparison(
        fileId: String,
        quality: Long,
        callback: (Result<CompressComparison?>) -> Unit,
    ) {
        worker.execute {
            reply(callback, compressor.comparison(fileId, quality.toInt()))
        }
    }

    override fun cancel(callback: (Result<Unit>) -> Unit) {
        cancelled.set(true)
        main.post { callback(Result.success(Unit)) }
    }

    override fun progress(callback: (Result<CompressProgress>) -> Unit) {
        main.post { callback(Result.success(state)) }
    }

    /**
     * Answers Dart, unless Dart has gone.
     *
     * A job that outlives the engine still finishes and still calls back, into
     * a channel that no longer has anything on the far end. Throwing there
     * would take down a run that had already succeeded, so the failure is
     * swallowed: the work is done and recorded either way, and the next engine
     * reads it from the ledger rather than from a reply it was never present
     * to receive.
     */
    private fun <T> reply(callback: (Result<T>) -> Unit, value: T) {
        main.post { runCatching { callback(Result.success(value)) } }
    }

    private companion object {
        /**
         * PROCESS SCOPED, NOT ENGINE SCOPED. THIS IS WHAT MAKES BACKGROUND
         * COMPRESSION ACTUALLY WORK.
         *
         * ─── THE BUG THIS FIXES IS INVISIBLE UNTIL YOU LEAVE THE APP ─────────
         *
         * These were fields on the host impl, which Flutter builds and destroys
         * with the engine. Leave the app during an encode and the service keeps
         * the process alive and the executor keeps working, exactly as
         * intended. Come back, and Flutter builds a NEW host impl whose state
         * says nothing is running.
         *
         * The screen then shows an idle app while a notification counts through
         * files, which reads as two features disagreeing about reality.
         *
         * ─── AND THE EXECUTOR HAS TO OUTLIVE IT TOO ──────────────────────────
         *
         * A per instance executor is shut down with the instance. The work
         * would survive on the old thread while every new call queued onto a
         * different one, and a cancel from the new engine would reach a flag
         * the running job was not watching.
         */
        private val worker = Executors.newSingleThreadExecutor()

        private val cancelled = AtomicBoolean(false)

        @Volatile
        private var state = CompressProgress(
            running = false,
            done = 0L,
            total = 0L,
            savedBytes = 0L,
            currentName = null,
        )
    }
}
