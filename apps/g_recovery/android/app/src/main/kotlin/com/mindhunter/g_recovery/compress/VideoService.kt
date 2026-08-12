package com.mindhunter.g_recovery.compress

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.mindhunter.g_recovery.MainActivity

/**
 * KEEPING A LONG ENCODE ALIVE.
 *
 * ─── WHY THE SCAN SERVICE CANNOT BE REUSED ───────────────────────────────────
 *
 * ScanService is declared shortService, which the system caps at roughly three
 * minutes and then kills. A six minute 4K clip takes longer than that to
 * re-encode on a good phone, so reusing it would produce a job that dies partway
 * through on exactly the large files this feature exists for, leaving a half
 * written file behind each time.
 *
 * mediaProcessing is the type Android 14 added for this. dataSync is the
 * fallback below it. Both are declared in the manifest and one is chosen here,
 * because passing a type that is not declared throws at startForeground rather
 * than degrading.
 *
 * ─── IT HOLDS NO ENCODER ─────────────────────────────────────────────────────
 *
 * This class does one thing: stay alive and show a notification. The encoding
 * lives elsewhere and reports into it. That split is deliberate, because a
 * service that also owned the pipeline would have to be torn down and rebuilt to
 * test either half.
 *
 * ─── AND IT IS HONEST ABOUT BEING KILLABLE ───────────────────────────────────
 *
 * START_NOT_STICKY, not START_STICKY. A restarted service would come back with
 * no idea which file it was on and no work queued. Silently doing nothing under
 * a notification that says it is working is worse than stopping.
 */
class VideoService : android.app.Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                // The user asked. Cancellation is the encoder's business; this
                // only stops holding the process up.
                stopSelf()
                return START_NOT_STICKY
            }
        }

        val done = intent?.getIntExtra(EXTRA_DONE, 0) ?: 0
        val total = intent?.getIntExtra(EXTRA_TOTAL, 0) ?: 0
        val name = intent?.getStringExtra(EXTRA_NAME)

        startForeground(
            NOTIFICATION_ID,
            build(done, total, name),
            typeFor(),
        )
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    /**
     * The strongest type this device supports.
     *
     * mediaProcessing carries a daily budget on Android 15 rather than a per
     * run timer, which is the right shape for something a person triggers a few
     * times a month. dataSync below API 34 is the closest equivalent and has no
     * short timer either.
     */
    private fun typeFor(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROCESSING
        } else {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        }

    private fun build(done: Int, total: Int, name: String?): Notification {
        channel()

        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, VideoService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        return NotificationCompat.Builder(this, CHANNEL)
            .setContentTitle(
                if (total > 0) "Compressing video, $done of $total"
                else "Compressing video",
            )
            // The file name rather than a percentage. A percentage of an encode
            // moves in a way nobody can predict, and the name is what tells
            // someone whether the clip they care about has been reached.
            .setContentText(name)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .addAction(0, "Stop", stop)
            .apply {
                if (total > 0) setProgress(total, done, false)
            }
            .build()
    }

    private fun channel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL) != null) return

        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL,
                "Video compression",
                // LOW, so it never makes a sound. This runs because the user
                // asked it to and is already watching; a chime for their own
                // instruction is noise.
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shows progress while video is being re-encoded."
                setShowBadge(false)
            },
        )
    }

    companion object {
        private const val CHANNEL = "video_compression"
        private const val NOTIFICATION_ID = 4711

        // A different id, so the completion notice does not replace an ongoing
        // one that is about to be cancelled and take itself down with it.
        private const val DONE_ID = 4712

        private const val ACTION_STOP = "com.mindhunter.g_recovery.STOP_VIDEO"
        private const val EXTRA_DONE = "done"
        private const val EXTRA_TOTAL = "total"
        private const val EXTRA_NAME = "name"

        /**
         * Starts the service, or updates the notification if it is running.
         *
         * The same call for both, because startForeground on an already
         * foregrounded service just replaces the notification. A separate update
         * path would mean two ways of getting the count wrong.
         */
        fun show(context: Context, done: Int, total: Int, name: String?) {
            val intent = Intent(context, VideoService::class.java)
                .putExtra(EXTRA_DONE, done)
                .putExtra(EXTRA_TOTAL, total)
                .putExtra(EXTRA_NAME, name)

            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            }
        }

        fun hide(context: Context) {
            runCatching {
                context.stopService(Intent(context, VideoService::class.java))
            }
        }

        /**
         * Says it finished, and leaves that on screen.
         *
         * ─── THE WHOLE POINT OF LETTING IT RUN IN THE BACKGROUND ─────────────
         *
         * A job the user walked away from ends with them not in the app. Simply
         * removing the ongoing notification means twenty minutes of encoding
         * finishes with a notification vanishing and nothing said, which is
         * indistinguishable from the job having been killed.
         *
         * Posted directly rather than through the service, because the service
         * is stopping and a foreground notification goes with it. This one is
         * dismissible and does not hold the process up.
         */
        fun finished(context: Context, files: Int, savedBytes: Long) {
            if (files <= 0) {
                hide(context)
                return
            }

            runCatching {
                val manager = context.getSystemService(NotificationManager::class.java)

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                    manager.getNotificationChannel(CHANNEL) == null
                ) {
                    manager.createNotificationChannel(
                        NotificationChannel(
                            CHANNEL,
                            "Video compression",
                            NotificationManager.IMPORTANCE_LOW,
                        ),
                    )
                }

                val open = PendingIntent.getActivity(
                    context,
                    0,
                    Intent(context, MainActivity::class.java),
                    PendingIntent.FLAG_IMMUTABLE or
                        PendingIntent.FLAG_UPDATE_CURRENT,
                )

                manager.notify(
                    DONE_ID,
                    NotificationCompat.Builder(context, CHANNEL)
                        .setContentTitle(
                            if (files == 1) "1 video compressed"
                            else "$files videos compressed",
                        )
                        .setContentText(
                            "${readable(savedBytes)} freed. The originals are " +
                                "in the trash for thirty days.",
                        )
                        .setSmallIcon(android.R.drawable.stat_sys_download_done)
                        .setAutoCancel(true)
                        .setOngoing(false)
                        .setContentIntent(open)
                        .build(),
                )
            }

            hide(context)
        }

        /**
         * Bytes, in the notification.
         *
         * Duplicated from the Dart formatter on purpose rather than passed
         * across the bridge: this line is written at the moment the job ends,
         * which is precisely the moment there may be no Dart left to ask.
         */
        private fun readable(bytes: Long): String {
            if (bytes < 1024) return "$bytes B"
            val units = arrayOf("kB", "MB", "GB", "TB")
            var value = bytes.toDouble() / 1024
            var unit = 0
            while (value >= 1024 && unit < units.size - 1) {
                value /= 1024
                unit++
            }
            return String.format("%.1f %s", value, units[unit])
        }
    }
}
