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
 * If the controller returns null (the provider was uninstalled since the widget
 * was placed), the container is left empty and the Dart side draws its own
 * fallback frame — never a crash and never a blank hole that reads as one.
 */
class WidgetPlatformView(
    context: Context,
    controller: WidgetHostController,
    widgetId: Int,
) : PlatformView {

    private val container = FrameLayout(context)

    init {
        val view = controller.createView(widgetId)
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
        return WidgetPlatformView(context, controller, widgetId)
    }

    companion object {
        const val VIEW_TYPE = "g_launcher/widget"
    }
}
