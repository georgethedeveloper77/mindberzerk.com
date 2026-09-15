package com.mindhunter.g_launcher.apps

import android.content.Context
import android.content.pm.LauncherApps
import android.graphics.Rect
import android.os.Build
import android.os.UserManager
import android.util.Log

/**
 * PHASE L6a: an app's OWN shortcuts, for the expanding row.
 *
 * ─── WHY THIS IS NOT IN ShortcutRepository ──────────────────────────────────
 *
 * That class is named for shortcuts and is about something else: it is the
 * pinned WEB APP store, where the launcher accepts a `PinItemRequest` from a
 * browser, persists it, and serves it back as an `AppEntry` the drawer treats
 * like any other app. Its one `getShortcuts` call fetches the icon for a site
 * it already owns.
 *
 * This reads shortcuts the launcher does not own and never will: the publisher
 * declares them, the publisher changes them, and the launcher's whole
 * involvement is to list them and start one. Nothing is stored, nothing is
 * cached, and the answer is expected to differ between two calls a minute
 * apart.
 *
 * Two different lifetimes behind one name is how somebody later persists a
 * shortcut that was never ours to keep.
 *
 * ─── NOTHING IS CACHED, ON PURPOSE ──────────────────────────────────────────
 *
 * A dynamic shortcut is the app's live state: the last three conversations, the
 * current playlist, whichever document was open. Caching it would show a row
 * from an hour ago and the failure would be invisible, since a stale shortcut
 * looks exactly like a current one until it is tapped.
 *
 * The query costs one binder call against a warm system service, and it happens
 * once per row the user deliberately opened. That is the correct place to spend
 * it.
 */
class AppShortcutReader(context: Context) {

    private companion object {
        /** Same prefix as AppRepository's `GLauncherApps`, so one grep finds both. */
        const val TAG = "GLauncherApps"
    }

    private val appContext = context.applicationContext
    private val launcherApps =
        appContext.getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps
    private val userManager =
        appContext.getSystemService(Context.USER_SERVICE) as UserManager

    /**
     * Every shortcut this app publishes, in the order the platform returns.
     *
     * ─── ALL THREE FLAGS, AND THE THIRD IS THE ONE THAT MATTERS ─────────────
     *
     * MANIFEST shortcuts are declared statically and never change. DYNAMIC ones
     * are pushed at runtime and are most of what a user recognises: the recent
     * chats, the last route. PINNED are ones some launcher has kept alive past
     * the publisher removing them.
     *
     * Asking for only the first would list a fixed menu that no app bothers to
     * declare any more, and the row would look empty on exactly the apps people
     * open most.
     *
     * ─── AND RANK IS NOT SORTED ON ─────────────────────────────────────────
     *
     * `ShortcutInfo.rank` orders dynamic shortcuts, and it orders them WITHIN
     * that kind only, so sorting the mixed list by it would interleave a
     * manifest entry ranked zero ahead of the conversation the user was last
     * in. The platform's own order already puts manifest before dynamic, which
     * is the order every system launcher shows.
     *
     * Returns empty on every failure. There are several real ones: API below
     * 25, an app publishing none, or a `SecurityException` from having lost the
     * home role between the tap and the query. The caller cannot act
     * differently on any of them, and a null would make it decide which kind of
     * nothing it is holding.
     */
    fun shortcutsFor(componentKey: String): List<ShortcutRow> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return emptyList()

        val key = ComponentKey.parse(componentKey) ?: return emptyList()
        val user = userManager.getUserForSerialNumber(key.userSerial)
            ?: return emptyList()

        return try {
            val query = LauncherApps.ShortcutQuery()
                .setPackage(key.packageName)
                .setQueryFlags(
                    LauncherApps.ShortcutQuery.FLAG_MATCH_MANIFEST or
                        LauncherApps.ShortcutQuery.FLAG_MATCH_DYNAMIC or
                        LauncherApps.ShortcutQuery.FLAG_MATCH_PINNED
                )

            launcherApps.getShortcuts(query, user).orEmpty().mapNotNull { info ->
                // `shortLabel` is what a launcher is meant to show. Blank is a
                // real state on a badly built app, and a row with no text is
                // worse than no row: it cannot be read, and it cannot be
                // explained either.
                val label = info.shortLabel?.toString()?.trim().orEmpty()
                if (label.isEmpty()) return@mapNotNull null
                ShortcutRow(
                    id = info.id,
                    label = label,
                    disabled = !info.isEnabled,
                )
            }
        } catch (e: SecurityException) {
            // Expected, not exceptional: the launcher must hold the home role
            // to read these, and it can lose it while the drawer is open.
            Log.i(TAG, "shortcuts denied for ${key.packageName}: $e")
            emptyList()
        } catch (e: Exception) {
            Log.w(TAG, "shortcuts failed for ${key.packageName}: $e")
            emptyList()
        }
    }

    /**
     * Start one, animating out of [bounds].
     *
     * False when the shortcut has gone, the publisher has disabled it, or the
     * launcher no longer holds the right to start it. The caller reports that
     * rather than appearing to work: a tap that does nothing and says nothing
     * is the failure people describe as the launcher freezing.
     */
    fun launch(componentKey: String, shortcutId: String, bounds: Rect?): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return false

        val key = ComponentKey.parse(componentKey) ?: return false
        val user = userManager.getUserForSerialNumber(key.userSerial) ?: return false

        return try {
            launcherApps.startShortcut(key.packageName, shortcutId, bounds, null, user)
            true
        } catch (e: IllegalStateException) {
            // The documented throw for a disabled shortcut or a locked profile.
            Log.i(TAG, "shortcut $shortcutId not startable: $e")
            false
        } catch (e: Exception) {
            Log.w(TAG, "shortcut $shortcutId failed: $e")
            false
        }
    }
}

/**
 * One shortcut, in Kotlin's own terms.
 *
 * Deliberately NOT the generated `AppShortcut`. The Pigeon class is the wire
 * format and its shape is decided by what crosses a bridge; this is what the
 * reader produces. Keeping them separate means a field added for the UI does
 * not silently become a schema change, which is how a codec gets renumbered by
 * someone who thought they were editing a data class.
 */
data class ShortcutRow(
    val id: String,
    val label: String,
    val disabled: Boolean,
)
