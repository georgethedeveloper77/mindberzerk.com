package com.mindhunter.g_recovery.content

/**
 * The ed25519 public keys this build accepts content from.
 *
 * BAKED INTO THE APK. NEVER IN REMOTE CONFIG, NEVER ON THE CDN. The whole point
 * of the signature is that compromising the CDN is not enough to compromise the
 * app; fetching the key from the same place as the payload gives that back and
 * turns the check into theatre. The host is swappable, the trust anchor is not.
 *
 * SAME KEY AS G LAUNCHER, deliberately. One signing machine, one private half
 * to protect, one `sign-pack.mjs`. Two keys would mean two secrets and no extra
 * safety: an attacker with the signing machine has both either way.
 *
 * ROTATION is a map, not a constant: publish under a new id, ship a release
 * accepting both, wait for the install base to move, drop the old entry later.
 * A client predating the new key refuses the pack and keeps what it has, which
 * is the correct failure.
 *
 * HEX, NOT BASE64. `android.util.Base64` is an Android API and returns null in
 * a plain JVM unit test, which would make this package untestable without
 * Robolectric. Hex costs 32 characters.
 */
internal object ContentKeys {

    const val CURRENT_KEY_ID: String = "mh-2026-07"

    /**
     * keyId to raw 32 byte ed25519 public key, lowercase hex.
     *
     * THIS IS THE REAL KEY, copied from the launcher's PackKeys. The comment
     * there still calls it a placeholder and it is not: it is the public half
     * of the pair at ~/.mindberzerk/pack-signing.key, and packs published from
     * the panel are signed with it today. Do not regenerate.
     */
    private val ACCEPTED_HEX: Map<String, String> = mapOf(
        CURRENT_KEY_ID to
            "a5482077e685b0078706166a55836e094fd63143c926f097e7f340fe9781bea0",
    )

    /**
     * Decoded once. A malformed entry drops the key rather than throwing: a typo
     * must not stop the app launching, and the visible symptom, every pack
     * refused with UnknownKey, points straight back here.
     */
    val accepted: Map<String, ByteArray> by lazy {
        ACCEPTED_HEX.mapNotNull { (id, hex) ->
            val raw = decodeHex(hex)
            if (raw != null && raw.size == PUBLIC_KEY_SIZE) id to raw else null
        }.toMap()
    }

    private const val PUBLIC_KEY_SIZE = 32

    /** Null on any malformed input rather than throwing. */
    fun decodeHex(s: String): ByteArray? {
        if (s.length % 2 != 0) return null
        val out = ByteArray(s.length / 2)
        for (i in out.indices) {
            val hi = Character.digit(s[i * 2], 16)
            val lo = Character.digit(s[i * 2 + 1], 16)
            if (hi < 0 || lo < 0) return null
            out[i] = ((hi shl 4) or lo).toByte()
        }
        return out
    }

    fun encodeHex(bytes: ByteArray): String {
        val sb = StringBuilder(bytes.size * 2)
        for (b in bytes) {
            val v = b.toInt() and 0xFF
            sb.append("0123456789abcdef"[v ushr 4])
            sb.append("0123456789abcdef"[v and 0x0F])
        }
        return sb.toString()
    }
}
