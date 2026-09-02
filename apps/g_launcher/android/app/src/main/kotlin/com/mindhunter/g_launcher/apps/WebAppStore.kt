package com.mindhunter.g_launcher.apps

import android.content.Context
import android.util.Base64
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Every web app this launcher holds, as a flat list on disk.
 *
 * ─── WHY THIS IS NATIVE AND NOT A PREF ──────────────────────────────────────
 *
 * Two reasons, and the first one is the hard one. [AppRepository.refresh] runs
 * from `LauncherApplication.onCreate` through `hostApi.start()`, which is
 * BEFORE the Dart isolate has read a single pref. A web app kept in prefs would
 * be missing from the first enumeration every cold start, appear a moment
 * later, and reorder the drawer under the user's thumb.
 *
 * The second is scope. Everything in `flutter.prefs.v1.<themeId>` is per
 * distro: hidden apps, folders, the custom drawer arrangement. A web app is not
 * a layout, it is a thing you installed, and installing one on Ubuntu then
 * switching to Kali must not make it disappear. There is a global prefs bucket
 * it could have lived in, but the first reason rules that out too.
 *
 * ─── THE ID IS BASE64, AND THAT IS NOT DECORATION ───────────────────────────
 *
 * A pinned shortcut's id is chosen by the app that published it, and Chrome
 * uses the SITE URL. So a raw id contains `/` and can contain `#`, which are
 * the two characters [ComponentKey.parse] splits on. It happens to survive
 * today, because that parser takes the FIRST slash and the LAST hash, but that
 * is a coincidence of the current implementation rather than a guarantee, and
 * a component key that decodes wrongly launches the wrong thing or nothing.
 *
 * URL_SAFE + NO_PADDING + NO_WRAP, so the result is `[A-Za-z0-9_-]` and cannot
 * collide with any separator no matter what a browser puts in an id.
 */
class WebAppStore(context: Context) {

    companion object {
        private const val TAG = "GLauncherWebApps"
        private const val FILE = "web_apps.json"

        /**
         * The class-name marker. `@` cannot appear in a Java class name, so a
         * key carrying this can never be mistaken for a real component and a
         * real component can never be mistaken for one of these.
         */
        const val MARKER = "@web:"

        private const val B64 =
            Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP
    }

    private val file = File(context.applicationContext.filesDir, FILE)

    /** Guards [cache] and every read/write of [file]. */
    private val lock = Any()

    /** Null until the first read. Loaded once, kept, written through. */
    private var cache: MutableList<WebApp>? = null

    // ---- identity --------------------------------------------------------

    /** True for a component key this store owns. Cheap; no parse, no disk. */
    fun owns(componentKey: String): Boolean = componentKey.contains("/$MARKER")

    /** The key a [WebApp] appears under in the app list. */
    fun keyOf(app: WebApp): String =
        "${app.publisherPackage}/$MARKER${encode(app.shortcutId)}#${app.userSerial}"

    /**
     * The record a key names, or null.
     *
     * Matched on the ENCODED id rather than by decoding the key, so a
     * malformed key finds nothing instead of decoding to something plausible.
     */
    fun find(componentKey: String): WebApp? = synchronized(lock) {
        load().firstOrNull { keyOf(it) == componentKey }
    }

    // ---- contents --------------------------------------------------------

    fun all(): List<WebApp> = synchronized(lock) { load().toList() }

    /**
     * Add, or replace one already held under the same id.
     *
     * Replacing rather than refusing: a site re-added after its name changed
     * should show the new name, and a duplicate row for the same shortcut is
     * worse than either.
     */
    fun put(app: WebApp) {
        synchronized(lock) {
            val list = load()
            list.removeAll { it.shortcutId == app.shortcutId && it.publisherPackage == app.publisherPackage }
            list.add(app)
            persist(list)
        }
    }

    fun remove(componentKey: String): Boolean = synchronized(lock) {
        val list = load()
        val before = list.size
        list.removeAll { keyOf(it) == componentKey }
        if (list.size == before) return false
        persist(list)
        true
    }

    // ---- disk ------------------------------------------------------------

    private fun load(): MutableList<WebApp> {
        cache?.let { return it }
        val list = mutableListOf<WebApp>()
        if (file.exists()) {
            try {
                val arr = JSONArray(file.readText())
                for (i in 0 until arr.length()) {
                    val o = arr.optJSONObject(i) ?: continue
                    val id = o.optString("id")
                    val pkg = o.optString("pkg")
                    if (id.isEmpty() || pkg.isEmpty()) continue
                    list.add(
                        WebApp(
                            shortcutId = id,
                            publisherPackage = pkg,
                            label = o.optString("label").ifEmpty { id },
                            userSerial = o.optLong("serial", 0L),
                            addedAt = o.optLong("addedAt", 0L),
                        )
                    )
                }
            } catch (e: Exception) {
                // A corrupt file reads as EMPTY and is then overwritten by the
                // next write. Throwing here would take down enumeration, which
                // means no drawer at all, to protect a list of web shortcuts.
                Log.w(TAG, "could not read $FILE: $e")
            }
        }
        cache = list
        return list
    }

    private fun persist(list: List<WebApp>) {
        cache = list.toMutableList()
        try {
            val arr = JSONArray()
            for (a in list) {
                arr.put(
                    JSONObject()
                        .put("id", a.shortcutId)
                        .put("pkg", a.publisherPackage)
                        .put("label", a.label)
                        .put("serial", a.userSerial)
                        .put("addedAt", a.addedAt)
                )
            }
            file.writeText(arr.toString())
        } catch (e: Exception) {
            Log.w(TAG, "could not write $FILE: $e")
        }
    }

    private fun encode(raw: String): String =
        Base64.encodeToString(raw.toByteArray(Charsets.UTF_8), B64)
}

/**
 * One site added from a browser.
 *
 * [publisherPackage] is the BROWSER, not the site: it is what
 * `LauncherApps.startShortcut` is addressed to and what Android will hold the
 * shortcut against. It is also why a web app's key looks like a Chrome key at a
 * glance, which the [WebAppStore.MARKER] exists to prevent being one.
 */
data class WebApp(
    val shortcutId: String,
    val publisherPackage: String,
    val label: String,
    val userSerial: Long,
    val addedAt: Long,
)
