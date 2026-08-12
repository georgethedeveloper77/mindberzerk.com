package com.mindhunter.g_recovery.recovery

import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.provider.MediaStore
import com.mindhunter.g_recovery.storage.ExtraPreviews
import android.util.Size
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.math.max

/**
 * Preview bytes for the review session.
 *
 * DOWNSCALED HERE, before anything crosses the channel. A hundred item session
 * of 12 megapixel photos is about 600 MB of full-size bitmaps; at 512 px on the
 * long edge the same session is a few megabytes. Decoding at full size and
 * shrinking afterwards would allocate the 600 MB anyway, which is the usual way
 * a gallery grid runs a phone out of memory.
 *
 * Returns null rather than throwing when there is no renderable preview. A Word
 * document genuinely has none, and that is not a failure.
 *
 * Audio and PDF no longer fall in that group: a track carries its cover art in
 * its own tags and a PDF has a first page, and both survive being deleted
 * because neither depends on a system thumbnail cache that the deletion cleared.
 */
internal class Thumbnailer(private val context: Context) {

    private val collection = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)

    fun bytes(record: RecoveryIndex.Record, maxPixels: Int): ByteArray? {
        val kind = record.item.kind
        if (kind !in RENDERABLE && kind !in ExtraPreviews.EXTRA_KINDS) return null
        val size = maxPixels.coerceIn(64, 2048)

        val bitmap = when {
            kind in RENDERABLE -> when (record) {
                is RecoveryIndex.Record.Media -> fromMediaStore(record.mediaId, size)
                is RecoveryIndex.Record.Loose -> fromFile(record.file, size)
            }

            // Cover art out of the tags. Works for a trashed track as well as a
            // loose one, because the tags travel with the bytes rather than
            // living in a system cache that a deletion cleared.
            kind == "audio" -> when (record) {
                is RecoveryIndex.Record.Media -> ExtraPreviews.audioArt(
                    context,
                    ContentUris.withAppendedId(collection, record.mediaId),
                    size,
                )

                is RecoveryIndex.Record.Loose ->
                    ExtraPreviews.audioArt(record.file.absolutePath, size)
            }

            ExtraPreviews.looksLikePdf(record.item.name, record.item.mimeType) ->
                when (record) {
                    is RecoveryIndex.Record.Media -> ExtraPreviews.pdfFirstPage(
                        context,
                        ContentUris.withAppendedId(collection, record.mediaId),
                        size,
                    )

                    is RecoveryIndex.Record.Loose ->
                        ExtraPreviews.pdfFirstPage(record.file, size)
                }

            else -> null
        } ?: return null

        return compress(bitmap)
    }

    private fun fromMediaStore(mediaId: Long, size: Int): Bitmap? {
        val uri = ContentUris.withAppendedId(collection, mediaId)

        // loadThumbnail is the fast path: on most devices it returns a cached
        // thumbnail the system already generated, with no full decode at all.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                return context.contentResolver.loadThumbnail(uri, Size(size, size), null)
            } catch (_: Throwable) {
                // Expected for TRASHED rows on several OEM builds: the system
                // thumbnail is evicted when an item goes to the bin. Fall
                // through and decode the original, which is still on disk.
            }
        }

        return try {
            context.contentResolver.openInputStream(uri)?.use { stream ->
                val bytes = stream.readBytes()
                decodeSampled(bytes, size)
            }
        } catch (_: Throwable) {
            null
        }
    }

    private fun fromFile(file: File, size: Int): Bitmap? = try {
        if (!file.exists() || file.length() == 0L) {
            null
        } else {
            decodeSampled(file.readBytes(), size)
        }
    } catch (_: Throwable) {
        // OutOfMemoryError included, deliberately. A single unreadable file must
        // not take down a review session that is otherwise working.
        null
    }

    /**
     * Two pass decode. Bounds first with inJustDecodeBounds, then the real
     * decode with a power of two sample size.
     *
     * inSampleSize is the only way to avoid allocating the full bitmap, and it
     * only accepts powers of two, so the result is at least the requested size
     * and usually larger. Good enough for a thumbnail and an order of magnitude
     * cheaper than decoding full and scaling.
     */
    private fun decodeSampled(bytes: ByteArray, size: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        val longest = max(bounds.outWidth, bounds.outHeight)
        if (longest <= 0) return null

        var sample = 1
        while (longest / (sample * 2) >= size) sample *= 2

        val options = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.RGB_565
        }
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
    }

    /**
     * JPEG at 82, not PNG.
     *
     * These are previews on their way to a screen, never files the user keeps,
     * so lossless costs three to five times the bytes across the channel for a
     * difference nobody can see at 512 px. The bitmap is recycled immediately:
     * a review session generates one per swipe and the native heap does not get
     * garbage collected on the same schedule as the Dart one.
     */
    private fun compress(bitmap: Bitmap): ByteArray? = try {
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 82, out)
        bitmap.recycle()
        out.toByteArray().takeIf { it.isNotEmpty() }
    } catch (_: Throwable) {
        null
    }

    private companion object {
        /** Kinds the bitmap path can draw. Audio and documents go elsewhere. */
        val RENDERABLE = setOf("image", "video")
    }
}
