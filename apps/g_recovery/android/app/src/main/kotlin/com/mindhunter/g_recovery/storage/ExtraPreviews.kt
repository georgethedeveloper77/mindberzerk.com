package com.mindhunter.g_recovery.storage

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.File
import kotlin.math.max
import kotlin.math.min

/**
 * PREVIEWS FOR THE TWO KINDS THAT USED TO HAVE NONE.
 *
 * Both thumbnailers gated on image and video and returned null for everything
 * else, which was accurate at the time: nothing rendered audio or documents. The
 * result was a grid of identical grey glyphs for a music folder, where a person
 * recognises a track by its cover long before they read its name.
 *
 * ─── AUDIO IS ALREADY IN THE FILE ────────────────────────────────────────────
 *
 * Cover art is embedded in the tags. MediaMetadataRetriever hands it over as
 * JPEG bytes with no decoding and no network, so this costs about what reading
 * the file size costs.
 *
 * ─── PDF IS THE PLATFORM RENDERER ────────────────────────────────────────────
 *
 * PdfRenderer has shipped since API 21 and draws a page into a bitmap. Only the
 * FIRST page, and only for the grid: a preview exists so someone can tell one
 * invoice from another, and rendering page one of a two hundred page report is
 * already more than that question needs.
 *
 * ─── EVERYTHING FAILS QUIETLY ────────────────────────────────────────────────
 *
 * An encrypted PDF, a track with no art, a codec this phone lacks: every one
 * returns null and the caller falls back to its glyph. None of them is an error
 * worth surfacing, and a grid that throws while scrolling is worse than a grid
 * with a plain icon in it.
 */
internal object ExtraPreviews {

    /** Kinds this can draw that the bitmap path cannot. */
    val EXTRA_KINDS = setOf("audio", "document")

    /**
     * Cover art from a URI backed track.
     *
     * MediaMetadataRetriever holds a file descriptor, so release is not
     * optional: leaking one per row of a scrolling grid exhausts the process
     * handle limit within a few hundred items.
     */
    fun audioArt(context: Context, uri: Uri, size: Int): Bitmap? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(context, uri)
            decode(retriever.embeddedPicture, size)
        } catch (_: Throwable) {
            null
        } finally {
            runCatching { retriever.release() }
        }
    }

    /** Cover art from a loose file on disk. */
    fun audioArt(path: String, size: Int): Bitmap? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            decode(retriever.embeddedPicture, size)
        } catch (_: Throwable) {
            null
        } finally {
            runCatching { retriever.release() }
        }
    }

    /**
     * The first page of a PDF, drawn onto white.
     *
     * White rather than transparent, and this is not cosmetic. A PDF page is
     * mostly unpainted, so a transparent bitmap composited onto a dark card
     * gives black text on a black square: a preview that is technically correct
     * and completely unreadable.
     */
    fun pdfFirstPage(descriptor: ParcelFileDescriptor?, size: Int): Bitmap? {
        val fd = descriptor ?: return null
        return try {
            PdfRenderer(fd).use { renderer ->
                if (renderer.pageCount < 1) return null
                renderer.openPage(0).use { page ->
                    // Keep the page's own aspect ratio. A square render of an A4
                    // page is a squashed document that reads as a rendering bug.
                    val scale = min(
                        size.toFloat() / page.width,
                        size.toFloat() / page.height,
                    )
                    val width = max(1, (page.width * scale).toInt())
                    val height = max(1, (page.height * scale).toInt())

                    val bitmap = Bitmap.createBitmap(
                        width,
                        height,
                        Bitmap.Config.ARGB_8888,
                    )
                    bitmap.eraseColor(Color.WHITE)
                    page.render(
                        bitmap,
                        null,
                        null,
                        PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY,
                    )
                    bitmap
                }
            }
        } catch (_: Throwable) {
            // Encrypted, password protected, or not really a PDF. All three are
            // ordinary and none is worth an error.
            null
        } finally {
            runCatching { fd.close() }
        }
    }

    fun pdfFirstPage(context: Context, uri: Uri, size: Int): Bitmap? = pdfFirstPage(
        runCatching {
            context.contentResolver.openFileDescriptor(uri, "r")
        }.getOrNull(),
        size,
    )

    fun pdfFirstPage(file: File, size: Int): Bitmap? = pdfFirstPage(
        runCatching {
            ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        }.getOrNull(),
        size,
    )

    /** True when the name or type says PDF. */
    fun looksLikePdf(name: String?, mimeType: String?): Boolean {
        if (mimeType != null && mimeType.contains("pdf", ignoreCase = true)) return true
        return name != null && name.endsWith(".pdf", ignoreCase = true)
    }

    private fun decode(bytes: ByteArray?, size: Int): Bitmap? {
        val data = bytes ?: return null
        if (data.isEmpty()) return null

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(data, 0, data.size, bounds)
        val longest = max(bounds.outWidth, bounds.outHeight)
        if (longest <= 0) return null

        var sample = 1
        while (longest / (sample * 2) >= size) sample *= 2

        return BitmapFactory.decodeByteArray(
            data,
            0,
            data.size,
            BitmapFactory.Options().apply {
                inSampleSize = sample
                inPreferredConfig = Bitmap.Config.RGB_565
            },
        )
    }
}
