package com.mindberzerk.gvpn

import android.content.Context
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel

/**
 * Process-wide WireGuard backend.
 *
 * ONE instance per process, created from the APPLICATION context: GoBackend
 * hands itself to its VpnService, and an Activity-scoped backend would leak
 * the Activity and lose the running tunnel the moment it is recreated.
 */
object WireGuard {
    @Volatile
    private var backend: GoBackend? = null

    fun backend(context: Context): GoBackend =
        backend ?: synchronized(this) {
            backend ?: GoBackend(context.applicationContext).also { backend = it }
        }
}

/**
 * The single tunnel G VPN runs. The name is what Android shows as the VPN
 * session; WireGuard limits it to 15 chars of [a-zA-Z0-9_=+.-].
 */
object GTunnel : Tunnel {
    override fun getName(): String = "gvpn"

    override fun onStateChange(newState: Tunnel.State) {
        // State is read by polling `status()` from Dart, so nothing is pushed
        // from here yet. A FlutterApi push replaces polling if it ever matters.
    }
}
