package com.mindhunter.g_recovery.content

import java.io.File
import java.security.MessageDigest

/**
 * PORT OF `g_launcher/theme/PackVerifier.kt`.
 *
 * Reads only. Moves nothing, installs nothing, deletes nothing, so it has no
 * opinion about where packs live and can be tested with a temp directory and no
 * Android runtime.
 *
 * SPLIT IN TWO ON PURPOSE. The downloader fetches the manifest first, verifies
 * THAT alone, and only then knows the trusted file list, the trusted sizes, and
 * whether the pack is worth downloading at all. Capping each file download at
 * its signed size is only possible in that order.
 */
internal class ContentVerifier(
    private val acceptedKeys: Map<String, ByteArray>,
    val appVersionCode: Int,
) {

    companion object {
        const val MANIFEST_NAME = "manifest.json"
        const val SIGNATURE_NAME = "manifest.sig"
        private const val CHUNK = 64 * 1024
    }

    /**
     * The full gate. Runs again at install time even though the downloader
     * already checked the manifest, because "I already checked while
     * downloading" is exactly the assumption that turns a resumed or
     * interrupted transfer into an unverified install.
     */
    fun verify(dir: File): VerifyResult {
        val manifest = when (val r = verifyManifest(dir)) {
            is VerifyResult.Ok -> r.manifest
            else -> return r
        }
        return verifyContents(dir, manifest)
    }

    /**
     * SIGNATURE BEFORE CONTENT. Nothing in the manifest is trusted, not even
     * the file list, until the signature over it checks out. Reversing that
     * because it fails faster means acting on attacker controlled paths and
     * sizes.
     */
    fun verifyManifest(dir: File): VerifyResult {
        val manifestFile = File(dir, MANIFEST_NAME)
        val sigFile = File(dir, SIGNATURE_NAME)

        if (!manifestFile.isFile) return VerifyResult.MissingManifest
        if (!sigFile.isFile) return VerifyResult.MissingSignature

        if (manifestFile.length() > ContentManifest.MAX_MANIFEST_BYTES) {
            return VerifyResult.ManifestTooLarge(manifestFile.length())
        }
        if (sigFile.length() != Ed25519.SIGNATURE_BYTES.toLong()) {
            return VerifyResult.BadSignature(
                "signature is ${sigFile.length()} bytes, expected ${Ed25519.SIGNATURE_BYTES}",
            )
        }

        // The signature covers these EXACT bytes. Never re-serialise the parsed
        // manifest and verify against that: a round trip through any JSON
        // library reorders keys and normalises whitespace, and the signature
        // would never match.
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

        // The keyId is read before the signature is checked, which sounds
        // backwards and is not: it only picks WHICH trusted key to try, and
        // every candidate is one already accepted. Naming a key grants nothing.
        val keyId = try {
            ContentManifest.parse(String(manifestBytes, Charsets.UTF_8)).keyId
        } catch (e: ContentFormatException) {
            return VerifyResult.MalformedManifest(e.message ?: "malformed")
        }

        val publicKey = acceptedKeys[keyId] ?: return VerifyResult.UnknownKey(keyId)

        if (!Ed25519.verify(publicKey, manifestBytes, sigBytes)) {
            return VerifyResult.BadSignature("ed25519 verification failed for key '$keyId'")
        }

        // From here on the manifest is TRUSTED. Everything above treated it as
        // attacker controlled; everything below may rely on it.
        val manifest = try {
            ContentManifest.parse(String(manifestBytes, Charsets.UTF_8))
        } catch (e: ContentFormatException) {
            return VerifyResult.MalformedManifest(e.message ?: "malformed")
        }

        if (manifest.minAppVersion > appVersionCode) {
            return VerifyResult.AppTooOld(manifest.minAppVersion, appVersionCode)
        }

        return VerifyResult.Ok(manifest)
    }

    /** Never call with a manifest that did not come out of [verifyManifest]. */
    fun verifyContents(dir: File, manifest: ContentManifest): VerifyResult {
        for (f in manifest.files) {
            val target = File(dir, f.path)

            // Belt and braces over isSafeRelativePath: resolve the canonical
            // path and confirm it is still inside dir. The parser rejects
            // anything that could escape as a string, but a symlink placed by
            // the unpacker would not show up in a string check, and this is the
            // one place where being wrong is unrecoverable.
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
            // MessageDigest.isEqual out of habit. Both sides are public here so
            // the comparison is not secret dependent, but making constant time
            // comparison the reflex is cheaper than deciding case by case.
            if (!MessageDigest.isEqual(
                    actual.toByteArray(Charsets.US_ASCII),
                    f.sha256.toByteArray(Charsets.US_ASCII),
                )
            ) {
                return VerifyResult.HashMismatch(f.path, f.sha256, actual)
            }
        }

        // NOTHING UNLISTED MAY SURVIVE. Without this a pack could ship a file
        // the manifest never mentions, so the signature never covered it, and it
        // would land in the install directory looking exactly as trustworthy as
        // its signed neighbours. Content files are read by path, so an unsigned
        // extra is a real payload, not a stray README.
        val listed = manifest.files.mapTo(HashSet()) { it.path }
        listed.add(MANIFEST_NAME)
        listed.add(SIGNATURE_NAME)
        val extras = walkRelative(dir).filter { it !in listed }.sorted()
        if (extras.isNotEmpty()) return VerifyResult.UnlistedFiles(extras)

        return VerifyResult.Ok(manifest)
    }

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
        return ContentKeys.encodeHex(digest.digest())
    }

    private fun isContained(parent: File, child: File): Boolean = try {
        val p = parent.canonicalFile
        val c = child.canonicalFile
        c.path == p.path || c.path.startsWith(p.path + File.separator)
    } catch (_: Exception) {
        false
    }

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
 * A SEALED HIERARCHY, NOT A BOOLEAN, because the caller says different things
 * for different failures. [AppTooOld] means update the app and is not a problem
 * with the pack. [BadSignature] means something is actively wrong upstream and
 * must be reported, never retried. [IoError] is the only one worth a retry.
 */
internal sealed class VerifyResult {
    data class Ok(val manifest: ContentManifest) : VerifyResult()

    object MissingManifest : VerifyResult()
    object MissingSignature : VerifyResult()
    data class ManifestTooLarge(val bytes: Long) : VerifyResult()
    data class MalformedManifest(val detail: String) : VerifyResult()
    data class UnknownKey(val keyId: String) : VerifyResult()
    data class BadSignature(val detail: String) : VerifyResult()
    data class AppTooOld(val required: Int, val actual: Int) : VerifyResult()
    data class MissingFile(val path: String) : VerifyResult()
    data class SizeMismatch(val path: String, val expected: Long, val actual: Long) : VerifyResult()
    data class HashMismatch(val path: String, val expected: String, val actual: String) :
        VerifyResult()
    data class UnsafePath(val path: String) : VerifyResult()
    data class UnlistedFiles(val paths: List<String>) : VerifyResult()
    data class IoError(val detail: String) : VerifyResult()

    val isOk: Boolean get() = this is Ok

    /** One line for a ContentSyncResult detail. Never shown as the primary UI. */
    fun describe(): String = when (this) {
        is Ok -> "ok"
        MissingManifest -> "no manifest"
        MissingSignature -> "no signature"
        is ManifestTooLarge -> "manifest is $bytes bytes"
        is MalformedManifest -> "malformed manifest: $detail"
        is UnknownKey -> "unknown signing key '$keyId'"
        is BadSignature -> detail
        is AppTooOld -> "needs app version $required, this is $actual"
        is MissingFile -> "missing $path"
        is SizeMismatch -> "$path is $actual bytes, signed as $expected"
        is HashMismatch -> "$path does not match its signed hash"
        is UnsafePath -> "unsafe path $path"
        is UnlistedFiles -> "unsigned extra files: ${paths.take(3).joinToString()}"
        is IoError -> detail
    }
}
