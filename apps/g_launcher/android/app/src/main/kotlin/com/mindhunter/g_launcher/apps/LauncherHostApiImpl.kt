package com.mindhunter.g_launcher.apps

import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.net.Uri
import android.os.Handler
import android.os.Looper
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
