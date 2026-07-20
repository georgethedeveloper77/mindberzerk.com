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
        }.sortedWith(
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
        val key = ComponentKey.parse(componentKey) ?: return
        val user = userManager.getUserForSerialNumber(key.userSerial) ?: return
        val component = ComponentName(key.packageName, key.className)

        // startMainActivity handles suspended apps by showing the system's
        // "app is paused" dialog for us. Don't pre-empt that with our own.
        launcherApps.startMainActivity(component, user, bounds, null)
    }

    fun openAppInfo(componentKey: String) {
        val key = ComponentKey.parse(componentKey) ?: return
        val user = userManager.getUserForSerialNumber(key.userSerial) ?: return
        launcherApps.startAppDetailsActivity(
            ComponentName(key.packageName, key.className),
            user,
            null,
            null,
        )
    }

    /** True if the caller should fire an ACTION_UNINSTALL_PACKAGE intent. */
    fun isUninstallable(componentKey: String): Boolean {
        val entry = cache.firstOrNull { it.componentKey == componentKey } ?: return false
        return !entry.isSystem && !entry.isWorkProfile
    }

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
 * The one place componentKey is constructed or parsed. Everything else treats
 * it as an opaque string.
 */
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
