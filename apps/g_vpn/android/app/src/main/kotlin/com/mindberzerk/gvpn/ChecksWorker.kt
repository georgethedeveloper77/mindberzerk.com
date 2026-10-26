package com.mindberzerk.gvpn

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull

/**
 * The background checks behind Alerts (new devices on your Wi-Fi, new big
 * breaches). Every few hours, when there is a network and the battery is
 * not low, Android runs this worker; it starts a Flutter engine with no
 * screen at `backgroundMain` in lib/background/background_checks.dart,
 * which reads the user's alert settings, checks, notifies, and says done.
 */
class ChecksWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val done = CompletableDeferred<Unit>()
        val engine = withContext(Dispatchers.Main) {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
            // Plugins register themselves on a new engine; the alerts
            // channel is ours, so it is set up here as MainActivity does.
            FlutterEngine(applicationContext).also { e ->
                Alerts.setUp(e.dartExecutor.binaryMessenger, applicationContext)
                MethodChannel(e.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
                    if (call.method == "done") done.complete(Unit)
                    result.success(null)
                }
                e.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(
                        loader.findAppBundlePath(),
                        "package:g_vpn/background/background_checks.dart",
                        "backgroundMain",
                    ),
                )
            }
        }
        // The Dart side gives itself three minutes; this is the backstop.
        withTimeoutOrNull(TimeUnit.MINUTES.toMillis(4)) { done.await() }
        withContext(Dispatchers.Main) { engine.destroy() }
        return Result.success()
    }

    companion object {
        private const val CHANNEL = "com.mindberzerk.gvpn/background"
        private const val WORK = "gvpn_background_checks"

        /** Keeps one periodic run scheduled; calling again changes nothing. */
        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<ChecksWorker>(6, TimeUnit.HOURS)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .setRequiresBatteryNotLow(true)
                        .build(),
                )
                .build()
            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(WORK, ExistingPeriodicWorkPolicy.KEEP, request)
        }
    }
}
