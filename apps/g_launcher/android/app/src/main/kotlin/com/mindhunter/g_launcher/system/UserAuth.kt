package com.mindhunter.g_launcher.system

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal

/**
 * "Is this the owner?" for the hidden apps lock.
 *
 * No CryptoObject: nothing is being unsealed, the launcher only wants a yes.
 * That is also why BIOMETRIC_WEAK is accepted on Android 11+, so Samsung's
 * face unlock counts, where the SSH keystore insists on STRONG.
 *
 * Every answer is a status string. The wire vocabulary is mirrored in
 * `lib/data/prefs/hidden_lock.dart`; adding one means adding it there too.
 */
object UserAuth {
    const val READY = "ready"
    const val NO_LOCK = "no_lock"
    const val UNSUPPORTED = "unsupported"
    const val OK = "ok"
    const val CANCELLED = "cancelled"
    const val LOCKOUT = "lockout"
    const val NO_WINDOW = "no_window"

    /** Whether a prompt can succeed at all on this phone right now. */
    fun availability(context: Context): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return UNSUPPORTED

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bm = context.getSystemService(BiometricManager::class.java)
                ?: return UNSUPPORTED
            return when (bm.canAuthenticate(AUTHENTICATORS)) {
                BiometricManager.BIOMETRIC_SUCCESS -> READY
                BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> NO_LOCK
                else -> UNSUPPORTED
            }
        }

        // Android 9 and 10: no canAuthenticate(authenticators). A secure
        // keyguard is the best available signal; Android 9 additionally needs
        // an enrolled biometric, which only the prompt itself can report.
        val km = context.getSystemService(KeyguardManager::class.java)
        return if (km?.isDeviceSecure == true) READY else NO_LOCK
    }

    /**
     * Show the system prompt over [activity] and answer once.
     *
     * Must be called on the main thread: the prompt is a window operation.
     */
    fun confirm(
        activity: Activity?,
        title: String,
        subtitle: String?,
        callback: (Result<String>) -> Unit,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            callback(Result.success(UNSUPPORTED))
            return
        }
        if (activity == null || activity.isFinishing || activity.isDestroyed) {
            callback(Result.success(NO_WINDOW))
            return
        }
        val available = availability(activity)
        if (available != READY) {
            callback(Result.success(available))
            return
        }

        val executor = activity.mainExecutor
        val prompt = BiometricPrompt.Builder(activity)
            .setTitle(title)
            .apply { if (subtitle != null) setSubtitle(subtitle) }
            .apply {
                when {
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.R ->
                        setAllowedAuthenticators(AUTHENTICATORS)

                    // setDeviceCredentialAllowed arrived in API 29. The same
                    // version split KeysHostApiImpl documents.
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> {
                        @Suppress("DEPRECATION")
                        setDeviceCredentialAllowed(true)
                    }

                    // Android 9: build() throws without a negative button. Its
                    // press arrives as ERROR_NEGATIVE_BUTTON below.
                    else -> setNegativeButton(
                        activity.getString(android.R.string.cancel),
                        executor,
                    ) { _, _ -> }
                }
            }
            .build()

        // Some OEM prompts call back twice when a cancel races a success, and
        // a Pigeon reply sent twice crashes the engine.
        var replied = false
        fun reply(status: String) {
            if (replied) return
            replied = true
            callback(Result.success(status))
        }

        try {
            prompt.authenticate(
                CancellationSignal(),
                executor,
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(
                        result: BiometricPrompt.AuthenticationResult,
                    ) = reply(OK)

                    override fun onAuthenticationError(code: Int, message: CharSequence?) =
                        reply(statusFor(code))

                    // onAuthenticationFailed is a misread finger: the prompt
                    // retries on its own, so it is deliberately not handled.
                },
            )
        } catch (_: Exception) {
            reply(UNSUPPORTED)
        }
    }

    private fun statusFor(code: Int): String = when (code) {
        BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT,
        BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT_PERMANENT -> LOCKOUT

        BiometricPrompt.BIOMETRIC_ERROR_HW_NOT_PRESENT,
        BiometricPrompt.BIOMETRIC_ERROR_HW_UNAVAILABLE,
        BiometricPrompt.BIOMETRIC_ERROR_NO_BIOMETRICS -> UNSUPPORTED

        // Constant added in API 29; the literal keeps API 28 compiling the
        // same branch.
        14 /* BIOMETRIC_ERROR_NO_DEVICE_CREDENTIAL */ -> NO_LOCK

        else -> CANCELLED
    }

    /** Fingerprint or face (weak is enough without crypto), or the PIN. */
    private val AUTHENTICATORS: Int
        get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            BiometricManager.Authenticators.BIOMETRIC_WEAK or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
        } else {
            0
        }
}
