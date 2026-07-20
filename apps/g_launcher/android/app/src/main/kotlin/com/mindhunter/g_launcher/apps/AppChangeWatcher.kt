package com.mindhunter.g_launcher.apps

import android.content.Context
import android.content.pm.LauncherApps
import android.os.Handler
import android.os.HandlerThread
import android.os.UserHandle
import com.mindhunter.g_launcher.AppChangeReason

/**
 * Replaces the PackageChangeReceiver from the plan doc.
 *
 * A BroadcastReceiver on ACTION_PACKAGE_ADDED/REMOVED misses two things a
 * launcher must not miss:
 *   - work-profile package events
 *   - suspension (Digital Wellbeing pausing an app). A paused app must grey
 *     out, not disappear and reappear.
 *
 * LauncherApps.Callback covers both and needs no extra permission.
 *
 * Every event collapses into "re-query and swap the whole list". At a few
 * hundred entries the query is cheap, and a full swap cannot desync the way a
 * hand-rolled delta can. Revisit only if profiling says so.
 */
class AppChangeWatcher(
    context: Context,
    private val repository: AppRepository,
    private val onChanged: (AppChangeReason, List<com.mindhunter.g_launcher.AppEntry>) -> Unit,
) {
    private companion object {
        /** Package updates arrive as a burst (removed → added → changed). */
        const val DEBOUNCE_MS = 250L
    }

    private val launcherApps =
        context.applicationContext.getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps

    private val thread = HandlerThread("g-launcher-apps").apply { start() }
    private val handler = Handler(thread.looper)

    private var pendingReason: AppChangeReason? = null

    private val refreshTask = Runnable {
        val reason = pendingReason ?: AppChangeReason.CHANGED
        pendingReason = null
        onChanged(reason, repository.refresh())
    }

    private val callback = object : LauncherApps.Callback() {
        override fun onPackageAdded(packageName: String?, user: UserHandle?) =
            schedule(AppChangeReason.ADDED)

        override fun onPackageRemoved(packageName: String?, user: UserHandle?) =
            schedule(AppChangeReason.REMOVED)

        override fun onPackageChanged(packageName: String?, user: UserHandle?) =
            schedule(AppChangeReason.CHANGED)

        override fun onPackagesAvailable(
            packageNames: Array<out String>?,
            user: UserHandle?,
            replacing: Boolean,
        ) = schedule(AppChangeReason.AVAILABILITY_CHANGED)

        override fun onPackagesUnavailable(
            packageNames: Array<out String>?,
            user: UserHandle?,
            replacing: Boolean,
        ) = schedule(AppChangeReason.AVAILABILITY_CHANGED)

        override fun onPackagesSuspended(packageNames: Array<out String>?, user: UserHandle?) =
            schedule(AppChangeReason.AVAILABILITY_CHANGED)

        override fun onPackagesUnsuspended(packageNames: Array<out String>?, user: UserHandle?) =
            schedule(AppChangeReason.AVAILABILITY_CHANGED)
    }

    /** Call from LauncherApplication.onCreate — not from the Activity. */
    fun start() {
        launcherApps.registerCallback(callback, handler)
        handler.post { onChanged(AppChangeReason.CHANGED, repository.refresh()) }
    }

    fun stop() {
        launcherApps.unregisterCallback(callback)
        handler.removeCallbacksAndMessages(null)
        thread.quitSafely()
    }

    private fun schedule(reason: AppChangeReason) {
        // Escalate: if anything in the burst was an add/remove, report that.
        if (pendingReason == null || reason != AppChangeReason.CHANGED) {
            pendingReason = reason
        }
        handler.removeCallbacks(refreshTask)
        handler.postDelayed(refreshTask, DEBOUNCE_MS)
    }
}
