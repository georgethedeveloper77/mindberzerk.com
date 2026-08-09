package com.mindhunter.g_recovery.recovery

import org.json.JSONArray
import org.json.JSONObject

/**
 * The trash path registry, parsed from JSON pushed in by Dart.
 *
 * PUSHED FROM DART rather than read from assets here, and that is the whole
 * architecture: Dart decides where the JSON came from. Today it is a bundled
 * asset. In Phase 7 it is a signed CDN pack and not one line of this file
 * changes. Recovery coverage is data, not code, which is the only way this app
 * ever supports a Tecno that nobody on the team owns.
 *
 * Every path in it is a CANDIDATE. The scanner probes each and reports only what
 * exists and holds files, so a wrong entry costs one stat call. That is what
 * makes it safe to publish guesses about hardware we cannot test on.
 */
internal class TrashMap private constructor(
    val version: Int,
    val restoreFolder: String,
    val appEntries: List<Entry>,
    val oemEntries: List<Entry>,
    val thumbnailPaths: List<String>,
) {

    internal data class Entry(
        val label: String,
        val paths: List<String>,
        val fidelity: String,
        val retentionDays: Int?,
        /** "trash" | "status" | "cache". Unknown values are passed through. */
        val role: String,
    )

    /** Every non-thumbnail candidate, app entries first. */
    fun fileEntries(): List<Entry> = appEntries + oemEntries

    companion object {
        /** Used until Dart pushes the real one, so a scan before startup finishes returns empty rather than crashing. */
        val empty =
            TrashMap(0, "Pictures/G Recovery", emptyList(), emptyList(), emptyList())

        /**
         * Never throws. A malformed pack means degraded coverage, which is
         * recoverable; a crash on launch is not. The same reasoning as the prefs
         * store on the Dart side.
         */
        fun parse(json: String): TrashMap = try {
            val root = JSONObject(json)
            TrashMap(
                version = root.optInt("version", 0),
                restoreFolder = root.optString("restoreFolder", "Pictures/G Recovery"),
                appEntries = entries(root.optJSONArray("apps")),
                oemEntries = entries(root.optJSONArray("oem")),
                thumbnailPaths = strings(
                    root.optJSONObject("thumbnails")?.optJSONArray("paths")
                ),
            )
        } catch (_: Throwable) {
            empty
        }

        private fun entries(array: JSONArray?): List<Entry> {
            if (array == null) return emptyList()
            val out = mutableListOf<Entry>()
            for (i in 0 until array.length()) {
                val item = array.optJSONObject(i) ?: continue
                val paths = strings(item.optJSONArray("paths"))
                if (paths.isEmpty()) continue
                out.add(
                    Entry(
                        label = item.optString("label", "Unknown"),
                        paths = paths,
                        fidelity = item.optString("fidelity", "full"),
                        retentionDays = if (item.has("retentionDays")) {
                            item.optInt("retentionDays")
                        } else {
                            null
                        },
                        // Defaults to trash, so a pack written before roles
                        // existed keeps working unchanged.
                        role = item.optString("role", "trash"),
                    )
                )
            }
            return out
        }

        private fun strings(array: JSONArray?): List<String> {
            if (array == null) return emptyList()
            val out = mutableListOf<String>()
            for (i in 0 until array.length()) {
                val value = array.optString(i)
                // A path with a separator at the front would escape the external
                // storage root when joined. Rejected here rather than at every
                // use site.
                if (value.isNotBlank() && !value.startsWith("/") && !value.contains("..")) {
                    out.add(value)
                }
            }
            return out
        }
    }
}
