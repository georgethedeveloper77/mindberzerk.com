package com.mindhunter.g_launcher.icons

import android.content.Context
import android.content.pm.LauncherActivityInfo
import android.content.pm.LauncherApps
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.UserManager
import com.mindhunter.g_launcher.apps.ComponentKey

/**
 * The three layers an icon can have, once pulled apart.
 *
 * Adaptive icons (API 26+) ship foreground + background as separate drawables,
 * sized 108x108dp with only the centre 72x72dp guaranteed visible. That safe
 * zone is what lets us re-mask them into any shape we like — it is the entire
 * reason a themed launcher can work at all.
 *
 * Legacy icons are a single opaque bitmap with the shape already baked in. We
 * cannot un-bake it. See IconRenderer for how we cope.
 */
data class ExtractedIcon(
    val foreground: Drawable?,
    val background: Drawable?,

    /**
     * The monochrome layer (API 33+, and only if the developer bothered to
     * supply one). This is what Material You themed icons use.
     *
     * Coverage in the wild is BAD — well under half of apps, and worse in the
     * budget-Android app mix that is G Launcher's actual audience. Any theme
     * that hard-depends on monochrome will look broken on a real phone. That is
     * precisely the hole the hand-crafted hero icon set (slice 5) exists to
     * fill, and why the renderer must degrade gracefully rather than assume.
     */
    val monochrome: Drawable?,

    /** False = legacy icon. The shape is already baked in; we cannot re-mask. */
    val isAdaptive: Boolean,
)

/**
 * Pulls icons out of LauncherApps. No permission required — same privileged,
 * visibility-exempt path as the app list.
 *
 * Rendering happens in IconRenderer. This class only fetches and classifies.
 */
class IconExtractor(context: Context) {

    private val appContext = context.applicationContext
    private val launcherApps =
        appContext.getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps
    private val userManager =
        appContext.getSystemService(Context.USER_SERVICE) as UserManager

    /**
     * Ask for the icon at the density we will actually draw at. Passing 0 gets
     * you the default density and a blurry icon on a high-DPI panel.
     */
    private val densityDpi = appContext.resources.displayMetrics.densityDpi

    fun extract(componentKey: String): ExtractedIcon? {
        val key = ComponentKey.parse(componentKey) ?: return null
        val info = resolve(key) ?: return null

        // getIcon() is the unbadged icon. We apply the work-profile badge
        // ourselves at render time, so the badge follows the theme instead of
        // being stamped on by the system in the system's own style.
        val drawable = info.getIcon(densityDpi) ?: return null
        return classify(drawable)
    }

    private fun resolve(key: ComponentKey): LauncherActivityInfo? {
        val user = userManager.getUserForSerialNumber(key.userSerial) ?: return null

        // Scoped to one package, so this is a short list — not a full app scan.
        return launcherApps
            .getActivityList(key.packageName, user)
            .firstOrNull { it.componentName.className == key.className }
    }

    private fun classify(drawable: Drawable): ExtractedIcon {
        if (drawable is AdaptiveIconDrawable) {
            return ExtractedIcon(
                foreground = drawable.foreground,
                background = drawable.background,
                monochrome = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    drawable.monochrome
                } else {
                    null
                },
                isAdaptive = true,
            )
        }

        return ExtractedIcon(
            foreground = drawable,
            background = null,
            monochrome = null,
            isAdaptive = false,
        )
    }
}
