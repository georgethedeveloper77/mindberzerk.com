package com.mindhunter.g_launcher.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.Looper
import android.view.ContextThemeWrapper
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.RemoteViews
import java.io.ByteArrayOutputStream

/**
 * Renders a picker thumbnail for an AppWidget provider.
 *
 * --- WHY THIS IS NOT `loadPreviewImage` AND A CANVAS -----------------------
 *
 * The first cut asked the provider for `previewImage`, then drew that drawable
 * into whatever rectangle the caller requested. Two things were wrong with it
 * and they compounded into "our picker looks like a cheap version of One UI".
 *
 * First, `previewImage` is the OLD mechanism and most modern widgets do not
 * ship one worth showing. Android 12 added `previewLayout`: a RemoteViews
 * layout the provider supplies FOR PICKERS, filled with representative content.
 * It is what draws Spotify's media bar, PayPal's action row and Claude's chat
 * pill in Samsung's picker. Almost every app that ships a widget today ships
 * one, so preferring it is most of the visual difference by itself.
 *
 * Second, drawing into the caller's exact rectangle STRETCHES. A 4x1 media bar
 * and a 2x2 tile forced into the same 96x64 box are both distorted, and a
 * distorted preview of a widget is a preview of a different widget. Everything
 * here preserves the provider's own aspect and returns a bitmap the Dart side
 * can lay out at its true proportions.
 *
 * --- THE LOOPER, WHICH IS NOT OPTIONAL --------------------------------------
 *
 * `RemoteViews.apply` INFLATES VIEWS, and view inflation constructs Handlers.
 * A Handler built on a thread with no Looper throws, and this runs on the host
 * impl's IO executor, which has none. Preparing one on first use is what makes
 * off-main-thread inflation safe; it is the same thing Launcher3 does with its
 * own HandlerThread, minus the extra thread. A prepared Looper that is never
 * looped costs nothing and is never torn down because the executor is single
 * threaded and lives as long as the process.
 */
class WidgetPreviewRenderer(context: Context) {

    private val appContext = context.applicationContext
    private val manager = AppWidgetManager.getInstance(appContext)

    /**
     * A PNG preview for [providerKey] that fits inside [maxWidthPx] by
     * [maxHeightPx] without distorting the widget's shape, or null when the
     * provider is gone and there is nothing honest to draw.
     *
     * The returned bitmap is usually SMALLER than the box in one axis. That is
     * the point: the Dart card reads the returned aspect and sizes itself, so a
     * 4x1 renders as a band and a 4x2 as a block, the way they will look once
     * placed.
     */
    fun render(providerKey: String, maxWidthPx: Int, maxHeightPx: Int): ByteArray? {
        val info = runCatching {
            manager.installedProviders.firstOrNull {
                it.provider.flattenToString() == providerKey
            }
        }.getOrNull() ?: return null

        val boxW = maxWidthPx.coerceAtLeast(1)
        val boxH = maxHeightPx.coerceAtLeast(1)
        val (w, h) = fit(aspectOf(info), boxW, boxH)

        val bitmap = fromPreviewLayout(info, w, h)
            ?: fromDrawable(info, w, h)
            ?: return null

        return runCatching {
            ByteArrayOutputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                out.toByteArray()
            }
        }.getOrNull().also { bitmap.recycle() }
    }

    // -- previewLayout, the good path ----------------------------------------

    private fun fromPreviewLayout(
        info: AppWidgetProviderInfo,
        w: Int,
        h: Int,
    ): Bitmap? {
        if (Build.VERSION.SDK_INT < 31) return null
        val layoutId = info.previewLayout
        if (layoutId == 0) return null

        return runCatching {
            ensureLooper()

            // A themed context, not the bare application one. A RemoteViews
            // layout resolves `?android:attr` colours and text appearances
            // against the host's theme, and an unthemed context resolves them
            // to nothing: black text on a black card, which reads as a broken
            // preview rather than a missing one.
            val host = ContextThemeWrapper(
                appContext,
                android.R.style.Theme_DeviceDefault_DayNight,
            )

            val parent = FrameLayout(host)
            val views = RemoteViews(info.provider.packageName, layoutId)
            val rendered: View = views.apply(host, parent)

            parent.addView(
                rendered,
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )

            drawToBitmap(parent, w, h)
        }.getOrNull()
    }

    /**
     * Prepared once per thread, never looped.
     *
     * See the class note. Guarded rather than unconditional because the same
     * renderer must stay callable from the main thread, where preparing a
     * second Looper throws.
     */
    private fun ensureLooper() {
        if (Looper.myLooper() == null) {
            runCatching { Looper.prepare() }
        }
    }

    // -- previewImage and the icon, both at true aspect -----------------------

    private fun fromDrawable(info: AppWidgetProviderInfo, w: Int, h: Int): Bitmap? {
        val drawable = runCatching { info.loadPreviewImage(appContext, 0) }.getOrNull()
            ?: runCatching { info.loadIcon(appContext, 0) }.getOrNull()
            ?: return null

        // The drawable's OWN aspect wins here, not the provider's declared one.
        // A preview image is a picture of the widget and stretching it to the
        // declared footprint is the distortion this class exists to remove; an
        // icon is square and must stay square.
        val iw = drawable.intrinsicWidth
        val ih = drawable.intrinsicHeight
        val (tw, th) = if (iw > 0 && ih > 0) fit(iw.toFloat() / ih, w, h) else (w to h)

        return runCatching {
            val bmp = Bitmap.createBitmap(tw, th, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, tw, th)
            drawable.draw(canvas)
            bmp
        }.getOrNull()
    }

    // -- geometry -------------------------------------------------------------

    /**
     * The provider's own width-to-height ratio.
     *
     * `targetCellWidth`/`targetCellHeight` are the Android 12 way to say
     * "4 by 1" and are already square-ish cells, so their ratio is the shape
     * directly. Below that, and on providers that never set them, the declared
     * minimum footprint in dp carries the same information. Falls back to 1
     * rather than dividing by zero on a provider that reports nothing.
     */
    private fun aspectOf(info: AppWidgetProviderInfo): Float {
        if (Build.VERSION.SDK_INT >= 31 &&
            info.targetCellWidth > 0 && info.targetCellHeight > 0
        ) {
            return info.targetCellWidth.toFloat() / info.targetCellHeight
        }
        if (info.minWidth > 0 && info.minHeight > 0) {
            return info.minWidth.toFloat() / info.minHeight
        }
        return 1f
    }

    /** The largest [aspect]-shaped rectangle that fits inside [boxW] by [boxH]. */
    private fun fit(aspect: Float, boxW: Int, boxH: Int): Pair<Int, Int> {
        val safe = if (aspect.isFinite() && aspect > 0f) aspect else 1f
        val byWidth = (boxW / safe).toInt()
        return if (byWidth <= boxH) {
            boxW to byWidth.coerceAtLeast(1)
        } else {
            (boxH * safe).toInt().coerceAtLeast(1) to boxH
        }
    }

    private fun drawToBitmap(view: View, w: Int, h: Int): Bitmap {
        view.measure(
            View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY),
        )
        view.layout(0, 0, w, h)
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        view.draw(Canvas(bmp))
        return bmp
    }
}
