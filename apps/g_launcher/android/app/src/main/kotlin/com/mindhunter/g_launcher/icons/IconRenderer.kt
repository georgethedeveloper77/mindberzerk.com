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
        paths: List<Path>,
        viewBox: Float,
        style: IconStyle,
        sizePx: Int,
        /** True when the pack draws outlines. Stroke weight is in viewBox units. */
        stroked: Boolean = false,
        strokeWidth: Float = 1f,
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val s = sizePx.toFloat()

        canvas.save()
        if (style.treatment != IconTreatment.ORIGINAL) {
            canvas.clipPath(maskPath(style, sizePx))
        }

        // ─── A LINE PACK HAS NO BRAND COLOUR, SO IT HAS NO BRAND PLATE ───────
        //
        // `BRAND_PLATE` means "fill the tile with the brand's own colour and
        // draw the mark on top". A line set publishes no colour: the whole
        // point is that the DISTRO supplies it. Asking for a brand plate here
        // would fill every tile with the fallback grey and produce 13,000
        // identical grey squares.
        //
        // So a stroked pack takes the theme-plate path regardless of what the
        // theme asked for. Handling it here rather than adding a third
        // `BrandTreatment` case is deliberate: a new enum value renumbers every
        // downstream Pigeon codec id, and it would be a wire-format change to
        // express something the pack already states about itself.
        val brandColour = glyph.color
        val glyphColor = when {
            stroked || brandColour == null || style.brandTreatment == BrandTreatment.THEME_PLATE -> {
                // Theme's own plate, themed glyph. When the theme sets no
                // background there is nothing to sit on, so fall back to the
                // brand plate rather than drawing a coloured glyph on nothing.
                // ─── A STROKED PACK DARKENS THE PLATE, NOT THE INK ────────
                //
                // Ubuntu's theme sets its plate to the accent, so an orange
                // outline on it is orange-on-orange. The obvious remedy is to
                // recolour the ink, and it is the wrong one: the tint IS the
                // product, and all fourteen packs would render white.
                //
                // So the PLATE moves. `plateFor` blends it toward black until
                // the stroke reads, keeping the hue, so Ubuntu gets a warm
                // near-black and Kali a cold one. A theme that already authored
                // a dark plate is returned untouched.
                //
                // Only for stroked packs, and only when the pack names a tint.
                // A hero pack or Simple Icons is unaffected, which is why this
                // is here rather than in `fillBackground`, where it would
                // repaint the generator too.
                // Both LOCALS, and both `val`, so the null checks below smart
                // cast. The first attempt tested `brandColour != null` inside
                // the expression that built the plate, which left the branch
                // yielding `Int?` and the whole `when` with it: "actual type is
                // Int?, but Int was expected" pointing at `paint.color`, forty
                // lines away from the cause.
                //
                // `style.backgroundColor` is read into a local for the same
                // reason: it is a property of a Pigeon-generated class, and
                // Kotlin will not smart cast one of those.
                val strokeInk = if (stroked) brandColour else null
                val plateBase = style.backgroundColor

                if (strokeInk != null && plateBase != null) {
                    canvas.drawColor(IconContrast.plateFor(plateBase, strokeInk))
                    strokeInk
                } else if (fillBackground(canvas, style, sizePx)) {
                    // ─── THE PACK'S COLOUR WINS, NOT THE THEME'S ──────────
                    //
                    // This read `monochromeTint ?: brandColour`, and that order
                    // was wrong the moment derived packs existed.
                    //
                    // `monochromeTint` is a THEME statement: "everything is one
                    // accent colour". `brandColour` is now the PACK's tint,
                    // stamped on every glyph by the `extends` resolver, and it
                    // is the entire product: fourteen packs share one geometry
                    // and differ only here.
                    //
                    // With the theme first, Ubuntu's white monochromeTint beat
                    // the pack's orange and every one of the fourteen rendered
                    // identically in white. Somebody who bought Kali blue while
                    // running Ubuntu would have received white, and there is no
                    // error anywhere that says so.
                    //
                    // The theme keeps its say when the pack has no colour of its
                    // own, which is every hero and Simple Icons pack. Only a
                    // pack that names a tint overrides it, and naming one is a
                    // deliberate act.
                    brandColour
                        ?: style.monochromeTint
                        ?: contrastOn(style.backgroundColor ?: Color.BLACK)
                } else {
                    val plate = brandColour ?: style.monochromeTint ?: Color.BLACK
                    canvas.drawColor(plate)
                    contrastOn(plate)
                }
            }

            else -> {
                canvas.drawColor(brandColour)
                contrastOn(brandColour)
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
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = glyphColor
            // `this.` is load-bearing for readability: the IconStyle parameter
            // is also called `style`, and Paint.style silently shadows it here.
            this.style = if (stroked) Paint.Style.STROKE else Paint.Style.FILL
            if (stroked) {
                // ─── ROUND CAPS AND JOINS ARE NOT A FLOURISH ─────────────────
                //
                // Arcticons and every set like it declare
                // `stroke-linecap:round; stroke-linejoin:round` in their source.
                // Android's default is BUTT and MITER, so drawing without these
                // gives every line square ends and sharp corners, which does not
                // look like a bug so much as like a different, worse icon set.
                strokeCap = Paint.Cap.ROUND
                strokeJoin = Paint.Join.ROUND
                // The width travels through the SAME viewBox-to-pixel scale the
                // geometry does. Setting it in pixels would make a 48-unit
                // drawing's line weight depend on the icon size, so the set
                // would look heavier in the dock than in the drawer.
                this.strokeWidth = strokeWidth * scale
            }
        }

        // Transform a COPY. The caller's Paths are parsed per render today, but
        // this class must not mutate anything it is handed — the moment paths
        // get cached, an in-place transform becomes a compounding scale bug that
        // only shows on the second draw.
        //
        // DRAWN SEPARATELY, not unioned into one Path. `addPath` would merge
        // them into a single stroked shape, and where two unrelated strokes
        // happen to end near each other the round joins would connect them.
        for (p in paths) {
            canvas.drawPath(Path(p).apply { transform(matrix) }, paint)
        }

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

        // Monochrome requested but unavailable: fall back to the real foreground
        // rather than drawing nothing. A themed launcher with holes in the grid
        // is worse than one that is 80% themed. Slice 5's hero icons close the
        // gap for the apps people actually look at.
        val tint = style.monochromeTint
        val fg = if (tint != null && icon.monochrome != null) icon.monochrome else icon.foreground

        val applyTint = tint != null && icon.monochrome != null

        // ─── THE FOREGROUND IS CHOSEN BEFORE THE BACKGROUND IS DRAWN ────────
        //
        // It used to be the other way round, which meant the plate was already
        // on the canvas by the time anything knew what would be drawn over it.
        // That ordering is what let an icon paint dark artwork onto a dark
        // plate: nothing in the sequence ever had both facts at once.
        val plan = legibilityPlan(fg, style, if (applyTint) tint else null)

        drawBackground(canvas, icon, style, sizePx, plan.keepAppBackground)
        drawLayer(canvas, fg, sizePx, ADAPTIVE_OVERSCAN * style.foregroundScale, plan.tint)

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

    /**
     * What to draw, once the plate and the artwork have been considered together.
     *
     * @param tint              the colour filter for the foreground layer, or null.
     * @param keepAppBackground true when the themed plate must be skipped and
     *                          the app's own background layer drawn instead.
     */
    private data class LegibilityPlan(val tint: Int?, val keepAppBackground: Boolean)

    /**
     * ─── DARK ART ON A DARK PLATE, AND WHAT TO DO ABOUT IT ──────────────────
     *
     * An adaptive icon's foreground was drawn to sit on the background layer the
     * app shipped with it. Nothing records which way round that pairing runs, and
     * plenty of them are dark artwork over a light layer. Replacing the light
     * layer with a dark themed plate leaves a black shape on a black square,
     * which is what Samsung Messages, Samsung Music and My Files were doing.
     *
     * There are two ways out, and which one is right depends on WHICH layer is
     * about to be drawn:
     *
     *   A MONOCHROME layer exists to be tinted, so a tint that cannot be seen is
     *   simply the wrong tint, and choosing a legible one is using the layer as
     *   its author intended. Retint.
     *
     *   The COLOURED foreground is real artwork. Tinting it would flatten it to
     *   a silhouette and throw away the colours that make the app recognisable,
     *   so the plate is the thing that gives way. The app's own background comes
     *   back, and the icon keeps the themed SHAPE through the mask clip. Less
     *   coherent than the rest of the set, and far better than a black square.
     *
     * When the theme sets no plate there is nothing to conflict with, so this is
     * a null check and a return: the common path costs one comparison.
     */
    private fun legibilityPlan(
        foreground: Drawable?,
        style: IconStyle,
        tint: Int?,
    ): LegibilityPlan {
        if (style.treatment == IconTreatment.ORIGINAL) return LegibilityPlan(tint, false)
        val plate = IconContrast.plateLuminance(style) ?: return LegibilityPlan(tint, false)

        val ink = IconContrast.inkLuminance(foreground, tint)
            ?: return LegibilityPlan(tint, false)

        if (IconContrast.ratio(ink, plate) >= IconContrast.MIN_RATIO) {
            return LegibilityPlan(tint, false)
        }

        return if (tint != null) {
            LegibilityPlan(IconContrast.legibleTint(plate), false)
        } else {
            LegibilityPlan(null, true)
        }
    }

    private fun drawBackground(
        canvas: Canvas,
        icon: ExtractedIcon,
        style: IconStyle,
        sizePx: Int,
        keepAppBackground: Boolean,
    ) {
        // ORIGINAL means "leave the app's own shape alone". There is no clip in
        // that case, so a flat fill would paint a full SQUARE plate behind an
        // icon whose whole point was to keep its silhouette — and renderLegacy
        // already declines to plate an ORIGINAL icon, so filling here made the
        // two paths disagree. Keep the app's own background instead.
        //
        // [keepAppBackground] is the second reason to decline, and it comes from
        // `legibilityPlan`: the themed plate would have made this icon's own
        // artwork invisible.
        if (!keepAppBackground &&
            style.treatment != IconTreatment.ORIGINAL &&
            fillBackground(canvas, style, sizePx)
        ) {
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
