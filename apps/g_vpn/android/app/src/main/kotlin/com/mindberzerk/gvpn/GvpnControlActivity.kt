package com.mindberzerk.gvpn

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Bundle

/**
 * Connect, disconnect or pause G VPN from another Mindberzerk app.
 *
 * An invisible activity rather than a broadcast receiver: the calling app is
 * in the foreground (the user just tapped its desklet), and an activity it
 * starts may start G VPN's foreground service, which a background receiver
 * is not allowed to. Protected by VPN_CONTROL, like the status provider.
 */
class GvpnControlActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        when (intent?.action) {
            ACTION_CONNECT ->
                // Needs Android's VPN consent, or a server never chosen:
                // only the app itself can sort either out.
                if (VpnService.prepare(this) != null || LastSession.load(this) == null) {
                    openApp()
                } else {
                    GvpnSessionService.send(this, GvpnSessionService.ACTION_RESUME)
                }
            ACTION_DISCONNECT -> GvpnSessionService.send(this, GvpnSessionService.ACTION_STOP)
            ACTION_PAUSE -> GvpnSessionService.send(
                this,
                GvpnSessionService.ACTION_PAUSE,
                intent.getIntExtra(EXTRA_MINUTES, 15).coerceIn(1, 24 * 60),
            )
            else -> openApp()
        }
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }

    private fun openApp() {
        packageManager.getLaunchIntentForPackage(packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ?.let(::startActivity)
    }

    companion object {
        const val ACTION_CONNECT = "com.mindberzerk.gvpn.action.CONNECT"
        const val ACTION_DISCONNECT = "com.mindberzerk.gvpn.action.DISCONNECT"
        const val ACTION_PAUSE = "com.mindberzerk.gvpn.action.PAUSE"
        const val EXTRA_MINUTES = "minutes"
    }
}
