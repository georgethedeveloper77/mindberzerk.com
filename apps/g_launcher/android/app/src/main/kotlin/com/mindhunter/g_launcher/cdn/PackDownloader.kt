package com.mindhunter.g_launcher.cdn

import com.mindhunter.g_launcher.theme.InstallResult
import com.mindhunter.g_launcher.theme.PackManifest
import com.mindhunter.g_launcher.theme.PackVerifier
import com.mindhunter.g_launcher.theme.ThemeAssetLoader
import com.mindhunter.g_launcher.theme.VerifyResult
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/**
 * PHASE C2 - turns "there is a newer brand pack" into "it is installed".
 *
 * Sits between [CdnClient] (bytes) and [ThemeAssetLoader] (the trust gate) and
 * owns the ORDER, which is where all the value is:
 *
 *   1. fetch index.json + index.sig, conditionally (ETag)
 *   2. verify the index signature and its generatedAt floor
 *   3. for the pack in question: is the advertised version newer than what is
 *      installed? If not, STOP. No payload is fetched at all.
 *   4. fetch manifest.json + manifest.sig into staging
 *   5. verify the MANIFEST ALONE. Now the file list, the sizes and the
 *      minAppVersion are trusted, before a single payload byte exists.
 *   6. free-space check against the now-trusted total
 *   7. download each file, capped at its exact signed size
 *   8. hand to ThemeAssetLoader.install, which verifies EVERYTHING again
 *
 * Step 8 re-verifying what step 5 already checked is not waste. It is a few
 * milliseconds of hashing against a network round trip, and it means there is
 * exactly ONE code path from disk into the live packs directory, with the full
 * check on it. "The downloader already verified this" is precisely the
 * assumption that turns an interrupted or resumed transfer into an unverified
 * install.
 *
 * The index cache lives in `packs/.index/`, as files rather than
 * SharedPreferences, so this whole package stays free of `android.*` and stays
 * unit-testable. It also keeps the cached index next to the packs it describes,
 * which means clearing one clears the other.
 */
class PackDownloader(
    private val client: CdnClient,
    private val loader: ThemeAssetLoader,
    private val packsRoot: File,
    private val acceptedKeys: Map<String, ByteArray>,
    private val verifier: PackVerifier,
    /** Remote prefix under the CDN root. Every object lives beneath it. */
    private val remoteRoot: String = "g-launcher",
) {

    companion object {
        private const val INDEX_DIR = ".index"

        /**
         * Scratch for [peekFile]. Deliberately NOT the staging directory:
         * `prepareStaging` wipes and recreates it, so a peek that borrowed it
         * could destroy an install in flight for the same pack. A read must not
         * be able to interfere with a write.
         *
         * Leading dot, like the others here, so it sorts and reads as internal
         * and `installedPackIds` cannot mistake it for a pack.
         */
        private const val PEEK_DIR = ".peek"
        private const val ETAG_NAME = "etag"

        /**
         * Refuse a pack that would leave the device with less than this free.
         * A launcher that fills the last 50MB of a 32GB phone to install a
         * wallpaper set has done something unforgivable to someone who cannot
         * afford a better phone.
         */
        private const val FREE_SPACE_FLOOR_BYTES = 200L * 1024 * 1024
    }

    // ── the index ────────────────────────────────────────────────────────────

    private val indexDir: File get() = File(packsRoot, INDEX_DIR)

    /** The last index we verified, or null. Never hits the network. */
    fun cachedIndex(): CdnIndex? {
        val f = File(indexDir, CdnIndex.INDEX_NAME)
        val s = File(indexDir, CdnIndex.SIGNATURE_NAME)
        if (!f.isFile || !s.isFile) return null
        return try {
            // Re-verified on every read, not trusted because it is "ours". The
            // packs directory is app-private, but a rooted device and a
            // backup/restore cycle are both real, and re-checking a 2KB file is
            // free next to the alternative.
            CdnIndex.parseVerified(f.readBytes(), s.readBytes(), acceptedKeys)
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Fetch the index if it changed, verify it, cache it.
     *
     * THE FRESHNESS FLOOR. A verified index whose [CdnIndex.generatedAt] is
     * older than the one already cached is DISCARDED. Signatures prove
     * authenticity and never freshness: a stale index is correctly signed
     * forever, so replaying yesterday's is a free way to hide today's update
     * from a device indefinitely. This one comparison is what closes that, and
     * it is the reason generatedAt is a required field rather than metadata.
     */
    fun refreshIndex(cancelled: AtomicBoolean = AtomicBoolean(false)): IndexResult {
        val etagFile = File(indexDir, ETAG_NAME)
        val etag = if (etagFile.isFile) etagFile.readText().trim().ifEmpty { null } else null

        val body = client.fetch(
            "$remoteRoot/${CdnIndex.INDEX_NAME}",
            CdnIndex.MAX_INDEX_BYTES,
            etag,
            cancelled,
        )

        val fetched: CdnClient.Fetch.Body = when (body) {
            is CdnClient.Fetch.NotModified -> {
                // The cheapest possible sync: the origin says nothing changed,
                // so no body crossed the wire at all. Still re-verify what we
                // hold rather than assuming a cached file is a good file.
                val cached = cachedIndex() ?: return IndexResult.Failed("304 but no usable cache")
                return IndexResult.Unchanged(cached)
            }
            is CdnClient.Fetch.Failed -> return IndexResult.Failed(body.detail)
            is CdnClient.Fetch.Body -> body
        }

        val sig = client.fetch(
            "$remoteRoot/${CdnIndex.SIGNATURE_NAME}",
            com.mindhunter.g_launcher.crypto.Ed25519.SIGNATURE_BYTES,
            null,
            cancelled,
        )
        if (sig !is CdnClient.Fetch.Body) {
            return IndexResult.Failed("could not fetch the index signature")
        }

        val fresh = CdnIndex.parseVerified(fetched.bytes, sig.bytes, acceptedKeys)
            ?: return IndexResult.Rejected("index signature or shape failed verification")

        val current = cachedIndex()
        if (current != null && fresh.generatedAt < current.generatedAt) {
            // Correctly signed, and older than what we hold. Almost always a
            // stale CDN edge, occasionally a replay. Either way, keep ours.
            return IndexResult.Stale(current, offered = fresh.generatedAt)
        }

        indexDir.mkdirs()
        File(indexDir, CdnIndex.INDEX_NAME).writeBytes(fetched.bytes)
        File(indexDir, CdnIndex.SIGNATURE_NAME).writeBytes(sig.bytes)
        if (fetched.etag != null) etagFile.writeText(fetched.etag) else etagFile.delete()

        return IndexResult.Updated(fresh)
    }

    // ── one pack ─────────────────────────────────────────────────────────────

    /**
     * Download and install [packId] if the index advertises something newer
     * than what is on disk.
     *
     * Entitlement is NOT checked here. [CdnPack.sku] is advisory presentation
     * data from the CDN; whether a user owns something is Play's answer and
     * belongs at the call site in C3. Putting a paid check inside the
     * downloader would put the entitlement decision on the same server as the
     * payload, which is the one place it must never live.
     */
    fun syncPack(
        packId: String,
        index: CdnIndex,
        cancelled: AtomicBoolean = AtomicBoolean(false),
        /**
         * Pack ids already being synced further up this call chain.
         *
         * Cycle break for the recursion below.
         *
         * ─── BEFORE `onProgress`, NOT AFTER ───────────────────────────────
         *
         * It went last at first, which broke every existing caller. Kotlin
         * binds a trailing lambda to the LAST parameter, so
         *
         *     downloader.syncPack(packId, index, cancel) { done, total -> ... }
         *
         * started passing the progress lambda as `visiting` and the compiler
         * reported it as an argument type mismatch inside PackHostApiImpl,
         * pointing at a call site nobody had touched.
         *
         * A trailing lambda parameter must stay last. Anything added to this
         * signature goes above it.
         */
        visiting: Set<String> = emptySet(),
        onProgress: ((done: Long, total: Long) -> Unit)? = null,
    ): SyncResult {
        val remote = index.pack(packId) ?: return SyncResult.NotOffered(packId)

        val installed = loader.installedVersion(packId)
        if (remote.version <= installed) return SyncResult.UpToDate(installed)

        // ─── DEPENDENCIES FIRST, OR THIS PACK ARRIVES AND DRAWS NOTHING ─────
        //
        // A derived icon pack is about 200 bytes: a colour and a pointer at
        // `arcticons-line`, which carries the 13,622 drawings all fourteen
        // distros share. Installed on its own it verifies, resolves and renders
        // absolutely nothing, with no error at any layer, because "no glyph for
        // this package" is the same answer an uncovered app gives.
        //
        // The index declares this in `requires`. Nothing acted on it until now,
        // which is why the field alone was never the fix: it described the
        // dependency and no code followed it.
        //
        // RECURSIVE, VIA syncPack ITSELF, so a dependency's own dependencies
        // resolve. `visiting` breaks cycles: a malformed index naming two packs
        // that require each other would otherwise recurse until the stack goes,
        // and this runs in a WorkManager job where that is a silent failure.
        //
        // A dependency that is ALREADY INSTALLED returns `UpToDate` and costs
        // one map lookup, so the common case after the first sync is free.
        for (need in remote.requires) {
            if (need == packId || need in visiting) continue
            when (val dep = syncPack(need, index, cancelled, visiting + packId, onProgress)) {
                is SyncResult.Installed, is SyncResult.UpToDate -> Unit
                // The dependent pack is NOT attempted. Downloading it anyway
                // would leave a paid pack installed and blank, which is worse
                // than not having it: the user sees it in their library and
                // nothing changes on screen.
                else -> return SyncResult.MissingDependency(need, dep)
            }
        }

        // Cheap refusal before any transfer. The pack's own manifest carries
        // the authoritative minAppVersion and PackVerifier enforces it; this is
        // the index's advisory copy, used only to avoid a pointless download.
        if (remote.minAppVersion > verifier.appVersionCode) {
            return SyncResult.AppTooOld(remote.minAppVersion)
        }

        val staging = loader.prepareStaging(packId)
            ?: return SyncResult.Failed("could not prepare staging for '$packId'")

        val prefix = "$remoteRoot/${remote.path}"

        // ── manifest first, and ONLY the manifest ────────────────────────────
        val manifestFetch = client.fetch(
            "$prefix/${PackVerifier.MANIFEST_NAME}",
            PackManifest.MAX_MANIFEST_BYTES,
            null,
            cancelled,
        )
        if (manifestFetch !is CdnClient.Fetch.Body) {
            loader.discardStaging(packId)
            return SyncResult.Failed("manifest: ${(manifestFetch as? CdnClient.Fetch.Failed)?.detail}")
        }
        val sigFetch = client.fetch(
            "$prefix/${PackVerifier.SIGNATURE_NAME}",
            com.mindhunter.g_launcher.crypto.Ed25519.SIGNATURE_BYTES,
            null,
            cancelled,
        )
        if (sigFetch !is CdnClient.Fetch.Body) {
            loader.discardStaging(packId)
            return SyncResult.Failed("signature: ${(sigFetch as? CdnClient.Fetch.Failed)?.detail}")
        }

        File(staging, PackVerifier.MANIFEST_NAME).writeBytes(manifestFetch.bytes)
        File(staging, PackVerifier.SIGNATURE_NAME).writeBytes(sigFetch.bytes)

        val manifestResult = verifier.verifyManifest(staging)
        if (manifestResult !is VerifyResult.Ok) {
            loader.discardStaging(packId)
            return SyncResult.Rejected(manifestResult)
        }
        val manifest = manifestResult.manifest

        // The index said one thing, the signed manifest says another. Trust the
        // signed one and stop: the mismatch means the index is stale or wrong,
        // and continuing would install something the caller did not decide to
        // install.
        if (manifest.packId != packId || manifest.version != remote.version) {
            loader.discardStaging(packId)
            return SyncResult.Rejected(
                VerifyResult.MalformedManifest(
                    "index advertised ${remote.packId} v${remote.version}, " +
                        "manifest says ${manifest.packId} v${manifest.version}",
                ),
            )
        }

        // ── now the sizes are trusted, so the budget is real ─────────────────
        val total = manifest.files.sumOf { it.size }
        // usableSpace returns 0 when the filesystem will not say, and on some
        // OEM ROMs it does exactly that. `in 1 until` skips the check in that
        // case rather than refusing every install on those devices.
        val usable = packsRoot.usableSpace
        if (usable in 1 until (total + FREE_SPACE_FLOOR_BYTES)) {
            loader.discardStaging(packId)
            return SyncResult.NoSpace(needed = total, usable = usable)
        }

        var done = 0L
        for (f in manifest.files) {
            if (cancelled.get()) {
                loader.discardStaging(packId)
                return SyncResult.Cancelled
            }
            // f.path came out of a verified manifest and was already checked by
            // PackManifest.isSafeRelativePath at parse time, which is why it is
            // safe to join here.
            val error = client.download(
                "$prefix/${f.path}",
                File(staging, f.path),
                f.size,
                cancelled,
            ) { soFar -> onProgress?.invoke(done + soFar, total) }

            if (error != null) {
                loader.discardStaging(packId)
                return SyncResult.Failed(error)
            }
            done += f.size
            onProgress?.invoke(done, total)
        }

        // ── the single gate. Full verification, again, on purpose ────────────
        return when (val installResult = loader.install(packId)) {
            is InstallResult.Installed -> SyncResult.Installed(installResult.manifest)
            is InstallResult.Stale -> SyncResult.UpToDate(installResult.installed)
            is InstallResult.Rejected -> SyncResult.Rejected(installResult.reason)
            is InstallResult.SwapFailed -> SyncResult.Failed(installResult.detail)
            InstallResult.NothingStaged -> SyncResult.Failed("staging vanished mid-install")
        }
    }

    // ── one file, without installing anything ────────────────────────────────

    /**
     * Fetch and verify ONE file out of a pack, without installing the pack.
     *
     * The storefront's reason for existing: a card for a distro nobody owns can
     * only draw what the signed index carries, which is five colours and a
     * layout enum, so every paid distro renders as a coloured rectangle. The
     * real look lives in the pack's own `theme.json`, and it is a few KB next to
     * a payload measured in megabytes.
     *
     * ─── IT IS STEPS 1 THROUGH 5 OF [syncPack], AND THEN IT STOPS ───────────
     *
     * The order that method documents at the top of this file exists exactly so
     * the manifest can be trusted before any payload is touched. This reuses
     * that prefix verbatim and then takes a single file from the now-trusted
     * list instead of all of them:
     *
     *   1. the pack is in the index at all
     *   2. manifest.json + manifest.sig into scratch
     *   3. verifyManifest, so the file list, sizes and hashes are trusted
     *   4. the index and the manifest agree about id and version
     *   5. download exactly the one requested entry, capped at its signed size
     *   6. hash it against the signed entry
     *
     * WHAT IT DELIBERATELY DOES NOT DO: touch the packs root, move
     * `installedVersion`, run the dependency walk, check free space, or call
     * [ThemeAssetLoader.install]. There is still exactly one code path from disk
     * into the live packs directory and this is not it.
     *
     * ─── THE HASH CHECK IS THE WHOLE POINT ────────────────────────────────────
     *
     * Without it this would be an unauthenticated GET whose result gets parsed
     * into a ThemeSpec and rendered, which is content driving UI with no
     * provenance. With it, the bytes are pinned to a hash inside an ed25519
     * signed manifest, so the guarantee is the same one an installed pack has.
     *
     * ─── ENTITLEMENT IS NOT CHECKED, MATCHING [syncPack] ──────────────────────
     *
     * Same reason, stated there: ownership is Play's answer and belongs at the
     * call site, never on the server holding the payload. It is also not a
     * paywall question. Showing somebody what a distro looks like before they
     * pay for it is the feature.
     *
     * ─── SCRATCH, NOT STAGING ─────────────────────────────────────────────────
     *
     * [ThemeAssetLoader.prepareStaging] wipes and recreates the pack's staging
     * directory, so calling it here would destroy a real download that happened
     * to be in flight for the same pack. A peek is a read; it must not be able
     * to interfere with an install. So it uses its own directory under
     * [PEEK_DIR], deleted in a `finally` whatever happens.
     *
     * Returns null on every failure without distinguishing them, because the
     * caller's only move is the same in all of them: draw the index preview it
     * drew before.
     */
    fun peekFile(
        packId: String,
        filename: String,
        index: CdnIndex,
        maxBytes: Long,
        cancelled: AtomicBoolean = AtomicBoolean(false),
    ): ByteArray? {
        if (!PackManifest.isSafePackId(packId)) return null
        // The caller names a file inside a pack, so this joins a string into a
        // path. Same gate the manifest parser applies to its own entries.
        if (!PackManifest.isSafeRelativePath(filename)) return null

        val remote = index.pack(packId) ?: return null

        val scratch = File(File(packsRoot, PEEK_DIR), packId)
        try {
            scratch.deleteRecursively()
            if (!scratch.mkdirs()) return null

            val prefix = "$remoteRoot/${remote.path}"

            val manifestFetch = client.fetch(
                "$prefix/${PackVerifier.MANIFEST_NAME}",
                PackManifest.MAX_MANIFEST_BYTES,
                null,
                cancelled,
            )
            if (manifestFetch !is CdnClient.Fetch.Body) return null

            val sigFetch = client.fetch(
                "$prefix/${PackVerifier.SIGNATURE_NAME}",
                com.mindhunter.g_launcher.crypto.Ed25519.SIGNATURE_BYTES,
                null,
                cancelled,
            )
            if (sigFetch !is CdnClient.Fetch.Body) return null

            File(scratch, PackVerifier.MANIFEST_NAME).writeBytes(manifestFetch.bytes)
            File(scratch, PackVerifier.SIGNATURE_NAME).writeBytes(sigFetch.bytes)

            val manifestResult = verifier.verifyManifest(scratch)
            if (manifestResult !is VerifyResult.Ok) return null
            val manifest = manifestResult.manifest

            // The index said one thing and the signed manifest says another.
            // Same refusal [syncPack] makes, for the same reason: the mismatch
            // means the index is stale or wrong, and continuing would render a
            // preview of a version this device was not offered.
            if (manifest.packId != packId || manifest.version != remote.version) {
                return null
            }

            // minAppVersion is NOT enforced here, and that is the one check
            // [syncPack] makes that this deliberately skips. A pack this build
            // is too old to RUN is still a pack the storefront has to describe,
            // and it already has its own card state saying so. Refusing the
            // preview would leave `requiresAppUpdate` as the one status with no
            // picture, which is precisely backwards: it is the card most in
            // need of explaining what the user is missing.

            val entry = manifest.files.firstOrNull { it.path == filename } ?: return null
            // A cap the CALLER sets, checked against the SIGNED size, so a
            // manifest promising a 40MB "theme.json" is refused before a socket
            // opens rather than after it fills the device.
            if (entry.size <= 0 || entry.size > maxBytes) return null

            val target = File(scratch, entry.path)
            val error = client.download("$prefix/${entry.path}", target, entry.size, cancelled)
            if (error != null) return null

            val bytes = target.readBytes()
            if (sha256Hex(bytes) != entry.sha256) return null

            return bytes
        } catch (_: Exception) {
            // Disk full, a permission surprise on an OEM ROM, a malformed
            // manifest that got past parse. A preview is never worth a crash on
            // the storefront.
            return null
        } finally {
            scratch.deleteRecursively()
        }
    }

    /**
     * Lowercase hex, matching what [PackManifest] parses and what
     * [PackVerifier] produces for files on disk.
     *
     * Over a ByteArray rather than a File because the payload here is a few KB
     * already in memory, and streaming it back off disk to hash it would be
     * work for its own sake.
     */
    private fun sha256Hex(bytes: ByteArray): String {
        val digest = java.security.MessageDigest.getInstance("SHA-256")
        return com.mindhunter.g_launcher.theme.PackKeys.encodeHex(digest.digest(bytes))
    }
}

/** Outcome of an index refresh. */
sealed class IndexResult {
    data class Updated(val index: CdnIndex) : IndexResult()
    data class Unchanged(val index: CdnIndex) : IndexResult()
    /** Correctly signed but older than the cached one. Kept ours. */
    data class Stale(val kept: CdnIndex, val offered: Long) : IndexResult()
    /** Signature or shape failed. Worth reporting; never worth retrying blindly. */
    data class Rejected(val detail: String) : IndexResult()
    data class Failed(val detail: String) : IndexResult()
}

/**
 * Outcome of syncing one pack.
 *
 * Split the same way [VerifyResult] is, and for the same reason: the caller has
 * to behave differently. [NoSpace] and [AppTooOld] are user-actionable,
 * [Failed] is worth a retry, [Rejected] is not and should be reported, and
 * [UpToDate] is the overwhelmingly common case and must be silent.
 */
sealed class SyncResult {
    data class Installed(val manifest: PackManifest) : SyncResult()
    data class UpToDate(val version: Int) : SyncResult()
    data class NotOffered(val packId: String) : SyncResult()
    data class AppTooOld(val required: Int) : SyncResult()
    data class NoSpace(val needed: Long, val usable: Long) : SyncResult()
    object Cancelled : SyncResult()
    data class Rejected(val reason: VerifyResult) : SyncResult()
    data class Failed(val detail: String) : SyncResult()

    /**
     * A pack this one cannot work without could not be installed.
     *
     * Carries the failing dependency's OWN result rather than flattening to a
     * string, because the caller's next step depends on it: `AppTooOld` means
     * update the app, `NoSpace` means free some, `Failed` means retry. Losing
     * that distinction would turn every dependency problem into one unhelpful
     * message, and the whole reason this case exists is that the alternative
     * failure, a paid pack installed and blank, explains nothing at all.
     */
    data class MissingDependency(val packId: String, val cause: SyncResult) : SyncResult()
}
