package com.mindberzerk.gvpn

import android.app.PendingIntent
import android.content.Intent
import android.graphics.drawable.Icon
import android.net.VpnService
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.wireguard.android.backend.Tunnel

/**
 * Quick Settings tile: one tap connects to the last server or disconnects.
 * When Android has not yet granted VPN permission, it opens the app instead.
 */
class GvpnTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        render()
    }

    override fun onClick() {
        super.onClick()
        val sent = when {
            active() -> GvpnSessionService.send(this, GvpnSessionService.ACTION_STOP)
            VpnService.prepare(this) != null || LastSession.load(this) == null -> false
            else -> GvpnSessionService.send(this, GvpnSessionService.ACTION_RESUME)
        }
        // Permission still needed, or Android refused a background start:
        // the app does it, one tap away.
        if (!sent) return openApp()
        qsTile?.let {
            it.state = Tile.STATE_UNAVAILABLE
            it.updateTile()
        }
        main.postDelayed({ render() }, 2_000)
    }

    private val main = android.os.Handler(android.os.Looper.getMainLooper())

    private fun active(): Boolean =
        GvpnSessionService.pausedUntil > 0 ||
            OpenVpnEngine.isActive ||
            SstpEngine.isActive(this) ||
            runCatching { WireGuard.backend(this).getState(GTunnel) == Tunnel.State.UP }.getOrDefault(false)

    private fun render() {
        val tile = qsTile ?: return
        val on = active()
        tile.state = if (on) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.icon = Icon.createWithResource(this, R.drawable.ic_stat_gvpn)
        tile.label = "G VPN"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) tile.subtitle = if (on) LastSession.load(this)?.label else null
        tile.updateTile()
    }

    private fun openApp() {
        val launch = packageManager.getLaunchIntentForPackage(packageName)?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) ?: return
        if (Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(PendingIntent.getActivity(this, 0, launch, PendingIntent.FLAG_IMMUTABLE))
        } else {
            @Suppress("DEPRECATION", "StartActivityAndCollapseDeprecated")
            startActivityAndCollapse(launch)
        }
    }
}
