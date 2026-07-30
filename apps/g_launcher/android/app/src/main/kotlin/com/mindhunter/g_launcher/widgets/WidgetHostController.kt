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

/** The launcher's AppWidget host. One per process. */
class LauncherWidgetHost(context: Context) : AppWidgetHost(context, HOST_ID) {
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
 * ─── WHY THIS IS SEPARATE FROM THE PIGEON IMPL, AND WHY THE ACTIVITY ATTACHES ─
 *
 * The host outlives any Activity, so it is created ONCE in LauncherApplication
 * next to the other hosts. But binding and configuring both call
 * `startActivityForResult`, which only an Activity can do — so LauncherActivity
 * attaches itself here on start and detaches on stop, and forwards its
 * `onActivityResult` back. The host's `startListening`/`stopListening` ride the
 * same lifecycle, because a host that is not listening delivers no updates.
 *
 * ─── ONE REQUEST AT A TIME, HELD ACROSS THE ROUND-TRIP ──────────────────────
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

    private var activity: Activity? = null
    private var pending: Pending? = null

    /**
     * Live host views, by widget id.
     *
     * ─── WHY THE VIEWS ARE TRACKED AT ALL ───────────────────────────────────
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

    // ── lifecycle (called by LauncherActivity) ──────────────────────────────

    fun attachActivity(a: Activity) { activity = a }

    fun detachActivity(a: Activity) { if (activity === a) activity = null }

    fun startListening() { runCatching { host.startListening() } }

    fun stopListening() { runCatching { host.stopListening() } }

    // ── placement ───────────────────────────────────────────────────────────

    /**
     * Allocate → bind → configure. Calls [onResult] with the widget id, or null
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
            configureOrFinish(a, p.widgetId, p.onResult) // bound → maybe config
        } else {
            p.onResult(p.widgetId) // configured
        }
        return true
    }

    // ── the view for the PlatformView ────────────────────────────────────────

    /** Inflate the hosted view for [widgetId], or null if the provider is gone. */
    fun createView(widgetId: Int): AppWidgetHostView? {
        val info = manager.getAppWidgetInfo(widgetId) ?: return null
        val view = runCatching { host.createView(appContext, widgetId, info) }
            .getOrNull() ?: return null

        // ─── STRIP THE DEFAULT PADDING ──────────────────────────────────────
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
        view.setPadding(0, 0, 0, 0)

        views[widgetId] = view
        return view
    }

    /** The PlatformView holding [widgetId] is gone. */
    fun releaseView(widgetId: Int) {
        views.remove(widgetId)
    }

    // ── resize + delete ──────────────────────────────────────────────────────

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
        // widget's RemoteViews variants. Without it the view keeps whichever
        // variant it inflated at first layout, so resizing a Spotify or Weather
        // widget changed its rectangle and not its contents.
        views[widgetId]?.let { view ->
            runCatching {
                view.updateAppWidgetSize(Bundle.EMPTY, minW, minH, maxW, maxH)
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
