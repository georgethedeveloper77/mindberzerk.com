package com.mindhunter.g_launcher.icons

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.PorterDuff
import android.graphics.PorterDuffColorFilter
import android.graphics.drawable.Drawable
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow

/**
 * IS THE ART GOING TO BE VISIBLE ON THE PLATE WE ARE ABOUT TO PUT BEHIND IT.
 *
 * ─── THE BUG THIS EXISTS FOR ────────────────────────────────────────────────
 *
 * `IconRenderer.drawBackground` discards `icon.background` whenever the theme
 * sets `backgroundColor`. That is the whole point of a themed plate and it is
 * correct. But an adaptive icon's FOREGROUND was drawn to sit on the background
 * the app shipped, and a good number of them are dark artwork on a light layer.
 * Replace the light layer with a dark plate and the foreground becomes a black
 * shape on a black square.
 *
 * Observed on a Galaxy S22 under the Kali theme: Samsung Messages, Samsung
 * Music and My Files all rendered as soft black blobs. Nothing threw, nothing
 * logged, and the icons were technically drawn exactly as specified.
 *
 * The same failure reaches the monochrome path from the other direction. A
 * theme that sets a dark `monochromeTint` gets a dark monochrome layer on its
 * own dark plate, and monochrome layers are simplified silhouettes, so the
 * result looks like a smudge rather than like the app.
 *
 * ─── WHY MEASURE RATHER THAN GUESS ──────────────────────────────────────────
 *
 * There is no flag on an adaptive icon saying "my foreground is dark". The only
 * honest way to know is to look at the pixels that are about to be drawn. So
 * this rasterises the layer once, small, and reads the ink.
 *
 * It runs behind `IconCache`, once per package per style, never in a scroll.
 */
internal object IconContrast {

    /**
     * Probe size. 24 squared is 576 pixels, which is enough to characterise a
     * layer's overall lightness and small enough that the cost disappears next
     * to the full-size render happening in the same call.
     */
    private const val PROBE = 24

    /** Below this, a pixel is antialiasing spill rather than ink. */
    private const val ALPHA_FLOOR = 8

    /**
     * The ratio below which we treat the pairing as a failure.
     *
     * DELIBERATELY LENIENT. WCAG asks 3:1 for large text, but a false positive
     * here does not dim a label, it silently un-themes an icon that looked
     * fine, and a set where a scattering of icons opted out of the theme for
     * reasons no screen explains is worse than the bug being fixed. The real
     * failures sit close to 1.0: black artwork on a near-black plate measures
     * about 1.1. Anything at 2.0 or above is legible even if it is not pretty.
     */
    const val MIN_RATIO = 2.0f

    /**
     * The target for a STROKED pack, which is higher than [MIN_RATIO].
     *
     * ─── A LINE IS NOT A SHAPE ────────────────────────────────────────────────
     *
     * [MIN_RATIO] was chosen for filled monochrome icons, where a large solid
     * area carries the contrast and 2:1 is enough to read.
     *
     * An outline set is 1.8 device pixels of stroke on a Tecno. At 2:1 it is
     * legible in the strict sense and muddy in practice: Ubuntu orange on a
     * 2.13:1 plate reads as a smudge at 96px. At 4.5 the same icon lands on
     * `#391407` and the line is crisp.
     *
     * Measured across all fourteen tints. Fedora's `#3C6EB4` is the one that
     * cannot reach it and falls through to black, which is the correct floor
     * rather than a failure.
     */
    const val STROKE_RATIO = 4.5f

    /**
     * Alpha-weighted mean relative luminance of a drawable's ink, 0 to 1.
     *
     * Null when the layer has no ink at all, which happens with a fully
     * transparent foreground and means there is nothing to judge.
     *
     * WEIGHTED BY ALPHA, not a plain average over covered pixels. A line icon
     * is mostly edge, and edges are partially covered; counting a 10% covered
     * pixel the same as a solid one biases every thin drawing toward the
     * background colour it happens to be composited against, which is exactly
     * the value this is trying to measure independently of.
     */
    fun inkLuminance(drawable: Drawable?, tint: Int?): Float? {
        if (drawable == null) return null

        val bitmap = Bitmap.createBitmap(PROBE, PROBE, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        // Same discipline as `IconRenderer.drawLayer`: drawables from
        // LauncherApps are shared and framework-cached, so a colour filter left
        // behind on one turns up tinted in the system UI.
        val previous = drawable.colorFilter
        val bounds = drawable.copyBounds()
        try {
            if (tint != null) {
                drawable.colorFilter = PorterDuffColorFilter(tint, PorterDuff.Mode.SRC_IN)
            }
            drawable.setBounds(0, 0, PROBE, PROBE)
            drawable.draw(canvas)
        } finally {
            drawable.colorFilter = previous
            drawable.bounds = bounds
        }

        val pixels = IntArray(PROBE * PROBE)
        bitmap.getPixels(pixels, 0, PROBE, 0, 0, PROBE, PROBE)
        bitmap.recycle()

        var weighted = 0.0
        var weight = 0.0
        for (p in pixels) {
            val a = (p ushr 24) and 0xFF
            if (a <= ALPHA_FLOOR) continue
            weighted += relativeLuminance(p) * a
            weight += a.toDouble()
        }
        if (weight == 0.0) return null
        return (weighted / weight).toFloat()
    }

    /**
     * The plate's luminance, or null when the theme is not overriding it.
     *
     * A gradient is averaged rather than sampled at one end. The art sits over
     * the whole plate, so one end being legible is not the question; a diagonal
     * gradient from near-black to near-white averages to a mid tone, and a mid
     * tone is genuinely the hardest case for both dark and light artwork.
     */
    fun plateLuminance(style: IconStyle): Float? {
        val start = style.backgroundColor ?: return null
        val end = style.backgroundGradientEnd ?: return relativeLuminance(start).toFloat()
        return ((relativeLuminance(start) + relativeLuminance(end)) / 2.0).toFloat()
    }

    /** WCAG contrast ratio between two relative luminances, 1.0 to 21.0. */
    fun ratio(a: Float, b: Float): Float {
        val hi = max(a, b)
        val lo = min(a, b)
        return (hi + 0.05f) / (lo + 0.05f)
    }

    /**
     * Black or white, whichever the plate can actually carry.
     *
     * Only ever applied to a MONOCHROME layer. A monochrome layer exists to be
     * tinted, so choosing a legible tint for it is using it as intended, not
     * overriding the author. The coloured foreground is never treated this way,
     * because tinting real artwork flattens it to a silhouette and throws the
     * colours away.
     */
    /**
     * A plate dark enough for [ink] to read on, keeping the distro's hue.
     *
     * ─── DARKEN THE PLATE, DO NOT RECOLOUR THE INK ────────────────────────────
     *
     * A line pack's colour IS the product: fourteen packs share one geometry and
     * differ only in tint. So when the tint collides with the theme's plate, the
     * ink must not move. Recolouring it to white makes all fourteen identical
     * and silently deletes the thing somebody paid for.
     *
     * The plate is blended toward black instead of replaced with it, so Ubuntu
     * keeps a warm near-black and Kali a cold one. The distro is still visible
     * in the surround; the outline is what carries it.
     *
     * Returns the ORIGINAL colour when it already reads, so a theme that
     * authored a sensible dark plate is left exactly as it is.
     */
    fun plateFor(plate: Int, ink: Int): Int {
        val inkLum = relativeLuminance(ink).toFloat()
        if (ratio(relativeLuminance(plate).toFloat(), inkLum) >= STROKE_RATIO) return plate

        // Stepped rather than solved, because the target is a ratio and the
        // relationship between blend fraction and luminance is not linear. Ten
        // steps is finer than the eye resolves and always terminates.
        for (step in 1..10) {
            val blended = blendToBlack(plate, step / 10f * 0.94f)
            if (ratio(relativeLuminance(blended).toFloat(), inkLum) >= STROKE_RATIO) return blended
        }
        // Nothing dark enough worked, which means the ink itself is very dark.
        // Black is the most contrast a plate can offer; the caller's own
        // fallback handles the rest.
        return Color.BLACK
    }

    /** [colour] mixed toward black by [amount], preserving hue. */
    private fun blendToBlack(colour: Int, amount: Float): Int {
        val keep = 1f - amount
        return Color.rgb(
            (Color.red(colour) * keep).toInt(),
            (Color.green(colour) * keep).toInt(),
            (Color.blue(colour) * keep).toInt(),
        )
    }

    fun legibleTint(plateLuminance: Float): Int =
        if (plateLuminance < 0.35f) Color.WHITE else Color.BLACK

    /** sRGB relative luminance, the WCAG definition. */
    private fun relativeLuminance(colour: Int): Double {
        val r = channel((colour shr 16) and 0xFF)
        val g = channel((colour shr 8) and 0xFF)
        val b = channel(colour and 0xFF)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private fun channel(value: Int): Double {
        val c = value / 255.0
        return if (c <= 0.03928) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
    }
}
