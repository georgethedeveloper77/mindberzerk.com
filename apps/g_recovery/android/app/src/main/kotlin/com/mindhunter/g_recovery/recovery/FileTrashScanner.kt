package com.mindhunter.g_recovery.recovery

import android.os.Environment
import android.webkit.MimeTypeMap
import java.io.File

/**
 * Loose files in trash directories and in the thumbnail cache.
 *
 * Everything here is a CANDIDATE PATH from the trashmap. Each is probed and only
 * what exists and holds files is reported, so a wrong entry costs one stat call.
 * That is precisely what makes it safe for the panel to publish paths for
 * hardware nobody on the team owns.
 *
 * Fidelity is carried per entry, and it is not decoration. A file recovered from
 * a thumbnail cache is a few hundred pixels on the long edge and can never be
 * anything more. Saying so is the difference between this app and the category.
 */
internal class FileTrashScanner {

    private val root: File get() = Environment.getExternalStorageDirectory()

    /** Shallow count for the pre-scan. Does not recurse. */
    fun countThumbnails(map: TrashMap): Pair<Int, Long> {
        var items = 0
        var bytes = 0L
        for (path in map.thumbnailPaths) {
            val dir = File(root, path)
            if (!dir.isDirectory) continue
            dir.listFiles()?.forEach { file ->
                if (file.isFile && file.length() > 0) {
                    items++
                    bytes += file.length()
                }
            }
        }
        return Pair(items, bytes)
    }

    fun scanEntries(
        entries: List<TrashMap.Entry>,
        index: RecoveryIndex,
        sourceId: String,
        fidelityOverride: String?,
        isCancelled: () -> Boolean,
        onProgress: (scanned: Int, total: Int) -> Unit,
    ) {
        val dirs = entries.flatMap { entry ->
            entry.paths.map { path -> Pair(entry, File(root, path)) }
        }.filter { it.second.isDirectory }

        // A real total, taken before the walk. Not a timer dressed up as a
        // progress bar, which is what the category ships.
        val total = dirs.sumOf { countFiles(it.second) }
        var scanned = 0

        for ((entry, dir) in dirs) {
            if (isCancelled()) return
            walk(dir) { file ->
                if (isCancelled()) return@walk false
                scanned++
                if (file.length() > 0 && !file.isHidden0()) {
                    index.put(
                        sourceId,
                        RecoveryIndex.Record.Loose(
                            file = file,
                            item = describe(file, entry, sourceId, fidelityOverride),
                        ),
                    )
                }
                onProgress(scanned, total)
                true
            }
        }
        onProgress(scanned, total)
    }

    /**
     * Depth-limited walk.
     *
     * Four levels, not unbounded recursion. A trash directory nested deeper than
     * that is not a trash directory, and an unbounded walk over shared storage on
     * a phone with a hundred thousand files turns a scan into a hang. Symlinks
     * are skipped for the same reason: a loop would never terminate.
     */
    private fun walk(dir: File, depth: Int = 0, onFile: (File) -> Boolean) {
        if (depth > 4) return
        val children = try {
            dir.listFiles()
        } catch (_: Throwable) {
            null
        } ?: return
        for (child in children) {
            try {
                if (child.canonicalPath != child.absolutePath) continue
            } catch (_: Throwable) {
                continue
            }
            if (child.isDirectory) {
                walk(child, depth + 1, onFile)
            } else if (child.isFile) {
                if (!onFile(child)) return
            }
        }
    }

    private fun countFiles(dir: File, depth: Int = 0): Int {
        if (depth > 4) return 0
        val children = try {
            dir.listFiles()
        } catch (_: Throwable) {
            null
        } ?: return 0
        var count = 0
        for (child in children) {
            count += if (child.isDirectory) countFiles(child, depth + 1) else 1
        }
        return count
    }

    private fun describe(
        file: File,
        entry: TrashMap.Entry,
        sourceId: String,
        fidelityOverride: String?,
    ): RecoverableItem {
        val extension = file.extension.lowercase()
        val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
        return RecoverableItem(
            itemId = "file:${file.absolutePath}",
            sourceId = sourceId,
            name = file.name,
            kind = kindOf(file, mime, extension),
            fidelity = fidelityOverride ?: entry.fidelity,
            sizeBytes = file.length(),
            // Deliberately null. The original location of a file sitting in a
            // trash folder is not recorded anywhere on the device, and inventing
            // one would put restored files in the wrong place with confidence.
            relativePath = null,
            mimeType = mime,
            origin = entry.label,
            role = entry.role,
            dateDeletedMillis = file.lastModified().takeIf { it > 0 },
            dateAddedMillis = null,
            expiresInDays = entry.retentionDays?.let { retention ->
                val ageDays = (System.currentTimeMillis() - file.lastModified()) / 86_400_000L
                (retention - ageDays).coerceAtLeast(0L)
            },
            previewUri = if (kindOf(file, mime, extension) == "image") {
                "file://${file.absolutePath}"
            } else {
                null
            },
            width = null,
            height = null,
            durationMillis = null,
        )
    }

    private fun kindOf(file: File, mime: String?, extension: String): String = when {
        mime?.startsWith("image/") == true -> "image"
        mime?.startsWith("video/") == true -> "video"
        mime?.startsWith("audio/") == true -> "audio"
        mime?.startsWith("text/") == true -> "document"
        extension in setOf("pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx") -> "document"
        // No extension and no mime type. Previously assumed to be an image,
        // which filled the grid with grey glyphs: a thumbnail cache holds index
        // and journal files alongside the JPEGs. Read the first bytes instead
        // of trusting the filename.
        mime == null -> sniff(file)
        else -> "other"
    }

    /**
     * File type from the first bytes.
     *
     * Four signatures cover everything a thumbnail cache or a chat media folder
     * realistically contains. Anything else is "other" and renders as a glyph,
     * which is the correct outcome for a database index file that was never a
     * picture.
     */
    private fun sniff(file: File): String {
        val header = ByteArray(12)
        val read = try {
            file.inputStream().use { it.read(header) }
        } catch (_: Throwable) {
            return "other"
        }
        if (read < 4) return "other"

        fun byte(index: Int): Int = header[index].toInt() and 0xFF

        // JPEG: FF D8 FF
        if (byte(0) == 0xFF && byte(1) == 0xD8 && byte(2) == 0xFF) return "image"
        // PNG: 89 50 4E 47
        if (byte(0) == 0x89 && byte(1) == 0x50 && byte(2) == 0x4E && byte(3) == 0x47) {
            return "image"
        }
        // GIF87a and GIF89a
        if (byte(0) == 0x47 && byte(1) == 0x49 && byte(2) == 0x46) return "image"
        if (read >= 12) {
            val brand = String(header, 4, 8, Charsets.ISO_8859_1)
            // RIFF....WEBP
            if (byte(0) == 0x52 && byte(1) == 0x49 && brand.endsWith("WEBP")) return "image"
            // ISO base media: ....ftyp
            if (brand.startsWith("ftyp")) {
                // HEIC and AVIF are images inside the same container as MP4.
                val sub = brand.substring(4)
                return if (sub.startsWith("hei") || sub.startsWith("avi")) "image" else "video"
            }
        }
        return "other"
    }

    /** `.nomedia` and other dotfiles are bookkeeping, not recoverable content. */
    private fun File.isHidden0(): Boolean = name.startsWith(".")
}
