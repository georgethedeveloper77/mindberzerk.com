package com.mindhunter.g_launcher

import android.app.Application
import com.mindhunter.g_launcher.apps.LauncherHostApiImpl
import com.mindhunter.g_launcher.cdn.PackHostApiImpl
import com.mindhunter.g_launcher.cdn.PackSyncWorker
import com.mindhunter.g_launcher.pack.PackFlutterApi
import com.mindhunter.g_launcher.pack.PackHostApi
import com.mindhunter.g_launcher.system.BadgeBridge
import com.mindhunter.g_launcher.system.ExitInfoBridge
import com.mindhunter.g_launcher.system.ForegroundTracker
import com.mindhunter.g_launcher.system.MemoryTrimmer
import com.mindhunter.g_launcher.widgets.WidgetHostController
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * The engine is warmed HERE, at process start — not in the Activity.
 *
 * Why this matters more for a launcher than for any other app: on a home press
 * the system resumes LauncherActivity, and whatever hasn't already been paid for
 * gets paid for in front of the user. If the FlutterEngine is created in the
 * Activity, every cold home press eats engine init + Dart isolate spin-up +
 * first frame. That is the difference between a launcher people keep and one
 * they uninstall in a week.
 *
 * The app list is primed here too (LauncherHostApiImpl.start()), so by the time
 * Dart asks for it, it is already sitting in memory.
 *
 * PHASE C adds two things and DELIBERATELY OMITS A THIRD.
 *
 * Added: a second host API for the store, and the periodic pack sync.
 *
 * Omitted: the IconCache invalidation listener. IconCache registers itself with
 * PackChangeNotifier in its own init block, because the cache is the thing that
 * knows it must invalidate, and a registration line in this file is a line a
 * later refactor deletes with nothing failing to notice.
 *
 * ─── AND THE COUNTERWEIGHT THE WARM ENGINE ALWAYS NEEDED ────────────────────
 *
 * Everything above buys a fast home press by keeping the engine, the isolate
 * and the whole widget tree resident forever. That half was right. The half
 * that was missing is that nothing ever gave any of it back: no `onTrimMemory`
 * override existed anywhere in this app, so Android asked this process to
 * release memory, repeatedly, into a method nobody had written.
 *
 * `dumpsys activity exit-info` on the test device: six `reason=3 (LOW_MEMORY)`
 * exits in fourteen hours, at RSS up to 778MB, plus one
 * `reason=9 (EXCESSIVE_RESOURCE_USAGE)` for burning 4.7% of a core over five
 * minutes with `state=empty`. A killed launcher means the next home press is a
 * cold start, and a cold start behind a stalled SystemUI window is what prints
 * "isn't optimized for the latest version of Android" on One UI.
 *
 * So this file now owns three small things that only the Application can own:
 * whether any Activity is started, what to drop when memory is asked for, and
 * why the previous process died.
 */
class LauncherApplication : Application() {

    companion object {
        const val ENGINE_ID = "g_launcher_engine"
    }

    lateinit var engine: FlutterEngine
        private set

    /// The AppWidget host, exposed so LauncherActivity can attach itself for the
    /// bind/config Activity results and drive startListening/stopListening.
    lateinit var widgetHost: WidgetHostController
        private set

    /// The app-list host API, exposed for the same reason [widgetHost] is:
    /// uninstall needs an Activity to start the system's confirmation on the
    /// launcher's own task, and this object is owned by the Application. See
    /// LauncherHostApiImpl.requestUninstall.
    lateinit var hostApi: LauncherHostApiImpl
        private set

    private lateinit var packApi: PackHostApiImpl

    /**
     * Constructed as a FIELD rather than a local in onCreate, because
     * [onTrimMemory] is a callback on this object and needs to reach it long
     * afterwards.
     *
     * `::engine` is passed as a lambda and not as a value: `engine` is `lateinit`
     * and this is built before it is assigned, so reading it eagerly here would
     * throw on the line that constructs it. It is also genuinely nullable in
     * practice, since a trim can arrive during onCreate on a device already
     * under pressure, which is exactly the device this exists for.
     */
    private val memory = MemoryTrimmer(
        engine = { if (::engine.isInitialized) engine else null },
        trimIcons = { full ->
            if (::hostApi.isInitialized) hostApi.trimMemory(full)
        },
    )

    /**
     * Started-activity count. Read by the app-change watcher to decide whether
     * a package event is worth a 250-app enumeration.
     *
     * Installed AFTER hostApi is built, further down, because its callback
     * reaches into it.
     */
    private val foreground = ForegroundTracker(
        onEnterForeground = { if (::hostApi.isInitialized) hostApi.onForeground() },
    )

    override fun onCreate() {
        super.onCreate()

        engine = FlutterEngine(this).apply {
            dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
        }

        val messenger = engine.dartExecutor.binaryMessenger

        // The AppWidget host, created here because it outlives any Activity.
        // LauncherActivity attaches for the Activity-result flow and the
        // listening lifecycle; the impl and the PlatformView factory both talk
        // to this one instance.
        widgetHost = WidgetHostController(this)

        hostApi = LauncherHostApiImpl(
            this,
            LauncherFlutterApi(messenger),
            widgetHost,
            isForeground = { foreground.isForeground },
        )
        LauncherHostApi.setUp(messenger, hostApi)

        // REGISTERED BEFORE start(), so the very first onActivityStarted cannot
        // land before the tracker is listening. On a home press that callback
        // is milliseconds away from this line.
        foreground.install(this)

        // The initial prime is DELIBERATELY NOT GATED on foreground, unlike
        // every later refresh. The process is usually being created because the
        // user just pressed home, and the whole reason the app list is primed
        // here is so it is already in memory when Dart asks. Gating it would
        // trade the exact latency this file exists to buy.
        hostApi.start()

        // NO PLATFORMVIEW FACTORY ANY MORE, AND THAT IS THE POINT.
        //
        // A hosted AppWidgetHostView used to be embedded through
        // `AndroidView(viewType: 'g_launcher/widget')`, which meant hybrid
        // composition. On this device that is broken rather than merely
        // expensive: Impeller on Vulkan asks Adreno's gralloc for pixel formats
        // it has no mapping for, the overlay buffers hybrid composition needs
        // are never allocated, and Flutter's layering collapses. The black quad,
        // the doubled clock desklet, desklets bleeding through the drawer, and
        // 302MB of GL memory were all that one failure.
        //
        // Widgets live in `WidgetStage` now, a plain ViewGroup behind
        // FlutterView, attached by LauncherActivity because a stage belongs to a
        // window. With no factory registered, nothing in this app can create a
        // PlatformView, so hybrid composition never turns on at all.

        // PHASE C — a SECOND host API on the same messenger, deliberately.
        // Pigeon keys handlers by channel name, so two APIs coexist without
        // touching each other; and because pack_api.dart is a separate schema
        // it has its own codec, so nothing here can shift the app-list codec
        // ids that a shipped APK already agrees on.
        packApi = PackHostApiImpl(this, PackFlutterApi(messenger))
        PackHostApi.setUp(messenger, packApi)

        // Notification badges. A plain MethodChannel rather than a third
        // Pigeon API: see the note in NotificationBadges.kt for why a badge
        // feature must not go anywhere near the launcher schema's codec.
        //
        // Registered here, on the warmed engine, because the LISTENER SERVICE
        // is constructed by the system on its own schedule and may well have
        // connected before this line runs. BadgeBridge caches what it has, so
        // setting the channel up late still delivers the current counts rather
        // than an empty screen until the next notification arrives.
        //
        // Costs nothing when the user has not granted access: the service is
        // never bound, nothing publishes, and the channel sits idle.
        BadgeBridge.setUp(this, messenger)

        // WHY THE PREVIOUS PROCESS DIED. A plain MethodChannel for the same
        // reason BadgeBridge is one: a diagnostic must not be able to renumber
        // the codec ids of the app it is diagnosing.
        //
        // Registered here rather than lazily, because Dart calls `drain`
        // immediately after Crashlytics comes up and a channel registered later
        // would answer MissingPluginException to the one call that matters.
        ExitInfoBridge.setUp(this, messenger)

        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)

        // PHASE C — enqueue, do not run. This returns immediately; WorkManager
        // owns the schedule from here and will not fire for hours, on unmetered
        // power. Nothing about a home press waits on it.
        //
        // Safe on every cold start: the policy is KEEP, so repeated calls do
        // not reset the interval. REPLACE would, and a launcher cold-starts
        // many times a day, so the job would effectively never run.
        PackSyncWorker.schedule(this)
    }

    /**
     * The level is NOT ordered by severity. See [MemoryTrimmer.onTrim]; the
     * dispatch lives there rather than here so this file stays a wiring file.
     */
    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        memory.onTrim(level)
    }

    /**
     * Deprecated on ComponentCallbacks since API 34 and still delivered on
     * every device this launcher targets, which is Infinix, Tecno and Redmi
     * well below that. Kept for exactly those devices, which are also the ones
     * with the least memory to spare.
     */
    @Deprecated("Superseded by onTrimMemory on API 34+, still delivered below it.")
    override fun onLowMemory() {
        super.onLowMemory()
        memory.onLow()
    }

    override fun onTerminate() {
        // Rarely called in practice; correctness, not a load-bearing path.
        hostApi.stop()
        packApi.shutdown()
        super.onTerminate()
    }
}
