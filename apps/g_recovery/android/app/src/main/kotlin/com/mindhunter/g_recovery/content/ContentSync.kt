package com.mindhunter.g_recovery.content

import android.content.Context
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Fetch, verify, install.
 *
 * INSTALL IS A DIRECTORY RENAME, and that is the single most important thing in
 * this file. Everything downloads into staging, is verified there, and only
 * then replaces the installed directory. A phone that dies mid download leaves
 * a staging directory nobody reads, never a half written pack that verifies
 * because verification already ran on the parts that arrived.
 *
 * Object layout is the panel's, not one this file invents:
 *
 *   g-recovery/index.json          signed catalogue
 *   g-recovery/index.sig           detached signature over those exact bytes
 *   g-recovery/<path>/manifest.json
 *   g-recovery/<path>/manifest.sig
 *   g-recovery/<path>/<payload>
 *
 * where `<path>` comes from the index entry and already contains the version.
 */
internal class ContentSync(
    context: Context,
    private val verifier: ContentVerifier,
) {

    private val root: File = File(context.filesDir, "content")
    private val installed: File = File(root, "installed")
    private val staging: File = File(root, "staging")
    private val etagFile: File = File(root, "index.etag")
    private val stampFile: File = File(root, "index.generatedAt")

    private val cancelled = AtomicBoolean(false)

    companion object {
        private const val INDEX_PATH = "index.json"

        /** `index.sig`. The panel writes this name; do not guess at it. */
        private const val INDEX_SIG_PATH = "index.sig"

        /** One content file is JSON. Anything near this is already wrong. */
        private const val MAX_CONTENT_BYTES = 2L * 1024 * 1024
    }

    fun read(packId: String): String? {
        if (!ContentManifest.isSafePackId(packId)) return null
        val dir = File(installed, packId)
        if (!dir.isDirectory) return null
        val manifest = readManifest(dir) ?: return null
        // A content pack holds exactly one payload file. Reading the first entry
        // from the SIGNED manifest rather than listing the directory means an
        // unsigned file dropped in later can never be the one that gets read.
        val first = manifest.files.firstOrNull() ?: return null
        val file = File(dir, first.path)
        return try {
            if (file.isFile) file.readText() else null
        } catch (_: Throwable) {
            null
        }
    }

    fun installedPacks(): List<ContentPackInfo> {
        val dirs = installed.listFiles()?.filter { it.isDirectory } ?: return emptyList()
        return dirs.mapNotNull { dir ->
            val manifest = readManifest(dir) ?: return@mapNotNull null
            ContentPackInfo(
                packId = manifest.packId,
                packType = manifest.packType,
                version = manifest.version.toLong(),
                installedVersion = manifest.version.toLong(),
                sizeBytes = manifest.files.sumOf { it.size },
            )
        }
    }

    fun sync(baseUrl: String): ContentSyncResult {
        cancelled.set(false)
        root.mkdirs()
        installed.mkdirs()

        val client = CdnClient(baseUrl)

        val previousEtag = readText(etagFile)

        val indexFetch = client.fetch(
            INDEX_PATH,
            ContentIndex.MAX_INDEX_BYTES,
            etag = previousEtag,
            cancelled = cancelled,
        )

        val indexBody = when (indexFetch) {
            is CdnClient.Fetch.NotModified ->
                return result("upToDate", "Content is current", changed = false)
            is CdnClient.Fetch.Failed ->
                // Offline is the ORDINARY case on a phone in a lift, and it
                // deserves silence. The bundled content is already doing its job.
                return result("offline", indexFetch.detail, changed = false)
            is CdnClient.Fetch.Body -> indexFetch
        }

        val sigFetch = client.fetch(
            INDEX_SIG_PATH,
            Ed25519.SIGNATURE_BYTES + 8,
            cancelled = cancelled,
        )
        val sigBytes = (sigFetch as? CdnClient.Fetch.Body)?.bytes
            ?: return result("failed", "index signature unavailable", changed = false)

        // Verified against EVERY accepted key rather than the one the index
        // names. The index does carry a keyId, but trusting it to select the key
        // would let a document choose its own verifier; trying all of a small
        // trusted set costs microseconds and keeps rotation working either way.
        val indexOk = ContentKeys.accepted.values.any { key ->
            Ed25519.verify(key, indexBody.bytes, sigBytes)
        }
        if (!indexOk) {
            // NEVER RETRIED. A bad signature means something is wrong upstream,
            // and fetching again just gets the same bad bytes.
            return result("rejected", "index signature did not verify", changed = false)
        }

        val index = try {
            ContentIndex.parse(String(indexBody.bytes, Charsets.UTF_8))
        } catch (e: ContentFormatException) {
            return result("rejected", e.message ?: "malformed index", changed = false)
        }

        // REPLAY GUARD. An index older than the one already seen is refused even
        // though its signature is perfectly valid, because a signature says who
        // wrote a document and not when. Without this an edge serving a stale
        // copy, or anyone able to replace one object, can pin a device to an old
        // catalogue indefinitely and nothing looks wrong.
        val lastSeen = readText(stampFile)?.toLongOrNull() ?: 0L
        if (index.generatedAt < lastSeen) {
            return result(
                "rejected",
                "index is older than the one already installed",
                changed = false,
            )
        }

        var changed = false
        var lastProblem: String? = null

        for (entry in index.entries) {
            if (cancelled.get()) break
            if (entry.minAppVersion > verifier.appVersionCode) continue
            if (currentVersion(entry.packId) >= entry.version) continue

            val problem = install(client, entry)
            if (problem == null) changed = true else lastProblem = problem
        }

        // ETag and stamp are stored ONLY when the whole pass succeeded. Storing
        // the ETag earlier would mean a failed install is never retried: the
        // next sync gets a 304 and concludes it is up to date.
        if (lastProblem == null) {
            writeText(stampFile, index.generatedAt.toString())
            indexBody.etag?.takeIf { it.isNotEmpty() }?.let { writeText(etagFile, it) }
        }

        return when {
            changed && lastProblem == null ->
                result("updated", "Content updated", changed = true)
            changed ->
                result("updated", "Updated, with one problem: $lastProblem", changed = true)
            lastProblem != null -> result("failed", lastProblem, changed = false)
            else -> result("upToDate", "Content is current", changed = false)
        }
    }

    fun cancel() = cancelled.set(true)

    /** Null on success, or a one line reason. */
    private fun install(client: CdnClient, entry: ContentIndex.Entry): String? {
        val stage = File(staging, entry.packId)
        stage.deleteRecursively()
        stage.mkdirs()

        // The index's own path, version included. Never assembled from the pack
        // id here: the directory depends on the pack type, and the panel is the
        // only thing that knows the mapping.
        val prefix = entry.path

        // Manifest and signature first, through fetch rather than download,
        // because download insists on an exact size and the manifest's is not
        // known until it has been read.
        val manifestBody = client.fetch(
            "$prefix/${ContentVerifier.MANIFEST_NAME}",
            ContentManifest.MAX_MANIFEST_BYTES,
            cancelled = cancelled,
        )
        val manifestBytes = (manifestBody as? CdnClient.Fetch.Body)?.bytes
            ?: return "${entry.packId}: manifest unavailable"

        val sigBody = client.fetch(
            "$prefix/${ContentVerifier.SIGNATURE_NAME}",
            Ed25519.SIGNATURE_BYTES + 8,
            cancelled = cancelled,
        )
        val sigBytes = (sigBody as? CdnClient.Fetch.Body)?.bytes
            ?: return "${entry.packId}: signature unavailable"

        try {
            File(stage, ContentVerifier.MANIFEST_NAME).writeBytes(manifestBytes)
            File(stage, ContentVerifier.SIGNATURE_NAME).writeBytes(sigBytes)
        } catch (e: Throwable) {
            return "${entry.packId}: ${e.message}"
        }

        // SIGNATURE BEFORE PAYLOAD. Everything below relies on the file list,
        // the sizes and the version floor, and none of that is trustworthy until
        // this returns Ok.
        val manifestResult = verifier.verifyManifest(stage)
        val manifest = (manifestResult as? VerifyResult.Ok)?.manifest
            ?: return "${entry.packId}: ${manifestResult.describe()}"

        for (file in manifest.files) {
            if (cancelled.get()) return "cancelled"
            if (file.size > MAX_CONTENT_BYTES) {
                return "${entry.packId}: ${file.path} is ${file.size} bytes"
            }
            val problem = client.download(
                "$prefix/${file.path}",
                File(stage, file.path),
                file.size,
                cancelled,
            )
            if (problem != null) return "${entry.packId}: $problem"
        }

        // The FULL check runs again on the complete staging directory. The
        // manifest was already verified, but "I checked while downloading" is
        // exactly the assumption that turns an interrupted transfer into an
        // unverified install.
        val full = verifier.verify(stage)
        if (!full.isOk) {
            stage.deleteRecursively()
            return "${entry.packId}: ${full.describe()}"
        }

        return commit(stage, entry.packId)
    }

    /**
     * Swap staging in for installed.
     *
     * The previous version is moved aside rather than deleted, and put back if
     * the second rename fails, so the window where nothing is installed does not
     * exist. Losing content to a failed update would silently drop the app back
     * to its bundled copy with no way to tell that had happened.
     */
    private fun commit(stage: File, packId: String): String? {
        val target = File(installed, packId)
        val previous = File(installed, "$packId.old")
        return try {
            previous.deleteRecursively()
            if (target.exists() && !target.renameTo(previous)) {
                "$packId: could not move the previous version aside"
            } else if (!stage.renameTo(target)) {
                previous.renameTo(target)
                "$packId: install rename failed"
            } else {
                previous.deleteRecursively()
                null
            }
        } catch (e: Throwable) {
            "$packId: ${e.message}"
        }
    }

    private fun currentVersion(packId: String): Int =
        readManifest(File(installed, packId))?.version ?: 0

    private fun readManifest(dir: File): ContentManifest? = try {
        val file = File(dir, ContentVerifier.MANIFEST_NAME)
        if (!file.isFile) null else ContentManifest.parse(file.readText())
    } catch (_: Throwable) {
        null
    }

    private fun readText(file: File): String? = try {
        if (file.isFile) file.readText().trim().ifEmpty { null } else null
    } catch (_: Throwable) {
        null
    }

    private fun writeText(file: File, value: String) {
        try {
            file.writeText(value)
        } catch (_: Throwable) {
            // A missing ETag costs one extra request per sync, and a missing
            // stamp costs one weakened replay check until the next success.
            // Neither is worth failing the whole operation for.
        }
    }

    private fun result(status: String, detail: String, changed: Boolean) =
        ContentSyncResult(
            status = status,
            detail = detail,
            changed = changed,
            packs = installedPacks(),
        )
}
