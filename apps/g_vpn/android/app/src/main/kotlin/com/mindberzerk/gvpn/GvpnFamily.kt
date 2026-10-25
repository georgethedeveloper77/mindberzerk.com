package com.mindberzerk.gvpn

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import com.wireguard.android.backend.Tunnel

/**
 * G VPN's status, readable by the other Mindberzerk apps (G Launcher's
 * desklet, G Recovery's cards) and by nothing else: the provider requires
 * com.mindberzerk.permission.VPN_CONTROL, which Android grants only to apps
 * signed with the certificates listed in res/values/family.xml.
 *
 * One row: state, label, paused_until. Apps watch the URI for changes;
 * G VPN calls [changed] whenever its state moves.
 */
class GvpnFamilyProvider : ContentProvider() {
    override fun onCreate() = true

    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, args: Array<out String>?, sort: String?): Cursor {
        val ctx = requireNotNull(context)
        val (state, label) = GvpnFamily.current(ctx)
        return MatrixCursor(arrayOf("state", "label", "paused_until"), 1).apply {
            addRow(arrayOf<Any?>(state, label, GvpnSessionService.pausedUntil))
        }
    }

    override fun getType(uri: Uri) = "vnd.android.cursor.item/vnd.com.mindberzerk.gvpn.status"
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, args: Array<out String>?) = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, args: Array<out String>?) = 0
}

object GvpnFamily {
    val STATUS_URI: Uri = Uri.parse("content://com.mindberzerk.gvpn.family/status")

    /** off, connecting, on, reconnecting or paused; and the server's name. */
    fun current(ctx: Context): Pair<String, String?> {
        val label = LastSession.load(ctx)?.label
        val wgUp = runCatching { WireGuard.backend(ctx).getState(GTunnel) == Tunnel.State.UP }.getOrDefault(false)
        val state = when {
            GvpnSessionService.pausedUntil > System.currentTimeMillis() -> "paused"
            OpenVpnEngine.isConnected || wgUp || SstpEngine.isConnected(ctx) -> "on"
            OpenVpnEngine.isReconnecting -> "reconnecting"
            OpenVpnEngine.isActive || SstpEngine.isActive(ctx) -> "connecting"
            else -> "off"
        }
        return state to (if (state == "off") null else label)
    }

    /** Tells watching apps to re-read. Cheap; safe from any thread. */
    fun changed(ctx: Context) {
        runCatching { ctx.contentResolver.notifyChange(STATUS_URI, null) }
    }
}
