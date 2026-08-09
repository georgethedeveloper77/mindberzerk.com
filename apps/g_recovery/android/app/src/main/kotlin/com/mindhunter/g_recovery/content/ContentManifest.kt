package com.mindhunter.g_recovery.content

import org.json.JSONArray
import org.json.JSONObject

/**
 * PORT OF `g_launcher/theme/PackManifest.kt`. Same format, same rules, and the
 * pack types are the only difference: this app ships registries and articles,
 * not themes and icons.
 *
 * ONE SIGNATURE, OVER THIS FILE ONLY. The manifest carries a SHA-256 for every
 * payload file, so a single 64 byte signature covers a pack of any size and
 * verification streams. Nothing is ever buffered whole.
 *
 * ON `org.json`: it is part of Android so it costs no APK size, but the
 * android.jar on the unit test classpath is a STUB whose methods throw. Tests
 * need a real `org.json:json` on the test classpath or every parse test fails
 * in a way that looks like a parser bug and is not.
 */
internal data class ContentManifest(
    val formatVersion: Int,
    val packType: String,
    val packId: String,
    val version: Int,
    val minAppVersion: Int,
    val keyId: String,
    val files: List<ContentFile>,
) {
    companion object {
        /**
         * A pack declaring a higher version is REFUSED rather than best effort
         * parsed. An unknown format may carry an unknown security relevant
         * field, and "ignore what you do not recognise" is how a signed format
         * gets downgraded.
         */
        const val SUPPORTED_FORMAT_VERSION: Int = 1

        const val MAX_MANIFEST_BYTES: Int = 256 * 1024

        /** Different from the launcher's set. Same slot, different app. */
        val KNOWN_PACK_TYPES: Set<String> = setOf("registry", "article", "guide")

        fun parse(json: String): ContentManifest {
            val root = try {
                JSONObject(json)
            } catch (e: Exception) {
                throw ContentFormatException("manifest is not valid JSON: ${e.message}")
            }

            val formatVersion = root.reqInt("formatVersion")
            if (formatVersion != SUPPORTED_FORMAT_VERSION) {
                throw ContentFormatException(
                    "unsupported formatVersion $formatVersion " +
                        "(this build speaks $SUPPORTED_FORMAT_VERSION)",
                )
            }

            val packType = root.reqString("packType")
            if (packType !in KNOWN_PACK_TYPES) {
                throw ContentFormatException("unknown packType '$packType'")
            }

            val packId = root.reqString("packId")
            if (!isSafePackId(packId)) {
                throw ContentFormatException("unsafe packId '$packId'")
            }

            val version = root.reqInt("version")
            if (version < 1) throw ContentFormatException("version must be >= 1")

            val minAppVersion = root.reqInt("minAppVersion")
            if (minAppVersion < 0) throw ContentFormatException("minAppVersion must be >= 0")

            val keyId = root.reqString("keyId")

            val filesArray: JSONArray = root.optJSONArray("files")
                ?: throw ContentFormatException("missing 'files'")
            if (filesArray.length() == 0) {
                throw ContentFormatException("'files' is empty; a pack with no payload is not a pack")
            }

            val files = ArrayList<ContentFile>(filesArray.length())
            val seen = HashSet<String>()
            for (i in 0 until filesArray.length()) {
                val o = filesArray.optJSONObject(i)
                    ?: throw ContentFormatException("files[$i] is not an object")

                val path = o.reqString("path")
                if (!isSafeRelativePath(path)) {
                    throw ContentFormatException("unsafe path in files[$i]: '$path'")
                }
                // A duplicate path would let a pack list one path twice with two
                // hashes, one to satisfy the check and one to describe the file
                // that actually lands. Reject rather than pick.
                if (!seen.add(path)) {
                    throw ContentFormatException("duplicate path '$path'")
                }

                val size = o.reqLong("size")
                if (size < 0) throw ContentFormatException("negative size for '$path'")

                val sha256 = o.reqString("sha256").lowercase()
                if (sha256.length != 64 || ContentKeys.decodeHex(sha256) == null) {
                    throw ContentFormatException("sha256 for '$path' is not 32 hex bytes")
                }

                files.add(ContentFile(path = path, size = size, sha256 = sha256))
            }

            return ContentManifest(
                formatVersion, packType, packId, version, minAppVersion, keyId, files,
            )
        }

        /**
         * A pack id becomes a DIRECTORY NAME under filesDir, so it is held to
         * the same standard as a payload path. `..` as a packId would place the
         * install root outside the content directory.
         */
        fun isSafePackId(id: String): Boolean {
            if (id.isEmpty() || id.length > 64) return false
            if (id == "." || id == "..") return false
            if (id.startsWith(".")) return false
            return id.all { it in 'a'..'z' || it in '0'..'9' || it == '-' || it == '_' || it == '.' }
        }

        /**
         * THE TRAVERSAL GATE. Every payload path is joined to a directory we
         * own, so a path that escapes writes anywhere the app can write,
         * including over the app's own files. Intentionally paranoid, and an
         * allowlist rather than a denylist, because a denylist for filesystem
         * paths is a losing game across OEM patched kernels and FAT external
         * storage.
         */
        fun isSafeRelativePath(path: String): Boolean {
            if (path.isEmpty() || path.length > 200) return false
            if (path.startsWith("/") || path.endsWith("/")) return false
            if (path.contains('\\') || path.contains('\u0000')) return false
            // A Windows drive letter is absolute with no leading slash. Cheap to
            // check, embarrassing to miss.
            if (path.length >= 2 && path[1] == ':') return false

            for (segment in path.split('/')) {
                if (segment.isEmpty() || segment == "." || segment == "..") return false
                if (segment.startsWith(" ") || segment.endsWith(" ")) return false
                val ok = segment.all {
                    it in 'a'..'z' || it in 'A'..'Z' || it in '0'..'9' ||
                        it == '-' || it == '_' || it == '.'
                }
                if (!ok) return false
            }
            return true
        }

        private fun JSONObject.reqString(key: String): String {
            if (!has(key) || isNull(key)) throw ContentFormatException("missing '$key'")
            val v = optString(key, "")
            if (v.isEmpty()) throw ContentFormatException("'$key' is empty")
            return v
        }

        private fun JSONObject.reqInt(key: String): Int {
            if (!has(key) || isNull(key)) throw ContentFormatException("missing '$key'")
            // optInt returns the fallback for a non-numeric value, which would
            // silently turn a string "1" into a valid formatVersion.
            val raw = opt(key)
            if (raw !is Number) throw ContentFormatException("'$key' is not a number")
            return raw.toInt()
        }

        private fun JSONObject.reqLong(key: String): Long {
            if (!has(key) || isNull(key)) throw ContentFormatException("missing '$key'")
            val raw = opt(key)
            if (raw !is Number) throw ContentFormatException("'$key' is not a number")
            return raw.toLong()
        }
    }
}

internal data class ContentFile(val path: String, val size: Long, val sha256: String)

/** The manifest is malformed. Distinct from "the manifest is a lie". */
internal class ContentFormatException(message: String) : Exception(message)
