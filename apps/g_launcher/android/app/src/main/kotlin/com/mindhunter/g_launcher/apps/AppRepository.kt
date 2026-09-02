package com.mindhunter.g_launcher.apps

import android.content.ComponentName
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.LauncherActivityInfo
import android.content.pm.LauncherApps
import android.util.Log
import android.graphics.Rect
import android.os.Build
import android.os.Process
import android.os.UserHandle
import android.os.UserManager
import com.mindhunter.g_launcher.AppEntry

/**
 * The app list. Uses LauncherApps, which is the launcher-privileged API:
 *
 *  - It does NOT require QUERY_ALL_PACKAGES. (Play plan §7.6 — this is the
 *    empirical proof. If you ever find yourself adding that permission to make
 *    the drawer work, you have used the wrong API somewhere.)
 *  - It is profile-aware, so work-profile apps appear correctly.
 *
 * Icons are deliberately absent here. See IconEngine (slice 2).
 */
class AppRepository(context: Context) {

    private companion object {
        const val TAG = "GLauncherApps"
    }

    private val appContext = context.applicationContext
    private val launcherApps =
        appContext.getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps
    private val userManager =
        appContext.getSystemService(Context.USER_SERVICE) as UserManager

    /**
     * Web apps, which are pinned shortcuts this launcher holds rather than
     * packages the system enumerates. Constructed here rather than injected so
     * `LauncherApplication` needs no change: this class is the only thing that
     * assembles an app list, and a second list assembled somewhere else is how
     * the drawer and the dock start disagreeing.
     */
    /**
     * PUBLIC, because `IconCache` needs it too. Every icon layer keys on the
     * package name, and a web app's package is the browser, so the icon cache
     * has to be able to ask "is this one of ours" before it consults any of
     * them. Exposing the repository is cheaper than threading a second
     * constructor argument through `LauncherApplication`.
     */
    val shortcuts = ShortcutRepository(appContext)

    @Volatile
    private var cache: List<AppEntry> = emptyList()

    /** Last known list without touching the system. Empty until [refresh]. */
    fun cached(): List<AppEntry> = cache

    /**
     * Blocking. Call from a worker thread — on a Tecno with ~200 apps this is
     * tens of ms, but it is not zero and it must never touch the main looper on
     * a home press.
     */
    fun refresh(): List<AppEntry> {
        val me = Process.myUserHandle()

        val profiles = userManager.userProfiles
        Log.i(TAG, "profiles=${profiles.size} me=$me")

        val entries = profiles.flatMap { user ->
            val serial = userManager.getSerialNumberForUser(user)
            val isWork = user != me

            // Passing null as the package name asks for every launchable
            // activity for that profile.
            val list = launcherApps.getActivityList(null, user)
            Log.i(TAG, "user=$user serial=$serial work=$isWork activities=${list.size}")

            list.map { info ->
                info.toAppEntry(serial = serial, isWorkProfile = isWork)
            }
        }.plus(
            // ── WEB APPS JOIN THE LIST, THEY DO NOT FOLLOW IT ──────────────
            //
            // Added BEFORE the sort, so a site lands in alphabetical position
            // among real apps instead of in a block at the end. That is the
            // whole of the "treat them like apps" decision expressed in one
            // line: everything downstream — the dock, folders, search, usage
            // ranking, hidden apps — reads this sorted list and needs no idea
            // that two kinds went into it.
            shortcuts.entries()
        ).sortedWith(
            compareBy(
                { it.label.lowercase() },
                { it.componentKey }, // stable tiebreak: two apps can share a label
            )
        )

        Log.i(TAG, "TOTAL=${entries.size}")
        cache = entries
        return entries
    }

    // ---- launching -------------------------------------------------------

    fun launch(componentKey: String, bounds: Rect?) {
        // Web apps first: their keys parse cleanly as components but name no
        // activity, so falling through to startMainActivity would be a start
        // on something that is not there.
        if (shortcuts.launch(componentKey, bounds)) return

        val key = ComponentKey.parse(componentKey) ?: return
        val user = userManager.getUserForSerialNumber(key.userSerial) ?: return
        val component = ComponentName(key.packageName, key.className)

        // startMainActivity handles suspended apps by showing the system's
        // "app is paused" dialog for us. Don't pre-empt that with our own.
        launcherApps.startMainActivity(component, user, bounds, null)
    }

    fun openAppInfo(componentKey: String) {
        // There is no package to show a details screen for. Android's own page
        // for the browser is not what someone tapping App info on a site
        // wants, so this does nothing rather than something misleading; the
        // drawer menu drops the entry in a later pass.
        if (shortcuts.store.owns(componentKey)) return

        val key = ComponentKey.parse(componentKey) ?: return
        val user = userManager.getUserForSerialNumber(key.userSerial) ?: return
        launcherApps.startAppDetailsActivity(
            ComponentName(key.packageName, key.className),
            user,
            null,
            null,
        )
    }

    /**
     * Why an uninstall would or would not proceed, as a status string.
     *
     * ─── A BOOLEAN WAS NOT ENOUGH, AND THE OLD ONE WAS ALSO WRONG ───────────
     *
     * This replaces `isUninstallable`, which returned false for three unrelated
     * situations and gave the caller no way to tell them apart. The caller's
     * only option was `return` with no side effect, so every refusal rendered
     * as a tap that did nothing, which is exactly how a working guard and a
     * broken feature come to look identical.
     *
     * The second fault was the FLAG_SYSTEM test. On a Samsung device that flag
     * is set on essentially every app that shipped with the phone, INCLUDING
     * the ones the user has since updated through Play. Those are genuinely
     * uninstallable: the system offers to remove the update and revert to the
     * factory version, which is what the user means by "uninstall Samsung
     * Internet". Refusing them was refusing the most common case on the very
     * device this launcher is developed on.
     *
     * Strings rather than an enum, per the Pigeon rule in the schema: enums are
     * numbered ahead of classes in the codec, so adding a third one silently
     * renumbers every existing class.
     */
    fun uninstallStatus(componentKey: String): String {
        // ── A WEB APP IS REMOVED, NOT UNINSTALLED ─────────────────────────
        //
        // There is no package, so ACTION_DELETE has nothing to address and the
        // system has nothing to confirm. Reported as its own status rather
        // than as a failure: the caller is expected to remove it directly, and
        // saying `refused` here would read as a bug in a path that works.
        if (shortcuts.store.owns(componentKey)) return UninstallStatus.WEB_APP

        val entry = cache.firstOrNull { it.componentKey == componentKey }
            ?: return UninstallStatus.UNKNOWN_APP

        // A work-profile app is owned by the profile admin. The uninstall would
        // be refused by the system rather than by us, and saying so up front is
        // more useful than handing the user a dialog that closes itself.
        if (entry.isWorkProfile) return UninstallStatus.WORK_PROFILE

        if (!entry.isSystem) return UninstallStatus.OK
        return if (isUpdatedSystemApp(entry)) UninstallStatus.OK else UninstallStatus.SYSTEM_APP
    }

    /**
     * Has this preinstalled app been updated since the factory image?
     *
     * `LauncherApps.getApplicationInfo` is used rather than PackageManager for
     * the same reason `updateTokenOf` avoids it: on Android 11+ the
     * PackageManager call is package-visibility filtered and throws for most
     * apps unless we hold QUERY_ALL_PACKAGES, which §7.6 rules out. LauncherApps
     * is the launcher-privileged path and needs no permission.
     *
     * Any failure reads as "not updated", which is the conservative answer: the
     * worst case is refusing an uninstall that would have worked, and the user
     * still has App info as a route to the same screen.
     */
    private fun isUpdatedSystemApp(entry: AppEntry): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val user = userManager.getUserForSerialNumber(entry.userSerial) ?: return false
        return try {
            val info = launcherApps.getApplicationInfo(entry.packageName, 0, user)
            (info.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
        } catch (e: Exception) {
            Log.i(TAG, "getApplicationInfo failed for ${entry.packageName}: $e")
            false
        }
    }

    /** The profile a componentKey's serial belongs to, or null if it is gone. */
    fun userFor(serial: Long): UserHandle? =
        userManager.getUserForSerialNumber(serial)

    // ---- mapping ---------------------------------------------------------

    private fun LauncherActivityInfo.toAppEntry(
        serial: Long,
        isWorkProfile: Boolean,
    ): AppEntry {
        val appInfo: ApplicationInfo = applicationInfo
        val pkg = componentName.packageName
        val cls = componentName.className

        return AppEntry(
            componentKey = ComponentKey(pkg, cls, serial).encode(),
            packageName = pkg,
            className = cls,
            userSerial = serial,
            label = label?.toString().orEmpty().ifBlank { pkg },
            updateToken = updateTokenOf(appInfo),
            isWorkProfile = isWorkProfile,
            isSuspended = (appInfo.flags and ApplicationInfo.FLAG_SUSPENDED) != 0,
            isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0,
            category = categoryOf(appInfo),
            isGame = isGameOf(appInfo),
        )
    }

    /**
     * The app's declared category, or -1 when it declares none.
     *
     * Free: ApplicationInfo is already in hand from LauncherApps, so this needs
     * no extra permission and no second query — the same reason updateToken
     * reads sourceDir instead of asking PackageManager for a version code.
     *
     * API 26+. Below that the field does not exist and everything reads as
     * undefined, which the Dart suggester treats as "no opinion" rather than as
     * a category of its own.
     */
    private fun categoryOf(appInfo: ApplicationInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            appInfo.category.toLong()
        } else {
            -1L // ApplicationInfo.CATEGORY_UNDEFINED, which is itself API 26.
        }

    /**
     * Is this a game?
     *
     * Two signals, and both are needed. `category == CATEGORY_GAME` is the
     * modern answer, but it only exists from API 26 and only when the developer
     * actually set `android:appCategory` — plenty never did. FLAG_IS_GAME is the
     * deprecated predecessor, and it is still the only thing that identifies a
     * lot of the older games sitting on a budget phone. Checking both is the
     * difference between a Games suggestion that finds twelve and one that finds
     * three.
     */
    @Suppress("DEPRECATION")
    private fun isGameOf(appInfo: ApplicationInfo): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            appInfo.category == ApplicationInfo.CATEGORY_GAME
        ) {
            return true
        }
        return (appInfo.flags and ApplicationInfo.FLAG_IS_GAME) != 0
    }

    /**
     * An "has this app changed?" token for the icon cache. NOT a real version code.
     *
     * The honest way to get a versionCode is PackageManager.getPackageInfo(),
     * but on Android 11+ that call is package-visibility filtered and throws
     * NameNotFoundException for most apps unless you hold QUERY_ALL_PACKAGES.
     * We are not adding that permission to save a version number (build plan
     * §7.6).
     *
     * ApplicationInfo.sourceDir is already in hand — LauncherApps handed it to
     * us, no permission required — and its path contains a per-install
     * randomised directory, so it changes whenever the app is updated or
     * reinstalled. That is exactly, and only, what the icon cache needs.
     *
     * Worst case on a hash collision: one stale icon. Not a crash.
     */
    private fun updateTokenOf(appInfo: ApplicationInfo): Long {
        val dir = appInfo.sourceDir ?: return 0L
        return dir.hashCode().toLong() and 0xFFFFFFFFL
    }
}

/**
 * The vocabulary `requestUninstall` answers in.
 *
 * MIRRORED IN DART in `data/repositories/app_repository.dart`. Both sides are
 * listed in the Pigeon schema's doc comment for `requestUninstall`, which is the
 * one place a reader is guaranteed to look; if you add a status, add it in all
 * three or the Dart side falls through to its generic message and the specific
 * reason you just went to the trouble of computing is thrown away.
 *
 * Strings and not an enum, deliberately. The schema note spells out why: Pigeon
 * numbers enums ahead of classes in the codec, so introducing one here would
 * renumber every existing class and break any APK already in the field.
 */
object UninstallStatus {
    /** Cleared our own checks. Not yet a promise that the dialog appeared. */
    const val OK = "ok"

    /** The system's uninstall confirmation was started. */
    const val LAUNCHED = "launched"

    /**
     * Started, but from the application context because no Activity was
     * attached. Distinct from [LAUNCHED] on purpose: this is the path that was
     * failing before, and if it ever comes back it should be visible in
     * Crashlytics rather than blending into success.
     */
    const val LAUNCHED_DETACHED = "launched_detached"

    /** Not in the app list. Almost always a stale tile for a removed app. */
    const val UNKNOWN_APP = "unknown_app"

    /** Preinstalled and never updated, so there is nothing to remove. */
    const val SYSTEM_APP = "system_app"

    /** Owned by the work profile's admin. */
    const val WORK_PROFILE = "work_profile"

    /** No activity on the device answers ACTION_DELETE. Rare, but real on ROMs. */
    const val NO_INSTALLER = "no_installer"

    /** The system refused the start outright. */
    const val REFUSED = "refused"

    /**
     * A web app. No package, so nothing to uninstall; the launcher removes it.
     *
     * Handled by the caller rather than here, because removal is not a
     * confirmation the system owns and should not borrow the uninstall
     * dialog's wording.
     */
    const val WEB_APP = "web_app"
}
data class ComponentKey(
    val packageName: String,
    val className: String,
    val userSerial: Long,
) {
    fun encode(): String = "$packageName/$className#$userSerial"

    companion object {
        fun parse(key: String): ComponentKey? {
            val hash = key.lastIndexOf('#')
            val slash = key.indexOf('/')
            if (hash <= 0 || slash <= 0 || slash > hash) return null
            val serial = key.substring(hash + 1).toLongOrNull() ?: return null
            return ComponentKey(
                packageName = key.substring(0, slash),
                className = key.substring(slash + 1, hash),
                userSerial = serial,
            )
        }
    }
}
