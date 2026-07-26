package com.mindhunter.g_launcher.icons

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.content.res.Resources
import android.content.res.XmlResourceParser
import android.graphics.drawable.Drawable
import android.os.Build
import com.mindhunter.g_launcher.apps.ComponentKey
import org.xmlpull.v1.XmlPullParser
import org.xmlpull.v1.XmlPullParserFactory

/**
 * ICON PACKS THAT ARE NOT OURS.
 *
 * Icon Pack Studio, Delta, Whicons, Papirus ports, the thousands of packs on
 * Play: every one of them is an installed APK that follows a convention ADW
 * invented and Nova made universal. A launcher that cannot read them is a
 * launcher people bounce off in the first five minutes, because "can I use my
 * icon pack" is the second question anyone asks after "can I change the grid".
 *
 * It also costs almost nothing. The pack is already on the device, already
 * drawn, already licensed to the user. We read its resources and hand a Drawable
 * to the same renderer that draws hero art.
 *
 * ─── THE CONVENTION, SUCH AS IT IS ──────────────────────────────────────────
 *
 * A pack declares one of a handful of intent actions on any activity, and ships
 * `appfilter.xml` either as a raw XML resource or as an asset. That file maps a
 * component to a drawable name:
 *
 *   <item component="ComponentInfo{com.whatsapp/com.whatsapp.Main}" drawable="whatsapp"/>
 *   <iconback img1="iconback1" img2="iconback2"/>
 *   <iconmask img1="iconmask"/>
 *   <iconupon img1="iconupon"/>
 *   <scale factor="0.9"/>
 *
 * There is no spec, no version, and no validation. Packs in the wild ship
 * duplicate entries, relative class names, entries for components that do not
 * exist, and occasionally malformed XML. So EVERY step here degrades to null
 * rather than throwing: a bad pack must cost the user their icons, not their
 * home screen.
 *
 * ─── THE PART THAT MAKES THIS INVISIBLE IF YOU MISS IT ──────────────────────
 *
 * Android 11+ package visibility. This launcher deliberately uses a scoped
 * `<queries>` block rather than QUERY_ALL_PACKAGES, and the block only declared
 * the LAUNCHER intent. `queryIntentActivities` for a theme action against that
 * manifest returns an EMPTY LIST on every modern device, with no error and no
 * log line. It looks exactly like "the user has no icon packs installed", and it
 * would look that way on a phone with forty of them.
 *
 * The manifest now declares [THEME_ACTIONS] in `<queries>`. If icon packs ever
 * stop appearing, that block is the first thing to check, not this file.
 *
 * ─── WHAT IS NOT HERE ───────────────────────────────────────────────────────
 *
 * `iconback` / `iconmask` / `iconupon` are PARSED and exposed, but nothing
 * composites them yet. They are how a pack dresses the apps it has no drawing
 * for, and doing it properly means compositing against the app's own icon in
 * IconRenderer. Until then an unthemed app falls through to the launcher's own
 * generator, which masks it into the current theme's shape — coherent with the
 * distro rather than with the pack, which is the better of the two wrong
 * answers.
 */

/** One installed icon pack, as the picker needs to draw it. */
data class InstalledIconPack(
    val packageName: String,
    val label: String,
)

/** The unthemed-app dressing a pack ships. Parsed, not yet composited. */
data class IconPackFallback(
    /** Background plates, chosen per-app so a grid is not uniform. */
    val back: List<String>,
    val mask: String?,
    val upon: String?,
    /** How far the app's own icon is inset before dressing. Usually ~0.9. */
    val scale: Float,
)

object IconPackDiscovery {

    /**
     * Every action a pack might declare.
     *
     * More than one because there is no standard, only a lineage. ADW came
     * first, Nova's became the de facto one, and the rest are launchers that
     * wanted their own name in the list. Packs commonly declare several, hence
     * the de-duplication by package below.
     *
     * MUST BE MIRRORED IN AndroidManifest.xml `<queries>`. An action here and
     * not there is worse than not supporting it at all: the pack is supported
     * in code and invisible at runtime.
     */
    val THEME_ACTIONS: List<String> = listOf(
        "org.adw.launcher.THEMES",
        "com.novalauncher.THEME",
        "com.anddoes.launcher.THEME",
        "com.teslacoilsw.launcher.THEME",
        "ch.deletescape.lawnchair.ICONPACK",
        "com.gau.go.launcherex.theme",
        "org.adw.launcher.icons.ACTION_PICK_ICON",
    )

    /**
     * Installed icon packs, de-duplicated and sorted by label.
     *
     * Ordered by label rather than by discovery order: discovery order is the
     * order of [THEME_ACTIONS], which is an implementation detail the user
     * would experience as a list that reshuffles itself for no reason.
     */
    fun list(context: Context): List<InstalledIconPack> {
        val pm = context.packageManager
        val found = LinkedHashMap<String, InstalledIconPack>()

        for (action in THEME_ACTIONS) {
            val infos = runCatching { query(pm, Intent(action)) }.getOrDefault(emptyList())
            for (info in infos) {
                val pkg = info.activityInfo?.packageName ?: continue
                if (found.containsKey(pkg)) continue
                // A pack whose label cannot be loaded is still a usable pack.
                val label = runCatching { info.loadLabel(pm)?.toString() }.getOrNull()
                found[pkg] = InstalledIconPack(pkg, label?.takeIf { it.isNotBlank() } ?: pkg)
            }
        }

        return found.values.sortedBy { it.label.lowercase() }
    }

    @Suppress("DEPRECATION")
    private fun query(pm: PackageManager, intent: Intent): List<ResolveInfo> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0L))
        } else {
            pm.queryIntentActivities(intent, 0)
        }
}

/**
 * The currently selected third-party pack.
 *
 * Shaped like [HeroIconResolver] on purpose: `load` is idempotent, `resolve`
 * returns null to fall through, and a miss is the normal case rather than an
 * error. Same contract, so IconCache treats it as one more layer rather than a
 * special case.
 */
class IconPackResolver(context: Context) {

    private val appContext = context.applicationContext

    private data class Pack(
        val packageName: String,
        /** The pack APK's resources. Held open; it is just a handle. */
        val res: Resources,
        /**
         * Keyed BOTH ways: "pkg/class" for the exact entry, and "pkg" for a
         * package-level fallback. Apps with several launchable activities are
         * why the first exists; packs that only ever list one activity per app
         * are why the second does.
         */
        val icons: Map<String, String>,
        val fallback: IconPackFallback,
    )

    private var loadedId: String? = null
    private var pack: Pack? = null

    /**
     * `lastUpdateTime` of the pack APK at the moment it was parsed.
     *
     * The cheap way to answer "did the thing I parsed actually change". Without
     * it the only honest answer to an app-change broadcast is "re-parse and
     * assume the worst", and the worst means clearing the icon disk cache. See
     * [reloadIfChanged].
     */
    private var loadedUpdateTime: Long = 0L

    /** Cheap and idempotent. Safe to call whenever the selection is re-read. */
    @Synchronized
    fun load(packageName: String?) {
        if (packageName == loadedId) return
        loadedId = packageName
        pack = packageName?.let { runCatching { readPack(it) }.getOrNull() }
        loadedUpdateTime = packageName?.let(::packageUpdateTime) ?: 0L
    }

    /**
     * Re-read even when the id is unchanged.
     *
     * The same trap the CDN resolvers have, arriving by a different route: a
     * pack updated through Play keeps its package name, so [load] would take its
     * early return and keep serving drawables from the Resources object opened
     * against the OLD APK. Call this from a package-changed broadcast.
     */
    @Synchronized
    fun reload() {
        val id = loadedId ?: return
        pack = runCatching { readPack(id) }.getOrNull()
        loadedUpdateTime = packageUpdateTime(id)
    }

    /**
     * Re-read ONLY if the pack's APK actually changed. Returns true when it did.
     *
     * ─── WHY THIS EXISTS RATHER THAN JUST CALLING [reload] ──────────────────
     *
     * The natural place to hook this is the launcher's existing app-change
     * watcher, because an icon pack IS an installed app and its install, update
     * and removal already arrive there. But that watcher fires for EVERY app on
     * the device, and Play routinely auto-updates a dozen at once. Reloading
     * unconditionally would mean clearing the icon disk cache a dozen times in a
     * morning, so every icon on the phone re-renders because an unrelated app
     * updated overnight. That is not a subtle regression; it is the disk tier
     * deleted.
     *
     * `lastUpdateTime` answers the question precisely for one binder call. No
     * pack selected costs nothing at all, since the caller checks that first.
     *
     * A pack that has been UNINSTALLED throws inside [packageUpdateTime] and
     * reads as 0, which differs from whatever was stored, so this reloads,
     * [readPack] returns null, and every app falls through to the layers below.
     * That is the correct outcome and it arrives without a special case.
     */
    @Synchronized
    fun reloadIfChanged(): Boolean {
        val id = loadedId ?: return false
        val now = packageUpdateTime(id)
        if (now == loadedUpdateTime) return false
        pack = runCatching { readPack(id) }.getOrNull()
        loadedUpdateTime = now
        return true
    }

    /** 0 when the package is gone or unreadable. */
    private fun packageUpdateTime(packageName: String): Long = runCatching {
        val pm = appContext.packageManager
        @Suppress("DEPRECATION")
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0L))
        } else {
            pm.getPackageInfo(packageName, 0)
        }
        info.lastUpdateTime
    }.getOrDefault(0L)

    /** True when a pack is selected AND parsed. */
    @Synchronized
    fun isActive(): Boolean = pack != null

    /** The pack's unthemed-app dressing, or null. Not composited yet. */
    @Synchronized
    fun fallback(): IconPackFallback? = pack?.fallback

    /**
     * The pack's drawable for this component, or null to fall through.
     *
     * Exact component first, then the package. A pack that themed Chrome's main
     * activity should still answer for Chrome when the drawer happens to hold a
     * different launchable activity of it.
     */
    @Synchronized
    fun resolve(componentKey: String): Drawable? {
        val p = pack ?: return null
        val key = ComponentKey.parse(componentKey) ?: return null

        val name = p.icons["${key.packageName}/${key.className}"]
            ?: p.icons[key.packageName]
            ?: return null

        return drawable(p, name)
    }

    // ---- pack loading ----------------------------------------------------

    private fun drawable(p: Pack, name: String): Drawable? {
        val id = runCatching { p.res.getIdentifier(name, "drawable", p.packageName) }
            .getOrDefault(0)
        if (id == 0) return null
        // An appfilter entry naming a drawable the APK does not contain is
        // common in packs assembled from a template. Null, not an exception.
        @Suppress("DEPRECATION")
        return runCatching { p.res.getDrawable(id, null) }.getOrNull()
    }

    private fun readPack(packageName: String): Pack? {
        val pm = appContext.packageManager
        val res = runCatching { pm.getResourcesForApplication(packageName) }.getOrNull()
            ?: return null

        val parser = openAppFilter(packageName, res) ?: return null

        val icons = HashMap<String, String>()
        val back = ArrayList<String>()
        var mask: String? = null
        var upon: String? = null
        var scale = 1.0f

        try {
            var event = parser.eventType
            while (event != XmlPullParser.END_DOCUMENT) {
                if (event == XmlPullParser.START_TAG) {
                    when (parser.name) {
                        "item" -> {
                            val component = parser.getAttributeValue(null, "component")
                            val drawable = parser.getAttributeValue(null, "drawable")
                            if (!component.isNullOrEmpty() && !drawable.isNullOrEmpty()) {
                                putEntry(icons, component, drawable)
                            }
                        }
                        // img1, img2, img3… A pack ships several plates and
                        // picks one per app so a grid does not look stamped.
                        "iconback" -> for (i in 0 until parser.attributeCount) {
                            parser.getAttributeValue(i)?.takeIf { it.isNotEmpty() }?.let(back::add)
                        }
                        "iconmask" -> mask = parser.getAttributeValue(null, "img1")
                        "iconupon" -> upon = parser.getAttributeValue(null, "img1")
                        "scale" -> scale = parser.getAttributeValue(null, "factor")
                            ?.toFloatOrNull()
                            // A pack asking for 0 or 12 is a typo, not an
                            // intention. Clamped rather than trusted, the same
                            // rule downloaded content follows everywhere else.
                            ?.coerceIn(0.3f, 1.0f)
                            ?: 1.0f
                    }
                }
                event = parser.next()
            }
        } catch (_: Throwable) {
            // Malformed XML partway through. Keep what parsed: a pack that
            // themes 300 apps and then trips over one bad tag is far more useful
            // than no pack at all, and the alternative is the user seeing their
            // selection silently do nothing.
        } finally {
            (parser as? XmlResourceParser)?.close()
        }

        if (icons.isEmpty()) return null

        return Pack(
            packageName = packageName,
            res = res,
            icons = icons,
            fallback = IconPackFallback(back = back, mask = mask, upon = upon, scale = scale),
        )
    }

    /**
     * `appfilter.xml` from wherever this pack happens to keep it.
     *
     * BOTH LOCATIONS ARE COMMON, which is the whole reason for the fallback.
     * Packs built from the CandyBar template compile it as an XML RESOURCE;
     * packs exported by Icon Pack Studio and most hand-rolled ones ship it as an
     * ASSET. Supporting only the first silently excludes a large share of what
     * people actually have installed, and the symptom is "some of my packs work".
     */
    private fun openAppFilter(packageName: String, res: Resources): XmlPullParser? {
        val id = runCatching { res.getIdentifier("appfilter", "xml", packageName) }
            .getOrDefault(0)
        if (id != 0) {
            runCatching { res.getXml(id) }.getOrNull()?.let { return it }
        }

        return runCatching {
            val assets = appContext.createPackageContext(packageName, 0).assets
            val parser = XmlPullParserFactory.newInstance().newPullParser()
            parser.setInput(assets.open("appfilter.xml"), null)
            parser
        }.getOrNull()
    }

    /**
     * `ComponentInfo{pkg/class}` into the two keys we look up by.
     *
     * FIRST ENTRY WINS. Duplicate components are routine in packs assembled by
     * merging several sources, and taking the last would mean the icon you see
     * depends on file order inside someone else's APK.
     *
     * A leading dot on the class name is expanded against the package, the same
     * shorthand a manifest uses. Rare in appfilter files, free to support, and
     * the failure without it is one app silently unthemed.
     */
    private fun putEntry(into: HashMap<String, String>, component: String, drawable: String) {
        val inner = component
            .substringAfter("ComponentInfo{", "")
            .substringBefore('}')
        if (inner.isEmpty()) return

        val pkg = inner.substringBefore('/', "")
        var cls = inner.substringAfter('/', "")
        if (pkg.isEmpty() || cls.isEmpty()) return
        if (cls.startsWith(".")) cls = pkg + cls

        // containsKey rather than putIfAbsent: the latter is a Java 8 default
        // method and needs desugaring below API 24, which is a build-config
        // dependency this file has no business having.
        val exact = "$pkg/$cls"
        if (!into.containsKey(exact)) into[exact] = drawable
        if (!into.containsKey(pkg)) into[pkg] = drawable
    }
}
