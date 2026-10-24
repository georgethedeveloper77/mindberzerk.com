package com.mindberzerk.gvpn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.os.Build

/**
 * Two jobs: re-arm the network watch after boot and app updates (both clear
 * PendingIntent callbacks), and act on "a Wi-Fi network is available".
 */
class AutoConnectReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> {
                AutoConnect.register(context)
                return
            }
        }

        val network: Network = (
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(ConnectivityManager.EXTRA_NETWORK, Network::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(ConnectivityManager.EXTRA_NETWORK)
            }
            ) ?: return

        val config = AutoConnect.configFor(context, network) ?: return

        // setState blocks while the tunnel comes up: keep the receiver alive
        // past onReceive and do the work off the main thread.
        val pending = goAsync()
        Thread {
            try {
                AutoConnect.connect(context, config)
            } finally {
                pending.finish()
            }
        }.start()
    }
}
