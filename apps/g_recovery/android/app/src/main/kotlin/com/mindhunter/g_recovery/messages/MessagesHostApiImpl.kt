package com.mindhunter.g_recovery.messages

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors

/**
 * The bridge for the message archive.
 *
 * Same contract as the recovery bridge: work on a worker, replies on the main
 * looper, and nothing above this line ever sees a Kotlin exception.
 */
internal class MessagesHostApiImpl(context: Context) : MessagesHostApi {

    private val app: Context = context.applicationContext
    private val store = MessageStore(app)
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private val prefs =
        app.getSharedPreferences(MessageListener.PREFS, Context.MODE_PRIVATE)

    fun dispose() {
        worker.shutdownNow()
    }

    override fun captureState(callback: (Result<MessageCapture>) -> Unit) {
        worker.execute {
            val records = store.all()
            reply(
                callback,
                MessageCapture(
                    listenerEnabled = listenerEnabled(),
                    capturing = prefs.getBoolean(MessageListener.KEY_CAPTURING, false),
                    messageCount = records.size.toLong(),
                    conversationCount = records
                        .mapNotNull { it.conversation }
                        .distinct()
                        .size
                        .toLong(),
                    since = prefs.getLong(MessageListener.KEY_SINCE, 0L)
                        .takeIf { it > 0L },
                ),
            )
        }
    }

    override fun openListenerSettings(callback: (Result<Boolean>) -> Unit) {
        // Not on the worker. This resolves an Activity and the caller is waiting
        // on a yes or no rather than on work.
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val ok = runCatching {
            app.startActivity(intent)
            true
        }.getOrDefault(false)
        main.post { callback(Result.success(ok)) }
    }

    override fun setCapturing(value: Boolean, callback: (Result<Unit>) -> Unit) {
        worker.execute {
            prefs.edit().putBoolean(MessageListener.KEY_CAPTURING, value).apply()
            // Stamped the first time it is switched on and never moved after.
            // This is the honest edge of the archive: everything older simply
            // was not captured, and the UI says so rather than showing a gap.
            if (value && prefs.getLong(MessageListener.KEY_SINCE, 0L) == 0L) {
                prefs.edit()
                    .putLong(MessageListener.KEY_SINCE, System.currentTimeMillis())
                    .apply()
            }
            reply(callback, Unit)
        }
    }

    override fun messages(
        conversation: String?,
        limit: Long,
        callback: (Result<List<ArchivedMessage>>) -> Unit,
    ) {
        worker.execute {
            val out = store.all()
                .asReversed()
                .asSequence()
                .filter { conversation == null || it.conversation == conversation }
                .take(limit.toInt().coerceAtLeast(1))
                .map { record ->
                    ArchivedMessage(
                        messageId = record.messageId,
                        packageName = record.packageName,
                        appLabel = record.appLabel,
                        conversation = record.conversation,
                        sender = record.sender,
                        text = record.text,
                        postedAtMillis = record.postedAtMillis,
                        removedAtMillis = record.removedAtMillis,
                        edited = record.edited,
                    )
                }
                .toList()
            reply(callback, out)
        }
    }

    override fun conversations(callback: (Result<List<String>>) -> Unit) {
        worker.execute {
            // Newest activity first, which is the order every messaging app
            // uses and the only one a person can navigate without reading.
            val seen = LinkedHashSet<String>()
            store.all().asReversed().forEach { record ->
                record.conversation?.let(seen::add)
            }
            reply(callback, seen.toList())
        }
    }

    override fun clear(callback: (Result<Unit>) -> Unit) {
        worker.execute {
            store.clear()
            reply(callback, Unit)
        }
    }

    /**
     * Whether this app is in the system's enabled listener list.
     *
     * Read from Secure settings rather than kept as a flag. The user can revoke
     * notification access at any moment from a settings screen this app never
     * sees, so any cached answer is a guess.
     */
    private fun listenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(
            app.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        val me = ComponentName(app, MessageListener::class.java)
        return flat.split(":").any {
            val parsed = ComponentName.unflattenFromString(it)
            parsed != null && parsed.packageName == me.packageName
        }
    }

    private fun <T> reply(callback: (Result<T>) -> Unit, value: T) {
        main.post { callback(Result.success(value)) }
    }
}
