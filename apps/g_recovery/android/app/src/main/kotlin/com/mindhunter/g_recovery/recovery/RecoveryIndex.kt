package com.mindhunter.g_recovery.recovery

import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

/**
 * Native-side record of everything a scan found, keyed by an opaque id.
 *
 * The id is opaque BY DESIGN. A MediaStore row and a loose file need completely
 * different restore paths, and encoding that difference into a string the UI can
 * read invites a caller to branch on it in Dart. Native holds the record; Dart
 * hands the id back and gets an outcome.
 *
 * ConcurrentHashMap because the scan writes from a worker thread while the UI
 * reads pages through the bridge on the platform thread. Since the background
 * service arrived there are two writers rather than one, from two components
 * that never see each other, which makes the concurrent map load-bearing rather
 * than merely careful.
 */
internal class RecoveryIndex {

    companion object {
        /**
         * THE ONE INDEX, for the whole process.
         *
         * The service and the Flutter engine are separate components with
         * separate lifetimes in a single process. Two indexes would mean a scan
         * that finished in the background was invisible to the UI that came back
         * afterwards, which is precisely the case the service exists to serve.
         *
         * Process death still empties it. That is honest rather than a gap: a
         * killed process has no scan results, and the app rescans rather than
         * showing a list of files that may no longer be there.
         */
        val shared = RecoveryIndex()
    }

    internal sealed class Record {
        abstract val item: RecoverableItem

        /** A row in MediaStore with IS_TRASHED set. Restored in place. */
        data class Media(override val item: RecoverableItem, val mediaId: Long) : Record()

        /** A loose file inside a trash or cache directory. Restored by copy. */
        data class Loose(override val item: RecoverableItem, val file: File) : Record()
    }

    private val records = ConcurrentHashMap<String, Record>()
    private val order = ConcurrentHashMap<String, MutableList<String>>()
    private val counter = AtomicLong(0)

    fun clear(sourceId: String) {
        order.remove(sourceId)?.forEach(records::remove)
    }

    fun clearAll() {
        records.clear()
        order.clear()
    }

    fun mintId(prefix: String): String = "$prefix:${counter.incrementAndGet()}"

    fun put(sourceId: String, record: Record) {
        records[record.item.itemId] = record
        order.getOrPut(sourceId) { mutableListOf() }.add(record.item.itemId)
    }

    fun get(itemId: String): Record? = records[itemId]

    fun remove(itemId: String) {
        records.remove(itemId)
        order.values.forEach { it.remove(itemId) }
    }

    fun count(sourceId: String): Int = order[sourceId]?.size ?: 0

    fun bytes(sourceId: String): Long =
        order[sourceId]?.sumOf { records[it]?.item?.sizeBytes ?: 0L } ?: 0L

    /**
     * A page, newest deleted first, then largest first for items with no
     * deletion date.
     *
     * Sorted on read rather than on insert because a scan streams results and
     * re-sorting a growing list on every find is quadratic on a device with
     * thirty thousand thumbnails.
     */
    fun page(sourceId: String, offset: Int, limit: Int): List<RecoverableItem> {
        val ids = order[sourceId] ?: return emptyList()
        val all = ids.mapNotNull { records[it]?.item }
            .sortedWith(
                compareByDescending<RecoverableItem> { it.dateDeletedMillis ?: 0L }
                    .thenByDescending { it.sizeBytes }
            )
        if (offset >= all.size) return emptyList()
        return all.subList(offset, minOf(offset + limit, all.size))
    }

    fun expiringSoon(): Int = records.values.count {
        val days = it.item.expiresInDays
        days != null && days <= 2
    }

    fun countOfKind(kind: String): Int =
        records.values.count { it.item.kind == kind }

    /**
     * Name match across everything found so far.
     *
     * Case-insensitive substring, not fuzzy. A user searching for "invoice"
     * expects the file called invoice, and a fuzzy match that also returns
     * "invite" costs more trust than it buys convenience.
     */
    fun searchByName(needle: String, limit: Int): List<RecoverableItem> =
        records.values
            .map { it.item }
            .filter { it.name.lowercase().contains(needle) }
            .sortedWith(
                compareByDescending<RecoverableItem> { it.dateDeletedMillis ?: 0L }
                    .thenByDescending { it.sizeBytes }
            )
            .take(limit)

    fun totalItems(): Int = records.size

    fun totalBytes(): Long = records.values.sumOf { it.item.sizeBytes }
}
