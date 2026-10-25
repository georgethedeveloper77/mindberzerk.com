package com.mindberzerk.gvpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import java.io.BufferedReader
import java.io.StringReader
import java.text.DateFormat
import java.util.Date
import java.util.concurrent.Executors

/**
 * G VPN's own foreground service: the notification and its buttons.
 *
 * - WireGuard connected: this IS the notification, with live speeds and
 *   Pause 15m / Pause 1h / Disconnect.
 * - OpenVPN connected: the engine shows its own notification, whose buttons
 *   point here; this service runs only during a pause.
 * - Paused (either engine): the tunnel is fully stopped, so the internet
 *   works directly, and a countdown shows Resume now / Disconnect. Because
 *   this service stays in the foreground, Android lets it reconnect on time.
 */
class GvpnSessionService : Service() {
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var lastRx = -1L
    private var lastTx = -1L

    private val resumeOnTime = Runnable { resume() }
    private val tick = object : Runnable {
        override fun run() {
            if (pausedUntil == 0L && isWireGuardUp()) {
                notifyLive()
                main.postDelayed(this, TICK_MS)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureChannel(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Android needs startForeground within seconds of every start.
        promote(if (pausedUntil > 0) pausedNotification() else liveNotification(null, null))
        when (intent?.action) {
            ACTION_CONNECTED -> showLive()
            ACTION_PAUSE -> pause(intent.getIntExtra(EXTRA_MINUTES, 15))
            ACTION_RESUME -> resume()
            ACTION_STOP -> stopByUser()
            else -> if (pausedUntil == 0L && !isWireGuardUp()) finish()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        main.removeCallbacksAndMessages(null)
        worker.shutdown()
        super.onDestroy()
    }

    // ── states ─────────────────────────────────────────────────────────────

    private fun showLive() {
        GvpnFamily.changed(this)
        lastRx = -1L
        main.removeCallbacks(tick)
        main.post(tick)
    }

    private fun pause(minutes: Int) {
        val session = LastSession.load(this) ?: return finish()
        main.removeCallbacks(tick)
        main.removeCallbacks(resumeOnTime)
        pausedUntil = System.currentTimeMillis() + minutes * 60_000L
        stopEngines(session) {}
        notify(pausedNotification())
        main.postDelayed(resumeOnTime, minutes * 60_000L)
        GvpnFamily.changed(this)
    }

    private fun resume() {
        main.removeCallbacks(resumeOnTime)
        pausedUntil = 0L
        val session = LastSession.load(this) ?: return finish()
        when (session) {
            is LastSession.WireGuard -> worker.execute {
                val ok = runCatching {
                    val config = Config.parse(BufferedReader(StringReader(session.config)))
                    WireGuard.backend(this).setState(GTunnel, Tunnel.State.UP, config)
                }.isSuccess
                main.post { if (ok) showLive() else finish() }
            }
            is LastSession.OpenVpn -> {
                OpenVpnEngine.connect(this, session.config, session.label, session.excludedApps, session.dnsServers) {}
                // The engine shows its own notification from here.
                finish()
            }
            is LastSession.Sstp -> {
                SstpEngine.connect(
                    this,
                    SstpEngine.Options(session.host, session.port, session.username, session.password, session.excludedApps, session.dnsServers),
                )
                // The SSTP engine's service shows the notification from here.
                finish()
            }
        }
    }

    private fun stopByUser() {
        main.removeCallbacks(resumeOnTime)
        main.removeCallbacks(tick)
        pausedUntil = 0L
        userStoppedAt = System.currentTimeMillis()
        // Same as the app's own Stop: auto-connect leaves this Wi-Fi alone.
        AutoConnect.markUserPaused(this)
        stopEngines(LastSession.load(this)) { main.post { finish() } }
    }

    private fun stopEngines(session: LastSession?, done: () -> Unit) {
        worker.execute {
            runCatching { WireGuard.backend(this).setState(GTunnel, Tunnel.State.DOWN, null) }
            runCatching { SstpEngine.disconnect(this) }
            if (session is LastSession.OpenVpn || OpenVpnEngine.isActive) {
                val latch = java.util.concurrent.CountDownLatch(1)
                OpenVpnEngine.forceStop(this) { latch.countDown() }
                latch.await(10, java.util.concurrent.TimeUnit.SECONDS)
            }
            done()
        }
    }

    private fun finish() {
        GvpnFamily.changed(this)
        main.removeCallbacksAndMessages(null)
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun isWireGuardUp() =
        runCatching { WireGuard.backend(this).getState(GTunnel) == Tunnel.State.UP }.getOrDefault(false)

    // ── notifications ──────────────────────────────────────────────────────

    private fun notifyLive() {
        val stats = runCatching { WireGuard.backend(this).getStatistics(GTunnel) }.getOrNull()
        val rx = stats?.totalRx() ?: 0L
        val tx = stats?.totalTx() ?: 0L
        val rates = if (lastRx >= 0) (rx - lastRx) * 1000 / TICK_MS to (tx - lastTx) * 1000 / TICK_MS else null
        lastRx = rx
        lastTx = tx
        notify(liveNotification(rates?.first, rates?.second))
    }

    private fun liveNotification(rxPerSec: Long?, txPerSec: Long?): Notification {
        val label = LastSession.load(this)?.label ?: "G VPN"
        val speeds = if (rxPerSec == null || txPerSec == null) "Protected" else "Protected · ↓ ${rate(rxPerSec)}  ↑ ${rate(txPerSec)}"
        return base()
            .setContentTitle(label)
            .setContentText(speeds)
            .setSmallIcon(R.drawable.ic_stat_gvpn)
            .addAction(0, getString(R.string.gvpn_pause_15), action(ACTION_PAUSE, 15, 1))
            .addAction(0, getString(R.string.gvpn_pause_60), action(ACTION_PAUSE, 60, 2))
            .addAction(0, getString(R.string.gvpn_disconnect), action(ACTION_STOP, 0, 3))
            .build()
    }

    private fun pausedNotification(): Notification {
        val at = DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(pausedUntil))
        return base()
            .setContentTitle(getString(R.string.gvpn_paused_title, at))
            .setContentText(getString(R.string.gvpn_paused_text))
            .setSmallIcon(R.drawable.ic_stat_vpn_outline)
            .setWhen(pausedUntil)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .addAction(0, getString(R.string.gvpn_resume_now), action(ACTION_RESUME, 0, 4))
            .addAction(0, getString(R.string.gvpn_disconnect), action(ACTION_STOP, 0, 3))
            .build()
    }

    private fun base(): NotificationCompat.Builder {
        val open = packageManager.getLaunchIntentForPackage(packageName)
        return NotificationCompat.Builder(this, CHANNEL)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(open?.let { PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE) })
    }

    private fun action(name: String, minutes: Int, code: Int): PendingIntent =
        servicePendingIntent(this, Intent(this, GvpnSessionService::class.java).setAction(name).putExtra(EXTRA_MINUTES, minutes), code)

    private fun promote(n: Notification) {
        val type = if (Build.VERSION.SDK_INT >= 34) ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE else 0
        ServiceCompat.startForeground(this, NOTIFICATION_ID, n, type)
    }

    private fun notify(n: Notification) {
        runCatching { getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, n) }
    }

    private fun rate(bytesPerSec: Long): String {
        val bits = bytesPerSec.coerceAtLeast(0) * 8.0
        return when {
            bits >= 1e6 -> "%.1f Mb/s".format(bits / 1e6)
            bits >= 1e3 -> "%.0f kb/s".format(bits / 1e3)
            else -> "%.0f b/s".format(bits)
        }
    }

    companion object {
        const val ACTION_CONNECTED = "com.mindberzerk.gvpn.CONNECTED"
        const val ACTION_PAUSE = "com.mindberzerk.gvpn.PAUSE"
        const val ACTION_RESUME = "com.mindberzerk.gvpn.RESUME"
        const val ACTION_STOP = "com.mindberzerk.gvpn.STOP"
        const val EXTRA_MINUTES = "minutes"
        private const val CHANNEL = "gvpn_session"
        private const val NOTIFICATION_ID = 0x6760
        private const val TICK_MS = 2_000L

        /** Epoch ms the pause ends; 0 when not paused. Read by status(). */
        @Volatile
        var pausedUntil = 0L
            private set

        /** Set when the user stops from a notification or the tile. */
        @Volatile
        var userStoppedAt = 0L

        /** False when Android refused the start (a background restriction). */
        fun send(ctx: Context, action: String, minutes: Int = 0): Boolean {
            val intent = Intent(ctx, GvpnSessionService::class.java).setAction(action).putExtra(EXTRA_MINUTES, minutes)
            return runCatching { ContextCompat.startForegroundService(ctx, intent) }.isSuccess
        }

        /** The app's own Stop: end any pause or live notification quietly. */
        fun end(ctx: Context) {
            pausedUntil = 0L
            ctx.stopService(Intent(ctx, GvpnSessionService::class.java))
        }

        fun servicePendingIntent(ctx: Context, intent: Intent, code: Int): PendingIntent {
            val flags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                PendingIntent.getForegroundService(ctx, code, intent, flags)
            } else {
                PendingIntent.getService(ctx, code, intent, flags)
            }
        }

        fun ensureChannel(ctx: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val nm = ctx.getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(CHANNEL) != null) return
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, ctx.getString(R.string.gvpn_channel_session), NotificationManager.IMPORTANCE_LOW).apply {
                    setShowBadge(false)
                },
            )
        }
    }
}
