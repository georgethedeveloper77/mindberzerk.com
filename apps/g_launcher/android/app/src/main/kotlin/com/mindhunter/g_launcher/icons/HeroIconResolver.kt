package com.mindhunter.g_launcher.icons

import android.content.Context
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
     */
    @Synchronized
    fun resolve(componentKey: String): Drawable? {
        val p = pack ?: return null
        val key = ComponentKey.parse(componentKey) ?: return null

        val filename = p.icons[componentKey]
            ?: p.icons[key.packageName]
            ?: return null

        val bytes = openPackFile(p.id, filename) ?: return null
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
        return BitmapDrawable(appContext.resources, bitmap)
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
