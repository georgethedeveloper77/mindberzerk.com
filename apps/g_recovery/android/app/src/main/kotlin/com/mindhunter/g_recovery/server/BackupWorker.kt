package com.mindhunter.g_recovery.server

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * THE NIGHTLY RUN.
 *
 * ─── PERIODIC, NOT AN ALARM AT 2AM ───────────────────────────────────────────
 *
 * A phone asked to do network work at an exact time will do it for a while and
 * then stop: Doze defers exact alarms, and OEM battery managers on Samsung,
 * Xiaomi and Transsion kill apps that ask for them repeatedly. A periodic
 * request says "about once a day, when the constraints are met", which the
 * system will actually honour.
 *
 * The cost is that "every night" is a description rather than a promise, and
 * the UI says "about once a day" rather than naming an hour it cannot keep.
 *
 * ─── CONSTRAINTS COME FROM THE USER'S OWN SETTINGS ───────────────────────────
 *
 * Wi-Fi only and while charging are toggles on the server page. Passing them to
 * WorkManager rather than checking them inside the worker means the system does
 * not wake the app at all until they hold, instead of waking it to discover it
 * should go back to sleep.
 */
internal class BackupWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    override fun doWork(): Result {
        val settings = applicationContext.getSharedPreferences(
            "server_settings",
            Context.MODE_PRIVATE,
        )
        if (settings.getString("host", null) == null) {
            // The server was forgotten between the job being queued and running.
            // Nothing to do and nothing wrong.
            return Result.success()
        }
        if (!settings.getBoolean("scheduled", false)) {
            return Result.success()
        }

        val credentials = Credentials(applicationContext)
        val id = settings.getString("id", "server") ?: "server"
        val password = credentials.password(id).orEmpty()
        if (password.isEmpty()) {
            // A keystore invalidation. Retrying nightly forever would drain the
            // battery for a password only the user can restore, so this fails
            // and waits to be asked again.
            return Result.failure()
        }

        val config = ServerConfig(
            id = id,
            protocol = settings.getString("protocol", "smb") ?: "smb",
            label = settings.getString("label", "") ?: "",
            host = settings.getString("host", "") ?: "",
            // 445 is SMB's port and only a fallback for a record that
            // predates the field. Every WebDAV server writes its own, 443 or
            // whatever the user's reverse proxy listens on.
            port = settings.getLong("port", 445L),
            share = settings.getString("share", null),
            username = settings.getString("username", "") ?: "",
            remotePath = settings.getString("remotePath", "/GRecovery")
                ?: "/GRecovery",
            encrypt = settings.getBoolean("encrypt", false),
            wifiOnly = settings.getBoolean("wifiOnly", true),
            whileCharging = settings.getBoolean("whileCharging", true),
            scheduled = true,
            // Read here too, and this is not duplication for its own sake.
            //
            // This worker rebuilds the config from preferences rather than
            // being handed one, because it wakes hours after anything was on
            // screen. Forgetting a field here does not fail to compile: it
            // produces a WebDAV server with no DAV root, whose every nightly
            // upload 404s, silently, for as long as nobody looks.
            secure = if (settings.contains("secure")) {
                settings.getBoolean("secure", true)
            } else {
                null
            },
            basePath = settings.getString("basePath", null),
            certPin = settings.getString("certPin", null),
        )

        return try {
            TransferEngine(applicationContext).run(
                config,
                password,
                AtomicBoolean(false),
            )
            Result.success()
        } catch (_: Throwable) {
            // RETRY, not failure. The commonest reason a backup fails at 3am is
            // that the laptop is off or the phone left the house, and both are
            // fixed by trying again rather than by giving up until the user
            // notices.
            Result.retry()
        }
    }

    companion object {
        private const val NAME = "g_recovery_backup"

        fun schedule(context: Context, wifiOnly: Boolean, charging: Boolean) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(
                    if (wifiOnly) NetworkType.UNMETERED else NetworkType.CONNECTED,
                )
                .setRequiresCharging(charging)
                // Not when storage is critically low. Writing a log or a temp
                // file on a full phone is how a backup turns into a crash.
                .setRequiresStorageNotLow(true)
                .build()

            val request = PeriodicWorkRequestBuilder<BackupWorker>(
                1,
                TimeUnit.DAYS,
            )
                .setConstraints(constraints)
                // A six hour window, so the system can batch this with whatever
                // else it was going to wake for rather than waking twice.
                .setInitialDelay(2, TimeUnit.HOURS)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                NAME,
                // UPDATE, not REPLACE. Replace restarts the period, so someone
                // toggling Wi-Fi only twice would push the next run a day away
                // each time.
                ExistingPeriodicWorkPolicy.UPDATE,
                request,
            )
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(NAME)
        }

        /**
         * When the system currently intends to run it.
         *
         * Null when nothing is enqueued OR when the job is already running,
         * which is honest: a run in progress has no next time yet.
         */
        fun nextRun(context: Context): Long? = runCatching {
            val infos = WorkManager.getInstance(context)
                .getWorkInfosForUniqueWork(NAME)
                .get()

            infos.firstOrNull { it.state == WorkInfo.State.ENQUEUED }
                ?.nextScheduleTimeMillis
                ?.takeIf { it > 0 && it < Long.MAX_VALUE }
        }.getOrNull()
    }
}
