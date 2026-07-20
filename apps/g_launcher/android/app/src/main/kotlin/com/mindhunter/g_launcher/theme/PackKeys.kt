package com.mindhunter.g_launcher.theme

/**
 * PHASE C1 - the ed25519 public keys this build will accept packs from.
 *
 * BAKED INTO THE APK. NEVER IN REMOTE CONFIG, NEVER ON THE CDN.
 *
 * The whole point of the signature is that compromising the CDN is not enough
 * to compromise the app. Fetching the key from the same place as the payload
 * gives that back for free and the check becomes theatre. Same reason
 * `cdn_base_url` IS in Remote Config and this is not: the host is swappable,
 * the trust anchor is not.
 *
 * ROTATION. This is a MAP, not a constant, so a key can be retired without a
 * flag day: publish under a new id, ship a release that accepts both, wait for
 * the install base to move, then drop the old entry in a later release. The
 * manifest names the id it was signed with, so a client that predates the new
 * key simply refuses the pack and keeps the one it has - which is the correct
 * failure, not a crash.
 *
 * The private half NEVER leaves the signing machine (and later, the admin
 * panel's server-side secret in C4). If it leaks, every key here is dead and
 * the fix is a Play release. Treat it like the upload keystore.
 *
 * KEYS ARE HEX, NOT BASE64, AND THAT IS DELIBERATE. `android.util.Base64` is an
 * Android API: in a plain JVM unit test it is a stub that returns null, so
 * anything reading this file would be untestable without Robolectric. Hex costs
 * 32 extra characters and keeps this whole package free of `android.*`.
 */
object PackKeys {

    /**
     * The id this build signs with today. The signing tool defaults to it;
     * `PackVerifier` does not care which of [accepted] a pack names.
     */
    const val CURRENT_KEY_ID: String = "mh-2026-07"

    /**
     * keyId -> raw 32-byte ed25519 public key, lowercase hex.
     *
     * PLACEHOLDER VALUE - replace before shipping. Generate the real pair with
     * `node tools/sign-pack.mjs keygen`, paste the public half here, and keep
     * the private half out of the repo. The fixture keypair the tests use is
     * generated in-test from a fixed seed and is deliberately NOT one of these:
     * a test key that can sign a pack the shipped app accepts is a backdoor.
     */
    private val ACCEPTED_HEX: Map<String, String> = mapOf(
        CURRENT_KEY_ID to
            "a5482077e685b0078706166a55836e094fd63143c926f097e7f340fe9781bea0",
    )

    /**
     * Decoded once. A malformed entry here is a build-time mistake, so it drops
     * the key rather than throwing: a typo must not stop the launcher booting,
     * and the visible symptom (every pack refused with UnknownKey) points
     * straight at this file.
     */
    val accepted: Map<String, ByteArray> by lazy {
        ACCEPTED_HEX.mapNotNull { (id, hex) ->
            val raw = decodeHex(hex)
            if (raw != null && raw.size == 32) id to raw else null
        }.toMap()
    }

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
