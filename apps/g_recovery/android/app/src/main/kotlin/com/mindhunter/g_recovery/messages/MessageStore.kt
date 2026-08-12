package com.mindhunter.g_recovery.messages

import android.content.Context
import org.json.JSONObject
import java.io.File

/**
 * WHERE CAPTURED MESSAGES LIVE.
 *
 * ─── A FILE, NOT A DATABASE ──────────────────────────────────────────────────
 *
 * One JSON object per line, appended. Room would bring a compiler plugin, a
 * schema, migrations and about a megabyte of dependency for a workload that is
 * append at one end, read the tail, and occasionally delete everything. There is
 * no query here more complicated than "the last N".
 *
 * ─── WRITTEN FROM A NOTIFICATION CALLBACK ────────────────────────────────────
 *
 * onNotificationPosted runs on the main thread of a system-bound service and is
 * expected to return immediately. Appending one short line to a file is well
 * inside that budget, and it is why nothing here does any parsing, sorting or
 * de-duplication on the write path. All of that happens on read.
 *
 * ─── BOUNDED ─────────────────────────────────────────────────────────────────
 *
 * Trimmed to [MAX_LINES] whenever it grows past a threshold. A message archive
 * that grows without limit on someone's phone is precisely the kind of thing
 * this app exists to help people find and delete.
 */
internal class MessageStore(context: Context) {

    private val file = File(context.applicationContext.filesDir, FILE_NAME)
    private val lock = Any()

    fun append(record: Record) {
        synchronized(lock) {
            runCatching {
                file.appendText(record.toJson().toString() + "\n")
                if (file.length() > TRIM_AT_BYTES) trimLocked()
            }
        }
    }

    /**
     * Marks a message as taken away.
     *
     * Rewrites the whole file, which sounds heavy and is not: removals are rare
     * relative to arrivals, and the file is capped at a few thousand short
     * lines. The alternative, a second log of removals merged on read, costs
     * more complexity than the write it saves.
     */
    fun markRemoved(messageId: String, atMillis: Long) {
        synchronized(lock) {
            val records = readAllLocked()
            var touched = false
            val updated = records.map { record ->
                if (record.messageId == messageId && record.removedAtMillis == null) {
                    touched = true
                    record.copy(removedAtMillis = atMillis)
                } else {
                    record
                }
            }
            if (touched) writeAllLocked(updated)
        }
    }

    fun all(): List<Record> = synchronized(lock) { readAllLocked() }

    fun clear() {
        synchronized(lock) { runCatching { file.delete() } }
    }

    fun count(): Int = synchronized(lock) { readAllLocked().size }

    private fun readAllLocked(): List<Record> {
        if (!file.exists()) return emptyList()
        return runCatching {
            file.readLines().mapNotNull { line ->
                if (line.isBlank()) null else Record.fromJson(JSONObject(line))
            }
        }.getOrDefault(emptyList())
    }

    private fun writeAllLocked(records: List<Record>) {
        runCatching {
            file.writeText(
                records.joinToString(separator = "\n") { it.toJson().toString() }
                    .plus("\n"),
            )
        }
    }

    private fun trimLocked() {
        val records = readAllLocked()
        if (records.size <= MAX_LINES) return
        writeAllLocked(records.takeLast(MAX_LINES))
    }

    /**
     * One captured message.
     *
     * [messageId] is derived from the posting app, the conversation and the
     * text, NOT from the notification's own key. A key is reused as a
     * conversation's notification is updated, so keying on it would mean each
     * new message in a chat overwrote the last one, which is exactly the history
     * this feature exists to keep.
     */
    internal data class Record(
        val messageId: String,
        val packageName: String,
        val appLabel: String,
        val conversation: String?,
        val sender: String?,
        val text: String,
        val postedAtMillis: Long,
        val removedAtMillis: Long? = null,
        val edited: Boolean = false,
    ) {
        fun toJson(): JSONObject = JSONObject().apply {
            put("id", messageId)
            put("pkg", packageName)
            put("app", appLabel)
            putOpt("conv", conversation)
            putOpt("from", sender)
            put("text", text)
            put("at", postedAtMillis)
            if (removedAtMillis != null) put("gone", removedAtMillis)
            if (edited) put("edited", true)
        }

        companion object {
            fun fromJson(json: JSONObject): Record? {
                val id = json.optString("id").takeIf { it.isNotBlank() }
                    ?: return null
                return Record(
                    messageId = id,
                    packageName = json.optString("pkg"),
                    appLabel = json.optString("app"),
                    conversation = json.optString("conv").takeIf { it.isNotBlank() },
                    sender = json.optString("from").takeIf { it.isNotBlank() },
                    text = json.optString("text"),
                    postedAtMillis = json.optLong("at"),
                    removedAtMillis =
                        if (json.has("gone")) json.optLong("gone") else null,
                    edited = json.optBoolean("edited", false),
                )
            }
        }
    }

    private companion object {
        const val FILE_NAME = "messages.jsonl"

        /** Roughly a few weeks of ordinary chat on a busy phone. */
        const val MAX_LINES = 4000

        /** Trim check, not a hard cap. Cheaper than counting lines per write. */
        const val TRIM_AT_BYTES = 1_500_000L
    }
}
