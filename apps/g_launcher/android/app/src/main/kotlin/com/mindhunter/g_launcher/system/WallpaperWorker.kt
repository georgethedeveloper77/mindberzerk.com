package com.mindhunter.g_launcher.system

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * Rotates the wallpaper, desktop-style.
 *
 * WorkManager's minimum periodic interval is FIFTEEN MINUTES, hard-enforced by
 * the OS. Ask for five and Android silently gives you fifteen — so we clamp
 * here and the UI must not offer anything shorter. Quietly lying to the user
 * about a setting is worse than not having it.
 */
class WallpaperWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    companion object {
        private const val WORK_NAME = "g_launcher_wallpaper_rotation"
        private const val PREFS = "wallpaper_rotation"
        private const val KEY_SOURCES = "sources"
        private const val KEY_INDEX = "index"
        private const val KEY_LOCK = "lock"

        const val MIN_INTERVAL_MINUTES = 15L

        fun schedule(
            context: Context,
            minutes: Long,
            sources: List<String>,
            applyToLock: Boolean,
        ) {
            if (sources.isEmpty()) {
                cancel(context)
                return
            }

            // The list can be long and WorkManager's inputData is capped at 10KB,
            // so it lives in our own prefs and the worker reads it each run. That
            // also means editing the list does not require rescheduling the job.
            context.applicationContext
                .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_SOURCES, sources.joinToString("\n"))
                .putBoolean(KEY_LOCK, applyToLock)
                .apply()

            val interval = maxOf(minutes, MIN_INTERVAL_MINUTES)

            val request = PeriodicWorkRequestBuilder<WallpaperWorker>(
                interval, TimeUnit.MINUTES,
            ).setConstraints(
                // Decoding a wallpaper is heavy. Not while the battery is dying.
                Constraints.Builder().setRequiresBatteryNotLow(true).build()
            ).build()

            WorkManager.getInstance(context.applicationContext)
                .enqueueUniquePeriodicWork(
                    WORK_NAME,
                    ExistingPeriodicWorkPolicy.UPDATE,
                    request,
                )
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context.applicationContext)
                .cancelUniqueWork(WORK_NAME)
        }
    }

    override fun doWork(): Result {
        val prefs = applicationContext
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        val sources = prefs.getString(KEY_SOURCES, "")
            ?.split("\n")
            ?.filter { it.isNotBlank() }
            ?: return Result.success()

        if (sources.isEmpty()) return Result.success()

        // Cycle in order rather than at random: shuffle can repeat the same
        // wallpaper twice running, which reads as "the rotation is broken".
        val index = prefs.getInt(KEY_INDEX, -1)
        val next = (index + 1) % sources.size

        val ok = WallpaperController(applicationContext)
            .setWallpaper(sources[next], prefs.getBoolean(KEY_LOCK, false))

        // Advance regardless: a source that fails every time (deleted photo)
        // must not wedge the rotation on it forever.
        prefs.edit().putInt(KEY_INDEX, next).apply()

        return if (ok) Result.success() else Result.retry()
    }
}
