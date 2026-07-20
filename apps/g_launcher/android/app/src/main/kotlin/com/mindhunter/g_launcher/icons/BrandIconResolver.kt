package com.mindhunter.g_launcher.icons

import android.content.Context
import android.graphics.Color
import android.graphics.Path
import androidx.core.graphics.PathParser
import com.mindhunter.g_launcher.apps.ComponentKey
import org.json.JSONObject
import java.io.File

/**
 * The HEAD of the icon pipeline: a brand glyph for the apps everyone recognises.
 *
 * Three layers feed the recipe engine, most specific first:
 *
 *   1. HeroIconResolver — hand-drawn, per distro, ~40-60 icons. Wins.
 *   2. THIS             — CC0 brand glyphs, shared across every theme, thousands.
 *   3. IconExtractor    — the generator, re-masking the app's own icon. Always
 *                         succeeds, so nothing is ever left blank.
 *
 * Hero beats brand deliberately. Hero art is drawn FOR one distro and says
 * "this is Yaru's Firefox"; a brand glyph is the same silhouette under every
 * theme and only says "this is Firefox". When a distro has bothered to draw one,
 * that is the more specific answer.
 *
 * WHY A PATH AND NOT A PICTURE. Every Simple Icon is a single `<path>` in a
 * 24x24 viewBox — not a document, not layers, one string and one brand hex. So
 * the pack ships as JSON path data and is rasterised natively at whatever size
 * is asked for. Roughly 1KB per icon against tens of KB for a PNG that is also
 * locked to one resolution, which is the difference between the full 3,449-icon
 * set being a ~3.5MB CDN file and being impossible.
 *
 * The CC0 licence covers the FILES, not the trademarks. Several major brands
 * (LinkedIn, Amazon, Microsoft, Adobe, Canva) are simply absent from the set for
 * that reason, and they are exactly the apps the hero packs need to cover.
 */

/** How a brand glyph is coloured. Parsed from a string; see the Pigeon schema. */
enum class BrandTreatment {
    /**
     * Plate in the brand's own colour, glyph in whichever of white/near-black
     * reads on it. WhatsApp stays green. Recognisable, slightly less cohesive.
     */
    BRAND_PLATE,

    /**
     * Plate in the theme's own background (flat or graded), glyph in the brand
     * hex. The whole grid reads as one set, at some cost to recognisability.
     */
    THEME_PLATE;

    companion object {
        /** Unknown or absent degrades to BRAND_PLATE rather than throwing. */
        fun parse(raw: String?): BrandTreatment = when (raw) {
            "themePlate" -> THEME_PLATE
            else -> BRAND_PLATE
        }
    }
}

/** One brand glyph: geometry in viewBox units, plus the brand's own colour. */
data class BrandGlyph(
    /** Raw SVG path data, in [BrandIconResolver.viewBox] units. */
    val pathData: String,

    /** ARGB. The brand's published colour. */
    val color: Int,
)

class BrandIconResolver(context: Context) {

    private val appContext = context.applicationContext

    /** CDN packs land here; bundled ones come out of Flutter's asset bundle. */
    private val downloadedPacksDir = File(appContext.filesDir, "brandpacks")

    private data class Pack(
        val id: String,
        val viewBox: Float,
        val glyphs: Map<String, BrandGlyph>,
    )

    private var loadedId: String? = null
    private var pack: Pack? = null

    /** The pack's coordinate space, 24 for Simple Icons. 0 when no pack. */
    val viewBox: Float get() = pack?.viewBox ?: 24f

    /** Cheap and idempotent — safe to call on every theme switch. */
    @Synchronized
    fun load(packId: String?) {
        if (packId == loadedId) return
        loadedId = packId
        pack = packId?.let { runCatching { readPack(it) }.getOrNull() }
    }

    /**
     * The brand glyph for this component, or null to fall through.
     *
     * Package name only. Unlike hero packs there is no componentKey tier: a
     * brand glyph identifies the BRAND, and every launchable activity in a
     * package belongs to the same brand.
     */
    @Synchronized
    fun resolve(componentKey: String): BrandGlyph? {
        val p = pack ?: return null
        val key = ComponentKey.parse(componentKey) ?: return null
        return p.glyphs[key.packageName]
    }

    /**
     * Parses path data into a Path in viewBox units. The renderer scales it.
     *
     * THE ONLY PLACE PATH DATA IS PARSED, on purpose. `androidx.core.graphics`
     * is the convenient answer but its parser has moved in and out of restricted
     * API over the years. If it is unavailable in the core version this build
     * resolves, vendoring AOSP's parser (Apache-2.0) is a drop-in replacement
     * and this is the single line that has to change.
     *
     * Returns null on malformed data rather than throwing: a bad glyph from a
     * CDN pack must degrade to the generator, not take out the drawer.
     */
    fun parsePath(glyph: BrandGlyph): Path? =
        runCatching { PathParser.createPathFromPathData(glyph.pathData) }.getOrNull()

    // ---- pack loading ----------------------------------------------------

    /**
     * pack.json:
     * {
     *   "id": "simple-icons",
     *   "viewBox": 24,
     *   "icons": {
     *     "com.whatsapp": { "d": "M17.472 14.382…", "hex": "25D366" }
     *   }
     * }
     */
    private fun readPack(packId: String): Pack? {
        val raw = openPackFile(packId, "pack.json") ?: return null
        val json = JSONObject(String(raw))
        val iconsJson = json.optJSONObject("icons") ?: return null

        val glyphs = buildMap {
            iconsJson.keys().forEach { pkg ->
                val entry = iconsJson.optJSONObject(pkg) ?: return@forEach
                val d = entry.optString("d").takeIf { it.isNotEmpty() } ?: return@forEach
                // Hex is stored without the leading '#', the way the upstream
                // dataset publishes it. Missing or unparseable falls back to a
                // neutral grey rather than dropping an otherwise good glyph.
                val hex = entry.optString("hex")
                val color = runCatching { Color.parseColor("#$hex") }.getOrDefault(0xFF6E6E6E.toInt())
                put(pkg, BrandGlyph(pathData = d, color = color))
            }
        }
        if (glyphs.isEmpty()) return null

        return Pack(
            id = packId,
            viewBox = json.optDouble("viewBox", 24.0).toFloat(),
            glyphs = glyphs,
        )
    }

    /**
     * CDN-downloaded packs win over bundled ones with the same id, so the brand
     * map can grow — new apps appear constantly — without a Play release. Same
     * property the themes and hero packs have.
     */
    private fun openPackFile(packId: String, filename: String): ByteArray? {
        val downloaded = File(File(downloadedPacksDir, packId), filename)
        if (downloaded.exists()) {
            return runCatching { downloaded.readBytes() }.getOrNull()
        }

        val assetPath = "flutter_assets/assets/brandpacks/$packId/$filename"
        return runCatching {
            appContext.assets.open(assetPath).use { it.readBytes() }
        }.getOrNull()
    }
}
