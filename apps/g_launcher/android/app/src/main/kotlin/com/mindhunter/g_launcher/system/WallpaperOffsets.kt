package com.mindhunter.g_launcher.system

import android.app.WallpaperManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * PHASE 5 PROBE - can this device pan its wallpaper at all.
 *
 * ─── WHY THIS IS NOT ON THE PIGEON BRIDGE ───────────────────────────────────
 *
 * `WallpaperManager.setWallpaperOffsets` takes a WINDOW TOKEN, and
 * `LauncherHostApiImpl` holds an application Context and nothing else. A
 * window token comes from a View that is attached to a window, which means the
 * Activity. That is the same reason `StageBridge` is set up in
 * `LauncherActivity.configureFlutterEngine` rather than in the Application, and
 * the comment there says so.
 *
 * A plain MethodChannel rather than a Pigeon addition, deliberately: this is a
 * probe. It answers one question, it is meant to be deleted or promoted
 * depending on the answer, and putting it in the schema would mean regenerating
 * two files and widening a contract for something that may turn out not to
 * work on this hardware at all.
 *
 * ─── THE QUESTION ───────────────────────────────────────────────────────────
 *
 * Parallax on a launcher is not the launcher drawing a wallpaper and moving it.
 * The window is transparent and `windowShowWallpaper` is set, so the wallpaper
 * is drawn by WindowManager UNDERNEATH Flutter, and Dart never holds it. The
 * only way to pan it is to ask the wallpaper service to, which is what this
 * does.
 *
 * Whether the service listens is another matter, and there is no API that
 * answers it:
 *
 *   * a LIVE wallpaper receives the offset and does whatever it likes with it,
 *     which is usually the right thing;
 *   * a STATIC wallpaper is panned by the system only if the stored bitmap is
 *     WIDER than the screen. One UI, recent Pixel builds and most Transsion
 *     ROMs crop to screen when a wallpaper is set, so there is nothing to pan
 *     and the call is silently a no-op.
 *
 * [diagnose] reads what can be read: whether a live wallpaper is running, and
 * how wide the system believes the wallpaper is against the display. A desired
 * width no greater than the display is a definitive "this will do nothing".
 * Everything else needs eyes on the screen, which is what [sweep] is for.
 */
object WallpaperOffsets {

    private const val TAG = "GLauncherOffsets"
    private const val CHANNEL = "g_launcher/wallpaper_offsets"

    private var view: View? = null
    private val main = Handler(Looper.getMainLooper())

    /** Cancels an in-flight [sweep] so two cannot fight over the offset. */
    private var sweeping: Runnable? = null

    /**
     * Called from `LauncherActivity.configureFlutterEngine`.
     *
     * [decorView] is passed as a lambda rather than a View because
     * `configureFlutterEngine` runs before the window is necessarily laid out,
     * and a token read too early is null. Resolved at call time instead, when
     * there is certainly a window because the user is looking at it.
     *
     * `setMethodCallHandler` REPLACES rather than stacks, so re-registering on
     * an Activity recreate is harmless. Same property `StageBridge` relies on.
     */
    fun setUp(messenger: BinaryMessenger, decorView: () -> View?) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            view = decorView()
            when (call.method) {
                "diagnose" -> result.success(diagnose())
                "setOffset" -> {
                    val x = (call.argument<Double>("x") ?: 0.5).toFloat()
                    result.success(setOffset(x))
                }
                "sweep" -> {
                    sweep()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * What can be known without looking at the screen.
     *
     * Returns a map rather than a formatted string, so Dart can decide what to
     * do with it. Also logged, because the fastest way to read this is a
     * logcat line while the device is in your hand.
     */
    fun diagnose(): Map<String, Any?> {
        val v = view
        val context = v?.context ?: return mapOf("error" to "no window yet")
        val wm = WallpaperManager.getInstance(context)

        val displayWidth = context.resources.displayMetrics.widthPixels
        val desired = wm.desiredMinimumWidth

        // A live wallpaper gets the offset delivered to its engine and decides
        // for itself. Null means a static bitmap, where the system does the
        // panning and only if it has something to pan with.
        val live = wm.wallpaperInfo?.packageName

        // THE DEFINITIVE NEGATIVE. If the system does not believe the wallpaper
        // is wider than the screen, there is nothing to slide and the offset
        // call is a no-op however correctly it is made. `desiredMinimumWidth`
        // returns 0 on some ROMs, which means "no opinion" rather than zero
        // width, so it is reported rather than judged.
        val pannable = live != null || (desired > displayWidth)

        val out = mapOf(
            "hasToken" to (v.windowToken != null),
            "liveWallpaper" to live,
            "displayWidth" to displayWidth,
            "desiredMinimumWidth" to desired,
            "likelyPannable" to pannable,
        )
        Log.i(TAG, "diagnose: $out")
        return out
    }

    /**
     * Push one offset. [x] is 0 for the far left, 1 for the far right.
     *
     * ─── THE STEP HAS TO BE SET, AND IT IS THE PART EVERYONE FORGETS ────────
     *
     * `setWallpaperOffsetSteps` tells the service how far apart the stops are.
     * The default assumes a two-page launcher, so a smooth 0-to-1 drag against
     * the default step lands on two positions and reads as a jump rather than a
     * pan. Setting it to a small value makes the offset continuous, which is
     * what a parallax needs.
     *
     * Returns false rather than throwing on a missing token: the window can be
     * gone between a scroll frame and this call, and a launcher that crashes
     * mid-swipe because the wallpaper could not be nudged is a worse outcome
     * than a wallpaper that did not move.
     */
    fun setOffset(x: Float): Boolean {
        val v = view ?: return false
        val token = v.windowToken ?: return false
        return try {
            val wm = WallpaperManager.getInstance(v.context)
            // Continuous rather than per page. See above.
            wm.setWallpaperOffsetSteps(0.0001f, 1f)
            wm.setWallpaperOffsets(token, x.coerceIn(0f, 1f), 0.5f)
            true
        } catch (e: Exception) {
            // An IllegalArgumentException here means the token is not one the
            // window manager recognises, which happens on a detached view.
            Log.w(TAG, "setWallpaperOffsets failed: ${e.javaClass.simpleName} ${e.message}")
            false
        }
    }

    /**
     * Drive the offset from 0 to 1 and back, over about four seconds.
     *
     * ─── THE ONLY WAY TO ANSWER THE QUESTION IS TO WATCH ────────────────────
     *
     * [diagnose] can prove a negative and cannot prove a positive: a wallpaper
     * wide enough to pan still might not, depending on what the ROM did to it
     * when it was set. So this exists to be looked at. Run it, watch the
     * wallpaper, and the answer takes four seconds.
     *
     * Slow on purpose. A real parallax tracks a finger and is over in 300ms; at
     * that speed on a device that is NOT panning, the eye cannot tell "it did
     * not move" from "it moved and I missed it".
     *
     * ON THE MAIN HANDLER, not a coroutine or a thread. `setWallpaperOffsets`
     * is a binder call that wants the window's own thread, and this posts one
     * step every 16ms rather than blocking anything.
     */
    fun sweep() {
        sweeping?.let { main.removeCallbacks(it) }

        val steps = 240
        var i = 0
        val tick = object : Runnable {
            override fun run() {
                // Out and back, so the wallpaper ends where it started and a
                // probe leaves nothing behind.
                val t = i / steps.toFloat()
                val x = if (t < 0.5f) t * 2f else (1f - t) * 2f
                if (!setOffset(x)) {
                    Log.w(TAG, "sweep stopped: no window token")
                    return
                }
                i++
                if (i <= steps) main.postDelayed(this, 16)
            }
        }
        sweeping = tick
        main.post(tick)
    }
}
