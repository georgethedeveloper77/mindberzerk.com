package com.mindberzerk.gvpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.VpnService
import android.net.wifi.WifiInfo
import android.os.Build
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import java.io.BufferedReader
import java.io.StringReader

/**
 * Auto-connect on untrusted Wi-Fi, with NO service running and no Dart.
 *
 * The system delivers "a Wi-Fi network is available" to [AutoConnectReceiver]
 * through a PendingIntent network callback. That registration outlives the
 * app process, costs nothing while idle, and is re-armed after reboot and
 * app updates by the same receiver. Battery cost is zero until a network
 * actually changes.
 *
 * Trust is judged by Wi-Fi SECURITY, not by network name: reading the SSID
 * needs location permission, which a VPN app should not ask for.
 */
object AutoConnect {
    private const val PREFS = "gvpn_autoconnect"
    private const val KEY_CONFIG = "config"
    private const val KEY_MODE = "mode"
    private const val KEY_PAUSED = "paused_network"
    private const val CHANNEL = "autoconnect"
    private const val NOTIFY_ID = 0x6771

    /** Private keys live in here too; backup is excluded in the manifest rules. */
    private fun prefs(ctx: Context): SharedPreferences =
        ctx.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun configure(ctx: Context, settings: AutoConnectSettings?) {
        unregister(ctx)
        if (settings == null) {
            prefs(ctx).edit().remove(KEY_CONFIG).remove(KEY_MODE).apply()
            return
        }
        prefs(ctx).edit()
            .putString(KEY_CONFIG, settings.configText)
            .putString(KEY_MODE, settings.mode.name)
            .apply()
        register(ctx)
    }

    /** Idempotent: unregister first so a re-arm never stacks callbacks. */
    fun register(ctx: Context) {
        if (prefs(ctx).getString(KEY_CONFIG, null) == null) return
        unregister(ctx)
        // NOT_VPN is in NetworkRequest's defaults, so our own tunnel never
        // triggers this callback.
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        cm(ctx).registerNetworkCallback(request, callbackIntent(ctx))
    }

    private fun unregister(ctx: Context) {
        try {
            cm(ctx).unregisterNetworkCallback(callbackIntent(ctx))
        } catch (_: IllegalArgumentException) {
            // Was not registered. Fine.
        }
    }

    /** MUTABLE on 12+: the system writes the Network into this intent's extras. */
    private fun callbackIntent(ctx: Context): PendingIntent {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
        return PendingIntent.getBroadcast(
            ctx.applicationContext,
            0,
            Intent(ctx.applicationContext, AutoConnectReceiver::class.java),
            flags,
        )
    }

    /**
     * Returns the config to bring up, or null when this network needs nothing.
     * Never fights the user: a manual disconnect on a network pauses
     * auto-connect until the phone joins a DIFFERENT network.
     */
    fun configFor(ctx: Context, network: Network): String? {
        val p = prefs(ctx)
        val config = p.getString(KEY_CONFIG, null) ?: return null
        if (WireGuard.backend(ctx).getState(GTunnel) == Tunnel.State.UP) return null
        if (p.getLong(KEY_PAUSED, -1L) == network.networkHandle) return null

        val caps = cm(ctx).getNetworkCapabilities(network) ?: return null
        if (!caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return null

        val mode = p.getString(KEY_MODE, AutoConnectMode.OPEN.name)
        val untrusted = mode == AutoConnectMode.ANY.name || isOpenOrPublic(caps)
        return if (untrusted) config else null
    }

    private fun isOpenOrPublic(caps: NetworkCapabilities): Boolean {
        if (caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL)) return true
        // Below Android 12 there is no public security-type API; only the
        // captive-portal signal above can fire there.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        val info = caps.transportInfo as? WifiInfo ?: return false
        return when (info.currentSecurityType) {
            WifiInfo.SECURITY_TYPE_OPEN,
            WifiInfo.SECURITY_TYPE_WEP,
            WifiInfo.SECURITY_TYPE_OWE -> true
            else -> false
        }
    }

    /** Runs on a background thread. */
    fun connect(ctx: Context, configText: String) {
        // Consent can only be granted from an Activity. If it was revoked,
        // ask the user to open the app instead of failing silently.
        if (VpnService.prepare(ctx) != null) {
            notifyTapToProtect(ctx)
            return
        }
        try {
            val config = Config.parse(BufferedReader(StringReader(configText)))
            WireGuard.backend(ctx).setState(GTunnel, Tunnel.State.UP, config)
        } catch (e: Exception) {
            // Includes background-start restrictions on some OEM builds. The
            // notification hands the job to the user, one tap away.
            notifyTapToProtect(ctx)
        }
    }

    fun markUserPaused(ctx: Context) {
        val handle = currentWifi(ctx)?.networkHandle ?: -1L
        prefs(ctx).edit().putLong(KEY_PAUSED, handle).apply()
    }

    fun clearUserPause(ctx: Context) {
        prefs(ctx).edit().remove(KEY_PAUSED).apply()
    }

    @Suppress("DEPRECATION")
    private fun currentWifi(ctx: Context): Network? {
        val cm = cm(ctx)
        return cm.allNetworks.firstOrNull { n ->
            val c = cm.getNetworkCapabilities(n) ?: return@firstOrNull false
            c.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) &&
                !c.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
        }
    }

    private fun notifyTapToProtect(ctx: Context) {
        val app = ctx.applicationContext
        val nm = app.getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Auto-connect", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Untrusted Wi-Fi alerts when G VPN cannot connect by itself"
                },
            )
        }
        val launch = app.packageManager.getLaunchIntentForPackage(app.packageName) ?: return
        val tap = PendingIntent.getActivity(
            app,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(app, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(app)
        }
        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher_monochrome)
            .setContentTitle("Untrusted Wi-Fi")
            .setContentText("Tap to turn on G VPN for this network.")
            .setContentIntent(tap)
            .setAutoCancel(true)
            .build()
        nm.notify(NOTIFY_ID, notification)
    }

    private fun cm(ctx: Context) = ctx.applicationContext.getSystemService(ConnectivityManager::class.java)
}
