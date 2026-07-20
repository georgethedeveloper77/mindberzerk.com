package com.mindhunter.g_launcher.icons

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PorterDuff
import android.graphics.PorterDuffColorFilter
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import kotlin.math.abs
import kotlin.math.pow
import kotlin.math.sign

/**
 * The shape an icon gets forced into. This is what ThemeSpec.icons.treatment
 * maps onto — one enum, one `when` in maskPath(). Adding a distro's shape means
 * adding one branch here, not touching anything else.
 */
enum class IconTreatment {
    CIRCLE,
    SQUIRCLE,
    ROUNDED_SQUARE,
    SQUARE,
    TEARDROP,

    /** Leave the app's own shape alone. Honest, and sometimes the right call. */
    ORIGINAL,
}

/**
 * The icon half of a ThemeSpec, resolved.
 *
 * @param backgroundColor  null = keep the app's own adaptive background layer.
 *                         Set = flat fill (what makes a Papirus/Breeze set feel
 *                         coherent rather than a bag of vendor colours).
 * @param monochromeTint   null = draw the app's real, coloured foreground.
 *                         Set = force the monochrome layer, tinted. This is the
 *                         "everything is one accent colour" look. It DEGRADES
 *                         when an app has no monochrome layer — see render().
 */
data class IconStyle(
    val treatment: IconTreatment = IconTreatment.ROUNDED_SQUARE,

    /**
     * Corner radius as a FRACTION of icon size, for ROUNDED_SQUARE.
     * 0.0 = square, 0.22 = default, 0.35 = One UI-ish, 0.5 = circle.
     *
     * A float rather than more enum cases on purpose: a distro whose icons are
     * a little squarer than KDE's should be a CDN theme edit, not a Play
     * release. That is the "new distros ship without an app update" property.
     */
    val cornerRadius: Float = 0.22f,

    val backgroundColor: Int? = null,
    val monochromeTint: Int? = null,

    /** <1 insets the glyph inside the shape. Papirus-ish sets want ~0.72. */
    val foregroundScale: Float = 1.0f,

    /** Hand-drawn pack that overrides the generator, e.g. "yaru". Plan §5.4. */
    val heroPack: String? = null,

    /**
     * Far end of a background gradient, ARGB. Null = flat fill.
     *
     * [backgroundColor] is the near end, so a gradient REQUIRES it. End set with
     * backgroundColor null means there is no flat fill to grade from, and
     * fillBackground falls back to the app's own adaptive background.
     */
    val backgroundGradientEnd: Int? = null,

    /**
     * Direction in degrees, rotating from top-to-bottom (0) toward left-to-right
     * (90). 45 is the diagonal most desktop icon sets use, and is the default
     * when a theme sets an end colour but no angle.
     */
    val gradientAngle: Float = 45f,

    /** CC0 brand-glyph pack, e.g. "simple-icons". Null = skip the brand layer. */
    val brandPack: String? = null,

    /** How a brand glyph is coloured. See [BrandTreatment]. */
    val brandTreatment: BrandTreatment = BrandTreatment.BRAND_PLATE,
)

/**
 * Turns an ExtractedIcon + IconStyle into a Bitmap.
 *
 * Pure and synchronous. It allocates a Bitmap per call, so it must NOT be
 * called from a scroll — that is what the cache in slice 4 is for.
 */
class IconRenderer {

    private companion object {
        /**
         * Adaptive icons are 108dp with a 72dp guaranteed-visible safe zone, so
         * the layers must be drawn 108/72 = 1.5x oversized and centre-cropped.
         * Skip this and every icon looks subtly zoomed-out with a visible seam
         * at the corners.
         */
        const val ADAPTIVE_OVERSCAN = 1.5f

        /** Superellipse exponent. 4.0 is the iOS-ish squircle. */
        const val SQUIRCLE_N = 4.0

        /**
         * How much of the canvas a brand glyph occupies. Chosen to match the
         * Android adaptive keyline (~60%), so a brand glyph and a generated icon
         * are the same optical size in the same grid.
         */
        const val BRAND_GLYPH_RATIO = 0.58f
    }

    // NO MUTABLE FIELDS ON THIS CLASS. One IconRenderer instance is shared by
    // IconCache's two-thread IO pool, so render() and renderHero() run
    // concurrently. Everything they touch must be a local. There used to be a
    // shared `paint` field here; it was never actually used, which is the only
    // reason it was not a race waiting to happen. Allocate Paints inside the
    // method — a Paint per icon is nothing next to the Bitmap it draws into.

    /**
     * A hand-drawn hero icon. Already final artwork, so by default it is drawn
     * as-is: masking it would slice the corners off a silhouette the artist
     * already shaped.
     *
     * [applyMask] is for packs that ship square full-bleed tiles and expect the
     * theme to shape them. The pack declares which it is.
     */
    fun renderHero(
        hero: Drawable,
        style: IconStyle,
        sizePx: Int,
        applyMask: Boolean,
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        if (applyMask && style.treatment != IconTreatment.ORIGINAL) {
            canvas.save()
            canvas.clipPath(maskPath(style, sizePx))
            fillBackground(canvas, style, sizePx)
            drawLayer(canvas, hero, sizePx, 1.0f, null)
            canvas.restore()
            return bitmap
        }

        drawLayer(canvas, hero, sizePx, 1.0f, null)
        return bitmap
    }

    /**
     * A CC0 brand glyph: one path in viewBox units, plus the brand's colour.
     *
     * The glyph is drawn at [BRAND_GLYPH_RATIO] of the canvas rather than full
     * bleed, and that ratio is not arbitrary. An adaptive icon's artwork sits
     * inside the Android keyline at roughly 60% of its tile, because that is
     * what the platform tells developers to draw. A brand glyph filling its
     * whole plate would read noticeably LARGER than every generated icon beside
     * it in the same grid. Matching the keyline is what makes a mixed drawer —
     * some brand, some hero, some generated — look like one icon set.
     */
    fun renderBrand(
        glyph: BrandGlyph,
        path: Path,
        viewBox: Float,
        style: IconStyle,
        sizePx: Int,
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val s = sizePx.toFloat()

        canvas.save()
        if (style.treatment != IconTreatment.ORIGINAL) {
            canvas.clipPath(maskPath(style, sizePx))
        }

        val glyphColor = when (style.brandTreatment) {
            BrandTreatment.THEME_PLATE -> {
                // Theme's own plate, brand-coloured glyph. If the theme sets no
                // background there is nothing to sit on, so fall back to the
                // brand plate rather than drawing a coloured glyph on nothing.
                if (fillBackground(canvas, style, sizePx)) {
                    glyph.color
                } else {
                    canvas.drawColor(glyph.color)
                    contrastOn(glyph.color)
                }
            }

            BrandTreatment.BRAND_PLATE -> {
                canvas.drawColor(glyph.color)
                contrastOn(glyph.color)
            }
        }

        // viewBox units -> pixels, centred, at the keyline ratio.
        val extent = s * BRAND_GLYPH_RATIO * style.foregroundScale
        val scale = extent / viewBox
        val offset = (s - extent) / 2f

        val matrix = Matrix().apply {
            setScale(scale, scale)
            postTranslate(offset, offset)
        }
        // Transform a COPY. The caller's Path is parsed per render today, but
        // this class must not mutate anything it is handed — the moment paths
        // get cached, an in-place transform becomes a compounding scale bug that
        // only shows on the second draw.
        val scaled = Path(path).apply { transform(matrix) }

        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = glyphColor
            // `this.` is load-bearing for readability: the IconStyle parameter
            // is also called `style`, and Paint.style silently shadows it here.
            this.style = Paint.Style.FILL
        }
        canvas.drawPath(scaled, paint)

        canvas.restore()
        return bitmap
    }

    /**
     * Black or white, whichever reads on [plate]. Rec. 709 relative luminance,
     * which tracks perception far better than averaging the channels — a
     * saturated green like WhatsApp's is much brighter to the eye than its RGB
     * mean suggests, and averaging would put white text on it.
     *
     * Near-black rather than pure black: #1A1A1A on a bright plate looks like
     * ink, pure black looks like a hole.
     */
    private fun contrastOn(plate: Int): Int {
        val r = Color.red(plate) / 255f
        val g = Color.green(plate) / 255f
        val b = Color.blue(plate) / 255f
        val luminance = 0.2126f * r + 0.7152f * g + 0.0722f * b
        return if (luminance > 0.55f) 0xFF1A1A1A.toInt() else Color.WHITE
    }

    fun render(icon: ExtractedIcon, style: IconStyle, sizePx: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        // A legacy icon has its shape baked into opaque pixels. Masking it to a
        // circle slices the corners off the artwork. So: give it a themed
        // background plate and draw the original, shrunk, on top. It is the
        // least-bad option and it is what every good icon pack does.
        if (!icon.isAdaptive) {
            renderLegacy(canvas, icon, style, sizePx)
            return bitmap
        }

        val mask = maskPath(style, sizePx)
        canvas.save()
        if (style.treatment != IconTreatment.ORIGINAL) {
            canvas.clipPath(mask)
        }

        drawBackground(canvas, icon, style, sizePx)

        // Monochrome requested but unavailable: fall back to the real foreground
        // rather than drawing nothing. A themed launcher with holes in the grid
        // is worse than one that is 80% themed. Slice 5's hero icons close the
        // gap for the apps people actually look at.
        val tint = style.monochromeTint
        val fg = if (tint != null && icon.monochrome != null) icon.monochrome else icon.foreground

        val applyTint = tint != null && icon.monochrome != null
        drawLayer(canvas, fg, sizePx, ADAPTIVE_OVERSCAN * style.foregroundScale, if (applyTint) tint else null)

        canvas.restore()
        return bitmap
    }

    private fun renderLegacy(
        canvas: Canvas,
        icon: ExtractedIcon,
        style: IconStyle,
        sizePx: Int,
    ) {
        if (style.treatment != IconTreatment.ORIGINAL) {
            canvas.save()
            canvas.clipPath(maskPath(style, sizePx))

            // No plate when the theme sets no background: a legacy icon on a
            // transparent plate is just the legacy icon, which is correct.
            fillBackground(canvas, style, sizePx)

            // 0.72 keeps the original artwork clear of the mask edge.
            drawLayer(canvas, icon.foreground, sizePx, 0.72f * style.foregroundScale, null)
            canvas.restore()
            return
        }

        drawLayer(canvas, icon.foreground, sizePx, style.foregroundScale, null)
    }

    private fun drawBackground(
        canvas: Canvas,
        icon: ExtractedIcon,
        style: IconStyle,
        sizePx: Int,
    ) {
        // ORIGINAL means "leave the app's own shape alone". There is no clip in
        // that case, so a flat fill would paint a full SQUARE plate behind an
        // icon whose whole point was to keep its silhouette — and renderLegacy
        // already declines to plate an ORIGINAL icon, so filling here made the
        // two paths disagree. Keep the app's own background instead.
        if (style.treatment != IconTreatment.ORIGINAL && fillBackground(canvas, style, sizePx)) {
            return
        }

        val bg = icon.background ?: ColorDrawable(Color.WHITE)
        drawLayer(canvas, bg, sizePx, ADAPTIVE_OVERSCAN, null)
    }

    /**
     * Paints the themed background plate into the current clip, flat or graded.
     *
     * Returns false when the theme asked for no plate at all, so the caller can
     * fall back to the app's own background layer.
     *
     * A gradient needs BOTH ends: [IconStyle.backgroundColor] is the near end.
     * An end colour with no start is treated as "no plate" rather than guessed
     * at, because guessing produces an icon set that is subtly wrong on every
     * app and no obvious place to look.
     */
    private fun fillBackground(canvas: Canvas, style: IconStyle, sizePx: Int): Boolean {
        val start = style.backgroundColor ?: return false
        val end = style.backgroundGradientEnd

        if (end == null) {
            canvas.drawColor(start)
            return true
        }

        val s = sizePx.toFloat()
        val rad = Math.toRadians(style.gradientAngle.toDouble())
        val dx = kotlin.math.sin(rad).toFloat()
        val dy = kotlin.math.cos(rad).toFloat()

        // Half-extent of a square projected onto the gradient direction. Using
        // s/2 instead would stop short of the corners on a diagonal, leaving a
        // flat band of the end colour along two edges.
        val half = (abs(dx) + abs(dy)) * s / 2f
        val cx = s / 2f
        val cy = s / 2f

        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                cx - dx * half,
                cy - dy * half,
                cx + dx * half,
                cy + dy * half,
                start,
                end,
                Shader.TileMode.CLAMP,
            )
        }

        // drawPaint fills the current CLIP, which is the mask path — so the
        // gradient takes the icon's shape for free.
        canvas.drawPaint(paint)
        return true
    }

    /**
     * Draws [drawable] centred, scaled by [scale] relative to [sizePx].
     * scale > 1 overscans (adaptive layers); scale < 1 insets (icon-pack look).
     */
    private fun drawLayer(
        canvas: Canvas,
        drawable: Drawable?,
        sizePx: Int,
        scale: Float,
        tint: Int?,
    ) {
        if (drawable == null) return

        val extent = (sizePx * scale).toInt()
        val offset = (sizePx - extent) / 2

        val previousFilter = drawable.colorFilter
        if (tint != null) {
            drawable.colorFilter = PorterDuffColorFilter(tint, PorterDuff.Mode.SRC_IN)
        }

        drawable.setBounds(offset, offset, offset + extent, offset + extent)
        drawable.draw(canvas)

        // Drawables from LauncherApps can be shared/cached by the framework.
        // Leaving a colour filter on one is how you end up with a blue Gmail
        // icon everywhere, including in the system UI.
        drawable.colorFilter = previousFilter
    }

    private fun maskPath(style: IconStyle, size: Int): Path {
        val s = size.toFloat()
        val path = Path()
        val rect = RectF(0f, 0f, s, s)

        when (style.treatment) {
            IconTreatment.CIRCLE -> path.addOval(rect, Path.Direction.CW)

            IconTreatment.SQUIRCLE -> superellipse(path, s, SQUIRCLE_N)

            IconTreatment.ROUNDED_SQUARE -> {
                val r = s * style.cornerRadius.coerceIn(0f, 0.5f)
                path.addRoundRect(rect, r, r, Path.Direction.CW)
            }

            IconTreatment.SQUARE -> path.addRect(rect, Path.Direction.CW)

            IconTreatment.TEARDROP -> {
                // Three round corners, one square. The old Pixel shape.
                val r = s * 0.5f
                path.addRoundRect(
                    rect,
                    floatArrayOf(r, r, r, r, 0f, 0f, r, r),
                    Path.Direction.CW,
                )
            }

            IconTreatment.ORIGINAL -> path.addRect(rect, Path.Direction.CW)
        }
        return path
    }

    /**
     * |x/a|^n + |y/b|^n = 1, sampled. A rounded-rect is NOT a squircle — the
     * curvature is discontinuous where the arc meets the straight edge, and on a
     * grid of 40 icons the eye picks it up as "slightly wrong" even when nobody
     * can say why. This is cheap and it is cached, so do it properly.
     */
    private fun superellipse(path: Path, size: Float, n: Double) {
        val half = size / 2.0
        val steps = 96
        val exp = 2.0 / n

        for (i in 0..steps) {
            val theta = 2.0 * Math.PI * i / steps
            val cos = kotlin.math.cos(theta)
            val sin = kotlin.math.sin(theta)

            val x = half + half * abs(cos).pow(exp) * sign(cos)
            val y = half + half * abs(sin).pow(exp) * sign(sin)

            if (i == 0) path.moveTo(x.toFloat(), y.toFloat())
            else path.lineTo(x.toFloat(), y.toFloat())
        }
        path.close()
    }
}
