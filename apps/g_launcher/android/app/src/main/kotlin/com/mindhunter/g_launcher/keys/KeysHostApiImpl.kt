package com.mindhunter.g_launcher.keys

import android.app.Activity
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import java.lang.ref.WeakReference
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Signature
import java.security.UnrecoverableKeyException
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec
import java.util.concurrent.Executor

/**
 * SSH keys that live in the secure element.
 *
 * ─── THE PROPERTY THIS FILE EXISTS TO HOLD ──────────────────────────────────
 *
 * The private key is generated inside the keystore and is NON-EXTRACTABLE. No
 * method here returns it, and none could: `KeyStore.getKey` hands back a handle
 * whose `getEncoded()` is null by construction.
 *
 * That matters for what happens after a compromise rather than before one. A
 * software key can be taken and used from anywhere, indefinitely, silently,
 * long after the phone is wiped. This one cannot be taken at all: signatures
 * happen inside the secure element, only while an attacker is resident on the
 * device, and only when a person approves each one.
 *
 * ─── WHY THE PLATFORM BiometricPrompt AND NOT androidx ──────────────────────
 *
 * `androidx.biometric.BiometricPrompt` requires a `FragmentActivity`, and
 * `LauncherActivity` extends `FlutterActivity`, which extends `Activity`.
 * Migrating the home activity of a launcher, with its widget stage, transparent
 * surface and gesture arbitration, to gain a dialog is a poor trade.
 *
 * The platform class takes any Activity and carries a `CryptoObject` the same
 * way. It arrived in API 28; this app's `minSdk` is 26, so API 26 and 27 are
 * told plainly that they cannot hold a key of this kind rather than being given
 * a silently weaker one.
 */
class KeysHostApiImpl(private val executor: Executor) : KeysHostApi {

    /**
     * WEAK, and for the same reason [LauncherHostApiImpl] holds one: this object
     * outlives any Activity, and a strong reference would leak the whole window
     * on every rotation.
     */
    private var activityRef: WeakReference<Activity>? = null

    fun attachActivity(activity: Activity) {
        activityRef = WeakReference(activity)
    }

    /**
     * Identity-checked. On a configuration change the replacement Activity's
     * onCreate has ALREADY run, so an unconditional clear here would throw away
     * the reference just handed over.
     */
    fun detachActivity(activity: Activity) {
        if (activityRef?.get() === activity) activityRef = null
    }

    private val keyStore: KeyStore
        get() = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }

    override fun listKeys(): List<String> {
        val out = mutableListOf<String>()
        val aliases = keyStore.aliases()
        while (aliases.hasMoreElements()) {
            val alias = aliases.nextElement()
            if (alias.startsWith(PREFIX)) out.add(alias.removePrefix(PREFIX))
        }
        return out.sorted()
    }

    override fun publicKey(alias: String): KeyInfo? {
        val cert = keyStore.getCertificate(PREFIX + alias) ?: return null
        val pub = cert.publicKey as? ECPublicKey ?: return null
        return info(alias, pub, hardware = isHardwareBacked(alias), strongBox = false)
    }

    override fun generateKey(alias: String): KeyResult {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            return failure(
                KeyFailure.UNSUPPORTED_PLATFORM,
                "This device is too old to hold a key behind a fingerprint. " +
                    "Android 9 or newer is needed.",
            )
        }

        if (keyStore.containsAlias(PREFIX + alias)) {
            return failure(KeyFailure.UNKNOWN, "A key called \"$alias\" already exists.")
        }

        // StrongBox FIRST, then the TEE. Most phones have a TEE and far fewer
        // have StrongBox, and a generate that simply fails on a mid-range device
        // is worse than one that quietly lands in the TEE. Which one it got is
        // reported, because it is the difference between two security claims.
        return try {
            generate(alias, strongBox = true)
        } catch (_: StrongBoxUnavailableException) {
            try {
                generate(alias, strongBox = false)
            } catch (e: Exception) {
                failure(KeyFailure.UNKNOWN, e.message ?: "Could not create the key.")
            }
        } catch (e: Exception) {
            failure(KeyFailure.UNKNOWN, e.message ?: "Could not create the key.")
        }
    }

    private fun generate(alias: String, strongBox: Boolean): KeyResult {
        val builder = KeyGenParameterSpec.Builder(
            PREFIX + alias,
            KeyProperties.PURPOSE_SIGN,
        )
            .setAlgorithmParameterSpec(ECGenParameterSpec(CURVE))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setUserAuthenticationRequired(true)
            // Enrolling a new fingerprint DESTROYS this key. That is the right
            // default: it means a key cannot be used by whoever added their own
            // finger to the device. The cost is copy explaining it, which the
            // caller owns.
            .setInvalidatedByBiometricEnrollment(true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // 0 seconds means PER USE, which is what makes a CryptoObject
            // mandatory and therefore meaningful. A non-zero timeout would
            // authenticate once and then sign freely for the window, silently
            // weaker than intended and impossible to notice.
            builder.setUserAuthenticationParameters(
                0,
                KeyProperties.AUTH_BIOMETRIC_STRONG or
                    KeyProperties.AUTH_DEVICE_CREDENTIAL,
            )
        } else {
            // The deprecated spelling of the same thing, and the only one that
            // exists on API 28 and 29. -1 is per use.
            @Suppress("DEPRECATION")
            builder.setUserAuthenticationValidityDurationSeconds(-1)
        }

        if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            builder.setIsStrongBoxBacked(true)
        }

        val generator = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC,
            ANDROID_KEYSTORE,
        )
        generator.initialize(builder.build())
        val pair = generator.generateKeyPair()
        val pub = pair.public as ECPublicKey

        return KeyResult(
            info = info(
                alias,
                pub,
                hardware = isHardwareBacked(alias),
                strongBox = strongBox,
            ),
        )
    }

    override fun deleteKey(alias: String): Boolean {
        val full = PREFIX + alias
        if (!keyStore.containsAlias(full)) return false
        keyStore.deleteEntry(full)
        return true
    }

    override fun sign(
        alias: String,
        challenge: ByteArray,
        callback: (Result<KeyResult>) -> Unit,
    ) {
        val activity = activityRef?.get()
        if (activity == null) {
            callback(Result.success(failure(KeyFailure.UNKNOWN, "No window to prompt in.")))
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            callback(Result.success(failure(KeyFailure.UNSUPPORTED_PLATFORM, "Android 9 or newer is needed.")))
            return
        }

        val signature: Signature
        try {
            val key = keyStore.getKey(PREFIX + alias, null) as? PrivateKey
            if (key == null) {
                callback(Result.success(failure(KeyFailure.UNKNOWN, "No key called \"$alias\".")))
                return
            }
            signature = Signature.getInstance(ALGORITHM)
            // initSign BEFORE the prompt. The CryptoObject has to wrap an
            // already-initialised Signature, and calling update on a per-use key
            // without authenticating throws UserNotAuthenticatedException.
            signature.initSign(key)
        } catch (_: KeyPermanentlyInvalidatedException) {
            callback(
                Result.success(
                    failure(
                        KeyFailure.INVALIDATED_BY_ENROLLMENT,
                        "This key was destroyed when a new fingerprint was added. " +
                            "Generate a new one and remove the old line from " +
                            "authorized_keys.",
                    ),
                ),
            )
            return
        } catch (_: UnrecoverableKeyException) {
            callback(
                Result.success(
                    failure(
                        KeyFailure.NO_AUTHENTICATION_CONFIGURED,
                        "No screen lock is set up, so a protected key cannot be used.",
                    ),
                ),
            )
            return
        } catch (e: Exception) {
            callback(Result.success(failure(KeyFailure.UNKNOWN, e.message ?: "Could not use the key.")))
            return
        }

        val cancellation = CancellationSignal()

        val prompt = BiometricPrompt.Builder(activity)
            .setTitle("Unlock SSH key")
            .setSubtitle(alias)
            // The device credential fallback, so a person whose fingerprint is
            // not reading can still get in with their PIN. Without it a wet
            // thumb locks someone out of their own server.
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    setAllowedAuthenticators(
                        android.hardware.biometrics.BiometricManager.Authenticators.BIOMETRIC_STRONG or
                            android.hardware.biometrics.BiometricManager.Authenticators.DEVICE_CREDENTIAL,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    setDeviceCredentialAllowed(true)
                }
            }
            .build()

        // Guards against the platform calling back twice, which some OEM
        // implementations do on a cancel that races a success. A Pigeon reply
        // sent twice is a crash in the engine, not a warning.
        var replied = false
        fun reply(result: KeyResult) {
            if (replied) return
            replied = true
            callback(Result.success(result))
        }

        prompt.authenticate(
            BiometricPrompt.CryptoObject(signature),
            cancellation,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    result: BiometricPrompt.AuthenticationResult,
                ) {
                    try {
                        val sig = result.cryptoObject?.signature ?: signature
                        sig.update(challenge)
                        // ASN.1 DER. Converted to the SSH wire form in Dart,
                        // where the mpint rules are pinned to fixed vectors.
                        reply(KeyResult(signature = sig.sign()))
                    } catch (e: Exception) {
                        reply(failure(KeyFailure.UNKNOWN, e.message ?: "Signing failed."))
                    }
                }

                override fun onAuthenticationError(code: Int, message: CharSequence?) {
                    // A dismissal is a CANCEL, not an error. The caller shows
                    // nothing for it, because someone who backed out of a prompt
                    // knows what they did.
                    reply(failure(KeyFailure.CANCELLED, message?.toString()))
                }

                // onAuthenticationFailed is deliberately not overridden: a
                // finger the sensor did not recognise is a retry, and the prompt
                // handles it. Replying here would end the operation on the first
                // bad read.
            },
        )
    }

    private fun info(
        alias: String,
        pub: ECPublicKey,
        hardware: Boolean,
        strongBox: Boolean,
    ) = KeyInfo(
        alias = alias,
        // RAW coordinates, sign byte and all. Normalising to 32 bytes happens in
        // Dart, where it is tested against fixed vectors rather than discovered
        // against a server that rejects one key in 256.
        x = pub.w.affineX.toByteArray(),
        y = pub.w.affineY.toByteArray(),
        hardwareBacked = hardware,
        strongBoxBacked = strongBox,
        createdAtMillis = System.currentTimeMillis(),
    )

    /**
     * Whether the key really is in hardware.
     *
     * Asked rather than assumed. A key generated with StrongBox requested can
     * still land in the TEE, and on an emulator it lands in software entirely,
     * so reporting the request rather than the result would be a security claim
     * that happens to be false.
     */
    private fun isHardwareBacked(alias: String): Boolean = try {
        val key = keyStore.getKey(PREFIX + alias, null)
        val factory = java.security.KeyFactory.getInstance(
            key.algorithm,
            ANDROID_KEYSTORE,
        )
        val spec = factory.getKeySpec(key, android.security.keystore.KeyInfo::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            spec.securityLevel != android.security.keystore.KeyProperties.SECURITY_LEVEL_SOFTWARE
        } else {
            @Suppress("DEPRECATION")
            spec.isInsideSecureHardware
        }
    } catch (_: Exception) {
        false
    }

    private fun failure(failure: KeyFailure, message: String?) =
        KeyResult(failure = failure, message = message)

    companion object {
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"

        /**
         * Namespaced, so this app's SSH keys cannot be confused with anything
         * else it might one day put in the keystore, and so [listKeys] can
         * enumerate them without returning entries it does not own.
         */
        private const val PREFIX = "gl_ssh_"

        private const val CURVE = "secp256r1"
        private const val ALGORITHM = "SHA256withECDSA"
    }
}
