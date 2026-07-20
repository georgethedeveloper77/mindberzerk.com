package com.mindhunter.g_launcher.theme

import java.io.File

/**
 * PHASE C1 - owns the packs directory on disk and the gate into it.
 *
 * SECURITY - DO NOT SKIP THIS (the original note, still true):
 * A theme drives fonts, colours, layout and icons. Content that drives UI is
 * code-adjacent. Verify the pack's ed25519 signature against the public key
 * baked into the app BEFORE unpacking or loading anything from it.
 * Without that check, whoever controls the CDN controls the app.
 *
 * The structural answer to that note is the two-directory rule:
 *
 *   packs/.staging/<packId>/   downloaded bytes, UNTRUSTED, nothing reads it
 *   packs/<packId>/            verified bytes, the only thing anything reads
 *
 * A file only ever crosses that line through [install], which will not move
 * anything until [PackVerifier] returns Ok. That is what makes the check
 * unskippable rather than merely documented: there is no other code path from
 * the network into a directory the theme resolver looks at.
 *
 * It matters more than it sounds. A half-written theme.json in the live packs
 * directory is not a cosmetic bug - it is the HOME SCREEN failing to parse on
 * every cold boot, on a device whose owner cannot open Settings to fix it
 * because Settings is reached through the launcher. `activeThemeSpecProvider`
 * falls back to bundled Ubuntu on a parse failure precisely so that is
 * survivable, but the right fix is for the bad file never to arrive.
 *
 * NO ANDROID IMPORTS HERE EITHER. The root directory is injected, so production
 * passes `File(context.filesDir, "packs")` and the tests pass a temp folder.
 * `cacheDir` would be wrong: the OS deletes it under storage pressure, and a
 * budget phone with 12GB free is under storage pressure permanently, so the
 * user's paid theme pack would evaporate at random.
 */
class ThemeAssetLoader(
    private val packsRoot: File,
    private val verifier: PackVerifier,
) {

    companion object {
        private const val STAGING_DIR = ".staging"

        /**
         * Where a swap parks the outgoing version while the new one moves in.
         * Named with a leading dot so it sorts and reads as internal, and
         * cleaned on every [prepareStaging] in case a previous process died
         * mid-swap.
         */
        private const val TRASH_DIR = ".trash"
    }

    /** The verified, readable directory for [packId]. May not exist yet. */
    fun installedDir(packId: String): File = File(packsRoot, packId)

    /** True when a verified copy of [packId] is on disk. */
    fun isInstalled(packId: String): Boolean =
        File(installedDir(packId), PackVerifier.MANIFEST_NAME).isFile

    /**
     * Clean staging for [packId] and hand back an empty directory to download
     * into. Also sweeps [TRASH_DIR], which is the recovery path for a process
     * killed mid-swap.
     *
     * Always starts empty. Resuming a partial download into a directory that
     * already has files would let yesterday's discarded bytes sit alongside
     * today's, and the unlisted-files check would reject the pack for reasons
     * nobody could work out from the error.
     */
    fun prepareStaging(packId: String): File? {
        if (!PackManifest.isSafePackId(packId)) return null
        File(packsRoot, TRASH_DIR).deleteRecursively()
        val dir = File(File(packsRoot, STAGING_DIR), packId)
        dir.deleteRecursively()
        return if (dir.mkdirs()) dir else null
    }

    /** Throw away a staged download without installing it. */
    fun discardStaging(packId: String) {
        if (!PackManifest.isSafePackId(packId)) return
        File(File(packsRoot, STAGING_DIR), packId).deleteRecursively()
    }

    /** The installed manifest, or null when nothing valid is installed. */
    fun installedManifest(packId: String): PackManifest? {
        if (!PackManifest.isSafePackId(packId)) return null
        val f = File(installedDir(packId), PackVerifier.MANIFEST_NAME)
        if (!f.isFile) return null
        return try {
            PackManifest.parse(f.readText())
        } catch (_: Exception) {
            null
        }
    }

    /** Installed pack version, or 0 when absent. */
    fun installedVersion(packId: String): Int = installedManifest(packId)?.version ?: 0

    /**
     * Verify the staged copy of [packId] and, if it passes, make it the
     * installed one.
     *
     * THE ROLLBACK FLOOR. A pack whose version is not strictly greater than
     * what is installed is refused. Without it a hostile or merely stale CDN
     * can serve you last month's pack - correctly signed, because it always
     * was - and walk you back onto a bug you already fixed. Signatures prove
     * authenticity, never freshness; the monotonic version is what proves
     * freshness, and it only works if the client enforces it.
     *
     * Re-installing the SAME version is refused too, and that is deliberate:
     * publishing a change without bumping the version is the mistake this
     * catches, and catching it loudly at install time beats debugging why a
     * device is serving content that no longer exists upstream.
     */
    fun install(packId: String): InstallResult {
        if (!PackManifest.isSafePackId(packId)) {
            return InstallResult.Rejected(VerifyResult.UnsafePath(packId))
        }

        val staged = File(File(packsRoot, STAGING_DIR), packId)
        if (!staged.isDirectory) return InstallResult.NothingStaged

        val result = verifier.verify(staged)
        if (result !is VerifyResult.Ok) {
            // A pack that failed verification is not kept around "in case".
            // There is no case; it is bytes of unknown origin sitting in the
            // app's private storage.
            staged.deleteRecursively()
            return InstallResult.Rejected(result)
        }

        val manifest = result.manifest

        // The directory name and the signed packId must agree, or a pack signed
        // for "fedora-41" could be installed as "ubuntu-24-04" and become the
        // fallback theme every failure path lands on.
        if (manifest.packId != packId) {
            staged.deleteRecursively()
            return InstallResult.Rejected(
                VerifyResult.MalformedManifest(
                    "packId '${manifest.packId}' does not match directory '$packId'",
                ),
            )
        }

        val current = installedVersion(packId)
        if (manifest.version <= current) {
            staged.deleteRecursively()
            return InstallResult.Stale(offered = manifest.version, installed = current)
        }

        val live = installedDir(packId)
        val trash = File(File(packsRoot, TRASH_DIR), "$packId-$current")

        packsRoot.mkdirs()
        trash.parentFile?.mkdirs()

        // THE SWAP. Two renames, not a copy: a rename within one filesystem is
        // effectively atomic, so there is no window in which the live directory
        // is half-populated. A recursive copy has exactly that window, and the
        // observer of it is the home screen.
        //
        // (`Files.move(..., ATOMIC_MOVE)` is the stricter tool but is API 26+,
        // and this runs on devices below that. `renameTo` inside one app's
        // filesDir is the same syscall in practice.)
        if (live.exists()) {
            if (!live.renameTo(trash)) {
                return InstallResult.SwapFailed("could not move the existing pack aside")
            }
        }

        if (!staged.renameTo(live)) {
            // Put it back. The device keeps the theme it had, which is the only
            // acceptable outcome of a failed install on a home screen.
            if (trash.exists()) trash.renameTo(live)
            return InstallResult.SwapFailed("could not move the verified pack into place")
        }

        trash.deleteRecursively()
        return InstallResult.Installed(manifest)
    }

    /** Remove an installed pack. The caller is responsible for not deleting the active one. */
    fun uninstall(packId: String): Boolean {
        if (!PackManifest.isSafePackId(packId)) return false
        return installedDir(packId).deleteRecursively()
    }

    /** Every installed pack id. Cheap directory scan; no parsing. */
    fun installedPackIds(): List<String> =
        packsRoot.listFiles()
            ?.filter { it.isDirectory && !it.name.startsWith(".") }
            ?.filter { File(it, PackVerifier.MANIFEST_NAME).isFile }
            ?.map { it.name }
            ?.sorted()
            ?: emptyList()
}

/**
 * Outcome of an install attempt.
 *
 * [Stale] is separated from [Rejected] on purpose: a stale pack is correctly
 * signed and perfectly valid, it is just behind. That is a normal race (two
 * devices, a cached CDN edge) and must not surface to the user as a security
 * warning, which is what folding it into [Rejected] would produce.
 */
sealed class InstallResult {
    data class Installed(val manifest: PackManifest) : InstallResult()
    object NothingStaged : InstallResult()
    data class Stale(val offered: Int, val installed: Int) : InstallResult()
    data class Rejected(val reason: VerifyResult) : InstallResult()
    data class SwapFailed(val detail: String) : InstallResult()
}
