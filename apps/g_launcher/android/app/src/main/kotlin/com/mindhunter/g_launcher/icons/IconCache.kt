package com.mindhunter.g_launcher.icons

import android.content.Context
import android.graphics.Bitmap
import android.util.LruCache
import com.mindhunter.g_launcher.apps.AppRepository
import com.mindhunter.g_launcher.cdn.PackChangeNotifier
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

/**
 * The slice that decides whether the drawer scrolls.
 *
 * Three layers, fastest first:
 *   1. memory LRU  — microseconds. Nearly every hit during a fling lands here.
 *   2. disk        — ~1ms. Survives process death, which is the whole point:
 *                    a launcher gets killed constantly, and re-rendering 200
 *                    icons on every cold start would be a visible stall.
 *   3. render      — 2-5ms per icon. On a 40-icon screen that is several
 *                    dropped frames if it ever happens on the main thread.
 *                    So it never does.
 *
 * Cache key is (componentKey, updateToken, themeId, sizePx):
 *   - updateToken changes when the app updates -> new icon, new key.
 *   - themeId changes when the user switches theme.
 *   - sizePx because home grid and drawer ask for different sizes, and scaling
 *     a 96px bitmap up to 144px looks exactly as bad as it sounds.
 */
class IconCache(
    context: Context,
    private val repository: AppRepository,
    private val extractor: IconExtractor,
    private val renderer: IconRenderer,
    private val heroes: HeroIconResolver,
    private val brands: BrandIconResolver,
) {

    private companion object {
        /**
         * ~1/8 of the heap, the conventional Android split. A 144px ARGB_8888
         * icon is ~83KB raw, but we cache PNG bytes (~8-15KB), so this holds
         * several hundred — more than any drawer shows at once.
         */
        val MEMORY_BUDGET_BYTES: Int = (Runtime.getRuntime().maxMemory() / 8).toInt()
    }

    private val diskDir = File(context.applicationContext.cacheDir, "icons").apply { mkdirs() }

    /**
     * Two threads, not one: a fling can request 20 icons at once and a single
     * worker serialises them into a visible cascade. Not more than two — icon
     * rendering is allocation-heavy and more threads just means more GC.
     */
    private val io = Executors.newFixedThreadPool(2)

    private val memory = object : LruCache<String, ByteArray>(MEMORY_BUDGET_BYTES) {
        override fun sizeOf(key: String, value: ByteArray): Int = value.size
    }

    init {
        // PHASE C2 — the hot-swap. The cache registers ITSELF rather than being
        // wired up by whoever constructs it, because the cache is the thing that
        // knows it must invalidate, and a registration living in
        // LauncherApplication is a line someone deletes during a refactor
        // without any test noticing.
        //
        // Fires on a WorkManager thread. Everything it touches is either
        // @Synchronized or thread-safe, and the disk sweep goes onto [io].
        PackChangeNotifier.register { _, packId -> onPackChanged(packId) }
    }

    @Volatile
    private var themeId: String = "default"

    @Volatile
    private var style: IconStyle = IconStyle(treatment = IconTreatment.ROUNDED_SQUARE)

    /**
     * Memory is dropped; disk is NOT. Switching back to a theme you have used
     * before then costs a disk read rather than 200 re-renders.
     *
     * THE EARLY RETURN IS LOAD-BEARING, NOT AN OPTIMISATION.
     *
     * Dart's `effectiveThemeProvider` watches `prefsProvider`, and calls this on
     * every emit. So this method fires on EVERY prefs write — hiding an app,
     * moving the dock, toggling verbose boot, nudging drawer columns, creating a
     * folder. None of those touch the icons, and `iconCacheId` comes back
     * byte-identical, but without this guard `evictAll()` still runs and the
     * whole memory tier is thrown away. The user then flings the drawer and every
     * icon re-reads from disk (~1ms each) for no reason at all.
     *
     * IconStyle is a data class, so this comparison is structural and free.
     * Do not "simplify" it away.
     */
    fun setTheme(themeId: String, style: IconStyle) {
        if (themeId == this.themeId && style == this.style) return

        this.themeId = themeId
        this.style = style
        heroes.load(style.heroPack)
        brands.load(style.brandPack)
        memory.evictAll()
    }

    /** Callback fires on an IO thread. Marshal to main yourself. */
    fun get(componentKey: String, sizePx: Int, callback: (ByteArray?) -> Unit) {
        val token = repository.cached()
            .firstOrNull { it.componentKey == componentKey }
            ?.updateToken
            ?: 0L

        val key = cacheKey(componentKey, token, sizePx)

        memory.get(key)?.let {
            callback(it)
            return
        }

        io.execute {
            val bytes = runCatching { loadOrRender(componentKey, key, sizePx) }.getOrNull()
            if (bytes != null) memory.put(key, bytes)
            callback(bytes)
        }
    }

    /**
     * A verified pack just landed. Drop everything derived from the old one.
     *
     * THE DISK TIER IS THE SUBTLE HALF. The cache key includes
     * `style.fingerprint()`, which carries the pack ID but NOT the pack
     * VERSION — deliberately, because threading a version through IconStyle
     * would mean touching all eight of the places a field has to be added and
     * would change the Pigeon wire format for something no theme author ever
     * sets. The consequence is that after an update the disk key is unchanged,
     * so every icon rendered from the old pack keeps being served from disk,
     * forever, and a brand pack that just gained 3,400 glyphs looks exactly
     * like a download that never happened.
     *
     * Clearing disk here costs a one-off re-render of whatever is on screen,
     * at most once a day, on a job that already only runs on unmetered power.
     * That is the correct trade.
     *
     * Ignores the packId and clears everything. Being precise would mean
     * knowing which cached bitmaps came from which layer of the pipeline, and
     * that information is not kept anywhere — nor should it be, to save one
     * re-render a day.
     */
    fun onPackChanged(packId: String) {
        // Both resolvers keep the id they were asked for, so an update — same
        // id, new bytes — needs reload(), not load(). load() would early-return.
        heroes.reload()
        brands.reload()
        clear()
    }

    fun clear() {
        memory.evictAll()
        io.execute { diskDir.listFiles()?.forEach { it.delete() } }
    }

    fun shutdown() = io.shutdown()

    // ---- internals -------------------------------------------------------

    private fun loadOrRender(componentKey: String, key: String, sizePx: Int): ByteArray? {
        val file = File(diskDir, key)
        if (file.exists()) {
            return runCatching { file.readBytes() }.getOrNull()
        }

        // THREE LAYERS, MOST SPECIFIC FIRST. Each miss is normal, not an error.
        //
        //   1. hero      — hand-drawn FOR this distro. "Yaru's Firefox."
        //   2. brand     — CC0 glyph, same under every theme. "Firefox."
        //   3. generator — re-masks the app's own icon. Always succeeds, so the
        //                  grid never has a hole in it.
        //
        // Hero above brand is the whole point of hero packs: when a distro has
        // bothered to draw an icon, that is the more specific answer than a
        // silhouette shared with every other theme.
        val bitmap = renderHero(componentKey, sizePx)
            ?: renderBrand(componentKey, sizePx)
            ?: renderGenerated(componentKey, sizePx)
            ?: return null

        val bytes = bitmap.toPngBytes()
        bitmap.recycle()

        // Write to a temp file and rename: two threads can race on the same
        // icon, and a half-written PNG in the cache is a corrupt icon forever.
        runCatching {
            val tmp = File(diskDir, "$key.tmp")
            tmp.writeBytes(bytes)
            tmp.renameTo(file)
        }

        return bytes
    }

    private fun renderHero(componentKey: String, sizePx: Int): Bitmap? {
        val hero = heroes.resolve(componentKey) ?: return null
        return renderer.renderHero(hero, style, sizePx, heroes.packWantsMask())
    }

    /**
     * A brand glyph, if the pack has one AND its path parses. Malformed path
     * data from a CDN pack falls through to the generator rather than throwing —
     * a bad glyph should cost one app its brand icon, not take out the drawer.
     */
    private fun renderBrand(componentKey: String, sizePx: Int): Bitmap? {
        val glyph = brands.resolve(componentKey) ?: return null
        val path = brands.parsePath(glyph) ?: return null
        return renderer.renderBrand(glyph, path, brands.viewBox, style, sizePx)
    }

    private fun renderGenerated(componentKey: String, sizePx: Int): Bitmap? {
        val icon = extractor.extract(componentKey) ?: return null
        return renderer.render(icon, style, sizePx)
    }

    private fun Bitmap.toPngBytes(): ByteArray {
        val out = java.io.ByteArrayOutputStream(16 * 1024)
        // PNG quality is ignored (lossless). WEBP would be smaller but costs
        // more CPU to decode, and we are optimising for scroll, not for disk.
        compress(Bitmap.CompressFormat.PNG, 100, out)
        return out.toByteArray()
    }

    private fun cacheKey(componentKey: String, token: Long, sizePx: Int): String {
        val raw = "$componentKey|$token|$themeId|$sizePx|${style.fingerprint()}"
        val digest = MessageDigest.getInstance("SHA-1").digest(raw.toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }

    /**
     * Belt and braces: themeId SHOULD change whenever the style changes, but if
     * someone edits a CDN theme without bumping its id, this keeps stale icons
     * out of the cache instead of shipping a bug that only reproduces on
     * devices that happened to fetch the old theme first.
     */
    private fun IconStyle.fingerprint(): String =
        "${treatment.name}:$cornerRadius:$foregroundScale:$backgroundColor:" +
            "$monochromeTint:$heroPack:$backgroundGradientEnd:$gradientAngle:" +
            "$brandPack:${brandTreatment.name}"
}
