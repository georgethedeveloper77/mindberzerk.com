package com.mindberzerk.gvpn

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Encryption at rest for everything G VPN keeps that could connect as the
 * user: WireGuard private keys, server configs, the G Servers device token.
 *
 * AES-256-GCM with a key generated inside Android Keystore. The key never
 * leaves secure hardware where the phone has it, so the stored text is
 * useless copied off the phone, even with root. Backups are off
 * (AndroidManifest), so the key never has to survive a restore.
 *
 * Sealed text is "gv1:" + Base64(12-byte IV + ciphertext with tag). Text
 * without the prefix is a value saved before encryption; [open] returns it
 * unchanged so callers can re-save it sealed.
 */
object SecretBox {
    private const val ALIAS = "gvpn.secrets.v1"
    private const val PREFIX = "gv1:"
    private const val IV_BYTES = 12
    private const val TAG_BITS = 128

    fun seal(plain: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val out = cipher.iv + cipher.doFinal(plain.toByteArray(Charsets.UTF_8))
        return PREFIX + Base64.encodeToString(out, Base64.NO_WRAP)
    }

    /** The plain text, or null when it cannot be decrypted (key gone, data damaged). */
    fun open(stored: String): String? {
        if (!stored.startsWith(PREFIX)) return stored
        return try {
            val data = Base64.decode(stored.substring(PREFIX.length), Base64.NO_WRAP)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(TAG_BITS, data, 0, IV_BYTES))
            String(cipher.doFinal(data, IV_BYTES, data.size - IV_BYTES), Charsets.UTF_8)
        } catch (e: Exception) {
            null
        }
    }

    fun isSealed(stored: String) = stored.startsWith(PREFIX)

    @Synchronized
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setRandomizedEncryptionRequired(true)
                .build(),
        )
        return generator.generateKey()
    }
}
