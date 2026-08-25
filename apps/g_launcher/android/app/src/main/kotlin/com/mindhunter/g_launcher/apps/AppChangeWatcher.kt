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
    /**
     * Is any Activity of this process STARTED right now?
     *
     * ─── WHY THIS PARAMETER EXISTS ──────────────────────────────────────────
     *
     * The callback below is registered from `Application.onCreate`, so it fires
     * for the whole life of the process, and a launcher spends most of its life
     * as an EMPTY background process behind whatever the user actually opened.
     * `LauncherApps.Callback` fires for EVERY app on the device, and Play
     * updates a dozen apps overnight.
     *
     * Each of those events used to run `repository.refresh()`, which is
     * `getActivityList(null, user)` across every profile plus a label load per
     * entry, roughly 250 binder-and-resource loads, and then pushed the whole
     * list over the platform channel into a live Dart tree that rebuilt and
     * re-requested every icon it could see. On a screen nobody was looking at.
     *
     * That is an EXCESSIVE_CPU kill, and the device recorded one:
     * `excessive cpu 14050 during 300005` with `state=empty`, roughly 4.7% of a
     * core sustained over five minutes against a limit of 2.
     */
    private val isForeground: () -> Boolean,
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

    /**
     * A change that arrived while nobody was looking, held until they are.
     *
     * Separate from [pendingReason], which is the 250ms burst debounce. This is
     * the SECOND deferral and it has no timer at all: it is released by
     * [onForeground] and by nothing else, so a package change at 3am costs one
     * volatile write instead of a full enumeration.
     */
    private var deferredReason: AppChangeReason? = null

    private val refreshTask = Runnable {
        val reason = pendingReason ?: AppChangeReason.CHANGED
        pendingReason = null

        // THE REFRESH IS THE EXPENSIVE PART, so the gate goes here rather than
        // around `schedule`. The debounce still runs and still collapses a
        // burst; what is skipped is the enumeration and the channel push.
        if (!isForeground()) {
            deferredReason = escalate(deferredReason, reason)
            return@Runnable
        }

        onChanged(reason, repository.refresh())
    }

    /**
     * An Activity just started. Apply whatever was held.
     *
     * ─── WHY THE STALE LIST IN THE MEANTIME IS SAFE ─────────────────────────
     *
     * Between the deferral and this call, `repository.cached()` names an app
     * that may have been uninstalled, and `IconCache.get` reads that cache for
     * its `updateToken`. Both are only ever observed through something drawn on
     * screen, and nothing is on screen: that is the precondition for having
     * deferred at all. This runs on `onStart`, before the first frame after a
     * home press, so the list is correct by the time anyone can see it.
     *
     * The one visible consequence is deliberate. Uninstall from the launcher
     * puts the system confirmation on top of us, which stops the Activity, so
     * the removal now lands as the user returns rather than behind the dialog.
     * The row disappearing at the moment the desktop comes back is the better
     * of the two.
     *
     * Posted to the watcher's own HandlerThread, never run inline: this is
     * called from `onActivityStarted` on the MAIN thread, and `refresh()` is
     * the several-hundred-binder-call enumeration its own doc warns must never
     * touch the main looper on a home press.
     */
    fun onForeground() {
        val reason = deferredReason ?: return
        deferredReason = null
        handler.post { onChanged(reason, repository.refresh()) }
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
        deferredReason = null
        launcherApps.unregisterCallback(callback)
        handler.removeCallbacksAndMessages(null)
        thread.quitSafely()
    }

    private fun schedule(reason: AppChangeReason) {
        pendingReason = escalate(pendingReason, reason)
        handler.removeCallbacks(refreshTask)
        handler.postDelayed(refreshTask, DEBOUNCE_MS)
    }

    /**
     * Collapse two reasons into the one worth reporting.
     *
     * If anything in the run was an add or a remove, that is what happened; a
     * CHANGED alongside it is the same package update's second event. Extracted
     * because [schedule] and [refreshTask] now both need it and a second
     * hand-written copy of this rule is a copy that drifts.
     */
    private fun escalate(
        held: AppChangeReason?,
        incoming: AppChangeReason,
    ): AppChangeReason =
        if (held == null || incoming != AppChangeReason.CHANGED) incoming else held
}
