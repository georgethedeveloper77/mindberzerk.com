package com.mindhunter.g_recovery.compress

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * DECIDING WHICH CLIPS ARE WORTH RE-ENCODING, AND ROUGHLY BY HOW MUCH.
 *
 * ─── NOTHING HERE TOUCHES THE LIBRARY ────────────────────────────────────────
 *
 * This class reads headers and writes to the cache directory. It has no method
 * that replaces, trashes or renames anything, which is deliberate for a first
 * use of a new encoder: if Transformer misbehaves on some chipset, the worst
 * outcome available here is a wasted temp file.
 *
 * ─── THE ESTIMATE IS A REAL ENCODE OF A REAL SLICE ───────────────────────────
 *
 * Measuring a whole video is the job itself, so it cannot also be the preview.
 * The alternative every cleaner picks is a bitrate formula, which is wrong in
 * both directions and knows nothing about the phone it is running on.
 *
 * Fifteen seconds through this encoder, on these pixels, extrapolated by
 * duration. It is a forecast and the schema says so, but it is a forecast made
 * by doing the thing rather than by describing it.
 *
 * ─── AND WHY THE MAIN THREAD KEEPS APPEARING BELOW ───────────────────────────
 *
 * Transformer requires a Looper: it must be built and started on one, and it
 * reports back on the same one. Everything calling into this class is already
 * on a worker, so the work is posted to main and the worker waits on a latch.
 * The wait is not a stall, since Transformer does its actual encoding on its
 * own threads and main only orchestrates.
 */
internal class VideoCompressor(
    context: Context,
    private val ledger: CompressLedger,
) {

    private val app: Context = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private val collection =
        MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)

    // ─────────────────────────────────────────────────────────────────────────
    // Listing
    // ─────────────────────────────────────────────────────────────────────────

    /** Counts and bytes for the scope card. Headers only, no decoding. */
    fun summary(minBytes: Long): Pair<Long, Long> {
        var count = 0L
        var bytes = 0L
        for (candidate in candidates(minBytes, Int.MAX_VALUE)) {
            if (!candidate.eligible) continue
            count++
            bytes += candidate.sizeBytes
        }
        return count to bytes
    }

    /**
     * Every clip over the floor, with a verdict attached.
     *
     * The ineligible ones come back too. A user whose largest video is simply
     * absent from a list about making files smaller will assume the app never
     * saw it; a row saying "already HEVC" answers that in four words.
     */
    fun candidates(minBytes: Long, limit: Int): List<VideoCandidate> {
        sweepSamples()
        val out = mutableListOf<VideoCandidate>()

        app.contentResolver.query(
            collection,
            arrayOf(
                MediaStore.Video.Media._ID,
                MediaStore.Video.Media.DISPLAY_NAME,
                MediaStore.Video.Media.SIZE,
                MediaStore.Video.Media.WIDTH,
                MediaStore.Video.Media.HEIGHT,
                MediaStore.Video.Media.DURATION,
                MediaStore.Video.Media.DATE_TAKEN,
                MediaStore.Video.Media.DATE_MODIFIED,
                MediaStore.Video.Media.RELATIVE_PATH,
            ),
            "${MediaStore.Video.Media.SIZE} >= ?",
            arrayOf(minBytes.toString()),
            "${MediaStore.Video.Media.SIZE} DESC",
        )?.use { cursor ->
            val idAt = cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
            val nameAt =
                cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
            val sizeAt = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
            val wAt = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.WIDTH)
            val hAt = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.HEIGHT)
            val durAt =
                cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
            val takenAt =
                cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_TAKEN)
            val modAt =
                cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_MODIFIED)
            val pathAt =
                cursor.getColumnIndexOrThrow(MediaStore.Video.Media.RELATIVE_PATH)

            while (cursor.moveToNext() && out.size < limit) {
                val id = cursor.getLong(idAt)
                val name = cursor.getString(nameAt) ?: "video_$id"
                if (isOurOutput(name)) continue

                val fileId = "file:$id"
                if (ledger.contains(fileId)) continue

                val uri = ContentUris.withAppendedId(collection, id)
                val track = trackOf(uri, fileId)
                val duration = cursor.getLong(durAt)
                val size = cursor.getLong(sizeAt)

                val width = cursor.getLong(wAt)
                val height = cursor.getLong(hAt)

                // From the container when it says, otherwise derived, and it
                // has to be computed BEFORE the verdict because the verdict now
                // depends on it.
                val bitrate = if (track.bitrate > 0) {
                    track.bitrate
                } else if (duration > 0) {
                    size * 8000 / duration
                } else {
                    0
                }

                val verdict =
                    verdict(track.codec, duration, bitrate, width * height)

                out += VideoCandidate(
                    fileId = fileId,
                    name = name,
                    sizeBytes = size,
                    widthPx = width,
                    heightPx = height,
                    durationMillis = duration,
                    codec = track.codec,
                    bitrate = bitrate,
                    eligible = verdict == null,
                    reason = verdict,
                    dateMillis = if (!cursor.isNull(takenAt)) {
                        cursor.getLong(takenAt)
                    } else {
                        cursor.getLong(modAt) * 1000
                    },
                    folder = cursor.getString(pathAt)?.trim('/'),
                )
            }
        }
        return out
    }

    /**
     * Why this clip should be left alone, or null when it should not be.
     *
     * ─── EVERY ANSWER HERE SAVES SOMEONE TEN MINUTES ─────────────────────────
     *
     * These are not edge cases being tidied away. Re-encoding is the slowest
     * thing this app does, and each of these is a file where all of that time
     * buys nothing.
     */
    private fun verdict(
        codec: String,
        durationMillis: Long,
        bitrate: Long,
        pixels: Long,
    ): String? = when {
        // The whole premise. HEVC, VP9 and AV1 are already the modern codecs,
        // and passing one through this pipeline produces a file of roughly the
        // same size after a very long wait.
        codec == "hevc" -> "Already HEVC"
        codec == "vp9" -> "Already VP9"
        codec == "av1" -> "Already AV1"

        // A clip shorter than the sample cannot be estimated from a sample, and
        // the saving on a few seconds of video is not worth the encode anyway.
        durationMillis in 1 until SAMPLE_MILLIS -> "Too short to be worth it"

        codec == "unknown" -> "This format cannot be read"

        // ─── THE TEST THE FIRST VERSION WAS MISSING ──────────────────────────
        //
        // Codec alone is not enough, and the file that proved it was a 42 MB
        // WhatsApp clip: H.264, therefore eligible, and re-encoding it was
        // forecast to produce 119 MB. Not a bad estimate. A correct one.
        //
        // WhatsApp had already crushed that video to roughly 1.2 Mbit. There is
        // nothing left in it to take out, and putting it through an encoder
        // again only adds back the bitrate the encoder thinks a video of that
        // size deserves.
        //
        // So the second question is how much room the pixels have been given.
        // A phone recording 1080p spends around 8 Mbit per megapixel; anything
        // sent through a messaging app is a fraction of that and is already as
        // small as it is going to get without looking worse.
        pixels > 0 && bitrate > 0 &&
            bitrate * 1_000_000 / pixels < MIN_BITS_PER_MEGAPIXEL ->
            "Already heavily compressed"

        else -> null
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Estimating
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Encodes the opening slice and scales the result by duration.
     *
     * ─── THE OPENING SLICE, AND ITS KNOWN BIAS ───────────────────────────────
     *
     * Seeking into the middle would sample more representative footage, but a
     * clipped export from a non zero start has to decode everything up to the
     * previous keyframe first, which on a long clip costs more than the sample.
     * The opening is what can be read cheaply.
     *
     * That biases the estimate: a video that opens on a still shot and later
     * pans across a crowd compresses better in its first seconds than across
     * its length, so the figure runs optimistic. The schema reports
     * sampledMillis precisely so the screen can say what the number came from.
     */
    fun estimate(fileId: String, preset: String): VideoEstimate? {
        val id = fileId.removePrefix("file:").toLongOrNull() ?: return null
        val uri = ContentUris.withAppendedId(collection, id)

        val size = runCatching {
            app.contentResolver.openAssetFileDescriptor(uri, "r")
                ?.use { it.length }
        }.getOrNull() ?: return null

        val duration = durationOf(uri)
        if (duration < SAMPLE_MILLIS) return null

        val sample = File(app.cacheDir, "estimate_$id.mp4")
        runCatching { sample.delete() }

        val bytes = transform(
            uri = uri,
            output = sample.absolutePath,
            preset = preset,
            // Read fresh here rather than from the cache, which stores only
            // the codec. Bitrate is needed for the smaller preset and is worth
            // one header read on a file the user has actually selected.
            sourceBitrate = trackOf(uri, null).bitrate,
            clipMillis = SAMPLE_MILLIS,
        )

        // ─── KEPT, NOT DELETED ───────────────────────────────────────────────
        //
        // This file is fifteen real seconds of the output at the chosen
        // settings, and it used to be weighed and thrown away. It is the
        // preview: not a prediction of what the encoder would do, but the thing
        // the encoder did.
        //
        // Not a leak. Every stale sample is swept at the start of the next
        // scan, and the cache directory is the one place Android will reclaim
        // on its own if the phone runs short.
        val produced = if (bytes > 0) sample.length() else 0
        if (produced <= 0) {
            runCatching { sample.delete() }
            return null
        }

        // Scaled by duration rather than by byte ratio. The sample carries a
        // full container header that the extrapolated whole would carry only
        // once, so this slightly overstates a long clip, which is the safe
        // direction for a number the user is deciding on.
        val scaled = produced.toDouble() * duration.toDouble() /
            SAMPLE_MILLIS.toDouble()

        return VideoEstimate(
            fileId = fileId,
            originalBytes = size,
            estimatedBytes = scaled.toLong(),
            sampledMillis = SAMPLE_MILLIS,
            preset = preset,
            samplePath = sample.absolutePath,
        )
    }

    // ─────────────────────────────────────────────────────────────────────────
    // The real thing
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Re-encodes clips and replaces them, keeping every original in the trash.
     *
     * ─── SAME ORDER AS THE IMAGE PATH, FOR THE SAME REASON ───────────────────
     *
     * Encode to cache, copy into the library, confirm the copy is a playable
     * video, and only then trash the original. A crash at any point before the
     * last step leaves two files, which costs space. The other order leaves
     * none, which costs the recording.
     *
     * ─── AND ONE STEP THE IMAGE PATH DOES NOT NEED ───────────────────────────
     *
     * The output is opened and checked for a video track before anything is
     * trashed. A JPEG that encoded at all is a JPEG; a video file can be
     * written, be the right size, and contain nothing playable if the encoder
     * gave up partway. Size alone is not evidence here.
     */
    fun compress(
        fileIds: List<String>,
        preset: String,
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
            val name = displayName(uri) ?: "video_$id.mp4"
            onProgress(index, name, saved)

            val result = runCatching {
                replace(uri, id, name, preset, cancelled)
            }.getOrDefault(-1L)

            when {
                result > 0 -> {
                    saved += result
                    out += CompressOutcome(fileId, "replaced", result)
                }
                // Came back no smaller. A success for the user and a non event
                // for the app: the recording is left exactly as it was.
                result == 0L -> out += CompressOutcome(fileId, "skipped", 0)
                else -> out += CompressOutcome(fileId, "failed", 0)
            }
        }

        onProgress(fileIds.size, null, saved)
        return out
    }

    /** Returns bytes saved, 0 when not worth it, -1 on failure. */
    private fun replace(
        uri: Uri,
        id: Long,
        name: String,
        preset: String,
        cancelled: AtomicBoolean,
    ): Long {
        val original = runCatching {
            app.contentResolver.openAssetFileDescriptor(uri, "r")
                ?.use { it.length }
        }.getOrNull() ?: return -1

        val duration = durationOf(uri)
        val temp = File(app.cacheDir, "encode_$id.mp4")
        runCatching { temp.delete() }

        try {
            val written = transform(
                uri = uri,
                output = temp.absolutePath,
                preset = preset,
                sourceBitrate = trackOf(uri, null).bitrate,
                clipMillis = 0,
                // Scaled to the clip, with a floor. Real time encoding is
                // roughly a third of playback on a modern phone, and a fixed
                // ceiling would either kill a long recording or let a stuck
                // encoder hold a worker for an hour.
                timeoutSeconds = maxOf(300L, duration / 1000 * 3),
                cancelled = cancelled,
            )
            if (written <= 0) return -1
            if (cancelled.get()) return -1

            val produced = temp.length()
            if (produced <= 0) return -1

            // A fifth, same floor as a photo. Twenty minutes of encoding to
            // save four percent is a trade nobody would take knowingly.
            if (produced >= original * 0.8) return 0

            // The check a photo does not need. An encoder that gave up partway
            // can leave a file of plausible size containing nothing playable.
            if (!isPlayable(temp)) return -1

            val values = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, compressedName(name))
                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                put(
                    MediaStore.Video.Media.RELATIVE_PATH,
                    relativePath(uri) ?: "Movies",
                )
                // Carried across explicitly, exactly as for photos. Without it
                // every re-encoded clip arrives dated today and the gallery
                // reorders itself around a recording nobody made today.
                takenAt(uri)?.let { put(MediaStore.Video.Media.DATE_TAKEN, it) }
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }

            val target = app.contentResolver.insert(collection, values)
                ?: return -1

            val copied = runCatching {
                app.contentResolver.openOutputStream(target)?.use { output ->
                    temp.inputStream().use { input -> input.copyTo(output) }
                    true
                } ?: false
            }.getOrDefault(false)

            if (!copied) {
                runCatching { app.contentResolver.delete(target, null, null) }
                return -1
            }

            app.contentResolver.update(
                target,
                ContentValues().apply {
                    put(MediaStore.Video.Media.IS_PENDING, 0)
                },
                null,
                null,
            )

            val trashed = runCatching {
                app.contentResolver.update(
                    uri,
                    ContentValues().apply {
                        put(MediaStore.Video.Media.IS_TRASHED, 1)
                    },
                    null,
                    null,
                ) > 0
            }.getOrDefault(false)

            if (!trashed) {
                // Both copies survive. Reporting a saving that did not happen
                // is the worse outcome, so this reports failure and leaves them.
                return -1
            }

            ledger.record(
                CompressedEntry(
                    fileId = "file:${ContentUris.parseId(target)}",
                    name = compressedName(name),
                    originalBytes = original,
                    newBytes = produced,
                    whenMillis = System.currentTimeMillis(),
                    // Never true for video. Every re-encode here loses
                    // something, which is why the original keeps its thirty
                    // days.
                    lossless = false,
                    quality = 0,
                ),
            )

            return original - produced
        } finally {
            // Whatever happened. A cache full of half written mp4s is what
            // turns up months later as "this app uses two gigabytes".
            runCatching { temp.delete() }
        }
    }

    /**
     * Whether the file contains something that will actually play.
     *
     * A track count and a video mime type. Not a decode: opening one frame
     * would catch more and would also cost real time on every file, and an
     * encoder that produced a valid header and garbage frames is a failure mode
     * nobody has reported on Transformer.
     */
    private fun isPlayable(file: File): Boolean {
        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(file.absolutePath)
            (0 until extractor.trackCount).any {
                extractor.getTrackFormat(it)
                    .getString(MediaFormat.KEY_MIME)
                    .orEmpty()
                    .startsWith("video/")
            }
        } catch (error: Exception) {
            false
        } finally {
            runCatching { extractor.release() }
        }
    }

    private fun displayName(uri: Uri): String? =
        app.contentResolver.query(
            uri,
            arrayOf(MediaStore.Video.Media.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { if (it.moveToFirst()) it.getString(0) else null }

    private fun relativePath(uri: Uri): String? =
        app.contentResolver.query(
            uri,
            arrayOf(MediaStore.Video.Media.RELATIVE_PATH),
            null,
            null,
            null,
        )?.use { if (it.moveToFirst()) it.getString(0) else null }

    private fun takenAt(uri: Uri): Long? =
        app.contentResolver.query(
            uri,
            arrayOf(MediaStore.Video.Media.DATE_TAKEN),
            null,
            null,
            null,
        )?.use {
            if (it.moveToFirst() && !it.isNull(0)) it.getLong(0) else null
        }

    /** Always mp4, whatever went in, because that is what Transformer writes. */
    private fun compressedName(name: String): String =
        "${name.substringBeforeLast('.', name)}_small.mp4"

    /**
     * Runs one export and blocks until it finishes.
     *
     * Returns bytes written, or -1. Transformer is built and started on the
     * main looper because it requires one; the caller is on a worker and waits
     * here while Transformer does the actual work on its own threads.
     */
    @OptIn(markerClass = [UnstableApi::class])
    private fun transform(
        uri: Uri,
        output: String,
        preset: String,
        sourceBitrate: Long,
        clipMillis: Long,
        timeoutSeconds: Long = TIMEOUT_SECONDS,
        cancelled: AtomicBoolean? = null,
    ): Long {
        val latch = CountDownLatch(1)
        var written = -1L

        // Held so it can be cancelled from the wait below. Assigned on main,
        // read from the worker, so it has to be volatile in effect: an
        // AtomicReference is the honest way to say that in Kotlin.
        val handle = AtomicReference<Transformer?>(null)

        main.post {
            val item = MediaItem.Builder()
                .setUri(uri)
                .apply {
                    if (clipMillis > 0) {
                        setClippingConfiguration(
                            MediaItem.ClippingConfiguration.Builder()
                                .setStartPositionMs(0)
                                .setEndPositionMs(clipMillis)
                                .build(),
                        )
                    }
                }
                .build()

            val edited = EditedMediaItem.Builder(item)
                // Audio passed through untouched.
                //
                // It is a fraction of the bytes and re-encoding it is the one
                // way to make a video sound worse while saving nothing worth
                // having.
                .setRemoveAudio(false)
                .build()

            val builder = Transformer.Builder(app)
                // HEVC is the entire point. Re-encoding H.264 as H.264 saves
                // nothing that would justify the wait.
                .setVideoMimeType(MimeTypes.VIDEO_H265)

            // ─── ALWAYS A TARGET, NEVER THE ENCODER'S OWN IDEA ───────────────
            //
            // The first version only set a bitrate for the smaller preset and
            // let the default stand for same. That is how a 42 MB clip forecast
            // to 119 MB: with nothing requested, the encoder picks whatever it
            // considers appropriate for the resolution, which for already
            // compressed footage is far more than was there.
            //
            // Deriving from the source makes the output smaller by
            // construction rather than by hope. HEVC at 60 percent of an H.264
            // bitrate is roughly matched quality, which is the entire reason
            // this feature swaps codec rather than just lowering the number.
            if (sourceBitrate > 0) {
                val factor = if (preset == "smaller") 0.4 else 0.6
                builder.setEncoderFactory(
                    DefaultEncoderFactory.Builder(app)
                        .setRequestedVideoEncoderSettings(
                            VideoEncoderSettings.Builder()
                                .setBitrate((sourceBitrate * factor).toInt())
                                .build(),
                        )
                        .build(),
                )
            }

            val transformer = builder
                .addListener(
                    object : Transformer.Listener {
                        override fun onCompleted(
                            composition: Composition,
                            result: ExportResult,
                        ) {
                            written = result.fileSizeBytes
                            latch.countDown()
                        }

                        override fun onError(
                            composition: Composition,
                            result: ExportResult,
                            exception: ExportException,
                        ) {
                            // Reported as a failure and nothing more. A device
                            // whose encoder refuses a particular clip is a real
                            // and unfixable case, and the honest response is
                            // that this file cannot be estimated.
                            written = -1
                            latch.countDown()
                        }
                    },
                )
                .build()

            handle.set(transformer)
            runCatching { transformer.start(edited, output) }
                .onFailure {
                    written = -1
                    latch.countDown()
                }
        }

        // ─── WAITED IN SLICES, SO STOP CAN ACTUALLY STOP ─────────────────────
        //
        // One long await would leave a cancel sitting unread until the encode
        // finished, which is exactly the case where a person is waiting and
        // wants out. A second at a time is fine: the wait costs nothing and
        // Transformer is doing its work on other threads regardless.
        var waited = 0L
        var finished = false
        while (waited < timeoutSeconds) {
            finished = runCatching {
                latch.await(1, TimeUnit.SECONDS)
            }.getOrDefault(false)
            if (finished) break

            if (cancelled?.get() == true) {
                // Cancel has to go back to the thread that started it.
                main.post { runCatching { handle.get()?.cancel() } }
                return -1
            }
            waited++
        }

        return if (finished) written else -1
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Headers
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Removes samples from previous sessions.
     *
     * Run when a list is built rather than on a timer, because that is exactly
     * when the old ones stop being useful and the new ones are about to be
     * made. An hour is generous for something whose only reader is a screen
     * that is currently open.
     */
    private fun sweepSamples() {
        val cutoff = System.currentTimeMillis() - SAMPLE_KEEP_MILLIS
        runCatching {
            app.cacheDir.listFiles { file ->
                file.name.startsWith("estimate_") && file.lastModified() < cutoff
            }?.forEach { it.delete() }
        }
    }

    private class Track(val codec: String, val bitrate: Long)

    /**
     * The video track's codec and bitrate, from the container.
     *
     * MediaExtractor rather than MediaMetadataRetriever: the retriever reports
     * a bitrate for the whole file including audio and says nothing about which
     * codec the video track uses, which is the only fact that matters here.
     */
    private fun trackOf(uri: Uri, fileId: String?): Track {
        // ─── THE CACHE IS NOT AN OPTIMISATION, IT IS THE FIX ─────────────────
        //
        // Opening a MediaExtractor is a header read, which is fast per file and
        // not remotely fast per library: two hundred clips is seconds of work,
        // and summary() runs from the Storage tab on open. A tab that stalls
        // when a phone holds a lot of video is a tab that looks broken on
        // exactly the devices this feature exists for.
        //
        // A file's codec cannot change. MediaStore issues a new id when a file
        // is rewritten, so a remembered verdict is good forever.
        if (fileId != null) {
            ledger.codecOf(fileId)?.let { return Track(it, 0) }
        }

        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(app, uri, null)
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME).orEmpty()
                if (!mime.startsWith("video/")) continue

                val bitrate = runCatching {
                    if (format.containsKey(MediaFormat.KEY_BIT_RATE)) {
                        format.getInteger(MediaFormat.KEY_BIT_RATE).toLong()
                    } else {
                        0L
                    }
                }.getOrDefault(0L)

                val codec = normalise(mime)
                if (fileId != null) ledger.rememberCodec(fileId, codec)
                return Track(codec, bitrate)
            }
            Track("unknown", 0)
        } catch (error: Exception) {
            Track("unknown", 0)
        } finally {
            runCatching { extractor.release() }
        }
    }

    private fun durationOf(uri: Uri): Long =
        app.contentResolver.query(
            uri,
            arrayOf(MediaStore.Video.Media.DURATION),
            null,
            null,
            null,
        )?.use {
            if (it.moveToFirst() && !it.isNull(0)) it.getLong(0) else 0L
        } ?: 0L

    /** A name a person recognises, from a mime type that nobody does. */
    private fun normalise(mime: String): String = when (mime.lowercase()) {
        "video/avc", "video/h264" -> "h264"
        "video/hevc", "video/h265" -> "hevc"
        "video/x-vnd.on2.vp9", "video/vp9" -> "vp9"
        "video/av01" -> "av1"
        "video/mp4v-es", "video/mpeg4" -> "mpeg4"
        else -> "unknown"
    }

    /** Same rule as the image path: never offer back what this app wrote. */
    private fun isOurOutput(name: String): Boolean =
        name.substringBeforeLast('.', name).endsWith("_small")

    private companion object {
        /**
         * Fifteen seconds.
         *
         * Long enough to cross at least one scene change on most handheld
         * footage, which is what stops a static opening shot from setting the
         * whole forecast. Short enough that a person waits a few seconds rather
         * than wondering whether the screen has frozen.
         */
        const val SAMPLE_MILLIS = 15_000L

        const val TIMEOUT_SECONDS = 120L

        /** How long a sample stays playable before the next scan clears it. */
        const val SAMPLE_KEEP_MILLIS = 60L * 60L * 1000L

        /**
         * Below this, the pixels have already been squeezed as far as they go.
         *
         * Bits per second per megapixel. A phone recording 1080p sits around
         * eight million; a clip that has been through a messaging app sits
         * near three. Four is the line, chosen so ordinary camera footage stays
         * eligible and anything already processed is left alone.
         *
         * It is a threshold rather than a measurement, which is unlike the rest
         * of this feature. The justification is that it only decides whether to
         * OFFER a file: nothing is ever done on this number, and every clip
         * that passes it is still measured for real before anything happens.
         */
        const val MIN_BITS_PER_MEGAPIXEL = 4_000_000L
    }
}
