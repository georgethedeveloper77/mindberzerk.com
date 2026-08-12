package com.mindhunter.g_recovery.recovery

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

/**
 * THE WHOLE PHONE, SCANNED, WHETHER OR NOT ANYONE IS WATCHING.
 *
 * ─── WHY A SERVICE AND NOT JUST A THREAD ─────────────────────────────────────
 *
 * Every other scan in this app runs on `RecoveryHostApiImpl`'s worker, which is
 * scoped to a Flutter engine. Swipe the app away and the engine is destroyed,
 * the executor is shut down, and a scan that was forty seconds into a thumbnail
 * cache is simply gone. That is the exact moment a long scan most needs to keep
 * going, because the user did not cancel it, they went to answer a message.
 *
 * ─── shortService, NOT dataSync ──────────────────────────────────────────────
 *
 * `dataSync` on API 34 and up requires FOREGROUND_SERVICE_DATA_SYNC, a Play
 * console declaration, and carries a cumulative six hour daily budget across the
 * whole app. `shortService` needs none of that. It buys roughly three minutes,
 * which comfortably covers a MediaStore query and the trash walks on any phone
 * this app supports, and when it does not, [onTimeout] keeps what was found and
 * says the picture is incomplete rather than pretending otherwise.
 *
 * ─── THE INDEX IS PROCESS WIDE ───────────────────────────────────────────────
 *
 * The service and the bridge are in the same process and share
 * [RecoveryIndex.shared], so results found here are already visible to the UI
 * the moment the user comes back. Nothing is copied and nothing is re-scanned.
 *
 * ─── THE TRASH MAP COMES OFF DISK ────────────────────────────────────────────
 *
 * The map arrives from Dart through `setTrashMap`, which is no use to a service
 * that may start with no engine alive. The bridge caches it to a file on every
 * set, and this reads that file. An absent file means the app has not completed
 * a first run yet, and the scan does the sources that need no map.
 */
class ScanService : Service() {

    private val cancelled = AtomicBoolean(false)
    private var worker: Thread? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_CANCEL) {
            cancelled.set(true)
            stopSelf()
            return START_NOT_STICKY
        }

        // Idempotent. A second start while a scan is in flight is a no-op, not a
        // second pass: two walks over one index double-count everything.
        if (worker?.isAlive == true) return START_NOT_STICKY

        startForegroundCompat(notification("Scanning this phone", null, 0, 0))
        cancelled.set(false)
        state = State(running = true)

        worker = thread(name = "g-recovery-scan") {
            try {
                val engine = ScanEngine(applicationContext, RecoveryIndex.shared)
                engine.run(
                    sourceIds = listOf(
                        SourceIds.MEDIA_TRASH,
                        SourceIds.APP_TRASH,
                        SourceIds.THUMBNAILS,
                    ),
                    trashMap = readTrashMap(),
                    isCancelled = cancelled::get,
                ) { sourceId, scanned, total, done ->
                    onProgress(sourceId, scanned, total, done)
                }
                finish(timedOut = false)
            } catch (error: Throwable) {
                // A scan that throws must still leave the state readable, or the
                // UI waits on a running flag that will never clear.
                finish(timedOut = false, error = error.message)
            }
        }

        return START_NOT_STICKY
    }

    /**
     * API 34 and up, when a short service runs out of time.
     *
     * Everything found so far stays in the shared index. The flag is what stops
     * a truncated pass from being presented as a complete one.
     */
    override fun onTimeout(startId: Int) {
        cancelled.set(true)
        finish(timedOut = true)
    }

    override fun onDestroy() {
        cancelled.set(true)
        super.onDestroy()
    }

    private fun onProgress(sourceId: String, scanned: Int, total: Int, done: Boolean) {
        val found = RecoveryIndex.shared.totalItems()
        state = State(
            running = true,
            sourceId = sourceId,
            scanned = scanned,
            total = total,
            found = found,
        )

        // Throttled the same way the bridge throttles its channel, and for the
        // same reason: a thumbnail cache with thirty thousand entries would
        // otherwise post thirty thousand notification updates.
        val now = System.currentTimeMillis()
        if (!done && now - lastNotifiedAt < 500) return
        lastNotifiedAt = now

        notifier().notify(
            NOTIFICATION_ID,
            notification(
                "Scanning this phone",
                if (found > 0) "$found recoverable so far" else null,
                scanned,
                total,
            ),
        )
    }

    private fun finish(timedOut: Boolean, error: String? = null) {
        val found = RecoveryIndex.shared.totalItems()
        state = State(
            running = false,
            found = found,
            timedOut = timedOut,
            finishedAtMillis = System.currentTimeMillis(),
            error = error,
        )

        stopForegroundCompat()

        // A completion notice only when there is something to report and the
        // user is not already looking at the app. Announcing "0 found" is the
        // correct answer and a pointless interruption.
        if (found > 0) {
            notifier().notify(
                NOTIFICATION_ID_DONE,
                notification(
                    if (timedOut) "Scan stopped early" else "Scan finished",
                    if (timedOut) "$found found so far. Open to continue."
                    else "$found items can still be recovered",
                    0,
                    0,
                    ongoing = false,
                ),
            )
        }
        stopSelf()
    }

    private fun readTrashMap(): TrashMap {
        val file = File(filesDir, TRASH_MAP_FILE)
        if (!file.exists()) return TrashMap.empty
        return try {
            TrashMap.parse(file.readText())
        } catch (_: Throwable) {
            TrashMap.empty
        }
    }

    private fun notifier(): NotificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun notification(
        title: String,
        body: String?,
        scanned: Int,
        total: Int,
        ongoing: Boolean = true,
    ): Notification {
        ensureChannel()

        val open = packageManager.getLaunchIntentForPackage(packageName)
        val tapThrough = open?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }

        val builder = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setOngoing(ongoing)
            .setOnlyAlertOnce(true)
        if (body != null) builder.setContentText(body)
        if (tapThrough != null) builder.setContentIntent(tapThrough)

        // A real determinate bar wherever a total is known. An indeterminate
        // spinner on a file scan is the visual grammar of the fake deep scan
        // this app exists not to perform.
        if (ongoing) {
            if (total > 0) {
                builder.setProgress(total, scanned.coerceAtMost(total), false)
            } else {
                builder.setProgress(0, 0, true)
            }
        }

        return builder.build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val existing = notifier().getNotificationChannel(CHANNEL_ID)
        if (existing != null) return
        notifier().createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Scanning",
                // LOW, so a scan the user started never makes a sound. This is
                // progress on a task they are waiting for, not news.
                NotificationManager.IMPORTANCE_LOW,
            )
        )
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    @Suppress("DEPRECATION")
    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= 24) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
    }

    /**
     * What the bridge reports to Dart.
     *
     * A plain immutable snapshot behind `@Volatile`, not a flow or a broadcast.
     * The reader is a poll from a screen that just appeared, and anything
     * subscription-shaped would need a live engine to deliver into, which is the
     * one thing this service cannot assume exists.
     */
    internal data class State(
        val running: Boolean = false,
        val sourceId: String? = null,
        val scanned: Int = 0,
        val total: Int = 0,
        val found: Int = 0,
        val timedOut: Boolean = false,
        val finishedAtMillis: Long? = null,
        val error: String? = null,
    )

    private var lastNotifiedAt = 0L

    companion object {
        const val TRASH_MAP_FILE = "trashmap.json"

        private const val CHANNEL_ID = "scan"
        private const val NOTIFICATION_ID = 4101
        private const val NOTIFICATION_ID_DONE = 4102
        private const val ACTION_CANCEL = "com.mindhunter.g_recovery.CANCEL_SCAN"

        /**
         * INTERNAL on the getter too, not just the setter.
         *
         * This service has to be public because the manifest instantiates it by
         * name, but [State] is internal like everything else in this package. A
         * public getter returning an internal type is a compile error, and the
         * fix is not to widen [State]: the only reader is the bridge, which is
         * internal as well.
         */
        @Volatile
        internal var state: State = State()

        fun start(context: Context) {
            val intent = Intent(context, ScanService::class.java)
            context.startForegroundService(intent)
        }

        fun cancel(context: Context) {
            val intent = Intent(context, ScanService::class.java)
                .setAction(ACTION_CANCEL)
            context.startService(intent)
        }
    }
}
