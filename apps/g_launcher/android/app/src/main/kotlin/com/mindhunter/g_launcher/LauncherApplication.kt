package com.mindhunter.g_launcher

import android.app.Application
import com.mindhunter.g_launcher.apps.LauncherHostApiImpl
import com.mindhunter.g_launcher.cdn.PackHostApiImpl
import com.mindhunter.g_launcher.cdn.PackSyncWorker
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

    private lateinit var hostApi: LauncherHostApiImpl
    private lateinit var packApi: PackHostApiImpl

    override fun onCreate() {
        super.onCreate()

        engine = FlutterEngine(this).apply {
            dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
        }

        val messenger = engine.dartExecutor.binaryMessenger

        hostApi = LauncherHostApiImpl(this, LauncherFlutterApi(messenger))
        LauncherHostApi.setUp(messenger, hostApi)
        hostApi.start()

        // PHASE C — a SECOND host API on the same messenger, deliberately.
        // Pigeon keys handlers by channel name, so two APIs coexist without
        // touching each other; and because pack_api.dart is a separate schema
        // it has its own codec, so nothing here can shift the app-list codec
        // ids that a shipped APK already agrees on.
        packApi = PackHostApiImpl(this, PackFlutterApi(messenger))
        PackHostApi.setUp(messenger, packApi)

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
