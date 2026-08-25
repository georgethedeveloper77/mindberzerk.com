package com.mindhunter.g_launcher.icons

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import com.mindhunter.g_launcher.apps.ComponentKey
import com.mindhunter.g_launcher.cdn.PackPaths
import org.json.JSONObject

/**
 * The difference between "themed" and "authentic".
 *
 * The generator (IconExtractor + IconRenderer) re-masks every app's real icon,
 * which gives 100% coverage but always looks like *Android icons wearing a
 * costume*. A real Ubuntu desktop does not show a re-tinted Chrome icon; it
 * shows the Yaru Chrome icon, drawn by hand, in the Yaru style.
 *
 * So: 40-60 hand-drawn icons per theme, covering the apps that DEFINE the
 * distro (Files, Terminal, Settings, Software) plus the handful of third-party
 * apps everyone actually has on their home screen. Those override the
 * generator. Everything else falls through to it. Plan §5.4.
 *
 * Lookup order, most specific first:
 *   1. exact componentKey  — for apps with several launchable activities
 *   2. packageName         — the normal case
 *   3. miss                — caller falls through to the generator
 */
class HeroIconResolver(context: Context) {

    private val appContext = context.applicationContext

    private data class Pack(
        val id: String,
        /**
         * True when the pack ships square, full-bleed artwork that still needs
         * the theme's mask applied. False when each icon is already final art
         * with its own silhouette and transparency — which is the usual case,
         * and masking it would slice the corners off.
         */
        val masked: Boolean,
        /** packageName or componentKey -> asset filename within the pack. */
        val icons: Map<String, String>,
    )

    private var loadedId: String? = null
    private var pack: Pack? = null

    /** Cheap and idempotent — safe to call on every theme switch. */
    @Synchronized
    fun load(packId: String?) {
        if (packId == loadedId) return
        loadedId = packId
        pack = packId?.let { runCatching { readPack(it) }.getOrNull() }
    }

    /**
     * Re-read from disk even when the id is unchanged. PHASE C2: an UPDATE keeps
     * the same pack id, so [load]'s early return would leave the old artwork
     * loaded until the process dies. See BrandIconResolver.reload for the long
     * version; this is the same trap.
     */
    @Synchronized
    fun reload() {
        val id = loadedId ?: return
        pack = runCatching { readPack(id) }.getOrNull()
    }

    /** True when the pack ships pre-masked square art that we must still shape. */
    fun packWantsMask(): Boolean = pack?.masked ?: false

    /**
     * The hand-drawn icon for this component, or null to fall through to the
     * generator. A missing hero icon is NOT an error — by design, most apps miss.
     *
     * [sizePx] is the edge the renderer will draw this at, and it is a REQUEST
     * rather than a promise: [decodeSampled] only ever halves, so what comes
     * back is at least this big and never upscaled. Pass the same value that
     * reaches `IconRenderer.renderHero`, because that is the size the drawable
     * is about to be squeezed into by `drawLayer`.
     */
    @Synchronized
    fun resolve(componentKey: String, sizePx: Int): Drawable? {
        val p = pack ?: return null
        val key = ComponentKey.parse(componentKey) ?: return null

        val filename = p.icons[componentKey]
            ?: p.icons[key.packageName]
            ?: return null

        val bytes = openPackFile(p.id, filename) ?: return null
        val bitmap = decodeSampled(bytes, sizePx) ?: return null
        return BitmapDrawable(appContext.resources, bitmap)
    }

    /**
     * Decode at the size we are going to draw at, not at whatever size the pack
     * author happened to export.
     *
     * ─── THE COST OF NOT DOING THIS ─────────────────────────────────────────
     *
     * `IconRenderer.drawLayer` calls `setBounds(0, 0, sizePx, sizePx)` and
     * draws, so a `BitmapDrawable` is scaled down by the canvas at paint time
     * no matter how large its bitmap is. The full-resolution decode was
     * therefore always thrown away: correct output, wasted allocation.
     *
     * The waste is not small. A 512px source is 1 MB at ARGB_8888 against the
     * 83 KB the 144px result needs, and a hero pack is 40 to 60 icons that all
     * pass through here on a cold drawer. Google Play flags this decode site
     * for exactly this reason.
     *
     * ─── WHY POWERS OF TWO ONLY ─────────────────────────────────────────────
     *
     * `inSampleSize` is documented to round DOWN to a power of two, so asking
     * for 3 silently gets 2 and the arithmetic you thought you did is not the
     * arithmetic that ran. Halving in a loop is the same result stated
     * honestly, and it stops one step before the result would be smaller than
     * requested, so nothing is ever upscaled to fill the tile. Hero art is the
     * most expensive pixels in the app and softening it to save memory would
     * be selling the wrong trade.
     *
     * The bounds pass reads the header only. It does not allocate pixels.
     */
    private fun decodeSampled(bytes: ByteArray, sizePx: Int): Bitmap? {
        if (sizePx <= 0) return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)

        // A pack file that is not an image at all, or is truncated. Fall through
        // to the plain decode so the caller's own null handling stays the single
        // place a bad hero icon is dealt with.
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        }

        var sample = 1
        while (
            bounds.outWidth / (sample * 2) >= sizePx &&
            bounds.outHeight / (sample * 2) >= sizePx
        ) {
            sample *= 2
        }

        val opts = BitmapFactory.Options().apply {
            inSampleSize = sample
            // inDensity and inTargetDensity are both left at 0, so
            // `setDensityFromOptions` leaves the bitmap's density exactly where
            // the no-Options decode left it. This method must not change what
            // the drawable reports, only how many pixels back it.
            inScaled = false
        }
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
    }

    // ---- pack loading ----------------------------------------------------

    /**
     * pack.json:
     * {
     *   "id": "yaru",
     *   "name": "Yaru",
     *   "masked": false,
     *   "icons": {
     *     "com.android.chrome": "chrome.png",
     *     "com.whatsapp": "whatsapp.png",
     *     "org.mozilla.firefox": "firefox.png"
     *   }
     * }
     */
    private fun readPack(packId: String): Pack? {
        val raw = openPackFile(packId, "pack.json") ?: return null
        val json = JSONObject(String(raw))

        val iconsJson = json.optJSONObject("icons") ?: return null
        val icons = buildMap {
            iconsJson.keys().forEach { k -> put(k, iconsJson.getString(k)) }
        }

        return Pack(
            id = packId,
            masked = json.optBoolean("masked", false),
            icons = icons,
        )
    }

    /**
     * CDN-downloaded packs win over bundled ones with the same id, so a theme's
     * icon set can be fixed or extended without shipping a Play release — the
     * same property the themes themselves have.
     */
    private fun openPackFile(packId: String, filename: String): ByteArray? {
        // PHASE C2: the verified packs root. filesDir/heropacks is gone; see
        // PackPaths for why an unverified read path next to a verified one is
        // worse than no read path at all.
        PackPaths.installedFile(appContext, packId, filename)?.let { downloaded ->
            return runCatching { downloaded.readBytes() }.getOrNull()
        }

        // Bundled: Flutter puts declared assets under flutter_assets/ in the APK.
        val assetPath = "flutter_assets/assets/heropacks/$packId/$filename"
        return runCatching {
            appContext.assets.open(assetPath).use { it.readBytes() }
        }.getOrNull()
    }
}
