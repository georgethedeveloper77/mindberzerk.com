package com.mindhunter.g_launcher.widgets

import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Keeps another app's widget code from taking the launcher down with it.
 *
 * ─── WHY A HOSTED WIDGET CAN CRASH THIS PROCESS ─────────────────────────────
 *
 * RemoteViews normally inflate framework views only, but OEM system widgets
 * (Honor's calendar, some MIUI and One UI clocks) ship custom view classes
 * that the host loads from the provider's APK and runs on OUR main thread,
 * with OUR permissions. Honor's `CalendarSwitchView` queries the calendar
 * provider from a Handler; this launcher has no READ_CALENDAR, so it throws
 * SecurityException and the process dies: the
 * `CalendarSwitchView$c$b.handleMessage` crash. Nothing in this app is on
 * that stack, so no try/catch of ours can reach it.
 *
 * ─── WHAT THIS DOES ─────────────────────────────────────────────────────────
 *
 * Runs the main Looper inside a catch. A throwable is swallowed ONLY when the
 * first non-platform frame on its stack belongs to a class this app's
 * ClassLoader cannot load, which is the exact signature of code that came
 * from another APK. Anything thrown from our code, Flutter, or a bundled
 * library is rethrown untouched and crashes exactly as before.
 *
 * The widget is left to show whatever it last drew. That is the same outcome
 * the stock launcher gives on these devices, minus the restart.
 */
object ForeignWidgetGuard {

    private const val TAG = "ForeignWidgetGuard"

    /** Packages that are the platform, not this app and not a widget. */
    private val PLATFORM_PREFIXES = arrayOf(
        "android.", "androidx.", "com.android.", "java.", "javax.",
        "kotlin.", "kotlinx.", "dalvik.", "libcore.", "sun.", "jdk.",
    )

    @Volatile
    private var installed = false

    /** Call once, from Application.onCreate. Safe to call again. */
    fun install(appClassLoader: ClassLoader) {
        if (installed) return
        installed = true

        // Posted, so it starts as the first message of the real main loop and
        // every later message is dispatched by the guarded loop below.
        Handler(Looper.getMainLooper()).post {
            while (true) {
                try {
                    Looper.loop()
                    // loop() returns only when the main looper quits, which
                    // happens at process death. Nothing left to guard.
                    return@post
                } catch (t: Throwable) {
                    if (!isForeign(t, appClassLoader)) throw t
                    Log.w(TAG, "Swallowed a hosted widget fault", t)
                }
            }
        }
    }

    /**
     * True when the top of [t]'s stack, past platform frames, is code this
     * app cannot load. A frame we CAN load that is not platform code is ours
     * (or a library we bundle), and it decides the other way.
     */
    private fun isForeign(t: Throwable, loader: ClassLoader): Boolean {
        for (frame in t.stackTrace) {
            val name = frame.className
            if (!isLoadable(name, loader)) return true
            if (PLATFORM_PREFIXES.none { name.startsWith(it) }) return false
        }
        return false
    }

    private fun isLoadable(className: String, loader: ClassLoader): Boolean =
        try {
            Class.forName(className, false, loader)
            true
        } catch (_: ClassNotFoundException) {
            false
        } catch (_: LinkageError) {
            // Present but broken to link is still ours to answer for.
            true
        }
}
