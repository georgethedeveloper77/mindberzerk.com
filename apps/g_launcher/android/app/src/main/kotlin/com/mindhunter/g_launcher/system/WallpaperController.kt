package com.mindhunter.g_launcher.system

import android.annotation.SuppressLint
import android.app.WallpaperManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.net.Uri
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Sets the REAL system wallpaper, rather than the launcher painting its own.
 *
 * Why it matters: if the shell draws its own Image over an opaque window, the
 * wallpaper does not appear in Recents, does not appear behind the app grid,
 * and live wallpapers do not work at all. Users cannot articulate why it feels
 * wrong, but they feel it. Setting the actual system wallpaper — with
 * windowShowWallpaper=true and a transparent window — is what makes the desktop
 * illusion hold together.
 *
 * SET_WALLPAPER is a normal permission: auto-granted, no prompt.
 */
class WallpaperController(context: Context) {

    private companion object {
        const val TAG = "GLauncherWallpaper"
    }

    private val appContext = context.applicationContext
    private val manager = WallpaperManager.getInstance(appContext)

    /**
     * Three schemes, one entry point — so the rotation worker never has to care
     * where a wallpaper came from:
     *
     *   asset:<path>   bundled in the APK
     *   https://…      CDN. Downloaded once, cached, then treated as local.
     *   content:// …   a photo the user picked
     *
     * The CDN case is what lets a new distro ship wallpapers without a Play
     * release — the same property themes and hero icon packs have.
     */
    fun setWallpaper(
        source: String,
        applyToLock: Boolean,
        fit: String = "cover",
        letterboxColor: Long = 0xFF000000L,
        focalX: Float = 0.5f,
        focalY: Float = 0.5f,
        zoom: Float = 1f,
    ): Boolean {
        // Clamped HERE rather than trusted from the caller. These arrive over a
        // Pigeon channel from stored prefs, and prefs outlive the code that
        // wrote them: a value authored by a future build, or a hand-edited
        // theme.json, must degrade to something sane rather than produce a
        // degenerate crop rect that the system silently ignores. A zoom below 1
        // would ask for a region larger than the bitmap.
        val fx = focalX.coerceIn(0f, 1f)
        val fy = focalY.coerceIn(0f, 1f)
        val z = zoom.coerceIn(1f, 4f)

        val decoded = decodeSampled(source, fit) ?: return false

        // "cover" (and anything unrecognised, per the degrade rule the schema
        // documents) is the LEGACY PATH, untouched: the sampled bitmap goes to
        // the system as before, keeping the 2x scroll width and therefore the
        // parallax existing users already have. Only the three fits that mean
        // "compose against MY screen" pay for a composite.
        val bitmap = when (fit) {
            "contain", "fill", "center" ->
                composite(decoded, fit, letterboxColor.toInt(), fx, fy, z).also {
                    if (it !== decoded) decoded.recycle()
                }
            else -> decoded
        }

        // ─── WHY THE CROP HINT IS NOW COMPUTED AND NOT NULL ─────────────────
        //
        // The composite fits have already drawn against this exact screen, so
        // the bitmap IS the frame and there is nothing left to hint: null is
        // correct for them.
        //
        // "cover" is the one that was wrong, and it was wrong for everybody
        // because it is the default. It handed the sampled bitmap over with a
        // null hint, and null means "display the full image if possible given
        // the image's and the device's aspect ratios", so the SYSTEM decided
        // which part of a 1200x2400 dragon survived being fitted to a surface
        // roughly twice the screen's width. That decision is not documented,
        // varies by OEM, and depends on the source aspect, which is exactly why
        // some wallpapers looked centred and others looked shoved sideways with
        // no pattern anyone could name.
        //
        // A hint of the surface's own aspect, positioned on the focal point,
        // replaces that guess with arithmetic and STILL SCROLLS: the hint is
        // the visible window, the rest of the bitmap remains available to pan
        // into. That is the whole reason this is a hint rather than a crop.
        val hint = if (bitmap === decoded) cropHint(bitmap, fx, fy, z) else null

        return try {
            // The flag-based overload is API 24 and minSdk is 26, so there is no
            // legacy branch here. The single-argument setBitmap() it replaced
            // could not target home and lock separately.
            manager.setBitmap(bitmap, hint, true, WallpaperManager.FLAG_SYSTEM)
            if (applyToLock) {
                manager.setBitmap(bitmap, hint, true, WallpaperManager.FLAG_LOCK)
            }
            true
        } catch (e: Exception) {
            // A failed wallpaper set must never take the launcher down. Worst
            // case the user keeps the wallpaper they already had.
            Log.w(TAG, "setWallpaper failed for $source", e)
            false
        } finally {
            bitmap.recycle()
        }
    }

    // ---- stash / restore -------------------------------------------------
    //
    // A theme replacing your wallpaper is fine. A theme replacing your wallpaper
    // with no way back is not. The honest position on how much of a net this
    // actually is, is in stashWallpaper's own comment. Read it before treating
    // restore as a guarantee anywhere else in the codebase.

    /**
     * Copies the current system wallpaper aside, ONCE.
     *
     * Once is the whole contract: called before every theme apply, but it
     * refuses to overwrite an existing stash. Otherwise the second theme switch
     * would stash the FIRST theme's wallpaper as "yours", and the original would
     * be gone for good.
     *
     * THIS IS EXPECTED TO RETURN FALSE ON ALMOST EVERY SHIPPING DEVICE, and that
     * is not a bug to chase. Reading the wallpaper back has been closed off in
     * two stages:
     *
     *   API 26 to 32   getWallpaperFile needs READ_EXTERNAL_STORAGE, which this
     *                  app does not declare and will not: a launcher asking for
     *                  storage to read a wallpaper is a worse trade than losing
     *                  the feature.
     *   API 33+        restricted to the app that set the wallpaper. A storage
     *                  permission would not help even if we held one, and the
     *                  alternatives lint names (MANAGE_EXTERNAL_STORAGE,
     *                  READ_WALLPAPER_INTERNAL) are respectively unshippable for
     *                  a launcher and signature-level.
     *
     * A live wallpaper or an OEM default has no file to hand over either way.
     *
     * So: the call is left in because it costs nothing and does work on the odd
     * ROM that permits it, false is the normal return, the Dart side hides its
     * restore option, and nothing pretends otherwise. If restore needs to be
     * real rather than opportunistic, it has to come from the user picking their
     * own wallpaper through ACTION_OPEN_DOCUMENT before the first theme apply.
     * That is a product decision, not a fix to this method.
     */
    @SuppressLint("MissingPermission")
    fun stashWallpaper(): Boolean {
        val stash = stashFile()
        if (stash.exists() && stash.length() > 0) return true

        return try {
            // Throws SecurityException on most devices. Caught below, by design.
            val fd = manager.getWallpaperFile(WallpaperManager.FLAG_SYSTEM)
                ?: return false // live wallpaper, OEM default, or not readable

            fd.use { descriptor ->
                FileInputStream(descriptor.fileDescriptor).use { input ->
                    // Temp-then-rename, same as the CDN cache: a half-written
                    // stash that we later trust is worse than no stash.
                    val tmp = File(stash.parentFile, "${stash.name}.tmp")
                    tmp.outputStream().use { input.copyTo(it) }
                    tmp.renameTo(stash)
                }
            }
            stash.exists() && stash.length() > 0
        } catch (e: Exception) {
            Log.w(TAG, "could not stash the current wallpaper", e)
            false
        }
    }

    fun hasStashedWallpaper(): Boolean =
        stashFile().let { it.exists() && it.length() > 0 }

    /**
     * Puts the stashed wallpaper back on home AND lock, then deletes the stash.
     *
     * Deleting is deliberate: after a restore the user is back where they
     * started, so the next theme apply should stash afresh. Keeping the old copy
     * would pin "restore" to a wallpaper from months ago.
     */
    fun restoreWallpaper(): Boolean {
        val stash = stashFile()
        if (!stash.exists() || stash.length() == 0L) return false

        val ok = setWallpaper(stash.absolutePath.let { "file://$it" }, true)
        if (ok) stash.delete()
        return ok
    }

    /**
     * Lives in filesDir, not cacheDir. The CDN cache is disposable by design and
     * the OS may clear it whenever it likes; the one copy of the user's own
     * wallpaper must not evaporate because storage got tight.
     */
    private fun stashFile(): File =
        File(appContext.filesDir, "wallpaper_stash.img")

    /**
     * Draws [src] onto a screen-sized canvas per [fit], bars filled with
     * [color] (the theme's own background, passed from Dart, so a letterboxed
     * photo still reads as that distro's desktop).
     *
     * SINGLE screen size, not the 2x scroll width: a chosen fit means "this is
     * how the image meets MY screen", and a panning wallpaper would re-crop it
     * per page, which contradicts the choice. Scroll stays a cover-only
     * property. Overflow (center on a large photo) clips at the canvas edge,
     * which IS the crop the mode promises.
     */
    private fun composite(
        src: Bitmap,
        fit: String,
        color: Int,
        focalX: Float,
        focalY: Float,
        zoom: Float,
    ): Bitmap {
        val metrics = appContext.resources.displayMetrics
        val w = metrics.widthPixels
        val h = metrics.heightPixels
        if (w <= 0 || h <= 0) return src

        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        canvas.drawColor(color)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)

        val dst = when (fit) {
            // FOCAL IS IGNORED for these two, deliberately, and that is not an
            // oversight to fix later. "fill" maps the whole image onto the
            // whole screen and "contain" shows the whole image inside it, so in
            // both cases every pixel of the source is already on screen. There
            // is nothing to choose between, and honouring a focal point here
            // would mean cropping an image whose entire promise is that it is
            // not cropped. The UI hides the framing drag on these fits for the
            // same reason.
            "fill" -> RectF(0f, 0f, w.toFloat(), h.toFloat())
            "contain" -> centred(
                src,
                minOf(w / src.width.toFloat(), h / src.height.toFloat()),
                w,
                h,
            )
            // "center": actual size, scaled by the user's zoom. This is the one
            // composite fit where framing means something, because the image
            // can be larger than the screen and something has to decide which
            // part of it you keep. decodeSampled has already brought a huge
            // photo near screen resolution, which is what actual-size means
            // once the alternative is an OOM.
            else -> focused(src, zoom, w, h, focalX, focalY)
        }
        canvas.drawBitmap(src, null, dst, paint)
        return out
    }

    private fun centred(src: Bitmap, scale: Float, w: Int, h: Int): RectF {
        val dw = src.width * scale
        val dh = src.height * scale
        val left = (w - dw) / 2f
        val top = (h - dh) / 2f
        return RectF(left, top, left + dw, top + dh)
    }

    /**
     * Like [centred], but the point [fx], [fy] of the source is pulled to the
     * middle of the screen where there is room to move it.
     *
     * THE CLAMP IS THE POINT. Sliding an oversized image around is what framing
     * means, but sliding an UNDERSIZED one only opens a letterbox gap on the
     * far side, which is a worse picture than the centred version the user
     * would otherwise have got. So each axis is clamped independently: pan the
     * axis that overflows, centre the axis that does not. A tall dragon on a
     * tall screen is therefore free vertically and pinned horizontally, which
     * is the behaviour you want and not a special case anyone has to author.
     */
    private fun focused(
        src: Bitmap,
        zoom: Float,
        w: Int,
        h: Int,
        fx: Float,
        fy: Float,
    ): RectF {
        val dw = src.width * zoom
        val dh = src.height * zoom

        val left = if (dw > w) {
            (w / 2f - fx * dw).coerceIn(w - dw, 0f)
        } else {
            (w - dw) / 2f
        }
        val top = if (dh > h) {
            (h / 2f - fy * dh).coerceIn(h - dh, 0f)
        } else {
            (h - dh) / 2f
        }
        return RectF(left, top, left + dw, top + dh)
    }

    /**
     * The sub-rectangle of [src] the system should treat as the visible window,
     * shaped like the wallpaper surface and centred on the focal point.
     *
     * SHAPED LIKE THE SURFACE, NOT THE SCREEN. `desiredMinimumWidth` is what
     * the platform actually holds, which on a scrolling launcher is roughly
     * twice the screen width. Handing it a screen-shaped hint would make it
     * stretch that region across the whole scroll span, and the wallpaper would
     * come out zoomed in with the pan doing nothing. Asking the manager rather
     * than hardcoding 2x also means an OEM that does not scroll gets a
     * screen-shaped hint for free.
     *
     * Returns null rather than a degenerate rect when the arithmetic cannot
     * produce a usable region, because null is the documented "you decide" and
     * a zero-area Rect is undefined behaviour.
     */
    private fun cropHint(src: Bitmap, fx: Float, fy: Float, zoom: Float): Rect? {
        val metrics = appContext.resources.displayMetrics
        val screenW = metrics.widthPixels
        val screenH = metrics.heightPixels
        if (screenW <= 0 || screenH <= 0) return null

        val surfaceW = manager.desiredMinimumWidth.takeIf { it > 0 } ?: (screenW * 2)
        val surfaceH = manager.desiredMinimumHeight.takeIf { it > 0 } ?: screenH
        if (surfaceH <= 0) return null

        val aspect = surfaceW.toFloat() / surfaceH.toFloat()
        val bw = src.width.toFloat()
        val bh = src.height.toFloat()
        if (bw <= 0f || bh <= 0f) return null

        // Largest rect of the surface's aspect that fits inside the bitmap,
        // then divided by the zoom, which is what zooming in means: keep less.
        var cw = min(bw, bh * aspect)
        var ch = cw / aspect
        if (ch > bh) {
            ch = bh
            cw = ch * aspect
        }
        cw /= zoom
        ch /= zoom
        if (cw < 1f || ch < 1f) return null

        val left = (fx * bw - cw / 2f).coerceIn(0f, bw - cw)
        val top = (fy * bh - ch / 2f).coerceIn(0f, bh - ch)

        val rect = Rect(
            left.roundToInt(),
            top.roundToInt(),
            (left + cw).roundToInt(),
            (top + ch).roundToInt(),
        )
        // Rounding can collapse a one-pixel edge case. A null hint is the old
        // behaviour, which is worse but never broken.
        return if (rect.width() > 0 && rect.height() > 0) rect else null
    }

    /**
     * Decoding a full-res wallpaper straight into memory is a reliable OOM on a
     * 4GB Tecno — a 4000x3000 JPEG is ~48MB as ARGB_8888. Sample it down to the
     * screen first.
     */
    private fun decodeSampled(source: String, fit: String): Bitmap? {
        val metrics = appContext.resources.displayMetrics
        // ─── THE TARGET DEPENDS ON THE FIT, AND IT DID NOT USED TO ──────────
        //
        // "cover" hands the bitmap to the system, which spreads it across a
        // surface roughly twice the screen's width, so it genuinely needs the
        // extra resolution. The composite fits draw onto a canvas that is
        // exactly one screen, so asking for double was buying a bitmap twice
        // the size and throwing half of it away. On a 4GB Tecno that is not a
        // rounding error, it is the difference between one sample step and two.
        val wide = fit != "contain" && fit != "fill" && fit != "center"
        val targetW = if (wide) {
            manager.desiredMinimumWidth.takeIf { it > 0 } ?: (metrics.widthPixels * 2)
        } else {
            metrics.widthPixels
        }
        val targetH = metrics.heightPixels

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        open(source)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0) return null

        val opts = BitmapFactory.Options().apply {
            inSampleSize = sampleSize(bounds.outWidth, bounds.outHeight, targetW, targetH)
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }

        return open(source)?.use { BitmapFactory.decodeStream(it, null, opts) }
    }

    private fun sampleSize(w: Int, h: Int, reqW: Int, reqH: Int): Int {
        var sample = 1
        val halfW = w / 2
        val halfH = h / 2
        while (halfW / sample >= reqW && halfH / sample >= reqH) {
            sample *= 2
        }
        return sample
    }

    private fun open(source: String): InputStream? = try {
        when {
            source.startsWith("asset:") -> {
                // Flutter bundles declared assets under flutter_assets/.
                appContext.assets.open("flutter_assets/${source.removePrefix("asset:")}")
            }

            source.startsWith("http://") || source.startsWith("https://") -> {
                cached(source)?.inputStream()
            }

            // The stash is written by us, so it is a plain path rather than a
            // content URI — contentResolver would refuse it.
            source.startsWith("file://") ->
                File(source.removePrefix("file://")).inputStream()

            else -> appContext.contentResolver.openInputStream(Uri.parse(source))
        }
    } catch (e: Exception) {
        Log.w(TAG, "cannot open $source", e)
        null
    }

    /**
     * Downloads a CDN wallpaper once, then serves it from disk forever.
     *
     * Note this is called TWICE per set — once to read the bounds, once to
     * decode — which is exactly why it must hit disk on the second call rather
     * than re-download. It is also why the download must not happen on the main
     * thread: the host API already routes setWallpaper through an IO executor,
     * and WallpaperWorker is a background worker by definition.
     */
    private fun cached(url: String): File? {
        val dir = File(appContext.cacheDir, "wallpapers").apply { mkdirs() }
        val file = File(dir, hash(url))
        if (file.exists() && file.length() > 0) return file

        return try {
            val connection = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 15_000
                readTimeout = 30_000
                instanceFollowRedirects = true
            }

            connection.inputStream.use { input ->
                // Temp-then-rename: a half-downloaded wallpaper left in the cache
                // is a permanently corrupt wallpaper, since we would then treat
                // it as already-fetched.
                val tmp = File(dir, "${file.name}.tmp")
                tmp.outputStream().use { input.copyTo(it) }
                tmp.renameTo(file)
            }

            if (file.exists()) file else null
        } catch (e: Exception) {
            // Offline, or the CDN is down. The user keeps the wallpaper they
            // have; the rotation worker moves on to the next source.
            Log.w(TAG, "download failed: $url", e)
            null
        }
    }

    private fun hash(url: String): String {
        val digest = MessageDigest.getInstance("SHA-1").digest(url.toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }
}
