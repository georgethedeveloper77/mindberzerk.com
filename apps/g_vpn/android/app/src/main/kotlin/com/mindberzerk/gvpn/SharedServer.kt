package com.mindberzerk.gvpn

import android.content.Intent
import android.net.Uri
import android.os.Build

/**
 * A server shared to G VPN from another app: a QR image (WhatsApp,
 * Telegram, the Gallery) or the settings as text. MainActivity records it;
 * Flutter takes it once, when it is ready to show the add-server sheet.
 */
sealed class SharedServer {
    data class Image(val uri: Uri) : SharedServer()
    data class Text(val text: String) : SharedServer()

    companion object {
        @Volatile
        private var pending: SharedServer? = null

        fun take(): SharedServer? = pending.also { pending = null }

        /** Records a share intent; anything else is ignored. */
        fun record(intent: Intent?) {
            if (intent?.action != Intent.ACTION_SEND) return
            val type = intent.type ?: return
            pending = when {
                type.startsWith("image/") -> stream(intent)?.let { Image(it) }
                type.startsWith("text/") ->
                    intent.getStringExtra(Intent.EXTRA_TEXT)?.takeIf { it.contains("[Interface]") }?.let { Text(it) }
                else -> null
            }
        }

        private fun stream(intent: Intent): Uri? =
            if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
    }
}
