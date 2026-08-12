package com.mindhunter.g_recovery.compare

import android.graphics.Bitmap

/**
 * THE THREE MEASUREMENTS, taken from one decoded bitmap.
 *
 * Exact duplicates, near duplicates and blur are three questions about the same
 * pixels, and the expensive part is not any of the arithmetic here: it is
 * decoding the image at all. So an image is decoded once, at a small working
 * size, and all three answers come off that one bitmap.
 *
 * ─── NO DEPENDENCY, NO MODEL ─────────────────────────────────────────────────
 *
 * Every algorithm here is thirty lines and forty years old. Shipping an ML model
 * to decide whether a photo is blurry would add megabytes to the APK, a licence
 * question, and a result nobody can explain, to answer something a Laplacian
 * settles exactly.
 */
internal object Perceptual {

    /** Working size for the hash. 9 wide because dHash compares adjacent pairs. */
    private const val HASH_W = 9
    private const val HASH_H = 8

    /**
     * A 64 bit difference hash.
     *
     * ─── WHY dHash AND NOT aHash ─────────────────────────────────────────────
     *
     * Average hash compares every pixel to the image mean, so it is thrown by a
     * brightness change: the same photo exported at a different exposure hashes
     * differently. dHash compares each pixel to the one on its right, which
     * measures GRADIENT rather than level, and gradient survives brightness,
     * contrast, re-encoding and mild resizing. Those are exactly the four things
     * that produce near duplicates on a phone.
     *
     * ─── WHY NOT pHash ───────────────────────────────────────────────────────
     *
     * A DCT based hash is more robust again, and it costs a discrete cosine
     * transform per image plus a great deal more code. For "is this the same
     * photo the user already has", dHash is enough, and it is enough by a wide
     * margin at a fraction of the work.
     */
    fun dHash(source: Bitmap): Long {
        val small = Bitmap.createScaledBitmap(source, HASH_W, HASH_H, true)
        val pixels = IntArray(HASH_W * HASH_H)
        small.getPixels(pixels, 0, HASH_W, 0, 0, HASH_W, HASH_H)
        if (small !== source) small.recycle()

        var hash = 0L
        var bit = 0
        for (y in 0 until HASH_H) {
            for (x in 0 until HASH_W - 1) {
                val left = luma(pixels[y * HASH_W + x])
                val right = luma(pixels[y * HASH_W + x + 1])
                if (left > right) hash = hash or (1L shl bit)
                bit++
            }
        }
        return hash
    }

    /**
     * How many bits differ. 0 is identical, 64 is opposite.
     *
     * Under about 10 on a 64 bit hash is the same picture. Above 16 is a
     * different picture that happens to share a composition, and the space
     * between is where a threshold has to be chosen rather than derived.
     */
    fun distance(a: Long, b: Long): Int = java.lang.Long.bitCount(a xor b)

    /**
     * Variance of the Laplacian. Higher is sharper.
     *
     * The standard measure, and the reasoning is simple: a sharp image has
     * abrupt intensity changes at edges, so the second derivative is large in
     * places and small in others, giving a wide spread. A blurred image has
     * gentle changes everywhere, so the second derivative is small everywhere
     * and the spread collapses.
     *
     * ─── IT IS SCALE DEPENDENT, AND THAT IS HANDLED ──────────────────────────
     *
     * The same photo measured at 1000 pixels and at 200 gives different numbers,
     * so a threshold is meaningless unless every image is measured at the same
     * size. Every caller here works at one fixed size for exactly that reason.
     *
     * ─── IT CANNOT TELL BLUR FROM INTENT ─────────────────────────────────────
     *
     * A portrait with a deliberately soft background, a photo of fog, a picture
     * of a blank wall: all score low and none is a mistake. This is why the UI
     * must present these as "worth a look" and never delete on the score alone.
     */
    fun sharpness(source: Bitmap, size: Int = 256): Double {
        val small = Bitmap.createScaledBitmap(source, size, size, true)
        val pixels = IntArray(size * size)
        small.getPixels(pixels, 0, size, 0, 0, size, size)
        if (small !== source) small.recycle()

        val grey = DoubleArray(size * size)
        for (i in pixels.indices) grey[i] = luma(pixels[i]).toDouble()

        var sum = 0.0
        var sumSquares = 0.0
        var count = 0

        // The 4 neighbour kernel, skipping the border so no index check is
        // needed inside the loop.
        for (y in 1 until size - 1) {
            for (x in 1 until size - 1) {
                val i = y * size + x
                val laplace = grey[i - size] + grey[i + size] +
                    grey[i - 1] + grey[i + 1] - 4 * grey[i]
                sum += laplace
                sumSquares += laplace * laplace
                count++
            }
        }
        if (count == 0) return 0.0

        val mean = sum / count
        return sumSquares / count - mean * mean
    }

    /** Rec. 601 luma. Cheap, and closer to perceived brightness than an average. */
    private fun luma(pixel: Int): Int {
        val r = (pixel shr 16) and 0xFF
        val g = (pixel shr 8) and 0xFF
        val b = pixel and 0xFF
        return (r * 299 + g * 587 + b * 114) / 1000
    }
}
