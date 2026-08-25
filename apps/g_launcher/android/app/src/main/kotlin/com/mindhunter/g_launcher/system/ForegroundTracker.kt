package com.mindhunter.g_launcher.system

import android.app.Activity
import android.app.Application
import android.os.Bundle

/**
 * Is any Activity of this process currently STARTED?
 *
 * ─── WHY A LAUNCHER NEEDS THIS AND ORDINARY APPS DO NOT ─────────────────────
 *
 * Most apps can equate "my process is alive" with "the user is looking at me",
 * because the process is created when the user opens the app and killed soon
 * after they leave. A launcher is the opposite: the process is created once and
 * then spends most of its life behind whatever the user actually opened, in
 * Android's terms an EMPTY process at importance 400.
 *
 * Everything registered from `Application.onCreate` keeps firing in that state.
 * `LauncherApps.Callback` in particular fires for every package event on the
 * device, and Play updates a dozen apps overnight, so a callback that does real
 * work runs a dozen times against a screen nobody is looking at. That showed up
 * on this device as an EXCESSIVE_CPU kill: 14050ms of CPU across a 300005ms
 * window with `state=empty`, against a limit of 2.
 *
 * ─── WHY STARTED AND NOT RESUMED ────────────────────────────────────────────
 *
 * onStop is the moment the window is no longer visible, which is the honest
 * boundary for "is any of this work worth doing". onPause fires for a dialog or
 * the system uninstall confirmation sitting on top of us, and those are moments
 * where the user is still very much in the launcher.
 *
 * ─── WHY NOT ProcessLifecycleOwner ──────────────────────────────────────────
 *
 * It would need `androidx.lifecycle:lifecycle-process` as a new dependency, and
 * it debounces transitions by 700ms so a configuration change does not read as
 * a background trip. This launcher only ever has one Activity and does not need
 * the debounce, so the dependency would buy nothing.
 */
class ForegroundTracker(
    /** Fires on the main thread when the count goes 0 to 1. */
    private val onEnterForeground: () -> Unit,
) : Application.ActivityLifecycleCallbacks {

    /**
     * Volatile because it is WRITTEN on the main thread and READ from the
     * watcher's HandlerThread. Without it the watcher could read a stale false
     * indefinitely and defer a refresh that should have run.
     */
    @Volatile
    var isForeground: Boolean = false
        private set

    /** Main thread only. Not volatile, and does not need to be. */
    private var started = 0

    fun install(app: Application) {
        app.registerActivityLifecycleCallbacks(this)
    }

    override fun onActivityStarted(activity: Activity) {
        started += 1
        if (started == 1) {
            isForeground = true
            onEnterForeground()
        }
    }

    override fun onActivityStopped(activity: Activity) {
        // Clamped rather than allowed to go negative. A stop without a matching
        // start should not happen, but if it ever does, a negative count would
        // wedge the launcher in the background state for the life of the
        // process and every package change would be deferred forever.
        started = (started - 1).coerceAtLeast(0)
        if (started == 0) isForeground = false
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
    override fun onActivityResumed(activity: Activity) = Unit
    override fun onActivityPaused(activity: Activity) = Unit
    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
    override fun onActivityDestroyed(activity: Activity) = Unit
}
