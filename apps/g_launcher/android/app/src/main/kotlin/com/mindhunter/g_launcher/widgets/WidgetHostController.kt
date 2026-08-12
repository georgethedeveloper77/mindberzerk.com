package com.mindhunter.g_launcher.widgets

import android.app.Activity
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.ContextThemeWrapper

/**
 * A hosted widget whose padding CANNOT be put back.
 *
 * ─── setPadding(0,0,0,0) IN createView WAS NOT HOLDING ──────────────────────
 *
 * `AppWidgetHostView` re-applies the platform's default widget margin from
 * inside `updateAppWidget`, every time a provider pushes new RemoteViews. So the
 * padding was correctly zeroed at creation and silently restored on the first
 * update, which is why a hosted widget looked right for an instant and then
 * settled into a box inset inside its own tile.
 *
 * Worse than cosmetic: `updateAppWidgetSize` subtracts that padding before
 * telling the provider what canvas it has. On this device that is the gap
 * between the two lines in logcat, which should be the same number and are not:
 *
 *     updateAppWidgetOptions() ... appWidgetSizes=[366.0x282.0]        (ours)
 *     updateAppWidgetOptions() ... appWidgetSizes=[349.64444x265.64444] (the view's)
 *
 * The provider is picking a layout for 349x265 and being laid out at 366x282, so
 * a responsive widget chooses the wrong variant and then gets stretched into the
 * remainder. That is "wrong shape" with a number attached to it.
 *
 * Overriding `setPadding` to swallow its arguments is what Launcher3 does, and
 * for the same reason: the tile already owns the gutter, so a second inset
 * inside the first is always wrong here.
 */
private class HostedWidgetView(context: Context) : AppWidgetHostView(context) {
    override fun setPadding(left: Int, top: Int, right: Int, bottom: Int) {
        super.setPadding(0, 0, 0, 0)
    }
}

/** The launcher's AppWidget host. One per process. */
class LauncherWidgetHost(context: Context) : AppWidgetHost(context, HOST_ID) {
    /**
     * Every hosted view is a [HostedWidgetView]. This is the ONLY hook the
     * framework offers for it: `createView` is final in effect and constructs
     * whatever this returns, so a subclass here is the only way to influence the
     * view that ends up holding the RemoteViews.
     *
     * [context] is whatever was handed to `AppWidgetHost.createView`, which is
     * why the themed wrapper in [WidgetHostController.createView] reaches the
     * inflation and not just this object.
     */
    override fun onCreateView(
        context: Context,
        appWidgetId: Int,
        appWidget: AppWidgetProviderInfo?,
    ): AppWidgetHostView = HostedWidgetView(context)

    private companion object {
        // Arbitrary, stable for the life of the install. Changing it orphans
        // every widget id already allocated, so never renumber it.
        const val HOST_ID = 0x6C67 // 'lg'
    }
}

/**
 * Owns the AppWidget host and the whole live-widget lifecycle: allocate, bind
 * (with Android's consent dialog), configure, create the host view for the
 * PlatformView, resize, and delete.
 *
 * --- WHY THIS IS SEPARATE FROM THE PIGEON IMPL, AND WHY THE ACTIVITY ATTACHES
 *
 * The host outlives any Activity, so it is created ONCE in LauncherApplication
 * next to the other hosts. But binding and configuring both call
 * `startActivityForResult`, which only an Activity can do - so LauncherActivity
 * attaches itself here on start and detaches on stop, and forwards its
 * `onActivityResult` back. The host's `startListening`/`stopListening` ride the
 * same lifecycle, because a host that is not listening delivers no updates.
 *
 * --- ONE REQUEST AT A TIME, HELD ACROSS THE ROUND-TRIP ----------------------
 *
 * A launcher is not a signed system app, so `bindAppWidgetIdIfAllowed` almost
 * always returns false and the user sees a consent dialog; many providers then
 * run a config Activity. Both are Activity results, so [addWidget]'s callback is
 * held in [pending] and resolved in [onActivityResult]. Only one can be in
 * flight because the user is looking at exactly one dialog.
 */
class WidgetHostController(context: Context) {

    private val appContext = context.applicationContext
    private val manager = AppWidgetManager.getInstance(appContext)
    private val host = LauncherWidgetHost(appContext)

    /**
     * The context hosted widgets are INFLATED against, and the reason they were
     * coming up invisible.
     *
     * ─── THE LAUNCHER'S OWN THEME IS TRANSPARENT, AND WIDGETS INHERIT IT ────
     *
     * `LauncherActivity.getBackgroundMode()` returns `transparent`, which is
     * what lets the wallpaper through and is not negotiable. Its cost is that
     * this application's theme is a translucent one, and RemoteViews resolve
     * `?android:attr/colorBackground`, `?android:attr/textColorPrimary` and
     * every text appearance against whatever context they are inflated with.
     * Handing them `appContext` resolved those attributes against a theme that
     * has no opaque background and no defined text colours, so a widget that
     * paints its own card came out with nothing behind it and, often, text the
     * same colour as the thing behind that. Reported as widgets appearing
     * transparent or simply not being visible.
     *
     * ─── THIS FILE ALREADY KNEW ────────────────────────────────────────────
     *
     * `WidgetPreviewRenderer.fromPreviewLayout` wraps for exactly this and says
     * so: "an unthemed context resolves them to nothing: black text on a black
     * card, which reads as a broken preview rather than a missing one." The
     * picker was fixed and the live path was not, which is why a widget could
     * preview correctly and then place invisibly. Same wrapper, same style, on
     * purpose: a preview that does not match what gets placed is worse than no
     * preview.
     *
     * ─── WHY NOT THE ACTIVITY'S CONTEXT, WHICH LAUNCHER3 USES ──────────────
     *
     * Because these views outlive the Activity. The whole point of the stage is
     * that a host view is created once and survives every page swipe and every
     * configuration change; a view holding an Activity context would pin a dead
     * Activity and its entire view tree for as long as the widget is on the
     * desktop. DayNight still follows the system setting through the application
     * resources, so the only thing given up is an Activity-level theme override,
     * which this app does not have.
     */
    private val widgetContext: Context = ContextThemeWrapper(
        appContext,
        android.R.style.Theme_DeviceDefault_DayNight,
    )

    private var activity: Activity? = null
    private var pending: Pending? = null

    /**
     * Live host views, by widget id.
     *
     * --- WHY THE VIEWS ARE TRACKED AT ALL -----------------------------------
     *
     * `updateAppWidgetOptions` tells the PROVIDER what size it has, which is
     * what makes a widget's own `onAppWidgetOptionsChanged` fire. It does not
     * tell the HOST VIEW anything, and on Android 12+ the host view is what
     * picks between the RemoteViews variants a responsive widget supplies. So a
     * widget shipping a compact layout and a full one would be told it had room
     * and still draw the compact one, which is most of "the Spotify widget
     * looks bad on this launcher".
     *
     * Held only while the PlatformView that created it is alive;
     * [releaseView] is called from its dispose.
     */
    private val views = mutableMapOf<Int, AppWidgetHostView>()

    private data class Pending(
        val widgetId: Int,
        val provider: ComponentName,
        val onResult: (Int?) -> Unit,
    )

    // -- lifecycle (called by LauncherActivity) ------------------------------

    fun attachActivity(a: Activity) { activity = a }

    fun detachActivity(a: Activity) { if (activity === a) activity = null }

    fun startListening() { runCatching { host.startListening() } }

    fun stopListening() { runCatching { host.stopListening() } }

    // -- placement -----------------------------------------------------------

    /**
     * Allocate -> bind -> configure. Calls [onResult] with the widget id, or null
     * if the user cancelled the bind dialog or the config screen. Runs on the
     * main thread (the Activity flow is main-thread, and Pigeon calls this from
     * there).
     */
    fun addWidget(providerKey: String, onResult: (Int?) -> Unit) {
        val a = activity
        val provider = ComponentName.unflattenFromString(providerKey)
        if (a == null || provider == null) { onResult(null); return }

        val id = host.allocateAppWidgetId()

        val allowed = runCatching {
            manager.bindAppWidgetIdIfAllowed(id, provider)
        }.getOrDefault(false)

        if (allowed) {
            configureOrFinish(a, id, onResult)
            return
        }

        // The normal path for a non-system launcher: ask the user to allow it.
        pending = Pending(id, provider, onResult)
        val intent = Intent(AppWidgetManager.ACTION_APPWIDGET_BIND).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_PROVIDER, provider)
        }
        runCatching { a.startActivityForResult(intent, REQ_BIND) }
            .onFailure {
                host.deleteAppWidgetId(id)
                pending = null
                onResult(null)
            }
    }

    private fun configureOrFinish(a: Activity, id: Int, onResult: (Int?) -> Unit) {
        val info: AppWidgetProviderInfo? = manager.getAppWidgetInfo(id)
        if (info?.configure != null) {
            pending = Pending(id, info.provider, onResult)
            runCatching {
                host.startAppWidgetConfigureActivityForResult(a, id, 0, REQ_CONFIG, null)
            }.onFailure {
                // Some config activities refuse to launch this way. Keep the
                // widget rather than lose it: an unconfigured widget still
                // draws, and the app can be reconfigured from its own settings.
                pending = null
                onResult(id)
            }
        } else {
            onResult(id)
        }
    }

    /** Routed from LauncherActivity.onActivityResult. Returns true if consumed. */
    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != REQ_BIND && requestCode != REQ_CONFIG) return false
        val p = pending ?: return true
        pending = null

        val ok = resultCode == Activity.RESULT_OK
        val a = activity
        if (!ok || a == null) {
            host.deleteAppWidgetId(p.widgetId)
            p.onResult(null)
            return true
        }

        if (requestCode == REQ_BIND) {
            configureOrFinish(a, p.widgetId, p.onResult) // bound -> maybe config
        } else {
            p.onResult(p.widgetId) // configured
        }
        return true
    }

    // -- the view for the PlatformView ---------------------------------------

    /**
     * Inflate the hosted view for [widgetId], or null if the provider is gone.
     *
     * [widthDp] and [heightDp] are the tile footprint the Dart side is about to
     * lay the view out into, passed as PlatformView creation params.
     *
     * --- WHY THE SIZE ARRIVES HERE AND NOT ONLY THROUGH updateSize ----------
     *
     * The first RemoteViews apply happens the moment this view attaches, and on
     * Android 12+ that apply is when the view picks among a responsive widget's
     * layout variants. The Dart side's first `updateWidgetSize` goes out in a
     * post-frame callback, which races this inflate and lost often enough that
     * Spotify came up in its cramped variant and stayed there. Sizing the view
     * synchronously here, before it is ever laid out, means the FIRST apply
     * already knows its canvas. The post-frame update that follows is then an
     * idempotent repeat, not the first news.
     *
     * Zero or negative dimensions skip the sizing (a defensive caller that has
     * no size yet still gets a view; the resize path will catch up).
     */
    fun createView(widgetId: Int, widthDp: Int, heightDp: Int): AppWidgetHostView? {
        val info = manager.getAppWidgetInfo(widgetId) ?: return null
        // widgetContext, NOT appContext. See the field's note: this is the
        // context the provider's RemoteViews resolve their theme attributes
        // against, and the launcher's own theme is translucent.
        val view = runCatching { host.createView(widgetContext, widgetId, info) }
            .getOrNull() ?: return null

        // --- STRIP THE DEFAULT PADDING --------------------------------------
        //
        // AppWidgetHostView applies the platform's default widget margin to any
        // provider targeting below API 15, and to plenty that target above it.
        // On a home screen full of icons that margin is what keeps widgets from
        // touching each other; on a desktop where the tile ALREADY has a gutter
        // and a frame, it is a second inset inside the first, and it is why a
        // hosted widget reads as floating in the middle of too much space while
        // its own content is cramped.
        //
        // Every launcher does this. It is the single cheapest visual difference
        // between a hosted widget that looks placed and one that looks pasted.
        //
        // KEPT, though [HostedWidgetView] now makes it a no-op that could not
        // fail. The line documents intent at the point the view is born, and the
        // override documents that the framework will try to undo it. Deleting
        // this one would leave the override looking like defensive noise.
        view.setPadding(0, 0, 0, 0)

        // Registered BEFORE the sizing call so updateSize can reach it. The
        // previous order (register after sizing, or size only from the Dart
        // side) is exactly the race described above.
        views[widgetId] = view

        if (widthDp > 0 && heightDp > 0) {
            updateSize(widgetId, widthDp, heightDp, widthDp, heightDp)
        }
        return view
    }

    /** The PlatformView holding [widgetId] is gone. */
    fun releaseView(widgetId: Int) {
        views.remove(widgetId)
    }

    // -- resize + delete -----------------------------------------------------

    fun updateSize(widgetId: Int, minW: Int, minH: Int, maxW: Int, maxH: Int) {
        val opts = Bundle().apply {
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, minW)
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, minH)
            putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, maxW)
            putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, maxH)
            // Android 12+ responsive widgets read the EXACT sizes list, not the
            // min/max range, to choose their layout. Without it a widget like
            // Spotify falls back to a conservative compact layout even when it
            // has room. We pass the one real size (the caller sends min == max).
            if (Build.VERSION.SDK_INT >= 31) {
                putParcelableArrayList(
                    AppWidgetManager.OPTION_APPWIDGET_SIZES,
                    arrayListOf(SizeF(maxW.toFloat(), maxH.toFloat())),
                )
            }
        }
        runCatching { manager.updateAppWidgetOptions(widgetId, opts) }

        // AND THE HOST VIEW, which is the half that was missing.
        //
        // The manager call above notifies the provider. This one tells the view
        // that renders it, which on API 31+ is what selects among a responsive
        // widget's RemoteViews variants.
        //
        // TWO THINGS THIS CALL MUST GET RIGHT, both learned the hard way:
        //
        //   * On 31+ it must be the List<SizeF> overload. The legacy 4-int
        //     overload predates responsive layouts and does not feed the exact
        //     sizes the view's variant selection reads, so the view kept
        //     whichever variant it inflated first and a resize changed the
        //     widget's rectangle but never its contents.
        //
        //   * A FRESH Bundle(), never Bundle.EMPTY. Both overloads WRITE the
        //     computed size options INTO the bundle they are handed, and
        //     Bundle.EMPTY is a process-global singleton. Passing it mutates
        //     shared framework state, and the day something else reads
        //     Bundle.EMPTY expecting emptiness is the day this becomes the
        //     bug nobody can reproduce.
        views[widgetId]?.let { view ->
            runCatching {
                if (Build.VERSION.SDK_INT >= 31) {
                    view.updateAppWidgetSize(
                        Bundle(),
                        listOf(SizeF(maxW.toFloat(), maxH.toFloat())),
                    )
                } else {
                    @Suppress("DEPRECATION")
                    view.updateAppWidgetSize(Bundle(), minW, minH, maxW, maxH)
                }
            }
        }
    }

    fun removeWidget(widgetId: Int) {
        views.remove(widgetId)
        runCatching { host.deleteAppWidgetId(widgetId) }
    }

    private companion object {
        const val REQ_BIND = 0x0B1D
        const val REQ_CONFIG = 0x0C06
    }
}
