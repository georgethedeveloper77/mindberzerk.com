package com.mindhunter.g_launcher

import android.app.Application
import com.mindhunter.g_launcher.apps.LauncherHostApiImpl
import com.mindhunter.g_launcher.cdn.PackHostApiImpl
import com.mindhunter.g_launcher.cdn.PackSyncWorker
import com.mindhunter.g_launcher.pack.PackFlutterApi
import com.mindhunter.g_launcher.pack.PackHostApi
import com.mindhunter.g_launcher.system.BadgeBridge
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

        hostApi = LauncherHostApiImpl(this, LauncherFlutterApi(messenger), widgetHost)
        LauncherHostApi.setUp(messenger, hostApi)
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

    override fun onTerminate() {
        // Rarely called in practice; correctness, not a load-bearing path.
        hostApi.stop()
        packApi.shutdown()
        super.onTerminate()
    }
}
