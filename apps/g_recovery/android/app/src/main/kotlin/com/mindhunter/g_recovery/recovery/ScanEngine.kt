package com.mindhunter.g_recovery.recovery

import android.content.Context

/**
 * THE SCAN ITSELF, extracted so there is exactly one of it.
 *
 * It used to live inline in `RecoveryHostApiImpl.scan`, which was fine while the
 * only caller was a Flutter engine. A background service cannot reach into that
 * class, and copying the body into the service would have created two scans that
 * drift apart the first time a source is added. The engine is the shared thing;
 * the bridge and the service are both just callers.
 *
 * STATELESS ACROSS CALLS. Every input arrives as an argument, including the
 * trash map and the cancellation check, so the same instance can be driven from
 * the platform thread or from a service worker without either knowing about the
 * other.
 */
internal class ScanEngine(context: Context, private val index: RecoveryIndex) {

    private val app: Context = context.applicationContext
    private val access = Access(app)
    private val mediaScanner = MediaTrashScanner(app)
    private val fileScanner = FileTrashScanner()

    /** Progress: source id, scanned, total, done. */
    internal fun interface Progress {
        fun report(sourceId: String, scanned: Int, total: Int, done: Boolean)
    }

    /**
     * Walks the requested sources and returns the summary.
     *
     * BLOCKS THE CALLING THREAD, deliberately. Both callers already have a
     * worker to run it on and neither wants a second layer of dispatch deciding
     * when their cancellation flag gets read.
     */
    fun run(
        sourceIds: List<String>,
        trashMap: TrashMap,
        isCancelled: () -> Boolean,
        progress: Progress,
    ): RecoverySummary {
        val granted = access.isGranted()
        val wanted = sourceIds.toSet()
        val sources = mutableListOf<RecoverySource>()

        if (SourceIds.MEDIA_TRASH in wanted) {
            index.clear(SourceIds.MEDIA_TRASH)
            if (granted) {
                mediaScanner.scan(
                    index = index,
                    sourceId = SourceIds.MEDIA_TRASH,
                    isCancelled = isCancelled,
                ) { scanned, total ->
                    progress.report(SourceIds.MEDIA_TRASH, scanned, total, false)
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
                    isCancelled = isCancelled,
                ) { scanned, total ->
                    progress.report(SourceIds.APP_TRASH, scanned, total, false)
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
                isCancelled = isCancelled,
            ) { scanned, total ->
                progress.report(SourceIds.THUMBNAILS, scanned, total, false)
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

        sources.forEach { progress.report(it.sourceId, 1, 1, true) }

        return RecoverySummary(
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
}
