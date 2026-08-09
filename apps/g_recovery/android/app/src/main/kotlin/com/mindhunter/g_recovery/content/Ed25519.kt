package com.mindhunter.g_recovery.content

import org.bouncycastle.crypto.params.Ed25519PublicKeyParameters
import org.bouncycastle.crypto.signers.Ed25519Signer

/**
 * PORT OF `g_launcher/crypto/Ed25519.kt`, unchanged in behaviour.
 *
 * Duplicated rather than shared, and that is a decision worth defending. Making
 * it shared means a Kotlin library module both apps depend on, which is a build
 * graph change for thirty lines of code. Duplicating a verify that has no
 * branches, no state and one documented contract is cheaper than coupling two
 * shipping apps through a new module. If a third app appears, extract it then.
 *
 * BouncyCastle's low-level API, not `Signature.getInstance("Ed25519")`: the
 * platform one is API 33+ and this app's floor is 30. No `Security.addProvider`
 * either, because registering a JCE provider fights Conscrypt on several OEM
 * ROMs. One code path, every device, always exercised.
 *
 * NO `android.*` IMPORTS, which is what keeps every caller unit-testable on a
 * plain JVM.
 */
internal object Ed25519 {

    const val SIGNATURE_BYTES = 64
    const val PUBLIC_KEY_BYTES = 32

    /**
     * NEVER THROWS. A malformed key, a truncated signature and a valid but
     * wrong signature all mean the same thing to the caller, and a downloaded
     * file must not be able to crash the app by being badly formed. Every
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
