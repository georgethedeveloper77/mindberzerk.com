package com.mindhunter.g_launcher.apps

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Rect
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.mindhunter.g_launcher.WidgetProviderInfo
import java.io.ByteArrayOutputStream
import com.mindhunter.g_launcher.AppChangeEvent
import com.mindhunter.g_launcher.AppChangeReason
import com.mindhunter.g_launcher.AppEntry
import com.mindhunter.g_launcher.LauncherFlutterApi
import com.mindhunter.g_launcher.LauncherHostApi
import com.mindhunter.g_launcher.icons.BrandIconResolver
import com.mindhunter.g_launcher.icons.BrandTreatment
import com.mindhunter.g_launcher.icons.IconCache
import com.mindhunter.g_launcher.icons.HeroIconResolver
import com.mindhunter.g_launcher.icons.IconExtractor
import com.mindhunter.g_launcher.icons.IconRenderer
import com.mindhunter.g_launcher.DeviceStats
import com.mindhunter.g_launcher.StatCapabilities
import com.mindhunter.g_launcher.system.DeviceStatsReader
import com.mindhunter.g_launcher.system.GestureAccessibilityService
import com.mindhunter.g_launcher.system.RoleRequester
import com.mindhunter.g_launcher.system.WallpaperController
import com.mindhunter.g_launcher.system.WallpaperWorker
import com.mindhunter.g_launcher.widgets.WidgetHostController
import java.util.concurrent.Executors

// Pigeon generates its own IconStyle/IconTreatment in the root package; the
// renderer has its own in .icons. Same names, different types. Alias rather
// than let Kotlin silently pick one.
import com.mindhunter.g_launcher.IconStyle as WireStyle
import com.mindhunter.g_launcher.IconTreatment as WireTreatment
import com.mindhunter.g_launcher.icons.IconStyle as RenderStyle
import com.mindhunter.g_launcher.icons.IconTreatment as RenderTreatment

/**
 * Pigeon host side. Owns the repository, the watcher and the icon cache.
 *
 * Constructed in LauncherApplication.onCreate with the warmed engine — NOT in
 * the Activity, which gets torn down and rebuilt.
 */
class LauncherHostApiImpl(
    context: Context,
    private val flutterApi: LauncherFlutterApi,
    private val widgetHost: WidgetHostController,
) : LauncherHostApi {

    private val appContext = context.applicationContext
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private val repository = AppRepository(appContext)
    private val roles = RoleRequester(appContext)
    private val wallpaper = WallpaperController(appContext)
    private val stats = DeviceStatsReader(appContext)

    private val iconCache = IconCache(
        context = appContext,
        repository = repository,
        extractor = IconExtractor(appContext),
        renderer = IconRenderer(),
        heroes = HeroIconResolver(appContext),
        brands = BrandIconResolver(appContext),
    )

    private val watcher = AppChangeWatcher(appContext, repository) { reason, apps ->
        // An icon pack IS an installed app, so its install, update or removal
        // already arrives here for free. Hooking it is what makes an UPDATED
        // pack take effect, rather than the resolver serving drawables from a
        // Resources handle opened against the previous APK until the process
        // dies — the same trap the CDN resolvers have, arriving through Play.
        //
        // SAFE TO CALL ON EVERY APP CHANGE, and that is a property of the
        // callee, not of this line. This watcher fires for every app on the
        // device and Play auto-updates a dozen at once; `onIconPackAppChanged`
        // returns immediately unless a pack is selected AND its APK actually
        // changed. Read its comment before making this call conditional here —
        // the guard is deliberately on the side that has the information.
        iconCache.onIconPackAppChanged()
        main.post { flutterApi.onAppsChanged(AppChangeEvent(reason, apps)) { } }
    }

    fun start() = watcher.start()

    fun stop() {
        watcher.stop()
        iconCache.shutdown()
        io.shutdown()
    }

    // ---- app list --------------------------------------------------------

    override fun getInstalledApps(callback: (Result<List<AppEntry>>) -> Unit) {
        val cached = repository.cached()
        if (cached.isNotEmpty()) {
            callback(Result.success(cached))
            return
        }
        io.execute {
            val apps = runCatching { repository.refresh() }
            main.post { callback(apps) }
        }
    }

    override fun launchApp(
        componentKey: String,
        sourceLeft: Double?,
        sourceTop: Double?,
        sourceRight: Double?,
        sourceBottom: Double?,
    ) {
        val density = appContext.resources.displayMetrics.density
        val bounds = if (
            sourceLeft != null && sourceTop != null &&
            sourceRight != null && sourceBottom != null
        ) {
            Rect(
                (sourceLeft * density).toInt(),
                (sourceTop * density).toInt(),
                (sourceRight * density).toInt(),
                (sourceBottom * density).toInt(),
            )
        } else null

        repository.launch(componentKey, bounds)
    }

    override fun openAppInfo(componentKey: String) = repository.openAppInfo(componentKey)

    override fun requestUninstall(componentKey: String) {
        if (!repository.isUninstallable(componentKey)) return
        val key = ComponentKey.parse(componentKey) ?: return
        val intent = Intent(Intent.ACTION_DELETE, Uri.parse("package:${key.packageName}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        appContext.startActivity(intent)
    }

    // ---- icons -----------------------------------------------------------

    override fun setIconTheme(themeId: String, style: WireStyle) {
        iconCache.setTheme(themeId, style.toRenderStyle())
    }

    override fun getIcon(
        componentKey: String,
        sizePx: Long,
        callback: (Result<ByteArray?>) -> Unit,
    ) {
        // IconCache calls back on an IO thread; Pigeon replies must go out from
        // the main thread.
        iconCache.get(componentKey, sizePx.toInt()) { bytes ->
            main.post { callback(Result.success(bytes)) }
        }
    }

    override fun clearIconCache(callback: (Result<Unit>) -> Unit) {
        iconCache.clear()
        callback(Result.success(Unit))
    }

    // ---- third-party icon packs ------------------------------------------

    /**
     * Installed Nova/ADW-format packs, package name to label.
     *
     * ON [io], NOT THE MAIN THREAD. It is seven `queryIntentActivities` calls
     * plus a label load per result, each of which is binder IPC into the package
     * manager. Individually trivial, collectively a stutter on the screen the
     * user just opened.
     *
     * AN EMPTY MAP IS A VALID ANSWER and is never reported as an error, because
     * "no icon packs installed" is the common case. Worth knowing while
     * debugging: an empty map is ALSO what a missing `<queries>` entry produces
     * on Android 11+, silently. Check the manifest before this method.
     */
    override fun installedIconPacks(callback: (Result<Map<String, String>>) -> Unit) {
        io.execute {
            val packs = runCatching {
                iconCache.installedIconPacks().associate { it.packageName to it.label }
            }.getOrDefault(emptyMap())
            main.post { callback(Result.success(packs)) }
        }
    }

    /**
     * Select a pack, or null for none.
     *
     * ALSO ON [io], and for a stronger reason than the method above: selecting a
     * pack parses `appfilter.xml` out of the pack's APK, which for a large pack
     * is thousands of XML entries. That is a visible freeze on the home screen
     * at the moment the user taps a radio button, which is the worst possible
     * moment for one.
     *
     * The reply is deliberately sent AFTER the parse rather than immediately, so
     * Dart can leave a spinner up and know when the grid is safe to repaint. The
     * bitmaps are still rendered lazily by the cache after that.
     */
    override fun setIconPack(packageName: String?, callback: (Result<Unit>) -> Unit) {
        io.execute {
            runCatching { iconCache.setSystemIconPack(packageName) }
            main.post { callback(Result.success(Unit)) }
        }
    }

    // ---- system ----------------------------------------------------------

    override fun isDefaultLauncher(): Boolean = roles.isDefaultLauncher()

    override fun requestDefaultLauncher() = roles.requestDefaultLauncher()

    override fun openAndroidSettings(action: String) = roles.openSettings(action)

    // ---- wallpaper -------------------------------------------------------

    override fun setWallpaper(
        source: String,
        applyToLock: Boolean,
        callback: (Result<Boolean>) -> Unit,
    ) {
        // Decoding + pushing a full wallpaper takes hundreds of ms. Never on the
        // main thread — this would be a visible freeze on the home screen.
        io.execute {
            val ok = runCatching { wallpaper.setWallpaper(source, applyToLock) }
                .getOrDefault(false)
            main.post { callback(Result.success(ok)) }
        }
    }

    override fun scheduleWallpaperRotation(
        minutes: Long,
        sources: List<String>,
        applyToLock: Boolean,
    ) {
        WallpaperWorker.schedule(appContext, minutes, sources, applyToLock)
    }

    override fun cancelWallpaperRotation() = WallpaperWorker.cancel(appContext)

    // Stash/restore all touch disk — copying a full wallpaper file, or decoding
    // and pushing one — so all three go through the IO executor. Same rule as
    // setWallpaper: never the main thread on a home screen.

    override fun stashWallpaper(callback: (Result<Boolean>) -> Unit) {
        io.execute {
            val ok = runCatching { wallpaper.stashWallpaper() }.getOrDefault(false)
            main.post { callback(Result.success(ok)) }
        }
    }

    override fun hasStashedWallpaper(callback: (Result<Boolean>) -> Unit) {
        io.execute {
            val ok =
                runCatching { wallpaper.hasStashedWallpaper() }.getOrDefault(false)
            main.post { callback(Result.success(ok)) }
        }
    }

    override fun restoreWallpaper(callback: (Result<Boolean>) -> Unit) {
        io.execute {
            val ok = runCatching { wallpaper.restoreWallpaper() }.getOrDefault(false)
            main.post { callback(Result.success(ok)) }
        }
    }

    // ---- gestures --------------------------------------------------------

    override fun isGestureServiceEnabled(): Boolean =
        GestureAccessibilityService.instance != null

    override fun openAccessibilitySettings() =
        roles.openSettings(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)

    override fun performGlobalAction(action: String): Boolean {
        // Service off -> false, not an exception. The Dart side shows the opt-in
        // card; it does not get a crash.
        val service = GestureAccessibilityService.instance ?: return false
        return service.perform(action)
    }

    // ---- device stats (PHASE D1) -----------------------------------------
    //
    // Both go through the SAME single-threaded `io` executor the wallpaper uses,
    // and that is deliberate rather than incidental: a snapshot touches a file
    // read and a StatFs, and the one thread this class must never occupy is the
    // one drawing the home screen. Serialising them behind one executor also
    // means two desklets mounting at once cannot double-probe.

    override fun getStatCapabilities(callback: (Result<StatCapabilities>) -> Unit) {
        io.execute {
            val caps = runCatching { stats.capabilities() }
            main.post { callback(caps) }
        }
    }

    override fun readStats(callback: (Result<DeviceStats>) -> Unit) {
        io.execute {
            val snapshot = runCatching { stats.read() }
            main.post { callback(snapshot) }
        }
    }

    // ---- app widgets (enumeration only; hosting is a later slice) ---------
    //
    // getInstalledProviders() needs neither a running AppWidgetHost nor the
    // BIND_APPWIDGET permission — enumerating providers and hosting one live are
    // separate Android capabilities, and only the second needs the host. Both
    // calls run on the SAME `io` executor as the app list and the stats, for the
    // same reason: resolving app labels walks PackageManager cold, and decoding a
    // preview bitmap is disk + draw, and neither may touch the thread painting
    // the home screen.

    override fun getInstalledWidgetProviders(
        callback: (Result<List<WidgetProviderInfo>>) -> Unit,
    ) {
        io.execute {
            val result = runCatching {
                val awm =
                    appContext.getSystemService(Context.APPWIDGET_SERVICE) as AppWidgetManager
                val pm = appContext.packageManager
                val density = appContext.resources.displayMetrics.density
                fun toDp(px: Int): Long = (px / density).toLong()

                awm.installedProviders.mapNotNull { info ->
                    // category bit 1 == WIDGET_CATEGORY_HOME_SCREEN. A keyguard-
                    // only or searchbox provider is not a desktop widget, and
                    // offering it would place something that will not draw here.
                    if (info.widgetCategory and 1 == 0) return@mapNotNull null

                    val pkg = info.provider.packageName
                    val appLabel = runCatching {
                        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
                    }.getOrDefault(pkg)
                    val label =
                        info.loadLabel(pm)?.toString() ?: info.provider.shortClassName

                    WidgetProviderInfo(
                        providerKey = info.provider.flattenToString(),
                        packageName = pkg,
                        appLabel = appLabel,
                        label = label,
                        minWidthDp = toDp(info.minWidth),
                        minHeightDp = toDp(info.minHeight),
                        minResizeWidthDp = toDp(info.minResizeWidth),
                        minResizeHeightDp = toDp(info.minResizeHeight),
                        targetCellWidth =
                            if (Build.VERSION.SDK_INT >= 31) info.targetCellWidth.toLong() else 0L,
                        targetCellHeight =
                            if (Build.VERSION.SDK_INT >= 31) info.targetCellHeight.toLong() else 0L,
                        resizeMode = info.resizeMode.toLong(),
                        category = info.widgetCategory.toLong(),
                        configurable = info.configure != null,
                        hasPreviewImage = info.previewImage != 0,
                    )
                }.sortedBy { it.appLabel.lowercase() }
            }
            main.post { callback(result) }
        }
    }

    override fun getWidgetPreview(
        providerKey: String,
        widthPx: Long,
        heightPx: Long,
        callback: (Result<ByteArray?>) -> Unit,
    ) {
        io.execute {
            val bytes: ByteArray? = runCatching {
                val awm =
                    appContext.getSystemService(Context.APPWIDGET_SERVICE) as AppWidgetManager
                val info = awm.installedProviders
                    .firstOrNull { it.provider.flattenToString() == providerKey }
                // Preview image first, the app's own widget icon as the honest
                // fallback. Null only when the provider vanished mid-scroll.
                val drawable = info?.loadPreviewImage(appContext, 0)
                    ?: info?.loadIcon(appContext, 0)
                    ?: return@runCatching null

                val w = widthPx.toInt().coerceAtLeast(1)
                val h = heightPx.toInt().coerceAtLeast(1)
                val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bmp)
                drawable.setBounds(0, 0, w, h)
                drawable.draw(canvas)
                ByteArrayOutputStream().use { bos ->
                    bmp.compress(Bitmap.CompressFormat.PNG, 100, bos)
                    bos.toByteArray()
                }
            }.getOrNull()
            main.post { callback(Result.success(bytes)) }
        }
    }

    // ---- app widgets (hosting) -------------------------------------------
    //
    // These delegate to the shared WidgetHostController, which owns the
    // AppWidgetHost and the Activity-result flow. addWidget can pop the system
    // bind dialog and a provider's config Activity, so its callback is resolved
    // by the controller on the main thread once those return — Pigeon is called
    // on the main thread, so no re-post is needed.

    override fun addWidget(providerKey: String, callback: (Result<Long?>) -> Unit) {
        widgetHost.addWidget(providerKey) { id ->
            callback(Result.success(id?.toLong()))
        }
    }

    override fun removeWidget(widgetId: Long) {
        widgetHost.removeWidget(widgetId.toInt())
    }

    override fun updateWidgetSize(
        widgetId: Long,
        minWidthDp: Long,
        minHeightDp: Long,
        maxWidthDp: Long,
        maxHeightDp: Long,
    ) {
        widgetHost.updateSize(
            widgetId.toInt(),
            minWidthDp.toInt(),
            minHeightDp.toInt(),
            maxWidthDp.toInt(),
            maxHeightDp.toInt(),
        )
    }

    private fun WireStyle.toRenderStyle(): RenderStyle = RenderStyle(
        treatment = when (treatment) {
            WireTreatment.CIRCLE -> RenderTreatment.CIRCLE
            WireTreatment.SQUIRCLE -> RenderTreatment.SQUIRCLE
            WireTreatment.ROUNDED_SQUARE -> RenderTreatment.ROUNDED_SQUARE
            WireTreatment.SQUARE -> RenderTreatment.SQUARE
            WireTreatment.TEARDROP -> RenderTreatment.TEARDROP
            WireTreatment.ORIGINAL -> RenderTreatment.ORIGINAL
        },
        cornerRadius = cornerRadius.toFloat(),
        foregroundScale = foregroundScale.toFloat(),
        backgroundColor = backgroundColor?.toInt(),
        monochromeTint = monochromeTint?.toInt(),
        heroPack = heroPack,
        backgroundGradientEnd = backgroundGradientEnd?.toInt(),
        // Wire side is nullable so an existing theme.json parses unchanged; the
        // renderer wants a concrete angle. 45 = the top-left-to-bottom-right
        // diagonal, and it is only read when an end colour is set.
        gradientAngle = gradientAngle?.toFloat() ?: 45f,
        brandPack = brandPack,
        brandTreatment = BrandTreatment.parse(brandTreatment),
    )
}
