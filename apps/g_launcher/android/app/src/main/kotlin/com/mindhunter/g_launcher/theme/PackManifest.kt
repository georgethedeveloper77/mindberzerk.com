package com.mindhunter.g_launcher.theme

import org.json.JSONArray
import org.json.JSONObject

/**
 * PHASE C1 - the signed description of a downloadable pack.
 *
 * ONE SIGNATURE, OVER THIS FILE ONLY. The manifest carries a SHA-256 for every
 * payload file, so a single 64-byte signature covers a pack of arbitrary size,
 * and verification streams: hash each file as it comes off disk, compare, stop
 * at the first mismatch. Nothing is ever buffered whole. That matters because
 * the target device is a 3GB Tecno, not a workstation, and a 40MB wallpaper
 * pack read into a ByteArray is an OOM on the home screen.
 *
 * The alternative - signing each file separately - costs a signature per file,
 * still needs a signed index to stop file *removal*, and buys nothing.
 *
 * ON `org.json`: it is part of Android, so it costs no APK size, but the
 * android.jar on the unit-test classpath is a STUB whose methods throw. That is
 * why `build.gradle.kts` adds `testImplementation("org.json:json:...")` - a real
 * implementation for tests. Without it every parse test fails in a way that
 * looks like a parser bug and is not.
 */
data class PackManifest(
    val formatVersion: Int,
    val packType: String,
    val packId: String,
    val version: Int,
    val minAppVersion: Int,
    val keyId: String,
    val files: List<PackFile>,
) {
    companion object {
        /**
         * The only format this build understands. A pack declaring a higher one
         * is refused rather than best-effort parsed: an unknown format may well
         * mean an unknown security-relevant field, and "ignore what you do not
         * recognise" is exactly how a signed format gets downgraded.
         *
         * This is the OPPOSITE of the rule ThemeSpec.fromJson follows for theme
         * bodies, where unknown keys degrade gracefully. Different layer,
         * different stakes: a theme that half-parses renders oddly, a manifest
         * that half-parses admits files.
         */
        const val SUPPORTED_FORMAT_VERSION: Int = 1

        /** Hard cap on the manifest itself. A signed file this large is wrong. */
        const val MAX_MANIFEST_BYTES: Int = 256 * 1024

        val KNOWN_PACK_TYPES: Set<String> = setOf("theme", "brand", "hero", "icon")

        /**
         * Parse, or throw [PackFormatException].
         *
         * Strict on purpose: missing key, wrong type, empty string and negative
         * number all fail. There is no default-and-continue path here.
         */
        fun parse(json: String): PackManifest {
            val root = try {
                JSONObject(json)
            } catch (e: Exception) {
                throw PackFormatException("manifest is not valid JSON: ${e.message}")
            }

            val formatVersion = root.reqInt("formatVersion")
            if (formatVersion != SUPPORTED_FORMAT_VERSION) {
                throw PackFormatException(
                    "unsupported formatVersion $formatVersion " +
                        "(this build speaks $SUPPORTED_FORMAT_VERSION)",
                )
            }

            val packType = root.reqString("packType")
            if (packType !in KNOWN_PACK_TYPES) {
                throw PackFormatException("unknown packType '$packType'")
            }

            val packId = root.reqString("packId")
            if (!isSafePackId(packId)) {
                throw PackFormatException("unsafe packId '$packId'")
            }

            val version = root.reqInt("version")
            if (version < 1) throw PackFormatException("version must be >= 1")

            val minAppVersion = root.reqInt("minAppVersion")
            if (minAppVersion < 0) throw PackFormatException("minAppVersion must be >= 0")

            val keyId = root.reqString("keyId")

            val filesArray: JSONArray = root.optJSONArray("files")
                ?: throw PackFormatException("missing 'files'")
            if (filesArray.length() == 0) {
                throw PackFormatException("'files' is empty; a pack with no payload is not a pack")
            }

            val files = ArrayList<PackFile>(filesArray.length())
            val seen = HashSet<String>()
            for (i in 0 until filesArray.length()) {
                val o = filesArray.optJSONObject(i)
                    ?: throw PackFormatException("files[$i] is not an object")

                val path = o.reqString("path")
                if (!isSafeRelativePath(path)) {
                    throw PackFormatException("unsafe path in files[$i]: '$path'")
                }
                // Duplicate paths would let a pack list one path twice with two
                // different hashes - one to satisfy the check, one to describe
                // the file that actually lands. Reject rather than pick.
                if (!seen.add(path)) {
                    throw PackFormatException("duplicate path '$path'")
                }

                val size = o.reqLong("size")
                if (size < 0) throw PackFormatException("negative size for '$path'")

                val sha256 = o.reqString("sha256").lowercase()
                if (sha256.length != 64 || PackKeys.decodeHex(sha256) == null) {
                    throw PackFormatException("sha256 for '$path' is not 32 hex bytes")
                }

                files.add(PackFile(path = path, size = size, sha256 = sha256))
            }

            return PackManifest(
                formatVersion = formatVersion,
                packType = packType,
                packId = packId,
                version = version,
                minAppVersion = minAppVersion,
                keyId = keyId,
                files = files,
            )
        }

        /**
         * A pack id becomes a DIRECTORY NAME under filesDir, so it is held to
         * the same standard as a payload path: lowercase, digits, dash, dot,
         * underscore, and never a dot-run. `..` as a packId would place the
         * install root outside the packs directory.
         */
        fun isSafePackId(id: String): Boolean {
            if (id.isEmpty() || id.length > 64) return false
            if (id == "." || id == "..") return false
            if (id.startsWith(".")) return false
            return id.all { it in 'a'..'z' || it in '0'..'9' || it == '-' || it == '_' || it == '.' }
        }

        /**
         * THE TRAVERSAL GATE. Every payload path is joined to a directory we
         * own, so a path that escapes it writes anywhere the app can write -
         * including over the app's own files. This is the single highest-value
         * check in the file and it is intentionally paranoid.
         *
         * Rejected: absolute paths, any '..' segment, any '.' segment, leading
         * or trailing slash, empty segments (which '//' produces), backslashes
         * (a Windows-authored manifest, and a separator on some filesystems),
         * NUL bytes, and anything over 200 chars. Allowed characters are a
         * deliberate allowlist, not a denylist, because a denylist for
         * filesystem paths is a losing game across Android's OEM-patched
         * kernels and FAT-formatted external storage.
         */
        fun isSafeRelativePath(path: String): Boolean {
            if (path.isEmpty() || path.length > 200) return false
            if (path.startsWith("/") || path.endsWith("/")) return false
            if (path.contains('\\') || path.contains('\u0000')) return false
            // A Windows drive letter is absolute even though it has no leading
            // slash. Cheap to check, embarrassing to miss.
            if (path.length >= 2 && path[1] == ':') return false

            val segments = path.split('/')
            for (s in segments) {
                if (s.isEmpty() || s == "." || s == "..") return false
                if (s.startsWith(" ") || s.endsWith(" ")) return false
                val ok = s.all {
                    it in 'a'..'z' || it in 'A'..'Z' || it in '0'..'9' ||
                        it == '-' || it == '_' || it == '.'
                }
                if (!ok) return false
            }
            return true
        }

        private fun JSONObject.reqString(key: String): String {
            if (!has(key) || isNull(key)) throw PackFormatException("missing '$key'")
            val v = optString(key, "")
            if (v.isEmpty()) throw PackFormatException("'$key' is empty")
            return v
        }

        private fun JSONObject.reqInt(key: String): Int {
            if (!has(key) || isNull(key)) throw PackFormatException("missing '$key'")
            // optInt returns the fallback for a non-numeric value, which would
            // silently turn a string "1" into a valid formatVersion. Check the
            // raw type first.
            val raw = opt(key)
            if (raw !is Number) throw PackFormatException("'$key' is not a number")
            return raw.toInt()
        }

        private fun JSONObject.reqLong(key: String): Long {
            if (!has(key) || isNull(key)) throw PackFormatException("missing '$key'")
            val raw = opt(key)
            if (raw !is Number) throw PackFormatException("'$key' is not a number")
            return raw.toLong()
        }
    }
}

/** One payload file inside a pack. [sha256] is lowercase hex. */
data class PackFile(
    val path: String,
    val size: Long,
    val sha256: String,
)

/** The manifest is malformed. Distinct from "the manifest is a lie". */
class PackFormatException(message: String) : Exception(message)
