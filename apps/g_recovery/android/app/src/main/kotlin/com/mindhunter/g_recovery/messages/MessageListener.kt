package com.mindhunter.g_recovery.messages

import android.app.Notification
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.security.MessageDigest

/**
 * KEEPS THE COPY ANDROID ALREADY GAVE US.
 *
 * ─── WHAT THIS IS NOT ────────────────────────────────────────────────────────
 *
 * It does not read anybody's messages out of anybody's app. WhatsApp's database
 * is encrypted inside its own private directory and no app on an unrooted phone
 * can open it. There is no second copy of a deleted message anywhere on the
 * device to go and find.
 *
 * ─── WHAT IT IS ──────────────────────────────────────────────────────────────
 *
 * When a message arrives it becomes a notification, and the system hands this
 * service the text. That text is written down. If the sender deletes the message
 * afterwards, WhatsApp replaces the visible one with "This message was deleted",
 * and the original is still in the archive because it was captured on arrival.
 *
 * ─── THE THREE LIMITS, WHICH THE UI MUST STATE ───────────────────────────────
 *
 * Only messages that arrive after this is switched on. Only text, since a photo
 * notification says "Photo" and the image itself never leaves the sending app.
 * And nothing at all from a chat the user has muted, because a muted chat posts
 * no notification.
 *
 * ─── OFF BY DEFAULT, TWICE ───────────────────────────────────────────────────
 *
 * The system permission is one decision and archiving is another. This service
 * can be bound and still write nothing, and that is the state a user is in if
 * they granted notification access and never switched capture on.
 */
class MessageListener : NotificationListenerService() {

    private lateinit var store: MessageStore
    private lateinit var prefs: SharedPreferences

    override fun onCreate() {
        super.onCreate()
        store = MessageStore(this)
        prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val notification = sbn ?: return
        if (!prefs.getBoolean(KEY_CAPTURING, false)) return
        if (!WATCHED.contains(notification.packageName)) return

        val extras: Bundle = notification.notification.extras
        val text = extras.charSequence(Notification.EXTRA_TEXT) ?: return
        if (text.isBlank()) return

        // Group summaries repeat what the individual notifications already say,
        // so capturing them would double every message and add a line reading
        // "3 new messages" to the archive.
        val isSummary = notification.notification.flags and
            Notification.FLAG_GROUP_SUMMARY != 0
        if (isSummary) return

        // WhatsApp's own replacement text. Recording it would overwrite nothing,
        // but it would put the tombstone in the archive beside the message it
        // replaced, which is noise at the exact moment the user is looking for
        // the original.
        if (DELETION_MARKERS.any { text.equals(it, ignoreCase = true) }) {
            markEdited(notification, extras)
            return
        }

        val conversation = extras.charSequence(Notification.EXTRA_CONVERSATION_TITLE)
            ?: extras.charSequence(Notification.EXTRA_TITLE)
        val sender = extras.charSequence(Notification.EXTRA_TITLE)

        store.append(
            MessageStore.Record(
                messageId = idFor(notification.packageName, conversation, text),
                packageName = notification.packageName,
                appLabel = labelFor(notification.packageName),
                conversation = conversation,
                sender = sender,
                text = text,
                postedAtMillis = notification.postTime,
            ),
        )
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        val notification = sbn ?: return
        if (!prefs.getBoolean(KEY_CAPTURING, false)) return
        if (!WATCHED.contains(notification.packageName)) return

        val extras: Bundle = notification.notification.extras
        val text = extras.charSequence(Notification.EXTRA_TEXT) ?: return
        val conversation = extras.charSequence(Notification.EXTRA_CONVERSATION_TITLE)
            ?: extras.charSequence(Notification.EXTRA_TITLE)

        // Recorded as "taken away", never as "deleted". A notification goes when
        // the user opens the chat, swipes it off, or the sender removes the
        // message, and the system does not say which. Labelling all three as a
        // deletion would be the kind of confident wrong answer this app is built
        // against.
        store.markRemoved(
            idFor(notification.packageName, conversation, text),
            System.currentTimeMillis(),
        )
    }

    /**
     * The one signal that really does mean a deletion.
     *
     * The tombstone arrives as an update to the same conversation, so the
     * message immediately before it in that chat is the one that was removed.
     */
    private fun markEdited(sbn: StatusBarNotification, extras: Bundle) {
        val conversation = extras.charSequence(Notification.EXTRA_CONVERSATION_TITLE)
            ?: extras.charSequence(Notification.EXTRA_TITLE)
            ?: return

        val latest = store.all().lastOrNull {
            it.packageName == sbn.packageName && it.conversation == conversation
        } ?: return

        store.append(latest.copy(edited = true, messageId = latest.messageId))
    }

    private fun labelFor(packageName: String): String = when (packageName) {
        "com.whatsapp" -> "WhatsApp"
        "com.whatsapp.w4b" -> "WhatsApp Business"
        "org.telegram.messenger" -> "Telegram"
        "com.instagram.android" -> "Instagram"
        "com.facebook.orca" -> "Messenger"
        "com.google.android.apps.messaging" -> "Messages"
        else -> packageName
    }

    /**
     * A stable id from content rather than from the notification key.
     *
     * A key is REUSED as a conversation's notification is updated, so keying on
     * it would mean every new message in a chat overwrote the previous one,
     * destroying the history this feature exists to keep.
     */
    private fun idFor(packageName: String, conversation: String?, text: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest("$packageName|${conversation.orEmpty()}|$text".toByteArray())
        return digest.take(12).joinToString("") { "%02x".format(it) }
    }

    private fun Bundle.charSequence(key: String): String? =
        getCharSequence(key)?.toString()?.trim()?.takeIf { it.isNotEmpty() }

    companion object {
        const val PREFS = "messages"
        const val KEY_CAPTURING = "capturing"
        const val KEY_SINCE = "since"

        /**
         * Messaging apps only.
         *
         * A listener is given EVERY notification on the phone, including banking
         * alerts and one time codes. Narrowing at the point of capture rather
         * than at the point of display means the rest is never written down at
         * all, which is the only version of this that is defensible.
         */
        val WATCHED = setOf(
            "com.whatsapp",
            "com.whatsapp.w4b",
            "org.telegram.messenger",
            "com.instagram.android",
            "com.facebook.orca",
            "com.google.android.apps.messaging",
        )

        val DELETION_MARKERS = listOf(
            "This message was deleted",
            "You deleted this message",
            "Message deleted",
        )
    }
}
