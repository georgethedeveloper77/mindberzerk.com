package com.mindhunter.g_recovery.compress

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * EVERYTHING THIS APP REMEMBERS ABOUT FILES IT HAS LOOKED AT.
 *
 * ─── EXTRACTED BECAUSE THERE ARE NOW TWO WRITERS ─────────────────────────────
 *
 * This lived inside ImageCompressor and was correct while it was the only thing
 * compressing. Video writes the same record, and two classes each holding their
 * own cache over one preferences file is a lost update waiting to happen: the
 * second one to save flattens whatever the first wrote.
 *
 * One instance, handed to both.
 *
 * ─── THREE FACTS, AND THEY ARE NOT THE SAME KIND OF THING ────────────────────
 *
 * The ledger is work done and is shown to the user. The no-gain set is a note
 * to the query saying do not ask again and belongs on no screen. The codec
 * verdicts are a cache of something that can never change. Keeping them apart
 * is what stops a screen accidentally reporting one as another.
 *
 * ─── PLAIN JSON IN PREFERENCES, NOT A DATABASE ───────────────────────────────
 *
 * A few hundred rows, read whole and written whole, always from a worker. A
 * table would be the right shape at ten thousand rows and pure ceremony here.
 */
internal class CompressLedger(context: Context) {

    private val app: Context = context.applicationContext

    private fun store() =
        app.getSharedPreferences("compress_ledger", Context.MODE_PRIVATE)

    // ─────────────────────────────────────────────────────────────────────────
    // Work done
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Cached, because the candidate query tests every row against it.
     *
     * Re-reading and re-parsing the file two thousand times to draw one list is
     * the kind of thing that makes a list feel slow for no reason anybody can
     * name.
     */
    private var entries: LinkedHashMap<String, CompressedEntry>? = null

    @Synchronized
    fun all(): LinkedHashMap<String, CompressedEntry> {
        entries?.let { return it }

        val out = LinkedHashMap<String, CompressedEntry>()
        runCatching {
            val raw = store().getString("entries", null) ?: return@runCatching
            val array = JSONArray(raw)
            for (i in 0 until array.length()) {
                val o = array.getJSONObject(i)
                val id = o.optString("fileId")
                if (id.isEmpty()) continue
                out[id] = CompressedEntry(
                    fileId = id,
                    name = o.optString("name"),
                    originalBytes = o.optLong("originalBytes"),
                    newBytes = o.optLong("newBytes"),
                    whenMillis = o.optLong("whenMillis"),
                    lossless = o.optBoolean("lossless"),
                    quality = o.optLong("quality"),
                )
            }
        }
        entries = out
        return out
    }

    @Synchronized
    fun record(entry: CompressedEntry) {
        val current = all()
        current[entry.fileId] = entry

        // Oldest out first. The window that matters is the thirty days a
        // trashed original can be restored in, and a record from six months ago
        // documents a file whose original is long gone.
        while (current.size > MAX_ENTRIES) {
            val oldest = current.keys.firstOrNull() ?: break
            current.remove(oldest)
        }

        val array = JSONArray()
        for (e in current.values) {
            array.put(
                JSONObject()
                    .put("fileId", e.fileId)
                    .put("name", e.name)
                    .put("originalBytes", e.originalBytes)
                    .put("newBytes", e.newBytes)
                    .put("whenMillis", e.whenMillis)
                    .put("lossless", e.lossless)
                    .put("quality", e.quality),
            )
        }
        store().edit().putString("entries", array.toString()).apply()
    }

    /** Newest first, which is the order the screen wants and prefs do not keep. */
    fun history(limit: Int): List<CompressedEntry> = all()
        .values
        .sortedByDescending { it.whenMillis }
        .take(limit)

    fun contains(fileId: String): Boolean = all().containsKey(fileId)

    // ─────────────────────────────────────────────────────────────────────────
    // Measured and not worth it
    // ─────────────────────────────────────────────────────────────────────────

    private var skipped: MutableSet<String>? = null

    @Synchronized
    private fun noGain(): MutableSet<String> {
        skipped?.let { return it }
        val out = store()
            .getStringSet("no_gain", emptySet())
            .orEmpty()
            .toMutableSet()
        skipped = out
        return out
    }

    fun isNoGain(fileId: String): Boolean = noGain().contains(fileId)

    @Synchronized
    fun markNoGain(fileIds: List<String>) {
        if (fileIds.isEmpty()) return
        val current = noGain()
        current.addAll(fileIds)
        // A fresh copy. SharedPreferences documents the set handed to
        // putStringSet as not to be mutated afterwards, and this one is held
        // and mutated for the life of the process.
        store().edit().putStringSet("no_gain", HashSet(current)).apply()
    }

    @Synchronized
    fun clearNoGain() {
        skipped = mutableSetOf()
        store().edit().remove("no_gain").apply()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Codec verdicts
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * WHAT CODEC A VIDEO IS IN, REMEMBERED FOREVER.
     *
     * ─── AND WHY THIS HAD TO EXIST ───────────────────────────────────────────
     *
     * Reading the codec means opening a MediaExtractor on the file. That is a
     * header read rather than a decode, which is fast enough per file and not
     * remotely fast enough per library: two hundred clips is seconds of work,
     * and it was being done from summary(), which the Storage tab watches on
     * open. A tab that stalls when a phone has a lot of video is a tab that
     * looks broken on exactly the devices this feature is for.
     *
     * The codec of a file cannot change. A file is written once, and MediaStore
     * hands out a new id if it is rewritten, so a verdict is good forever and
     * the second open of the screen costs nothing.
     */
    private var codecs: MutableMap<String, String>? = null

    @Synchronized
    private fun codecMap(): MutableMap<String, String> {
        codecs?.let { return it }

        val out = mutableMapOf<String, String>()
        runCatching {
            val raw = store().getString("codecs", null) ?: return@runCatching
            val o = JSONObject(raw)
            for (key in o.keys()) out[key] = o.getString(key)
        }
        codecs = out
        return out
    }

    fun codecOf(fileId: String): String? = codecMap()[fileId]

    @Synchronized
    fun rememberCodec(fileId: String, codec: String) {
        val current = codecMap()
        if (current[fileId] == codec) return
        current[fileId] = codec

        // Bounded like the rest. A phone that has held five thousand distinct
        // videos has long since deleted most of them, and a verdict for a file
        // that no longer exists is dead weight in a file read on every open.
        if (current.size > MAX_CODECS) {
            val excess = current.size - MAX_CODECS
            current.keys.take(excess).toList().forEach(current::remove)
        }

        val o = JSONObject()
        for ((key, value) in current) o.put(key, value)
        store().edit().putString("codecs", o.toString()).apply()
    }

    private companion object {
        const val MAX_ENTRIES = 400
        const val MAX_CODECS = 2000
    }
}
