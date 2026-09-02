package com.mindhunter.g_launcher.apps

import android.content.Context
import android.content.pm.LauncherApps
import android.content.pm.ShortcutInfo
import android.graphics.Rect
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Process
import android.os.UserManager
import android.util.Log
import com.mindhunter.g_launcher.AppEntry

/**
 * Pinned shortcuts: accepting them, launching them, listing them as apps.
 *
 * ─── WHAT THIS FIXES ────────────────────────────────────────────────────────
 *
 * `ShortcutManager.isRequestPinShortcutSupported()` returns FALSE unless the
 * default launcher declares an activity handling ACTION_CONFIRM_PIN_SHORTCUT.
 * This app declared none, so while G Launcher held HOME, Chrome asked the
 * system whether a shortcut could be pinned, was told no, and dropped the
 * install with no error anywhere the user could see it. That is the whole of
 * the "PWAs do not work" report: not a filter, not enumeration, an absent
 * manifest entry.
 *
 * ─── AND WHAT IT DOES NOT FIX ───────────────────────────────────────────────
 *
 * WebAPKs are real packages and were never affected. Chrome mints them through
 * Google's server whenever the site has a valid manifest and Play services are
 * present, they arrive with a real MAIN/LAUNCHER activity, and
 * `LauncherApps.getActivityList` has been returning them all along. Nothing
 * here touches them. This is only the fallback path, for sites Chrome cannot
 * mint and for browsers that do not.
 *
 * ─── A WEB APP IS AN AppEntry, DELIBERATELY ─────────────────────────────────
 *
 * `drawer_items.dart` argues at length that a synthetic entry must never
 * masquerade as an AppEntry, and names three ways it goes wrong: launch fires
 * on a component key that is not there, getIcon asks for an icon that is not
 * there, and pin-to-dock resolves to nothing. That argument was written about
 * launcher CHROME — Settings, the Terminal — which has no package, no icon and
 * no launch intent at any layer.
 *
 * A pinned web app is not that. It has a real publisher package, a real icon
 * held by the system, and a real launch path through `startShortcut`. All
 * three objections are answered by [WebAppStore.owns] plus a branch, and the
 * prize for answering them is large: the dock, the home grid, folders, search,
 * hidden apps, usage ranking and the Kickoff rail all work on these with ZERO
 * Dart changes, because they already work on AppEntry.
 *
 * If you are here to add a fourth thing that is not an app, re-read that
 * comment first. It is still right about launcher chrome.
 */
class ShortcutRepository(context: Context) {

    private companion object {
        const val TAG = "GLauncherWebApps"
    }

    private val appContext = context.applicationContext
    private val launcherApps =
        appContext.getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps
    private val userManager =
        appContext.getSystemService(Context.USER_SERVICE) as UserManager

    val store = WebAppStore(appContext)

    // ---- accepting -------------------------------------------------------

    /**
     * Take a pin request from a browser and keep it. True when something was
     * added.
     *
     * ─── NO CONFIRMATION SHEET, AND THAT IS THE DESIGN ──────────────────────
     *
     * Chrome has already shown its own "Install <site>?" dialog by the time it
     * calls `requestPinShortcut`. A second sheet here asks the same question
     * two taps later and the honest answer to "are you sure" is that they
     * already said so. The launcher accepts and says so afterwards.
     *
     * ─── ACCEPT BEFORE PERSISTING ───────────────────────────────────────────
     *
     * `accept()` is what makes the system consider the shortcut pinned by us,
     * and it is the call that can be refused. Persisting first would leave a
     * row in our store for a shortcut Android does not think we hold, which
     * renders as an app that cannot launch.
     */
    fun acceptPin(request: LauncherApps.PinItemRequest): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        if (request.requestType != LauncherApps.PinItemRequest.REQUEST_TYPE_SHORTCUT) {
            // Widgets come through the same API and are WidgetHost's business.
            return false
        }
        if (!request.isValid) return false

        val info: ShortcutInfo = request.shortcutInfo ?: return false

        val accepted = try {
            request.accept()
        } catch (e: Exception) {
            Log.w(TAG, "accept() refused: $e")
            false
        }
        if (!accepted) return false

        val label = (info.shortLabel ?: info.longLabel)?.toString().orEmpty()
        store.put(
            WebApp(
                shortcutId = info.id,
                publisherPackage = info.`package`,
                // Falls back to the package rather than to blank. A nameless
                // row sorts to the top of the drawer and looks like a bug.
                label = label.ifBlank { info.`package` },
                userSerial = userManager.getSerialNumberForUser(info.userHandle),
                addedAt = System.currentTimeMillis(),
            )
        )
        Log.i(TAG, "pinned ${info.id} from ${info.`package`}")
        return true
    }

    // ---- the app list ----------------------------------------------------

    /**
     * Every held web app, as app-list entries.
     *
     * The flag values are all deliberate and all honest:
     *
     *  - `isSystem` false: nothing preinstalled this.
     *  - `isWorkProfile` from the serial, so a shortcut pinned from a work
     *    profile browser still reports correctly.
     *  - `isSuspended` false: there is no ApplicationInfo to carry the flag,
     *    and a suspended browser is the browser's problem, not the site's.
     *  - `category` -1, CATEGORY_UNDEFINED. `builtInBucket` files these under
     *    Other in the library, which is exactly right: nothing declares a
     *    category for a web app and guessing one from a URL is the kind of
     *    invention that comment forbids.
     *  - `updateToken` from the label, so a renamed site re-renders its icon
     *    rather than serving the old bitmap forever.
     */
    fun entries(): List<AppEntry> {
        val me = Process.myUserHandle()
        val mySerial = userManager.getSerialNumberForUser(me)
        return store.all().map { app ->
            AppEntry(
                componentKey = store.keyOf(app),
                packageName = app.publisherPackage,
                // NOT a class, and it says so. Nothing reconstructs a key from
                // these two fields (the schema calls componentKey opaque), but
                // this lands in logs and in a prefs dump, and a raw shortcut id
                // sitting in a className slot reads like a real component.
                className = "${WebAppStore.MARKER}${app.shortcutId}",
                userSerial = app.userSerial,
                label = app.label,
                updateToken = app.label.hashCode().toLong() and 0xFFFFFFFFL,
                isWorkProfile = app.userSerial != mySerial,
                isSuspended = false,
                isSystem = false,
                category = -1L,
                isGame = false,
            )
        }
    }

    // ---- launching -------------------------------------------------------

    /** True when this key was ours and the start was attempted. */
    fun launch(componentKey: String, bounds: Rect?): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val app = store.find(componentKey) ?: return false
        val user = userManager.getUserForSerialNumber(app.userSerial) ?: return false
        return try {
            launcherApps.startShortcut(app.publisherPackage, app.shortcutId, bounds, null, user)
            true
        } catch (e: Exception) {
            // The publishing app was uninstalled, or the shortcut was revoked.
            // The row survives until the user removes it; a launch that throws
            // here would take the launcher down on a tap.
            Log.w(TAG, "startShortcut failed for ${app.shortcutId}: $e")
            true
        }
    }

    // ---- icons -----------------------------------------------------------

    /**
     * The site's own icon, as the system holds it.
     *
     * ─── WHY THIS EXISTS AT ALL ─────────────────────────────────────────────
     *
     * Every layer in `IconCache` keys on the PACKAGE NAME, and a web app's
     * package is the browser. So the icon pack, the hero pack and the brand
     * pack all answer for "com.chrome.beta" and hand back Chrome's icon for
     * four different sites, while the generator returns null because
     * `IconExtractor` looks for an activity whose class name is `@web:...` and
     * finds none. Blank on one distro, four identical Chrome tiles on another.
     *
     * ─── THE LIVE ShortcutInfo, NOT OUR STORED RECORD ───────────────────────
     *
     * The bitmap belongs to the system, not to us, so this is a query rather
     * than a field read. It needs FLAG_MATCH_PINNED and the HOME role. We hold
     * HOME whenever any of this is on screen, but an OEM build can guard it
     * harder than AOSP, so every failure returns null and the caller falls
     * back. An icon path must never throw.
     */
    fun iconDrawable(componentKey: String, densityDpi: Int): Drawable? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
        val app = store.find(componentKey) ?: return null
        val user = userManager.getUserForSerialNumber(app.userSerial) ?: return null

        return try {
            val query = LauncherApps.ShortcutQuery()
                .setPackage(app.publisherPackage)
                .setShortcutIds(listOf(app.shortcutId))
                .setQueryFlags(
                    LauncherApps.ShortcutQuery.FLAG_MATCH_PINNED or
                        LauncherApps.ShortcutQuery.FLAG_MATCH_DYNAMIC or
                        LauncherApps.ShortcutQuery.FLAG_MATCH_MANIFEST
                )
            val info = launcherApps.getShortcuts(query, user)?.firstOrNull()
                ?: return null
            launcherApps.getShortcutIconDrawable(info, densityDpi)
        } catch (e: SecurityException) {
            Log.w(TAG, "shortcut icon denied for ${app.shortcutId}: $e")
            null
        } catch (e: Exception) {
            Log.w(TAG, "shortcut icon failed for ${app.shortcutId}: $e")
            null
        }
    }

    /** Forget one. The system unpins it as soon as we stop claiming it. */
    fun remove(componentKey: String): Boolean = store.remove(componentKey)
}
