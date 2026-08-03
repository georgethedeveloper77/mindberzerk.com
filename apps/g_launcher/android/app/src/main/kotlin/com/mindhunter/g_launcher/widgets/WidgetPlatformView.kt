package com.mindhunter.g_launcher.widgets

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Wraps a hosted [android.appwidget.AppWidgetHostView] so Flutter can embed it
 * with an AndroidView. The view is inflated by the shared [WidgetHostController]
 * from the widget id passed as a creation param.
 *
 * The creation params also carry the tile's footprint in dp (`widthDp`,
 * `heightDp`), because the FIRST RemoteViews apply is where an Android 12+
 * responsive widget picks its layout variant, and by then it is too late for a
 * size update that went out post-frame from Dart. See
 * [WidgetHostController.createView] for the full story; missing or zero sizes
 * degrade to the old behaviour (inflate now, size when the resize path fires).
 *
 * If the controller returns null (the provider was uninstalled since the widget
 * was placed), the container is left empty and the Dart side draws its own
 * fallback frame - never a crash and never a blank hole that reads as one.
 */
class WidgetPlatformView(
    context: Context,
    private val controller: WidgetHostController,
    private val widgetId: Int,
    widthDp: Int,
    heightDp: Int,
) : PlatformView {

    private val container = FrameLayout(context)

    init {
        val view = controller.createView(widgetId, widthDp, heightDp)
        if (view != null) {
            container.addView(
                view,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                ),
            )
        }
    }

    override fun getView(): View = container

    override fun dispose() {
        // Tell the controller to drop its reference BEFORE the view is detached.
        // It holds host views so a resize can reach them (see its `views` map);
        // leaving one behind after the PlatformView is gone would keep an
        // AppWidgetHostView, and the RemoteViews tree under it, alive for the
        // life of the process.
        controller.releaseView(widgetId)
        container.removeAllViews()
    }
}

/** Registered once on the warmed engine in LauncherApplication. */
class WidgetPlatformViewFactory(
    private val controller: WidgetHostController,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val widgetId = (params?.get("widgetId") as? Number)?.toInt() ?: -1
        // Absent on a params map written by an older Dart build; 0 means "no
        // size yet" and the controller skips the initial sizing rather than
        // telling the provider it has a zero-dp canvas.
        val widthDp = (params?.get("widthDp") as? Number)?.toInt() ?: 0
        val heightDp = (params?.get("heightDp") as? Number)?.toInt() ?: 0
        return WidgetPlatformView(context, controller, widgetId, widthDp, heightDp)
    }

    companion object {
        const val VIEW_TYPE = "g_launcher/widget"
    }
}
