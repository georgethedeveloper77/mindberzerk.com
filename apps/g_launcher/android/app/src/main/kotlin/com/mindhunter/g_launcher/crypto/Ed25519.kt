package com.mindhunter.g_launcher.crypto

import org.bouncycastle.crypto.params.Ed25519PublicKeyParameters
import org.bouncycastle.crypto.signers.Ed25519Signer

/**
 * PHASE C2 - the one place ed25519 verification happens.
 *
 * Extracted out of PackVerifier because the CDN INDEX is signed too, with the
 * same keys and the same rules, and two copies of a crypto call is two places
 * to get the "swallow the exception and return false" contract subtly
 * different. There is exactly one verify in this app and this is it.
 *
 * Why BouncyCastle's low-level API and not `Signature.getInstance("Ed25519")`:
 * the platform one is API 33+ and this launcher's install base is Infinix,
 * Tecno and Redmi, mostly well below it. No `Security.addProvider` call either -
 * registering a JCE provider fights Conscrypt on several OEM ROMs and fails at
 * the least convenient moment. One code path, every device, always exercised.
 *
 * NO `android.*` IMPORTS. That is what keeps every caller unit-testable on a
 * plain JVM, and it is easy to lose by reaching for Log or Base64.
 */
object Ed25519 {

    /** Raw ed25519 signature length. Anything else is refused without work. */
    const val SIGNATURE_BYTES = 64

    /** Raw ed25519 public key length. */
    const val PUBLIC_KEY_BYTES = 32

    /**
     * True when [signature] is a valid signature over [message] by [publicKey].
     *
     * NEVER THROWS. A malformed key, a truncated signature and a valid-but-wrong
     * signature all mean the same thing to the caller, and a downloaded file
     * must not be able to crash the home screen by being badly formed. Every
     * exception here is an answer of "no", not an error to propagate.
     */
    fun verify(publicKey: ByteArray, message: ByteArray, signature: ByteArray): Boolean {
        if (publicKey.size != PUBLIC_KEY_BYTES) return false
        if (signature.size != SIGNATURE_BYTES) return false
        return try {
            val signer = Ed25519Signer()
            signer.init(false, Ed25519PublicKeyParameters(publicKey, 0))
            signer.update(message, 0, message.size)
            signer.verifySignature(signature)
        } catch (_: Exception) {
            false
        }
    }
}
