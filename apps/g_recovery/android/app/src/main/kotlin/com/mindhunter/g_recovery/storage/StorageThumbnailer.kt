package com.mindhunter.g_recovery.storage

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Size
import java.io.ByteArrayOutputStream
import kotlin.math.max

/**
 * Preview bytes for files that are still on the device.
 *
 * Near duplicate of the recovery Thumbnailer, and that is deliberate rather
 * than lazy. This one takes a URI, that one takes an index Record; unifying
 * them would mean the storage schema depending on the recovery index, which is
 * the coupling the two schemas exist to avoid. The shared part is forty lines
 * of BitmapFactory, and forty lines of duplication is cheaper than a dependency
 * between two bridges that have different lifetimes.
 *
 * Unlike the recovery path this can use loadThumbnail with confidence: these
 * files are not trashed, so the system thumbnail is still cached.
 */
internal class StorageThumbnailer(private val context: Context) {

    fun bytes(uri: Uri, kind: String, maxPixels: Int): ByteArray? {
        if (kind != "image" && kind != "video") return null
        val size = maxPixels.coerceIn(64, 2048)
        val bitmap = load(uri, size) ?: return null
        return try {
            val out = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 82, out)
            bitmap.recycle()
            out.toByteArray().takeIf { it.isNotEmpty() }
        } catch (_: Throwable) {
            null
        }
    }

    private fun load(uri: Uri, size: Int): Bitmap? {
        try {
            return context.contentResolver.loadThumbnail(uri, Size(size, size), null)
        } catch (_: Throwable) {
            // Falls through for formats the system never thumbnailed, such as a
            // RAW file from a camera app.
        }
        return try {
            context.contentResolver.openInputStream(uri)?.use { stream ->
                val bytes = stream.readBytes()
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                val longest = max(bounds.outWidth, bounds.outHeight)
                if (longest <= 0) return null
                var sample = 1
                while (longest / (sample * 2) >= size) sample *= 2
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
        } catch (_: Throwable) {
            null
        }
    }
}
