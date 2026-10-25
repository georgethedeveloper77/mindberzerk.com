package com.mindberzerk.gvpn

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import androidx.preference.PreferenceManager

/**
 * G VPN's front for the SSTP engine (kittoku/osc, MIT): free VPN Gate
 * servers over SSTP, TLS on TCP 443 or the server's own port.
 *
 * The engine reads its settings from the app's default SharedPreferences
 * under its own key names; this object writes them, then starts or stops the
 * engine's VpnService. Flutter's settings live in a different file
 * (FlutterSharedPreferences), so nothing collides.
 */
object SstpEngine {
    // The engine's actions and status keys (kittoku/osc).
    private const val ACTION_CONNECT = "kittoku.osc.connect"
    private const val ACTION_DISCONNECT = "kittoku.osc.disconnect"
    private const val KEY_ROOT_STATE = "ROOT_STATE"
    private const val KEY_HOME_STATUS = "HOME_STATUS"

    data class Options(
        val host: String,
        val port: Int,
        val username: String,
        val password: String,
        val excludedApps: List<String>,
        val dnsServers: List<String>,
    )

    fun connect(context: Context, o: Options) {
        val prefs = PreferenceManager.getDefaultSharedPreferences(context)
        prefs.edit().apply {
            putString("HOME_HOSTNAME", o.host)
            putString("SSL_PORT", o.port.toString())
            putString("HOME_USERNAME", o.username)
            putString("HOME_PASSWORD", o.password)
            putString("HOME_STATUS", "")
            // VPN Gate servers present self-signed certificates.
            putBoolean("SSL_DO_VERIFY", false)
            putBoolean("SSL_DO_SPECIFY_CERT", false)
            putBoolean("SSL_DO_USE_CUSTOM_SNI", false)
            putBoolean("PROXY_DO_USE_PROXY", false)
            putStringSet("PPP_AUTH_PROTOCOLS", setOf("PAP", "MSCHAPv2"))
            putBoolean("PPP_IPv4_ENABLED", true)
            putBoolean("PPP_IPv6_ENABLED", false)
            // Shield: Quad9 instead of the server's DNS.
            putBoolean("DNS_DO_REQUEST_ADDRESS", o.dnsServers.isEmpty())
            putBoolean("DNS_DO_USE_CUSTOM_SERVER", o.dnsServers.isNotEmpty())
            putString("DNS_CUSTOM_ADDRESS", o.dnsServers.firstOrNull() ?: "")
            putBoolean("ROUTE_DO_ADD_DEFAULT_ROUTE", true)
            // Local network (printers, casting) stays reachable.
            putBoolean("ROUTE_DO_ROUTE_PRIVATE_ADDRESSES", false)
            putBoolean("ROUTE_DO_ADD_CUSTOM_ROUTES", false)
            // App rules: the chosen apps skip the VPN.
            putBoolean("ROUTE_DO_ENABLE_APP_BASED_RULE", o.excludedApps.isNotEmpty())
            putString("ROUTE_APP_LIST_TYPE", "Disallowed Apps")
            putStringSet("ROUTE_SELECTED_APPS", o.excludedApps.toSet())
            // The engine retries a dropped connection three times, 10 s apart.
            putBoolean("RECONNECTION_ENABLED", true)
            putString("RECONNECTION_COUNT", "3")
            putString("RECONNECTION_INTERVAL", "10")
            putBoolean("LOG_DO_SAVE_LOG", false)
        }.commit()
        ContextCompat.startForegroundService(context, service(context).setAction(ACTION_CONNECT))
    }

    fun disconnect(context: Context) {
        if (!isActive(context)) return
        runCatching { context.startService(service(context).setAction(ACTION_DISCONNECT)) }
    }

    /** The engine's service is running: connecting, connected or retrying. */
    fun isActive(context: Context): Boolean =
        PreferenceManager.getDefaultSharedPreferences(context).getBoolean(KEY_ROOT_STATE, false)

    /** Traffic is flowing: the engine reports its network once the tunnel is up. */
    fun isConnected(context: Context): Boolean =
        isActive(context) &&
            !PreferenceManager.getDefaultSharedPreferences(context).getString(KEY_HOME_STATUS, "").isNullOrEmpty()

    private fun service(context: Context) =
        Intent().setClassName(context, "kittoku.osc.service.SstpVpnService")
}
