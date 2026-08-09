package com.mindhunter.g_recovery.content

import org.json.JSONObject

/**
 * The signed catalogue: what packs exist, at what version, and WHERE.
 *
 * SIGNED SEPARATELY FROM THE PACKS, with the same keys. Without it a CDN with
 * write access could withhold an update indefinitely and the client would never
 * know it was behind, or serve an old pack whose own signature is still
 * perfectly valid. The index is what makes version a fact rather than a hope.
 *
 * ─── THE SHAPE IS THE PANEL'S, NOT ONE I CHOSE ──────────────────────────────
 *
 * `admin/src/lib/core/sign.ts` writes this file, and its comment is explicit
 * that the signature covers the exact serialised bytes. Everything here is read
 * from what that function emits. The two fields worth calling out:
 *
 *  * `path` is `<dir>/<packId>/<version>`, VERSION INCLUDED, so every object
 *    under a pack is immutable and cacheable for a year. Following it rather
 *    than assembling a path from the packId is not optional: the directory
 *    depends on the pack type, and the panel's own history includes two publish
 *    paths that disagreed about exactly that and orphaned files for months.
 *  * `generatedAt` is unix SECONDS, and it is the replay guard. A device that
 *    accepts an older index can be pinned to a stale catalogue forever by an
 *    edge that keeps serving yesterday's copy.
 */
internal data class ContentIndex(
    val formatVersion: Int,
    val generatedAt: Long,
    val keyId: String,
    val entries: List<Entry>,
) {
    internal data class Entry(
        val packId: String,
        val packType: String,
        /** `<dir>/<packId>/<version>`, relative to the app prefix on the CDN. */
        val path: String,
        val version: Int,
        val minAppVersion: Int,
        val sizeBytes: Long,
        val title: String,
        val summary: String,
    )

    companion object {
        const val MAX_INDEX_BYTES: Int = 256 * 1024

        /** The only format this build reads. Higher is refused, not guessed at. */
        const val SUPPORTED_FORMAT_VERSION: Int = 1

        fun parse(json: String): ContentIndex {
            val root = try {
                JSONObject(json)
            } catch (e: Exception) {
                throw ContentFormatException("index is not valid JSON: ${e.message}")
            }

            val formatVersion = root.optInt("formatVersion", 0)
            if (formatVersion != SUPPORTED_FORMAT_VERSION) {
                throw ContentFormatException(
                    "unsupported index formatVersion $formatVersion " +
                        "(this build speaks $SUPPORTED_FORMAT_VERSION)",
                )
            }

            val generatedAt = root.optLong("generatedAt", 0L)
            if (generatedAt <= 0L) throw ContentFormatException("index has no generatedAt")

            val array = root.optJSONArray("packs")
                ?: throw ContentFormatException("index has no 'packs'")

            val out = ArrayList<Entry>(array.length())
            for (i in 0 until array.length()) {
                val o = array.optJSONObject(i) ?: continue

                // A BAD ENTRY IS SKIPPED rather than fatal, which is the opposite
                // of the manifest rule. An index describes many packs for many
                // client versions, and one malformed row must not stop the
                // others installing. A manifest describes one thing, so there
                // half-parsing means admitting files.
                val packId = o.optString("packId", "")
                if (!ContentManifest.isSafePackId(packId)) continue

                val path = o.optString("path", "")
                if (!isSafeIndexPath(path)) continue

                val version = o.optInt("version", 0)
                if (version < 1) continue

                out.add(
                    Entry(
                        packId = packId,
                        packType = o.optString("packType", "registry"),
                        path = path,
                        version = version,
                        minAppVersion = o.optInt("minAppVersion", 0),
                        sizeBytes = o.optLong("sizeBytes", 0L),
                        title = o.optString("title", packId),
                        summary = o.optString("summary", ""),
                    )
                )
            }
            return ContentIndex(
                formatVersion = formatVersion,
                generatedAt = generatedAt,
                keyId = root.optString("keyId", ""),
                entries = out,
            )
        }

        /**
         * A pack path is joined onto the CDN base to build a URL, so it is held
         * to the same standard as a payload path minus the file extension rule:
         * no leading or trailing slash, no traversal, no empty segments.
         *
         * `CdnClient.resolve` refuses these too. Both, because a path rejected
         * here is one whose whole pack is skipped with the others still
         * installing, while one that reaches the client is a failed fetch.
         */
        fun isSafeIndexPath(path: String): Boolean {
            if (path.isEmpty() || path.length > 200) return false
            if (path.startsWith("/") || path.endsWith("/")) return false
            if (path.contains("..") || path.contains("//")) return false
            if (path.contains('\\') || path.contains('\u0000')) return false
            return path.split('/').all { segment ->
                segment.isNotEmpty() &&
                    segment.all {
                        it in 'a'..'z' || it in 'A'..'Z' || it in '0'..'9' ||
                            it == '-' || it == '_' || it == '.'
                    }
            }
        }
    }
}
