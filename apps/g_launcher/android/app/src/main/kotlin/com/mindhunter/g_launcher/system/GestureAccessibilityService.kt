package com.mindhunter.g_launcher.system

import android.accessibilityservice.AccessibilityService
import android.os.Build
import android.view.accessibility.AccessibilityEvent

/**
 * The ONLY way a launcher can pull down the notification shade or lock the
 * screen. Android provides no other API — not for third parties.
 *
 * This service reads no screen content and receives no events (see
 * accessibility_service_config.xml: no event types, no packages, no
 * canRetrieveWindowContent). It exists purely as a handle for
 * performGlobalAction. That restraint is not cosmetic: the config file is what
 * the OS shows the user, and it is what makes the permission prompt honest.
 *
 * It is still the single biggest "do you trust this app" moment we ask for, so
 * it stays strictly opt-in and every gesture that needs it degrades to a no-op
 * when it is off — never a crash, never a nag.
 */
class GestureAccessibilityService : AccessibilityService() {

    companion object {
        /**
         * Set on connect, cleared on destroy. The host API reaches through this
         * to fire global actions.
         */
        @Volatile
        var instance: GestureAccessibilityService? = null
            private set

        const val ACTION_NOTIFICATIONS = "notifications"
        const val ACTION_QUICK_SETTINGS = "quickSettings"
        const val ACTION_LOCK_SCREEN = "lockScreen"
        const val ACTION_RECENTS = "recents"
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    /** Returns false when the action is unsupported on this OS version. */
    fun perform(action: String): Boolean = when (action) {
        ACTION_NOTIFICATIONS -> performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS)
        ACTION_QUICK_SETTINGS -> performGlobalAction(GLOBAL_ACTION_QUICK_SETTINGS)
        ACTION_RECENTS -> performGlobalAction(GLOBAL_ACTION_RECENTS)
        ACTION_LOCK_SCREEN ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                performGlobalAction(GLOBAL_ACTION_LOCK_SCREEN)
            } else {
                false
            }
        else -> false
    }

    // We subscribe to nothing, so these never fire. Required overrides.
    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit
    override fun onInterrupt() = Unit
}
