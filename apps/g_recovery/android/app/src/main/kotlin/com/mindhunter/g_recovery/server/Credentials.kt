package com.mindhunter.g_recovery.server

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * WHERE THE SERVER PASSWORD LIVES.
 *
 * ─── ENCRYPTED BY THE PHONE, NOT BY US ───────────────────────────────────────
 *
 * EncryptedSharedPreferences with a MasterKey held in the hardware keystore. The
 * key never leaves the secure element, this app cannot export it, and another
 * app cannot read the file even with root on a device where the keystore is
 * backed by hardware.
 *
 * ─── THE KEY CAN BE INVALIDATED, AND THAT IS THE INTERESTING CASE ────────────
 *
 * Changing or removing the screen lock can destroy the master key on some
 * devices, and a restore from backup can bring across a preferences file the new
 * keystore cannot open. Both leave a file full of bytes that will never decrypt.
 *
 * The wrong response is to crash or to silently return no password, because the
 * second one produces a backup that fails every night at 2am for a reason nobody
 * can see. This clears the unreadable file and reports that it happened, so the
 * app can ask for the password again and say why.
 */
internal class Credentials(context: Context) {

    private val app: Context = context.applicationContext

    /** Set when a read failed because the key no longer opens the file. */
    var wasInvalidated: Boolean = false
        private set

    private var prefs: SharedPreferences? = null

    private fun open(): SharedPreferences? {
        prefs?.let { return it }

        return try {
            val key = MasterKey.Builder(app)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            EncryptedSharedPreferences.create(
                app,
                FILE,
                key,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
            ).also { prefs = it }
        } catch (_: Throwable) {
            // The file exists and this key cannot open it. Deleting is the only
            // recovery: the bytes are unreadable by anything, forever, and
            // leaving them means every future open throws in the same way.
            //
            // Only the password is lost. The server settings live in ordinary
            // preferences, so the user retypes one field rather than setting the
            // whole thing up again.
            wasInvalidated = true
            runCatching {
                app.deleteSharedPreferences(FILE)
            }
            runCatching {
                val key = MasterKey.Builder(app)
                    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                    .build()
                EncryptedSharedPreferences.create(
                    app,
                    FILE,
                    key,
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
                ).also { prefs = it }
            }.getOrNull()
        }
    }

    fun password(serverId: String): String? =
        open()?.getString(serverId, null)

    fun put(serverId: String, password: String) {
        open()?.edit()?.putString(serverId, password)?.apply()
    }

    fun clear(serverId: String) {
        open()?.edit()?.remove(serverId)?.apply()
    }

    /** Called once the app has asked the user to retype. */
    fun acknowledgeInvalidation() {
        wasInvalidated = false
    }

    private companion object {
        /**
         * Its own file, not the app's general preferences.
         *
         * Deleting it on an invalidated key must not take the theme, the sort
         * order and the onboarding flag with it.
         */
        const val FILE = "server_credentials"
    }
}
