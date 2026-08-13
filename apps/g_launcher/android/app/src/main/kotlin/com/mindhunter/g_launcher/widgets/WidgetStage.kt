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

    /**
     * May a press be taken from Flutter and given to a widget?
     *
     * ─── VISIBLE AND INTERACTIVE ARE NOT THE SAME QUESTION ──────────────────
     *
     * The stage had one flag, and `LauncherActivity.dispatchTouchEvent` asks
     * [hitTest] on every ACTION_DOWN. So any press landing inside a widget's
     * rectangle was claimed for the widget BEFORE Flutter saw it, whatever
     * Flutter happened to be drawing on top.
     *
     * That is right for a desktop at rest and wrong the moment anything is
     * layered over it. The desklet menu opens ANCHORED TO THE WIDGET, so its
     * rows sit directly on the hit rect and the ones overlapping it could not
     * be tapped at all: the press went to Spotify, underneath the panel the
     * user was aiming at. The same is true of any pushed route, including
     * Settings and the widget picker, where a tap that happens to land where a
     * widget sits on the desktop below is swallowed by a view nobody can see.
     *
     * Hiding the stage would also fix it and would be worse: the widget would
     * vanish the instant you held it, so the menu would be about something no
     * longer on screen. So visibility and interactivity are separated. The
     * widget keeps drawing; it simply stops taking touches until the thing on
     * top of it is gone.
     */
    private var interactive = true

    // ─── THE RETRY, AND WHY A SKIPPED WIDGET NEVER CAME BACK ────────────────
    //
    // `createView` returns null when `AppWidgetManager.getAppWidgetInfo` does
    // not yet know the id. That is a real window right after
    // `bindAppWidgetIdIfAllowed`: measured on device, the provider pushed two
    // updates 700ms after the bind and the host still had no view for them.
    //
    // The loop below used to `continue` past that, which would be fine if
    // anything came back. Nothing does. Dart only calls `sync` when the flat
    // rect list CHANGES, and a settled desktop reports the same rects forever,
    // so the skipped widget stayed an empty tile until the user moved
    // something. That is the "I add Spotify and get nothing" report, and it is
    // also why one widget worked and the next did not: the race is won or lost
    // by a few hundred milliseconds.
    //
    // So the stage remembers the last thing Dart asked for and asks itself
    // again. Bounded, because a provider that has genuinely been uninstalled
    // will never resolve and a self-rescheduling runnable with no ceiling is a
    // battery drain nobody can see.
    private var lastPlacements: List<Placement> = emptyList()
    private var lastVisible = false
    private var retries = 0
    private var retryScheduled = false

    /** About two seconds at [RETRY_DELAY_MS]. Long enough for a slow bind. */
    private const val MAX_RETRIES = 8
    private const val RETRY_DELAY_MS = 250L

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

        // A retry posted to a layer that is going away either never runs or
        // runs against the wrong window. Either way the flag must not survive,
        // or the NEXT layer's first failure would find `retryScheduled` still
        // true and never schedule anything.
        retryScheduled = false
        retries = 0
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
    fun sync(
        placements: List<Placement>,
        visible: Boolean,
        interactive: Boolean,
    ) {
        val layer = stage ?: return
        val host = controller ?: return

        // Set BEFORE the early returns below, so a sync carrying nothing but a
        // change of interactivity still lands. Dart sends exactly that when a
        // menu opens over a desktop whose rects have not moved.
        this.interactive = interactive

        layer.visibility = if (visible) View.VISIBLE else View.GONE
        hitRects.clear()

        // Held so a retry has something to replay. See the fields' note.
        lastPlacements = placements
        lastVisible = visible

        val present = mutableSetOf<Int>()
        var missing = false

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
                if (view == null) {
                    // Not "this widget is broken", usually. The id is bound and
                    // the manager has not caught up. Flagged for the retry
                    // below rather than skipped and forgotten.
                    missing = true
                    continue
                }
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

        if (missing) {
            scheduleRetry(layer)
        } else {
            // A clean pass resets the budget, so a widget added later gets its
            // own full allowance rather than inheriting an exhausted one.
            retries = 0
        }
    }

    /**
     * Ask ourselves again shortly, for the ids that could not be created.
     *
     * Posted to the stage's own view, so it rides the same message queue as
     * everything else here and dies with the window rather than outliving it.
     * [retryScheduled] collapses a burst: several syncs can fail in a row while
     * a bind settles, and each queueing its own runnable would multiply the
     * work exactly when the system is already busy.
     */
    private fun scheduleRetry(layer: FrameLayout) {
        if (retryScheduled || retries >= MAX_RETRIES) return
        retryScheduled = true
        retries++

        layer.postDelayed({
            retryScheduled = false
            // Re-read rather than capture: `stage` may have been replaced by a
            // configuration change in the meantime, and replaying into a dead
            // layer would put the view somewhere nobody is looking.
            if (stage != null && lastPlacements.isNotEmpty()) {
                sync(lastPlacements, lastVisible, interactive)
            }
        }, RETRY_DELAY_MS)
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
        if (!interactive) return false
        if (stage?.visibility != View.VISIBLE) return false
        return hitRects.values.any { it.contains(x, y) }
    }

    // ── the long press, which is the only thing native decides ──────────────

    /**
     * Which widget the current gesture is over, and where it started.
     *
     * ─── WHY NATIVE HAS TO DETECT THIS ──────────────────────────────────────
     *
     * `LauncherActivity.dispatchTouchEvent` gives the entire gesture to the
     * widget as soon as a press lands inside one, and it is right to: a media
     * scrub that changes owner half way through is worse than one that never
     * started. The consequence is that FlutterView never sees the press, so no
     * Flutter recogniser can fire, so `EditableDesklet`'s long press could not
     * run for a hosted tile however it was written.
     *
     * That made hosted widgets the only tiles on the desktop that could not be
     * moved, resized or removed, and left every one of them stuck at whatever
     * span the picker chose. A 4x2 Spotify card is a thin bar with an empty
     * band under it; the same widget pulled to 4x4 is the one people recognise.
     * The grid was placing it correctly the whole time. Nothing could ask for a
     * different rectangle.
     *
     * So the press is timed HERE and the outcome is sent to Dart, which already
     * owns the menu, the edit mode and the resize handles.
     */
    private var pressId: Int? = null
    private var pressX = 0f
    private var pressY = 0f
    private var pressHandled = false

    private var pressRunnable: Runnable? = null

    /** Matches `_holdToLift` in desklet_editor, so both kinds of tile feel the same. */
    private const val LONG_PRESS_MS = 300L

    /**
     * How far the finger may wander before this is a drag rather than a hold.
     *
     * A literal rather than `ViewConfiguration.scaledTouchSlop` on purpose:
     * that value is tuned for scrolling lists and is small enough that a thumb
     * resting on a media widget cancels the hold about half the time. Flutter's
     * own long-press slop is larger for the same reason, and matching the tile
     * beside it matters more here than matching a list.
     */
    private const val PRESS_SLOP_PX = 40f

    /** Hand a gesture to the widget under it. */
    fun dispatch(ev: MotionEvent): Boolean {
        val layer = stage?.takeIf { it.visibility == View.VISIBLE } ?: return false

        when (ev.actionMasked) {
            MotionEvent.ACTION_DOWN -> beginPress(layer, ev)

            MotionEvent.ACTION_MOVE -> {
                val dx = ev.x - pressX
                val dy = ev.y - pressY
                if (dx * dx + dy * dy > PRESS_SLOP_PX * PRESS_SLOP_PX) cancelPress()
            }

            MotionEvent.ACTION_UP,
            MotionEvent.ACTION_CANCEL -> cancelPress()
        }

        // ─── AFTER THE HOLD FIRES, THE WIDGET GETS NOTHING MORE ─────────────
        //
        // The provider has already been sent an ACTION_CANCEL by [beginPress]'s
        // runnable, so it has released its own pressed state. Forwarding the
        // rest would let a media button also fire on the UP that ends a hold,
        // which is the "I long-pressed and it skipped the track" bug every
        // launcher hits once.
        if (pressHandled) {
            if (ev.actionMasked == MotionEvent.ACTION_UP ||
                ev.actionMasked == MotionEvent.ACTION_CANCEL
            ) {
                pressHandled = false
            }
            return true
        }

        return layer.dispatchTouchEvent(ev)
    }

    private fun beginPress(layer: FrameLayout, ev: MotionEvent) {
        cancelPress()
        pressHandled = false
        pressX = ev.x
        pressY = ev.y

        // Which widget, decided once on DOWN for the same reason ownership is:
        // a gesture belongs to whoever its first press hit.
        pressId = hitRects.entries
            .firstOrNull { it.value.contains(ev.x, ev.y) }
            ?.key
            ?: return

        val id = pressId ?: return
        val r = Runnable {
            pressRunnable = null
            pressHandled = true

            // CANCEL the widget's own gesture before telling Dart. Without it
            // the provider keeps a button highlighted for as long as the menu
            // is open, because from its side the finger never lifted.
            val cancel = MotionEvent.obtain(ev)
            cancel.action = MotionEvent.ACTION_CANCEL
            layer.dispatchTouchEvent(cancel)
            cancel.recycle()

            // The PRESS POINT goes with it, in pixels, global to the screen.
            //
            // Dart cannot recover this: the gesture never reached Flutter, by
            // design. And it needs it, because anchoring a hosted widget's menu
            // to the TILE breaks down once the tile is large. A 366x475dp
            // widget leaves no room for a 330dp panel below it and 91dp above,
            // so the panel clamps to the screen edge and lands on top of the
            // thing it is about. The finger is a point and always has room
            // beside it, which is why the folder member menu anchors that way
            // too.
            StageBridge.notifyLongPress(id, pressX, pressY)
        }
        pressRunnable = r
        layer.postDelayed(r, LONG_PRESS_MS)
    }

    private fun cancelPress() {
        pressRunnable?.let { stage?.removeCallbacks(it) }
        pressRunnable = null
        pressId = null
    }
}
