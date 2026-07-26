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

    // Held because the picker queries the package manager on demand, long after
    // construction. The constructor parameter is not a property, so a method
    // cannot reach it.
    private val appContext = context.applicationContext

    private val diskDir = File(appContext.cacheDir, "icons").apply { mkdirs() }

    /**
     * Third-party icon packs (Icon Pack Studio, Nova-format packs from Play).
     *
     * CONSTRUCTED HERE rather than injected, unlike the other four collaborators,
     * and that is deliberate. Those are passed in because they are shared: the
     * extractor and renderer are used by more than one caller. This one has
     * exactly one consumer, so injecting it would mean editing whoever builds
     * the cache to hand over an object only the cache ever touches.
     */
    private val iconPacks = IconPackResolver(appContext)

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
     * The user's chosen third-party icon pack, by package name. Null = none.
     *
     * DELIBERATELY NOT A FIELD ON [IconStyle], and the reason is worth stating
     * because putting it there is the obvious move. IconStyle is THEME CONTENT:
     * it arrives from a theme.json over the CDN, and adding a field to it means
     * the eight-place ritual plus a Pigeon wire change. But a third-party pack
     * is not content a distro can author — it names an APK that happens to be
     * installed on ONE device. A theme could not fill it in even if it wanted
     * to, so it does not belong in the theme's payload.
     *
     * It is a device-level choice, so it lives beside the style rather than
     * inside it, and reaches the cache key on its own.
     */
    @Volatile
    private var systemIconPack: String? = null

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

    /**
     * Select a third-party icon pack, or null to stop using one.
     *
     * The same early return as [setTheme], for the same reason: this will be
     * called on every settings emit once it is wired to prefs, and dropping the
     * memory tier because the user moved the dock is exactly the bug the guard
     * above documents.
     *
     * DISK IS NOT SWEPT, and does not need to be. The pack name is part of
     * [cacheKey], so entries rendered under a different pack simply are not
     * looked up. Switching back to a pack you used before is then a disk read
     * rather than a re-render, which is the same property switching themes has.
     */
    fun setSystemIconPack(packageName: String?) {
        if (packageName == systemIconPack) return

        // LOAD BEFORE FLIPPING THE FIELD. The order is the whole correctness of
        // this method and it is not the order you write first.
        //
        // `systemIconPack` is part of [cacheKey], and `get` runs on a DIFFERENT
        // thread pool from this call. Flip the field first and there is a window
        // where a concurrent icon request computes the NEW cache key while
        // `iconPacks` still holds the OLD pack — it renders without the new
        // artwork and writes that bitmap to disk under the new key. The icon is
        // then permanently wrong for that app, and only for whichever apps
        // happened to be on screen at the moment of the switch, which is as
        // close to unreproducible as this codebase gets.
        //
        // Loading first closes it: `load` and `resolve` are both @Synchronized,
        // so a request arriving mid-load blocks until the pack is ready, and
        // until the field flips it is still keying against the old pack it is
        // correctly using.
        iconPacks.load(packageName)
        systemIconPack = packageName
        memory.evictAll()
    }

    /** Installed packs, for the picker. Queries the package manager; not hot. */
    fun installedIconPacks(): List<InstalledIconPack> = IconPackDiscovery.list(appContext)

    /**
     * A pack APK was installed, updated or removed. Re-read and drop derived
     * bitmaps.
     *
     * An UPDATE keeps the package name, so [IconPackResolver.load] would early-
     * return and keep serving drawables from a Resources handle opened against
     * the previous APK. Same trap as a CDN pack update, arriving through Play
     * instead. Wire this to a PACKAGE_REPLACED receiver when one exists.
     */
    fun onIconPackAppChanged() {
        // TWO EARLY RETURNS, both load-bearing, because the natural caller is
        // the launcher's app-change watcher and that fires for EVERY app on the
        // device. Play auto-updates a dozen at once; without these, an unrelated
        // overnight update would clear the icon disk cache a dozen times and
        // every icon on the phone would re-render in the morning.
        //
        //   1. nobody selected a pack, which is almost everyone: free.
        //   2. the selected pack's APK did not change: free, one binder call.
        //
        // Only a pack that genuinely changed reaches `clear()`.
        if (systemIconPack == null) return
        if (!iconPacks.reloadIfChanged()) return
        clear()
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

        // FOUR LAYERS, MOST SPECIFIC FIRST. Each miss is normal, not an error.
        //
        //   1. icon pack — a third-party pack the user installed and CHOSE.
        //   2. hero      — hand-drawn FOR this distro. "Yaru's Firefox."
        //   3. brand     — CC0 glyph, same under every theme. "Firefox."
        //   4. generator — re-masks the app's own icon. Always succeeds, so the
        //                  grid never has a hole in it.
        //
        // Hero above brand is the whole point of hero packs: when a distro has
        // bothered to draw an icon, that is the more specific answer than a
        // silhouette shared with every other theme.
        //
        // THE USER'S PACK SITS ABOVE ALL OF IT, because picking one is the most
        // explicit statement anyone makes about their icons. Everything below is
        // an inference — the distro's taste, a brand's identity, or a guess at
        // reshaping the app's own art. A person who went to Play, installed a
        // pack and selected it has said what they want.
        //
        // The layers below still fill the gaps, so a pack covering 300 apps does
        // not leave the other hundred bare. If that mixing ever reads as
        // incoherent, moving `renderIconPack` below `renderHero` is the one-line
        // change, and it is a taste call rather than a correctness one.
        val bitmap = renderIconPack(componentKey, sizePx)
            ?: renderHero(componentKey, sizePx)
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

    /**
     * A drawable straight out of the user's chosen pack.
     *
     * Rendered through [IconRenderer.renderHero] with `applyMask = false`,
     * because that is precisely what this art is: final, already-shaped
     * artwork with its own silhouette and transparency. Masking it would slice
     * the corners off a shape the pack's author chose. The two cases are the
     * same case, so they share the code rather than growing a near-duplicate.
     */
    private fun renderIconPack(componentKey: String, sizePx: Int): Bitmap? {
        val drawable = iconPacks.resolve(componentKey) ?: return null
        return renderer.renderHero(drawable, style, sizePx, false)
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
        // systemIconPack is in the key for the same reason themeId is: change it
        // and every bitmap derived from the old one must stop being found.
        // Leaving it out would be the classic version of this bug — the setting
        // appears to work for apps nobody has scrolled past yet, and every app
        // already in the cache keeps its old icon forever.
        val raw = "$componentKey|$token|$themeId|$sizePx|${style.fingerprint()}" +
            "|${systemIconPack ?: "-"}"
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
