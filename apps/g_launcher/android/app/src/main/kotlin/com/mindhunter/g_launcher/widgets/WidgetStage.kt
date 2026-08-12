package com.mindhunter.g_launcher.widgets

import android.app.Activity
import android.appwidget.AppWidgetHostView
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout

/**
 * Every hosted third-party AppWidget, in a plain Android ViewGroup BEHIND
 * Flutter.
 *
 * ─── WHY THIS REPLACED PLATFORMVIEWS ENTIRELY ───────────────────────────────
 *
 * Hosting an AppWidget inside Flutter means a PlatformView, and a PlatformView
 * turns on hybrid composition. On this device that is not merely expensive, it
 * is broken. Logcat, immediately after `Using hybrid composition for platform
 * view: 0`:
 *
 *     E/qdgralloc: GetGpuPixelFormat: No map for format: 0x38
 *     E/Gralloc4:  isSupported(1, 1, 56, 1, ...) failed with 1
 *     E/GraphicBufferAllocator: Failed to allocate (4 x 4) format 56 usage 300
 *     E/AHardwareBuffer: GraphicBuffer(w=4, h=4, lc=1) failed
 *
 * Hybrid composition allocates overlay surfaces to stack Flutter content above
 * and below the native view. Impeller on Vulkan requests pixel formats Adreno's
 * gralloc has no mapping for, the overlay buffers never exist, and Flutter's
 * layering silently collapses. That ONE failure produced every symptom we spent
 * days treating as separate bugs: the black quad where the widget should be, the
 * clock desklet drawing twice, desklets bleeding through the drawer and through
 * pushed routes, and 302MB of EGL and GL mtrack.
 *
 * There was a second, independent problem in the same place. Widgets lived
 * inside a `PageView.builder`, which disposes pages as they scroll out, so every
 * swipe destroyed the AppWidgetHostViews and re-inflated each provider's whole
 * RemoteViews tree on the way back. Re-inflation replays CACHED RemoteViews
 * whose image URIs have since expired, so Spotify's provider returned
 * FileNotFoundException for every album cover, dozens of synchronous binder
 * calls to another process on the main thread. That was both the missing artwork
 * and the `Davey! duration=1662ms`.
 *
 * A view in this stage is created once and lives until the widget is removed
 * from the desktop. Nothing about scrolling can destroy it, so neither problem
 * has anywhere left to happen.
 *
 * ─── WHY BEHIND FLUTTER WORKS ───────────────────────────────────────────────
 *
 * `LauncherActivity.getBackgroundMode()` returns `transparent`, which is the
 * line that lets the system wallpaper show through. Its second consequence is
 * that FlutterActivity renders to a FlutterTextureView rather than the opaque
 * SurfaceView it uses by default, and a TextureView composites IN the view
 * hierarchy in normal draw order. So a sibling at index 0 shows through wherever
 * Flutter's own pixels are transparent, for exactly the same reason the
 * wallpaper does. Verified on device before any of this was written.
 *
 * ─── WHAT DART OWNS AND WHAT THIS OWNS ──────────────────────────────────────
 *
 * Dart owns every decision: which widgets exist, where they sit, how big they
 * are, and whether they should be visible right now. It measures each tile's
 * real global rectangle and sends it. This file owns nothing but obedience, and
 * that split is deliberate: the grid, the spans and the placements already have
 * one home in `WidgetSpanResolver` and `DeskletLayout`, and a second opinion
 * living in Kotlin is how the two drift.
 */
object WidgetStage {

    /** One placed widget, in dp, in GLOBAL screen coordinates. */
    data class Placement(
        val widgetId: Int,
        val x: Double,
        val y: Double,
        val w: Double,
        val h: Double,
    )

    private var stage: FrameLayout? = null
    private var controller: WidgetHostController? = null

    /**
     * Which Activity the current [stage] belongs to.
     *
     * Needed because a stage belongs to a WINDOW while everything else here
     * belongs to the process, and on a configuration change two Activities are
     * briefly alive at once. See [attach] and [detach].
     */
    private var owner: Activity? = null

    private val views = mutableMapOf<Int, AppWidgetHostView>()

    /** Last synced rects in PIXELS, for hit testing. Empty while hidden. */
    private val hitRects = mutableMapOf<Int, android.graphics.RectF>()

    private var density = 1f

    // ── lifecycle ───────────────────────────────────────────────────────────

    /**
     * Insert the stage behind Flutter.
     *
     * POSTED, not run inline: at `onCreate` time FlutterActivity has not
     * finished attaching its view, so index 0 would be index 0 of an empty
     * parent and Flutter would be added underneath us afterwards. One post puts
     * this after the attach, which is the difference between a stage behind
     * Flutter and a stage in front of it.
     */
    fun attach(activity: Activity, host: WidgetHostController) {
        val content = activity.findViewById<ViewGroup>(android.R.id.content) ?: return
        controller = host

        // Re-read on every attach. A configuration change is exactly when this
        // can move (a display size change, DeX, a resizable window), and a
        // density captured once would convert every dp the Dart side sends with
        // the OLD scale for the rest of the process.
        density = activity.resources.displayMetrics.density

        content.post {
            // ─── THE OLD GUARD WAS `if (stage != null) return`, AND IT LOST ──
            //
            // On a configuration change the system runs the NEW Activity's
            // onCreate before the OLD one's onDestroy. So this post was queued
            // while the previous Activity's stage was still in place, and
            // whether the launcher survived a rotation came down to whether
            // this runnable happened to run before or after that detach:
            //
            //   post runs AFTER detach   stage is null, a new layer is built,
            //                            everything works. The common case,
            //                            which is why this looked fine.
            //
            //   post runs BEFORE detach  stage is non-null so this returned,
            //                            then detach nulled it, and the new
            //                            Activity ended up with NO STAGE AT
            //                            ALL. Every hosted widget silently
            //                            gone until the process restarted.
            //
            // A race that resolves the wrong way some of the time is the worst
            // shape a bug can have, because it reads as flakiness rather than
            // as a defect. Identity is the fix: a stage already living in THIS
            // content is nothing to do, and a stage belonging to anything else
            // is stale and gets replaced.
            val existing = stage
            if (existing != null && existing.parent === content) return@post
            if (existing != null) dropLayer(existing)

            val layer = FrameLayout(activity).apply {
                // Not clickable and not focusable. Touches arrive only through
                // LauncherActivity.dispatchTouchEvent, which forwards a gesture
                // here ONLY when its first press landed inside a widget and the
                // desktop is at rest. Anything else would have this layer
                // stealing presses meant for Flutter, invisibly, from behind.
                isClickable = false
                isFocusable = false
                // Hidden until Dart says otherwise. A stage that defaults to
                // visible shows stale widget positions for the frame before the
                // first sync, which reads as tiles jumping on every launch.
                visibility = View.GONE
            }
            content.addView(
                layer,
                0,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                ),
            )
            stage = layer
            owner = activity

            // ─── RE-ADOPT, DO NOT RE-INFLATE ─────────────────────────────
            //
            // Host views outlive Activities on purpose; that is the entire
            // premise of this class. After a configuration change they are
            // parentless but perfectly alive, so they are moved into the new
            // layer rather than thrown away.
            //
            // Without this the map was cleared on detach, `sync` found nothing
            // for each id and called `createView` again, and every rotation
            // paid the full RemoteViews re-inflation this class exists to
            // avoid, while the previous view leaked because the controller
            // still held it. The 1.7s hitch, once per rotation.
            //
            // GONE until the next sync places them. A view re-added at its old
            // margins would flash at the pre-rotation position for one frame,
            // which is the jump the visibility default already guards against
            // on a cold start.
            for (view in views.values) {
                (view.parent as? ViewGroup)?.removeView(view)
                view.visibility = View.GONE
                layer.addView(view)
            }
        }
    }

    /**
     * Tear down the layer for [activity], if it is the one that owns it.
     *
     * ─── IDENTITY-CHECKED FOR THE REASON [attach] EXPLAINS ──────────────────
     *
     * The outgoing Activity's onDestroy runs AFTER the incoming one's onCreate,
     * so an unconditional teardown here destroys the stage the new Activity has
     * just built. Same shape as `hostApi.detachActivity` and
     * `widgetHost.detachActivity`, which both take the caller for this reason.
     *
     * ─── AND THE VIEW MAP SURVIVES ──────────────────────────────────────────
     *
     * `views.clear()` used to be here. It should not be: a host view belongs to
     * the process, like the host that made it, and clearing the map orphaned
     * every one of them. [attach] re-adopts them into the next layer.
     *
     * `controller` is not cleared either. It is the process-wide
     * WidgetHostController, handed in by whichever Activity attached last, and
     * nulling it here left `sync` returning early against a live stage.
     */
    fun detach(activity: Activity) {
        if (owner !== activity) return
        stage?.let(::dropLayer)
        stage = null
        owner = null
    }

    /**
     * Unparent a layer without destroying the widgets in it.
     *
     * `removeAllViews` rather than leaving them: a view may not have two
     * parents, so they have to come out before [attach] can put them into the
     * next layer.
     */
    private fun dropLayer(layer: FrameLayout) {
        layer.removeAllViews()
        (layer.parent as? ViewGroup)?.removeView(layer)
        hitRects.clear()
    }

    // ── the one call Dart makes ─────────────────────────────────────────────

    /**
     * Place [placements] and show or hide the whole layer.
     *
     * ─── A WIDGET MISSING FROM THE LIST IS HIDDEN, NOT DESTROYED ──────────
     *
     * This is the single most important line in the file. Dart only reports
     * tiles that are currently laid out, so a widget on a workspace page the
     * PageView has unmounted simply stops appearing in the list. Destroying its
     * host view there would reintroduce exactly the re-inflation churn this
     * class exists to remove, one page swipe at a time.
     *
     * So the view is kept and set GONE. It is released only by [release], which
     * Dart calls when the widget is actually taken off the desktop.
     */
    fun sync(placements: List<Placement>, visible: Boolean) {
        val layer = stage ?: return
        val host = controller ?: return

        layer.visibility = if (visible) View.VISIBLE else View.GONE
        hitRects.clear()

        val present = mutableSetOf<Int>()

        for (p in placements) {
            present += p.widgetId

            val wPx = (p.w * density).toInt().coerceAtLeast(1)
            val hPx = (p.h * density).toInt().coerceAtLeast(1)
            val xPx = (p.x * density).toInt()
            val yPx = (p.y * density).toInt()

            var view = views[p.widgetId]
            if (view == null) {
                // Sized at creation, and that ordering matters: on API 31+ the
                // FIRST RemoteViews apply is when a responsive widget picks its
                // layout variant. A size arriving after it is too late, and
                // Spotify keeps the cramped bar it inflated. `createView`
                // applies the size synchronously before that first apply.
                view = host.createView(p.widgetId, p.w.toInt(), p.h.toInt())
                    ?: continue
                views[p.widgetId] = view
                layer.addView(view, FrameLayout.LayoutParams(wPx, hPx))
            }

            view.visibility = View.VISIBLE

            val lp = view.layoutParams as FrameLayout.LayoutParams
            val sizeChanged = lp.width != wPx || lp.height != hPx
            if (sizeChanged || lp.leftMargin != xPx || lp.topMargin != yPx) {
                lp.width = wPx
                lp.height = hPx
                lp.leftMargin = xPx
                lp.topMargin = yPx
                view.layoutParams = lp
            }

            // ONLY on a real size change. `updateAppWidgetOptions` wakes the
            // provider's `onAppWidgetOptionsChanged`, and firing it on every
            // sync would have every widget on the desktop rebuilding its
            // RemoteViews each time anything moved.
            if (sizeChanged) {
                host.updateSize(p.widgetId, p.w.toInt(), p.h.toInt(), p.w.toInt(), p.h.toInt())
            }

            if (visible) {
                hitRects[p.widgetId] = android.graphics.RectF(
                    xPx.toFloat(),
                    yPx.toFloat(),
                    (xPx + wPx).toFloat(),
                    (yPx + hPx).toFloat(),
                )
            }
        }

        for ((id, view) in views) {
            if (id !in present) view.visibility = View.GONE
        }
    }

    /** The widget is off the desktop for good. Free the view AND the host id. */
    fun release(widgetId: Int) {
        val view = views.remove(widgetId) ?: return
        (view.parent as? ViewGroup)?.removeView(view)
        controller?.releaseView(widgetId)
        hitRects.remove(widgetId)
    }

    // ── input ───────────────────────────────────────────────────────────────

    /**
     * Did this press land on a live widget?
     *
     * Only consulted on ACTION_DOWN. A gesture belongs to whoever its first
     * press hit, for the whole of its life: deciding per event would let a drag
     * that began on the wallpaper end up scrubbing a media widget it happened to
     * pass over.
     */
    fun hitTest(x: Float, y: Float): Boolean {
        if (stage?.visibility != View.VISIBLE) return false
        return hitRects.values.any { it.contains(x, y) }
    }

    /** Hand a gesture to the widget under it. */
    fun dispatch(ev: MotionEvent): Boolean =
        stage?.takeIf { it.visibility == View.VISIBLE }?.dispatchTouchEvent(ev) ?: false
}
