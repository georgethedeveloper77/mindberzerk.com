package com.mindhunter.g_launcher.system

import android.content.ComponentCallbacks2
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine

/**
 * Gives memory back when Android asks for it.
 *
 * ─── THE BUG THIS FIXES: SIX LOW_MEMORY KILLS IN FOURTEEN HOURS ─────────────
 *
 * Before this file, nothing in the app overrode `onTrimMemory` or
 * `onLowMemory`. Not the Application, not the Activity, and nothing on the Dart
 * side. Android asks a process to release memory repeatedly before it kills it,
 * and every one of those requests went into a method nobody had written.
 *
 * `dumpsys activity exit-info` on the test device showed the result: six
 * `reason=3 (LOW_MEMORY)` exits in one day, at RSS values of 778MB, 761MB,
 * 696MB, 442MB and down. A launcher idling near 800MB is not a launcher with a
 * leak so much as a launcher with no release valve.
 *
 * ─── WHY THE ENGINE MAKES THIS WORSE, NOT BETTER ────────────────────────────
 *
 * `LauncherApplication` warms the FlutterEngine at process start and
 * `LauncherActivity.shouldDestroyEngineWithHost()` returns false, which is the
 * right call for a home press and is not what this file changes. The
 * consequence is that the Dart isolate, the whole widget tree, Flutter's
 * `ImageCache` (100 MiB by default), the Skia resource cache and `IconCache`'s
 * LRU all stay resident when the process is EMPTY, and none of them shrink.
 *
 * Flutter has its own handling for this, in
 * `FlutterActivityAndFragmentDelegate.onTrimMemory`, and it is unreachable
 * here: it only runs while an Activity is attached to the engine, which is
 * exactly the state we are NOT in when it matters. So the signal has to be
 * forwarded from the Application, which is what [onTrim] does.
 *
 * ─── WHAT IS DROPPED AND WHAT IS KEPT ───────────────────────────────────────
 *
 * Memory tiers only. `IconCache`'s DISK tier survives every level, deliberately
 * and for the reason its own comments already argue: a launcher is killed
 * constantly, and re-rendering two hundred icons on the next cold start is a
 * visible stall. A disk read is about 1ms. A render is 2 to 5ms plus the
 * allocations that got us killed in the first place.
 */
class MemoryTrimmer(
    /** Null until the engine is built. Read lazily for exactly that reason. */
    private val engine: () -> FlutterEngine?,
    /** True drops the whole icon memory tier, false halves it. */
    private val trimIcons: (full: Boolean) -> Unit,
) {

    private companion object {
        const val TAG = "GLauncherMemory"
    }

    /**
     * `level` is NOT ordered by severity, which is the trap in this API and the
     * reason this is a `when` on exact values rather than a chain of `>=`.
     * The running levels are 5, 10 and 15; the backgrounded levels are 20, 40,
     * 60 and 80. So `RUNNING_CRITICAL` (15) is more urgent than `UI_HIDDEN`
     * (20) and compares as smaller. A `level >= TRIM_MEMORY_BACKGROUND` test,
     * which is what Flutter's own delegate uses, silently ignores every
     * running-low signal on a visible launcher.
     */
    fun onTrim(level: Int) {
        when (level) {
            // Not visible. Nobody is looking at a single one of these bitmaps,
            // so there is no cost to dropping all of them beyond a re-decode
            // whenever the user comes back, which is a home press they are
            // already waiting on.
            ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN,
            ComponentCallbacks2.TRIM_MEMORY_BACKGROUND,
            ComponentCallbacks2.TRIM_MEMORY_MODERATE,
            ComponentCallbacks2.TRIM_MEMORY_COMPLETE,
            -> hard(level)

            // Visible, and the device is about to start killing. A re-decode
            // stutter on the drawer is strictly better than being the process
            // that gets picked, because being picked costs the user a full cold
            // start of their home screen.
            ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL -> hard(level)

            // Visible and under pressure, but not yet at the point where
            // blanking what is on screen is worth it. Halve the icon tier and
            // leave Flutter's decoded images alone: clearing those while the
            // drawer is open is a visible flash of empty tiles, and the whole
            // point of the drawer is that it does not do that.
            ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW -> soft(level)

            // TRIM_MEMORY_RUNNING_MODERATE and anything unrecognised: no-op.
            // Moderate fires often enough that reacting to it would mean a
            // launcher that permanently re-renders its own icons.
            else -> Unit
        }
    }

    /** The last warning before the kill. Treated as the hardest level there is. */
    fun onLow() = hard(ComponentCallbacks2.TRIM_MEMORY_COMPLETE)

    // ---- levels ------------------------------------------------------------

    private fun soft(level: Int) {
        Log.i(TAG, "trim level=$level: halving icon memory tier")
        runCatching { trimIcons(false) }
    }

    private fun hard(level: Int) {
        Log.i(TAG, "trim level=$level: dropping icon memory tier and Dart image cache")
        runCatching { trimIcons(true) }
        runCatching { notifyDart() }
    }

    /**
     * Reaches Dart's `ImageCache` without a single line of Dart.
     *
     * `ServicesBinding` already listens on the `flutter/system` channel and
     * handles a `memoryPressure` message by calling
     * `PaintingBinding.handleMemoryPressure`, which clears both the pending and
     * the live image caches. `SystemChannel.sendMemoryPressureWarning` is the
     * supported way to post that message, and it is the same call Flutter's own
     * Activity delegate makes.
     *
     * That matters more here than the icon tier does. `app_icon.dart` renders
     * through `Image.memory`, and `MemoryImage` compares by `Uint8List`
     * INSTANCE rather than by content, so every re-resolve of `iconProvider`
     * mints a fresh cache entry for a bitmap that is byte-identical to one
     * already decoded. Theme switches, pack generation bumps, `updateToken`
     * changes and the different `sizePx` each surface asks for all churn it.
     * The cache self-caps at 100 MiB and, until this call existed, never went
     * back down.
     *
     * If this does not compile against the pinned Flutter version, the
     * equivalent one-liner is `flutterEngine.notifyLowMemory()`, which wraps
     * this plus a JNI-side notification.
     */
    private fun notifyDart() {
        val flutterEngine = engine() ?: return
        flutterEngine.systemChannel.sendMemoryPressureWarning()
    }
}
