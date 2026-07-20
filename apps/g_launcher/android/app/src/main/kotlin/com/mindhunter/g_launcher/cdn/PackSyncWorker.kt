package com.mindhunter.g_launcher.cdn

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.mindhunter.g_launcher.theme.PackKeys
import com.mindhunter.g_launcher.theme.PackVerifier
import com.mindhunter.g_launcher.theme.ThemeAssetLoader
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * PHASE C2 - keeps installed packs current, in the background, with no UI.
 *
 * The brand pack is the first payload through this pipeline on purpose. It is
 * one JSON file that has to grow forever as new apps appear, it exercises the
 * whole chain (fetch, verify, cache, hot-swap without a restart), and if it
 * fails the worst outcome is a few apps keep their generated icons for another
 * day. A theme pack, by contrast, can take the home screen down. Themes second.
 *
 * WHY A WORKER AND NOT A COROUTINE AT APP START. A launcher process is killed
 * constantly - it is the thing the OS reclaims first when a game wants memory -
 * so anything started in `onCreate` gets roughly as long as the user stays on
 * the home screen, which on a phone is seconds. WorkManager owns the schedule,
 * survives the process, and honours Doze and the metered-network constraint
 * that keeps this off a user's data bundle.
 *
 * ONLY UPDATES WHAT IS ALREADY INSTALLED. It never installs something new: a
 * background job that silently adds packs is a background job that silently
 * uses someone's storage. New installs are always a user action, in C2b's
 * storefront.
 */
class PackSyncWorker(context: Context, params: WorkerParameters) : Worker(context, params) {

    override fun doWork(): Result {
        val packsRoot = File(applicationContext.filesDir, "packs")
        packsRoot.mkdirs()

        val verifier = PackVerifier(
            acceptedKeys = PackKeys.accepted,
            appVersionCode = appVersionCode(),
        )
        val loader = ThemeAssetLoader(packsRoot, verifier)
        val downloader = PackDownloader(
            client = CdnClient(CdnConfig.baseUrl(packsRoot)),
            loader = loader,
            packsRoot = packsRoot,
            acceptedKeys = PackKeys.accepted,
            verifier = verifier,
        )

        val index = when (val r = downloader.refreshIndex()) {
            is IndexResult.Updated -> r.index
            is IndexResult.Unchanged -> r.index
            is IndexResult.Stale -> r.kept
            // A transport failure is the normal case on a phone: retry with
            // WorkManager's backoff. A REJECTED index is not - it means the
            // signature failed, and retrying a bad signature just burns battery
            // producing the same answer.
            is IndexResult.Failed -> return Result.retry()
            is IndexResult.Rejected -> return Result.failure()
        }

        var installedAnything = false
        for (packId in loader.installedPackIds()) {
            when (val r = downloader.syncPack(packId, index)) {
                is SyncResult.Installed -> {
                    installedAnything = true
                    val type = index.pack(packId)?.packType ?: "unknown"
                    // The hot-swap. Without this the new pack sits on disk,
                    // fully verified, doing nothing until the process restarts.
                    PackChangeNotifier.notifyInstalled(type, packId)
                }
                // Everything else is either normal (UpToDate, NotOffered) or
                // not fixable by retrying the whole job right now. One pack
                // failing must not stop the others syncing.
                else -> Unit
            }
        }

        return if (installedAnything) Result.success() else Result.success()
    }

    /**
     * Must match `_appVersionCode` in theme_engine.dart and the versionCode in
     * the manifest. Read from PackageManager rather than hardcoded so a release
     * bump cannot leave this behind - which would silently refuse every pack
     * that targets the new build.
     */
    private fun appVersionCode(): Int = try {
        val pm = applicationContext.packageManager
        val info = pm.getPackageInfo(applicationContext.packageName, 0)
        @Suppress("DEPRECATION")
        info.versionCode
    } catch (_: Exception) {
        0
    }

    companion object {
        private const val WORK_NAME = "g_launcher_pack_sync"

        /**
         * Call once from `LauncherApplication.onCreate`.
         *
         * KEEP is deliberate: REPLACE would reset the interval on every cold
         * start, and a launcher cold-starts many times a day, so the job would
         * effectively never run.
         *
         * Daily, unmetered, not-low-battery. A brand pack that gains icons
         * within 24 hours is well inside what anyone would notice, and a
         * launcher spending someone's data bundle on icon glyphs is not a
         * trade this app gets to make on their behalf.
         */
        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<PackSyncWorker>(1, TimeUnit.DAYS)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.UNMETERED)
                        .setRequiresBatteryNotLow(true)
                        .build(),
                )
                .setInitialDelay(2, TimeUnit.HOURS)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
        }
    }
}
