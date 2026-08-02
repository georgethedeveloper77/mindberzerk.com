package com.mindhunter.g_launcher.system

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.UserManager
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Notification badges: the count of live notifications per app, pushed to Dart.
 *
 * ─── WHY THIS IS NOT A PIGEON API ───────────────────────────────────────────
 *
 * Every other native surface in this app goes through Pigeon, and this one
 * deliberately does not.
 *
 * Pigeon generates one codec per schema and assigns ids to classes and enums by
 * their position in the file, so `launcher_api.dart` carries ids a shipped APK
 * already agrees on. Appending a method is safe; the danger is that a badge
 * feature naturally wants a "dot or count or none" enum, and adding a third
 * enum to that schema renumbers every existing class. `pack_api.dart` exists as
 * its own schema for exactly this reason, and its header says so at length.
 *
 * A plain MethodChannel needs no schema at all. It is also what the app already
 * does for the other thing the system pushes at it unprompted: `home_press` in
 * LauncherActivity is a BasicMessageChannel for the same reason.
 *
 * ─── WHAT THE USER HAS TO GRANT, AND WHY IT IS NOT A RUNTIME PERMISSION ─────
 *
 * Reading notifications is not a `requestPermissions` prompt. Android gates it
 * behind a full-page settings screen with a scary confirmation dialog, because
 * a notification listener can read the CONTENT of every notification on the
 * phone. There is no way to ask for less.
 *
 * This service reads none of it. It counts, and it counts by package. Nothing
 * here touches a title, a body, a sender or an image, and nothing is stored.
 * That is worth saying in the UI when we ask, because the system dialog is
 * going to imply the opposite and the honest answer is a good one.
 *
 * Until it is granted, `getActiveNotifications` is never called and Dart simply
 * receives no badges. Never a crash, never a nag, which is the same contract
 * the accessibility-gated gestures already live under.
 */
class NotificationBadgeService : NotificationListenerService() {

    /**
     * Connected means the user granted access AND the system has bound us.
     * Recomputing here is what makes a fresh grant show badges immediately
     * rather than on the next notification, which on a quiet phone could be
     * an hour and would read as the permission not having worked.
     */
    override fun onListenerConnected() {
        super.onListenerConnected()
        BadgeBridge.attachService(this)
        publish()
    }

    override fun onListenerDisconnected() {
        BadgeBridge.detachService(this)
        // Clear rather than leave the last counts on screen. Access was revoked
        // or the service was unbound, so every number we hold is now a claim we
        // cannot support.
        BadgeBridge.publish(emptyMap())
        super.onListenerDisconnected()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) = publish()

    override fun onNotificationRemoved(sbn: StatusBarNotification?) = publish()

    /**
     * Recount from scratch on every change rather than incrementing.
     *
     * Tempting to keep a running tally and adjust it, and wrong: posted and
     * removed callbacks can be missed while the service is unbound, an update
     * to an existing notification posts again with the same key, and a group
     * summary appears and disappears on its own schedule. A tally drifts, and a
     * badge that says three when there is one is worse than no badge.
     *
     * `getActiveNotifications` is a cheap binder call over a list that is
     * almost always short, and it is the only source that cannot be wrong.
     */
    private fun publish() {
        val active = try {
            activeNotifications
        } catch (_: SecurityException) {
            // Racing a revoke. Not an error worth logging every time.
            return
        } ?: return

        val users = getSystemService(Context.USER_SERVICE) as? UserManager
        val counts = HashMap<String, Int>()

        for (sbn in active) {
            if (!countable(sbn)) continue

            // Keyed to match AppEntry exactly. A work-profile app is a
            // DIFFERENT entry in the drawer with the same package name, and
            // badging both from one count would put the work chat's unread
            // number on the personal one.
            val serial = users?.getSerialNumberForUser(sbn.user) ?: 0L
            val key = "${sbn.packageName}#$serial"
            counts[key] = (counts[key] ?: 0) + 1
        }

        BadgeBridge.publish(counts)
    }

    /**
     * What counts as an unread thing.
     *
     * Three exclusions, each of which would otherwise put a permanent badge on
     * an app that has nothing to tell you:
     *
     *  - ONGOING notifications are a music player, a download, a VPN, a
     *    navigation session. They are a status, not a message, and they never
     *    go away on their own, so badging them means a number that can never
     *    be cleared.
     *  - GROUP SUMMARIES are the collapsed header over a set of notifications
     *    that are ALSO in this list. Counting both double-counts every
     *    conversation in a messaging app.
     *  - NON-CLEARABLE ones the user cannot dismiss, for the same reason as
     *    ongoing: a badge you cannot get rid of by doing anything is not
     *    information, it is a defect the user will report.
     */
    private fun countable(sbn: StatusBarNotification): Boolean {
        if (sbn.isOngoing) return false
        if (!sbn.isClearable) return false
        val flags = sbn.notification?.flags ?: return false
        if (flags and Notification.FLAG_GROUP_SUMMARY != 0) return false
        return true
    }
}

/**
 * The one place Dart and the listener service meet.
 *
 * An object rather than an injected dependency because the two halves have
 * lifecycles that do not line up and neither one can own the other. The service
 * is constructed by the SYSTEM, whenever it feels like it, and destroyed the
 * same way; the channel belongs to the Flutter engine, which LauncherApplication
 * warms at process start. Either can exist without the other.
 *
 * So both register here and this holds the last known counts. A service that
 * connects before Dart is listening publishes into the cache; Dart asks for it
 * on start and gets the current answer rather than waiting for the next
 * notification to arrive.
 */
object BadgeBridge {

    const val CHANNEL = "g_launcher/notifications"

    private var channel: MethodChannel? = null
    private var service: NotificationBadgeService? = null

    /** The last published counts, keyed "packageName#userSerial". */
    private var counts: Map<String, Int> = emptyMap()

    fun setUp(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        val ch = MethodChannel(messenger, CHANNEL)

        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                // Whether the user has granted notification access. Read from
                // the system's own list rather than from a flag we keep,
                // because it can be revoked in Settings at any time and we are
                // not told.
                "isEnabled" -> result.success(isEnabled(app))

                // The full-page grant screen. There is no dialog form of this.
                "openSettings" -> {
                    openSettings(app)
                    result.success(null)
                }

                // Dart asking for the current state, on start or after coming
                // back from the settings screen. Answers from the cache when
                // the service is not bound, which is the honest empty map.
                "refresh" -> {
                    service?.let { result.success(counts) } ?: result.success(counts)
                }

                else -> result.notImplemented()
            }
        }

        channel = ch

        // A service that connected before the engine warmed has already cached
        // its counts. Hand them over rather than making Dart wait.
        if (counts.isNotEmpty()) push(counts)
    }

    fun attachService(s: NotificationBadgeService) {
        service = s
    }

    fun detachService(s: NotificationBadgeService) {
        if (service === s) service = null
    }

    fun publish(next: Map<String, Int>) {
        if (next == counts) return
        counts = next
        push(next)
    }

    private fun push(next: Map<String, Int>) {
        val ch = channel ?: return
        // The channel is not thread safe and this arrives on the service's own
        // thread. Posting to the main looper is not optional here.
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            ch.invokeMethod("badges", next)
        }
    }

    /**
     * Is our listener in the system's enabled list?
     *
     * The stored setting is a colon-separated list of flattened component
     * names, and the correct test is on the COMPONENT rather than on the
     * package: a `contains(packageName)` check is the common shortcut and it
     * returns true for any app whose package name happens to contain ours as a
     * substring.
     */
    fun isEnabled(context: Context): Boolean {
        val me = ComponentName(context, NotificationBadgeService::class.java)
        val raw = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false

        return raw.split(':').any {
            val c = ComponentName.unflattenFromString(it)
            c != null && c == me
        }
    }

    fun openSettings(context: Context) {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            // Launched from an application context in some paths, and a
            // non-Activity context cannot start an Activity without this.
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (_: Exception) {
            // A handful of OEM builds do not expose the screen. Falling back to
            // the app's own settings page is better than a crash, and better
            // than nothing happening when the user taps Allow.
            try {
                context.startActivity(
                    Intent(Settings.ACTION_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            } catch (_: Exception) {
            }
        }
    }
}
