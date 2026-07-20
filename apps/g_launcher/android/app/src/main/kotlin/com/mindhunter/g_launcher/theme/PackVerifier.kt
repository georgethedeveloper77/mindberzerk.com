package com.mindhunter.g_launcher.theme

import com.mindhunter.g_launcher.crypto.Ed25519
import java.io.File
import java.security.MessageDigest

/**
 * PHASE C1 - decides whether a staged pack directory is trustworthy.
 *
 * Reads only. Moves nothing, installs nothing, deletes nothing - that is
 * [ThemeAssetLoader]'s job. Kept separate so this class has no opinion about
 * where packs live and can be tested with a temp directory and no Android
 * runtime at all.
 *
 * NO `android.*` IMPORTS IN THIS FILE. That is the property that makes the
 * whole thing unit-testable on the JVM, and it is easy to lose by reaching for
 * `android.util.Base64` or `Log`. If you need to log, return a result and let
 * the caller log it.
 *
 * The crypto itself lives in `crypto/Ed25519`, shared with the CDN index.
 *
 * PHASE C2 SPLIT THIS IN TWO. [verifyManifest] and [verifyContents] used to be
 * one method, and the downloader needs them apart: it fetches the manifest
 * first, verifies THAT alone, and only then knows the trusted list of files,
 * their trusted sizes and whether the pack is even worth downloading. Capping
 * each file download at its signed size is only possible in that order.
 * [verify] still runs both, and remains the single gate at install time.
 */
class PackVerifier(
    /** keyId -> raw 32-byte ed25519 public key. Usually [PackKeys.accepted]. */
    private val acceptedKeys: Map<String, ByteArray>,
    /**
     * This build's versionCode, checked against the manifest's minAppVersion.
     * PUBLIC so PackDownloader can make the same comparison against the index's
     * advisory copy and skip a pointless transfer. One number, one owner: a
     * constant copied into two files drifts the first time someone bumps one.
     */
    val appVersionCode: Int,
) {

    companion object {
        const val MANIFEST_NAME = "manifest.json"
        const val SIGNATURE_NAME = "manifest.sig"

        /** Streaming read size. Small enough to be invisible in a 3GB heap. */
        private const val CHUNK = 64 * 1024
    }

    /**
     * Verify [dir] as a complete pack: signature, then every file.
     *
     * THIS IS THE GATE. `ThemeAssetLoader.install` calls it and moves nothing
     * unless it returns Ok. The downloader calls the two halves separately for
     * its own reasons, but the full check always runs again here, because
     * "I already checked while downloading" is exactly the assumption that
     * turns a resumed or interrupted download into an unverified install.
     */
    fun verify(dir: File): VerifyResult {
        val manifest = when (val r = verifyManifest(dir)) {
            is VerifyResult.Ok -> r.manifest
            else -> return r
        }
        return verifyContents(dir, manifest)
    }

    /**
     * Verify ONLY the manifest and its signature. The payload files need not
     * exist yet, which is the point: the downloader fetches these two small
     * files first, and everything it does next - the version-floor check that
     * may abort the download entirely, the free-space check, the per-file byte
     * cap - depends on having a TRUSTED file list before a single payload byte
     * is fetched.
     *
     * Order is deliberate: SIGNATURE BEFORE CONTENT. Nothing in the manifest is
     * trusted, not even the file list, until the signature over it checks out.
     * Reversing that because it "fails faster" means acting on attacker
     * controlled paths and sizes.
     */
    fun verifyManifest(dir: File): VerifyResult {
        val manifestFile = File(dir, MANIFEST_NAME)
        val sigFile = File(dir, SIGNATURE_NAME)

        if (!manifestFile.isFile) return VerifyResult.MissingManifest
        if (!sigFile.isFile) return VerifyResult.MissingSignature

        if (manifestFile.length() > PackManifest.MAX_MANIFEST_BYTES) {
            return VerifyResult.ManifestTooLarge(manifestFile.length())
        }
        if (sigFile.length() != Ed25519.SIGNATURE_BYTES.toLong()) {
            return VerifyResult.BadSignature(
                "signature is ${sigFile.length()} bytes, expected ${Ed25519.SIGNATURE_BYTES}",
            )
        }

        // The signature covers these EXACT bytes. Never re-serialise the parsed
        // manifest and verify against that: a round-trip through any JSON
        // library reorders keys and normalises whitespace, and the signature
        // would never match. It also means the bytes are read once and the
        // parse happens on the same array that was verified.
        val manifestBytes = try {
            manifestFile.readBytes()
        } catch (e: Exception) {
            return VerifyResult.IoError("reading manifest: ${e.message}")
        }
        val sigBytes = try {
            sigFile.readBytes()
        } catch (e: Exception) {
            return VerifyResult.IoError("reading signature: ${e.message}")
        }

        // The keyId is read from the manifest BEFORE the signature is checked,
        // which sounds backwards. It is not: we only use it to pick which
        // public key to try, and every candidate key is one we already trust.
        // Naming a key does not grant anything; a pack that names a key it
        // cannot sign for still fails below.
        val keyId = try {
            PackManifest.parse(String(manifestBytes, Charsets.UTF_8)).keyId
        } catch (e: PackFormatException) {
            return VerifyResult.MalformedManifest(e.message ?: "malformed")
        }

        val publicKey = acceptedKeys[keyId] ?: return VerifyResult.UnknownKey(keyId)

        if (!Ed25519.verify(publicKey, manifestBytes, sigBytes)) {
            return VerifyResult.BadSignature("ed25519 verification failed for key '$keyId'")
        }

        // ── From here on the manifest is TRUSTED. Everything above this line
        //    treated it as attacker-controlled; everything below may rely on it.
        val manifest = try {
            PackManifest.parse(String(manifestBytes, Charsets.UTF_8))
        } catch (e: PackFormatException) {
            return VerifyResult.MalformedManifest(e.message ?: "malformed")
        }

        if (manifest.minAppVersion > appVersionCode) {
            return VerifyResult.AppTooOld(manifest.minAppVersion, appVersionCode)
        }

        return VerifyResult.Ok(manifest)
    }

    /**
     * Verify the payload against an ALREADY-VERIFIED [manifest].
     *
     * Never call this with a manifest that did not come out of
     * [verifyManifest]. The paths in it are used to open files.
     */
    fun verifyContents(dir: File, manifest: PackManifest): VerifyResult {
        for (f in manifest.files) {
            val target = File(dir, f.path)

            // Belt and braces over PackManifest.isSafeRelativePath: resolve the
            // canonical path and confirm it is still inside `dir`. The parser
            // should already have rejected anything that could escape, but a
            // symlink placed by the unpacker would not show up in the string
            // check, and this is the one place where being wrong is
            // unrecoverable.
            if (!isContained(dir, target)) return VerifyResult.UnsafePath(f.path)
            if (!target.isFile) return VerifyResult.MissingFile(f.path)
            if (target.length() != f.size) {
                return VerifyResult.SizeMismatch(f.path, f.size, target.length())
            }

            val actual = try {
                sha256Hex(target)
            } catch (e: Exception) {
                return VerifyResult.IoError("hashing ${f.path}: ${e.message}")
            }
            // MessageDigest.isEqual rather than String.equals out of habit. The
            // comparison is not secret-dependent here (both sides are public),
            // but making constant-time comparison the reflex is cheaper than
            // deciding case by case.
            if (!MessageDigest.isEqual(
                    actual.toByteArray(Charsets.US_ASCII),
                    f.sha256.toByteArray(Charsets.US_ASCII),
                )
            ) {
                return VerifyResult.HashMismatch(f.path, f.sha256, actual)
            }
        }

        // NOTHING UNLISTED MAY SURVIVE. Without this a pack could ship a file
        // the manifest never mentions - so the signature never covered it - and
        // it would land in the install directory looking exactly as trustworthy
        // as its signed neighbours. Font files and wallpapers are loaded by
        // path, so an unsigned extra is a real payload, not a stray README.
        val listed = manifest.files.mapTo(HashSet()) { f -> f.path }
        listed.add(MANIFEST_NAME)
        listed.add(SIGNATURE_NAME)
        val extras = walkRelative(dir).filter { it !in listed }.sorted()
        if (extras.isNotEmpty()) return VerifyResult.UnlistedFiles(extras)

        return VerifyResult.Ok(manifest)
    }

    // ── internals ────────────────────────────────────────────────────────────

    private fun sha256Hex(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buf = ByteArray(CHUNK)
            while (true) {
                val n = input.read(buf)
                if (n <= 0) break
                digest.update(buf, 0, n)
            }
        }
        return PackKeys.encodeHex(digest.digest())
    }

    /** True when [child] resolves to something inside [parent]. */
    private fun isContained(parent: File, child: File): Boolean = try {
        val p = parent.canonicalFile
        val c = child.canonicalFile
        c.path == p.path || c.path.startsWith(p.path + File.separator)
    } catch (_: Exception) {
        false
    }

    /** Every regular file under [root], as forward-slash relative paths. */
    private fun walkRelative(root: File): List<String> {
        val out = ArrayList<String>()
        val prefixLength = root.path.length + 1
        root.walkTopDown().forEach { f ->
            if (f.isFile) out.add(f.path.substring(prefixLength).replace(File.separatorChar, '/'))
        }
        return out
    }
}

/**
 * Why a pack was accepted or refused.
 *
 * A SEALED HIERARCHY, NOT A BOOLEAN, because the caller has to say different
 * things to the user for different failures. [AppTooOld] means "update G
 * Launcher" and is not a problem with the pack; [BadSignature] means something
 * is actively wrong upstream and should be reported, not retried; [IoError] is
 * the only one worth a retry button. Collapsing these to `false` produces the
 * "Download failed" dialog that tells nobody anything.
 */
sealed class VerifyResult {
    data class Ok(val manifest: PackManifest) : VerifyResult()

    object MissingManifest : VerifyResult()
    object MissingSignature : VerifyResult()
    data class ManifestTooLarge(val bytes: Long) : VerifyResult()
    data class MalformedManifest(val detail: String) : VerifyResult()
    data class UnknownKey(val keyId: String) : VerifyResult()
    data class BadSignature(val detail: String) : VerifyResult()
    data class AppTooOld(val required: Int, val actual: Int) : VerifyResult()
    data class MissingFile(val path: String) : VerifyResult()
    data class SizeMismatch(val path: String, val expected: Long, val actual: Long) : VerifyResult()
    data class HashMismatch(val path: String, val expected: String, val actual: String) : VerifyResult()
    data class UnsafePath(val path: String) : VerifyResult()
    data class UnlistedFiles(val paths: List<String>) : VerifyResult()
    data class IoError(val detail: String) : VerifyResult()

    val isOk: Boolean get() = this is Ok
}
