package com.mindhunter.g_recovery.recovery

import android.content.Context
import android.os.Handler
import android.os.Looper
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * The bridge implementation.
 *
 * THREADING, because it is the part that goes wrong silently. A scan walks
 * shared storage and can take tens of seconds; running it on the platform thread
 * freezes the UI and eventually trips an ANR. So every call is dispatched to a
 * single worker and every Pigeon callback is posted back to the main looper,
 * which is where Flutter requires them.
 *
 * A SINGLE worker, not a pool. Two concurrent scans over the same index would
 * interleave writes and double-count, and disk is the bottleneck anyway.
 */
internal class RecoveryHostApiImpl(context: Context) : RecoveryHostApi {

    private val app: Context = context.applicationContext
    private val worker: ExecutorService = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private val access = Access(app)
    private val index = RecoveryIndex()
    private val mediaScanner = MediaTrashScanner(app)
    private val liveSearcher = LiveFileSearcher(app)
    private val thumbnailer = Thumbnailer(app)
    private val fileScanner = FileTrashScanner()
    private val restorer = Restorer(app)

    private var trashMap: TrashMap = TrashMap.empty
    private val cancelled = AtomicBoolean(false)

    private var flutterApi: RecoveryFlutterApi? = null

    /** Throttles progress so a fast source cannot flood the channel. */
    private var lastProgressAt = 0L

    fun attachFlutterApi(api: RecoveryFlutterApi) {
        flutterApi = api
    }

    fun dispose() {
        cancelled.set(true)
        worker.shutdownNow()
        flutterApi = null
    }

    override fun setTrashMap(json: String, callback: (Result<Unit>) -> Unit) {
        worker.execute {
            trashMap = TrashMap.parse(json)
            reply(callback, Unit)
        }
    }

    override fun access(callback: (Result<RecoveryAccess>) -> Unit) {
        worker.execute {
            val granted = access.isGranted()
            reply(
                callback,
                RecoveryAccess(
                    allFilesAccess = granted,
                    canSeeOtherAppsTrash = granted,
                    storageManagerAvailable = access.isSettingsAvailable(),
                ),
            )
        }
    }

    override fun requestAllFilesAccess(callback: (Result<Boolean>) -> Unit) {
        // Not on the worker: startActivity from a background thread is legal but
        // the resolve check touches PackageManager and the caller is waiting on a
        // yes or no, not on work.
        reply(callback, access.openSettings())
    }

    /**
     * Counts only, and it must stay that way.
     *
     * This runs while the user is choosing a theme in onboarding, so that home
     * opens populated instead of on a spinner. A directory walk here would make
     * the theme picker janky on exactly the budget devices this targets.
     */
    override fun prescan(callback: (Result<RecoverySummary>) -> Unit) {
        worker.execute {
            val granted = access.isGranted()
            val media = if (granted) mediaScanner.count() else MediaTrashScanner.Tally()
            val thumbnails = fileScanner.countThumbnails(trashMap)

            val sources = listOf(
                RecoverySource(
                    sourceId = SourceIds.MEDIA_TRASH,
                    label = "System trash",
                    fidelity = "full",
                    available = granted,
                    itemCount = media.items.toLong(),
                    totalBytes = media.bytes,
                    detail = if (granted) {
                        "Original files, restored to their own folder"
                    } else {
                        "Needs file access. Without it Android hides every other app's deleted files."
                    },
                    retentionDays = 30,
                ),
                RecoverySource(
                    sourceId = SourceIds.APP_TRASH,
                    label = "App trash folders",
                    fidelity = "full",
                    available = granted,
                    itemCount = 0,
                    totalBytes = 0,
                    detail = if (granted) "Scan to see what is here" else "Needs file access",
                    retentionDays = null,
                ),
                RecoverySource(
                    sourceId = SourceIds.THUMBNAILS,
                    label = "Thumbnail cache",
                    fidelity = "preview",
                    available = true,
                    itemCount = thumbnails.first.toLong(),
                    totalBytes = thumbnails.second,
                    detail = "The original is gone. What is left is the small preview Android kept.",
                    retentionDays = null,
                ),
            )

            reply(
                callback,
                RecoverySummary(
                    sources = sources,
                    totalItems = (media.items + thumbnails.first).toLong(),
                    totalBytes = media.bytes + thumbnails.second,
                    expiringSoonItems = 0,
                    imageCount = media.images.toLong(),
                    videoCount = media.videos.toLong(),
                    audioCount = media.audio.toLong(),
                    documentCount = media.documents.toLong(),
                    // Thumbnails are folded in here rather than into images.
                    // They ARE images, but a tile reading "141 photos" that is
                    // mostly 512 px previews would be the exact overclaim this
                    // app refuses to make. Home surfaces them as their own row.
                    otherCount = (media.other + thumbnails.first).toLong(),
                    // The flag that stops the pre-scan from lying. Before the
                    // grant these numbers are a floor, not a total, and the UI
                    // has to say so rather than presenting them as the answer.
                    partial = !granted,
                ),
            )
        }
    }

    override fun scan(sourceIds: List<String>, callback: (Result<RecoverySummary>) -> Unit) {
        cancelled.set(false)
        worker.execute {
            val granted = access.isGranted()
            val wanted = sourceIds.toSet()
            val sources = mutableListOf<RecoverySource>()

            if (SourceIds.MEDIA_TRASH in wanted) {
                index.clear(SourceIds.MEDIA_TRASH)
                if (granted) {
                    mediaScanner.scan(
                        index = index,
                        sourceId = SourceIds.MEDIA_TRASH,
                        isCancelled = cancelled::get,
                    ) { scanned, total ->
                        emitProgress(SourceIds.MEDIA_TRASH, scanned, total)
                    }
                }
                sources.add(
                    source(
                        SourceIds.MEDIA_TRASH,
                        "System trash",
                        "full",
                        granted,
                        if (granted) "Original files, restored to their own folder"
                        else "Needs file access",
                        30,
                    )
                )
            }

            if (SourceIds.APP_TRASH in wanted) {
                index.clear(SourceIds.APP_TRASH)
                if (granted) {
                    fileScanner.scanEntries(
                        entries = trashMap.fileEntries(),
                        index = index,
                        sourceId = SourceIds.APP_TRASH,
                        fidelityOverride = null,
                        isCancelled = cancelled::get,
                    ) { scanned, total ->
                        emitProgress(SourceIds.APP_TRASH, scanned, total)
                    }
                }
                sources.add(
                    source(
                        SourceIds.APP_TRASH,
                        "App trash folders",
                        "full",
                        granted,
                        if (granted) "Files apps kept after you deleted them"
                        else "Needs file access",
                        null,
                    )
                )
            }

            if (SourceIds.THUMBNAILS in wanted) {
                index.clear(SourceIds.THUMBNAILS)
                fileScanner.scanEntries(
                    entries = listOf(
                        TrashMap.Entry(
                            label = "Thumbnail cache",
                            paths = trashMap.thumbnailPaths,
                            fidelity = "preview",
                            retentionDays = null,
                            role = "cache",
                        )
                    ),
                    index = index,
                    sourceId = SourceIds.THUMBNAILS,
                    fidelityOverride = "preview",
                    isCancelled = cancelled::get,
                ) { scanned, total ->
                    emitProgress(SourceIds.THUMBNAILS, scanned, total)
                }
                sources.add(
                    source(
                        SourceIds.THUMBNAILS,
                        "Thumbnail cache",
                        "preview",
                        true,
                        "Previews only. The originals are gone and cannot be brought back.",
                        null,
                    )
                )
            }

            sources.forEach { emitProgress(it.sourceId, 1, 1, done = true) }

            reply(
                callback,
                RecoverySummary(
                    sources = sources,
                    totalItems = index.totalItems().toLong(),
                    totalBytes = index.totalBytes(),
                    expiringSoonItems = index.expiringSoon().toLong(),
                    partial = !granted,
                    imageCount = index.countOfKind("image").toLong(),
                    videoCount = index.countOfKind("video").toLong(),
                    audioCount = index.countOfKind("audio").toLong(),
                    documentCount = index.countOfKind("document").toLong(),
                    otherCount = index.countOfKind("other").toLong(),
                ),
            )
        }
    }

    override fun cancelScan(callback: (Result<Unit>) -> Unit) {
        cancelled.set(true)
        reply(callback, Unit)
    }

    override fun items(
        sourceId: String,
        offset: Long,
        limit: Long,
        callback: (Result<List<RecoverableItem>>) -> Unit,
    ) {
        worker.execute {
            reply(callback, index.page(sourceId, offset.toInt(), limit.toInt()))
        }
    }

    override fun restore(
        itemIds: List<String>,
        callback: (Result<List<RestoreOutcome>>) -> Unit,
    ) {
        worker.execute {
            val out = itemIds.map { id ->
                val record = index.get(id)
                if (record == null) {
                    RestoreOutcome(id, "notFound", "This item is no longer in the scan", null)
                } else {
                    val outcome = restorer.restore(record, trashMap.restoreFolder)
                    // Drop it from the index on success so a second tap cannot
                    // restore the same thing twice and report success both times.
                    if (outcome.status == "restored" || outcome.status == "expired") {
                        index.remove(id)
                    }
                    outcome
                }
            }
            reply(callback, out)
        }
    }

    override fun purge(
        itemIds: List<String>,
        callback: (Result<List<RestoreOutcome>>) -> Unit,
    ) {
        worker.execute {
            val out = itemIds.map { id ->
                val record = index.get(id)
                if (record == null) {
                    RestoreOutcome(id, "notFound", "This item is no longer in the scan", null)
                } else {
                    val outcome = restorer.purge(record)
                    if (outcome.status == "restored" || outcome.status == "expired") {
                        index.remove(id)
                    }
                    outcome
                }
            }
            reply(callback, out)
        }
    }

    override fun thumbnail(
        itemId: String,
        maxPixels: Long,
        callback: (Result<ByteArray?>) -> Unit,
    ) {
        worker.execute {
            // Search results are not in the scan index: the live searcher does
            // not register them, because doing so would fold files that were
            // never deleted into the recoverable totals. Their ids are minted
            // here though, so native can rebuild the record it needs.
            //
            // Native parsing its own id format is fine. The opacity rule is
            // about DART not parsing it, so that no caller can branch on the
            // difference between a MediaStore row and a loose file.
            val record = index.get(itemId) ?: liveRecord(itemId)
            reply(
                callback,
                if (record == null) null else thumbnailer.bytes(record, maxPixels.toInt()),
            )
        }
    }

    override fun search(
        query: String,
        limit: Long,
        callback: (Result<List<RecoverableItem>>) -> Unit,
    ) {
        worker.execute {
            // Deleted items first, then live files, because the reason the app
            // is open is the deleted ones. Both come from the same index of
            // names, so a user who cannot remember whether they deleted it does
            // not have to choose a tab.
            val needle = query.trim().lowercase()
            val deleted = if (needle.length < 2) {
                emptyList()
            } else {
                index.searchByName(needle, limit.toInt())
            }
            val remaining = (limit.toInt() - deleted.size).coerceAtLeast(0)
            val live = if (remaining == 0) {
                emptyList()
            } else {
                liveSearcher.search(query, remaining)
            }
            reply(callback, deleted + live)
        }
    }

    /**
     * Rebuilds a record for a search result.
     *
     * Search results are not in the scan index: the live searcher does not
     * register them, because folding files that were never deleted into the
     * recoverable totals would inflate every number on home. Their ids are
     * minted here though, so native can reconstruct what the thumbnailer needs.
     *
     * Native parsing its own id format is fine. The opacity rule is about DART
     * not parsing it, so that no caller can branch on the difference between a
     * MediaStore row and a loose file.
     */
    private fun liveRecord(itemId: String): RecoveryIndex.Record? {
        if (!itemId.startsWith("live:")) return null
        val mediaId = itemId.removePrefix("live:").toLongOrNull() ?: return null
        return RecoveryIndex.Record.Media(
            mediaId = mediaId,
            item = RecoverableItem(
                itemId = itemId,
                sourceId = SourceIds.LIVE_FILES,
                name = itemId,
                kind = "image",
                fidelity = "full",
                sizeBytes = 0,
                origin = null,
                role = null,
            ),
        )
    }

    private fun source(
        id: String,
        label: String,
        fidelity: String,
        available: Boolean,
        detail: String,
        retention: Long?,
    ) = RecoverySource(
        sourceId = id,
        label = label,
        fidelity = fidelity,
        available = available,
        itemCount = index.count(id).toLong(),
        totalBytes = index.bytes(id),
        detail = detail,
        retentionDays = retention,
    )

    /**
     * Throttled to roughly 12 per second.
     *
     * Without this a thumbnail cache with thirty thousand entries posts thirty
     * thousand messages to the platform thread, and the progress bar becomes the
     * slowest part of the scan.
     */
    private fun emitProgress(
        sourceId: String,
        scanned: Int,
        total: Int,
        done: Boolean = false,
    ) {
        val now = System.currentTimeMillis()
        if (!done && now - lastProgressAt < 80) return
        lastProgressAt = now
        val progress = ScanProgress(
            sourceId = sourceId,
            scanned = scanned.toLong(),
            total = total.toLong(),
            found = index.count(sourceId).toLong(),
            foundBytes = index.bytes(sourceId),
            done = done,
        )
        main.post { flutterApi?.onScanProgress(progress) { } }
    }

    /** Pigeon callbacks must be invoked on the main looper. */
    private fun <T> reply(callback: (Result<T>) -> Unit, value: T) {
        main.post { callback(Result.success(value)) }
    }
}
