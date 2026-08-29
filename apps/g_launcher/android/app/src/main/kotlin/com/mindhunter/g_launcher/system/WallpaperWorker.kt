package com.mindhunter.g_launcher.system

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
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
        private const val KEY_FIT = "fit"
        private const val KEY_COLOR = "letterboxColor"
        private const val KEY_FRAMING = "framing"

        const val MIN_INTERVAL_MINUTES = 15L

        fun schedule(
            context: Context,
            minutes: Long,
            sources: List<String>,
            applyToLock: Boolean,
            fit: String = "cover",
            letterboxColor: Long = 0xFF000000L,
            framingJson: String = "",
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
                // Stored beside the list for the same reason the list lives
                // here: every tick must render the way a manual apply does,
                // without a reschedule when only the fit changed.
                .putString(KEY_FIT, fit)
                .putLong(KEY_COLOR, letterboxColor)
                // Stored verbatim and parsed per tick rather than expanded into
                // keys here. Expanding it would mean one prefs key per wallpaper
                // per field, and the pool changes far more often than the
                // schedule does: a rotation whose list is edited must not have
                // to clean up orphaned keys from wallpapers that left the pool.
                .putString(KEY_FRAMING, framingJson)
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

        val source = sources[next]
        val framing = framingFor(prefs.getString(KEY_FRAMING, "") ?: "", source)

        val ok = WallpaperController(applicationContext)
            .setWallpaper(
                source,
                prefs.getBoolean(KEY_LOCK, false),
                // The per-wallpaper fit wins, and the schedule's fit is the
                // fallback. A rotation that rendered differently from a manual
                // apply of the same image would look like the rotation was
                // picking a different picture.
                framing?.optString("fit").takeUnless { it.isNullOrBlank() }
                    ?: prefs.getString(KEY_FIT, "cover") ?: "cover",
                prefs.getLong(KEY_COLOR, 0xFF000000L),
                (framing?.optDouble("focalX", 0.5) ?: 0.5).toFloat(),
                (framing?.optDouble("focalY", 0.5) ?: 0.5).toFloat(),
                (framing?.optDouble("zoom", 1.0) ?: 1.0).toFloat(),
            )

        // Advance regardless: a source that fails every time (deleted photo)
        // must not wedge the rotation on it forever.
        prefs.edit().putInt(KEY_INDEX, next).apply()

        return if (ok) Result.success() else Result.retry()
    }

    /**
     * This source's framing block, or null when it has none.
     *
     * SWALLOWS EVERYTHING. A malformed blob here must not wedge the rotation:
     * the worker's whole contract is that it keeps cycling even when one entry
     * is broken, which is why [doWork] advances the index whether or not the
     * apply succeeded. Returning null falls back to the schedule's own fit and
     * a centred focal point, which is what every rotation did before framing
     * existed.
     */
    private fun framingFor(json: String, source: String): JSONObject? {
        if (json.isBlank()) return null
        return runCatching {
            JSONObject(json).optJSONObject(source)
        }.getOrNull()
    }
}
