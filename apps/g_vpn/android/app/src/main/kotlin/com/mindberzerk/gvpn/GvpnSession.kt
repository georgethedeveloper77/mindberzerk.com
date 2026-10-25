package com.mindberzerk.gvpn

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * The last tunnel G VPN brought up, kept so it can be brought up again
 * without the app's screens: after a pause, from the Quick Settings tile, or
 * from a notification when Android has restarted the app's process.
 *
 * App-private storage, beside the saved servers themselves.
 */
sealed class LastSession {
    abstract val label: String

    data class WireGuard(override val label: String, val config: String) : LastSession()

    data class Sstp(
        override val label: String,
        val host: String,
        val port: Int,
        val username: String,
        val password: String,
        val excludedApps: List<String>,
        val dnsServers: List<String>,
    ) : LastSession()

    data class OpenVpn(
        override val label: String,
        val config: String,
        val excludedApps: List<String>,
        val dnsServers: List<String>,
    ) : LastSession()

    companion object {
        private const val PREFS = "gvpn_session"
        private const val KEY = "last.v1"

        fun save(ctx: Context, session: LastSession) {
            val json = when (session) {
                is WireGuard -> JSONObject().put("engine", "wg").put("label", session.label).put("config", session.config)
                is Sstp -> JSONObject()
                    .put("engine", "sstp")
                    .put("label", session.label)
                    .put("host", session.host)
                    .put("port", session.port)
                    .put("user", session.username)
                    .put("pass", session.password)
                    .put("excluded", JSONArray(session.excludedApps))
                    .put("dns", JSONArray(session.dnsServers))
                is OpenVpn -> JSONObject()
                    .put("engine", "ovpn")
                    .put("label", session.label)
                    .put("config", session.config)
                    .put("excluded", JSONArray(session.excludedApps))
                    .put("dns", JSONArray(session.dnsServers))
            }
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, json.toString()).apply()
        }

        fun load(ctx: Context): LastSession? {
            val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null) ?: return null
            return runCatching {
                val j = JSONObject(raw)
                fun list(key: String): List<String> {
                    val a = j.optJSONArray(key) ?: return emptyList()
                    return List(a.length()) { a.getString(it) }
                }
                when (j.getString("engine")) {
                    "wg" -> WireGuard(j.getString("label"), j.getString("config"))
                    "sstp" -> Sstp(
                        j.getString("label"), j.getString("host"), j.getInt("port"),
                        j.getString("user"), j.getString("pass"), list("excluded"), list("dns"),
                    )
                    else -> OpenVpn(j.getString("label"), j.getString("config"), list("excluded"), list("dns"))
                }
            }.getOrNull()
        }
    }
}
