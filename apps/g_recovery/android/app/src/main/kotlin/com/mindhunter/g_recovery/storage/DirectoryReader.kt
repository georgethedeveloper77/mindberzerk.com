package com.mindhunter.g_recovery.storage

import android.content.Context
import android.os.Build
import android.os.Environment
import android.os.storage.StorageManager
import java.io.File

/**
 * WHAT IS ACTUALLY ON DISK.
 *
 * ─── WHY NOT MediaStore ──────────────────────────────────────────────────────
 *
 * Everything else in this package reads the media index, which is the right
 * source for "what photos do I have" and the wrong one for "what is in this
 * folder". MediaStore never saw the zip a file manager wrote, does not index
 * most documents, and has no concept of a directory that contains nothing it
 * cares about.
 *
 * A browser built on it would show a filesystem that does not exist, which is
 * the opposite of what that screen is for.
 *
 * ─── ONE LEVEL, NEVER RECURSIVE ──────────────────────────────────────────────
 *
 * listFiles on a folder with forty thousand entries is already slow. Walking it
 * to total its size would make every tap cost seconds, so a directory reports no
 * size at all and reports how many things are directly inside instead.
 *
 * ─── THE LOCKED FOLDERS ARE LISTED ───────────────────────────────────────────
 *
 * Android/data and Android/obb are unreadable from Android 11, and this returns
 * them anyway with readable false. Hiding them would teach a false picture: they
 * are exactly where a deleted chat message lives, and the reason it cannot be
 * recovered.
 */
internal class DirectoryReader(context: Context) {

    private val app: Context = context.applicationContext

    /**
     * Every mounted volume.
     *
     * ─── StatFs, NOT File.getFreeSpace ───────────────────────────────────────
     *
     * getFreeSpace on external storage reports the space available to THIS app
     * after quotas, which on some OEM builds is a number the user has never
     * seen anywhere. StatFs reports what Settings reports, and matching the
     * system figure matters more here than being technically precise: a storage
     * app that disagrees with Settings is assumed to be wrong.
     */
    fun volumes(): List<VolumeEntry> {
        val manager = app.getSystemService(StorageManager::class.java)
            ?: return emptyList()

        val out = mutableListOf<VolumeEntry>()
        for (volume in manager.storageVolumes) {
            val dir = runCatching {
                if (Build.VERSION.SDK_INT >= 30) {
                    volume.directory
                } else {
                    Environment.getExternalStorageDirectory()
                        .takeIf { volume.isPrimary }
                }
            }.getOrNull()

            // Unmounted, ejected, or a volume this app cannot see. Reporting it
            // with zeroes would be worse than leaving it out: a row reading
            // "SD card, 0 B free" looks like a full card rather than an absent
            // one.
            val stats = dir?.let {
                runCatching { android.os.StatFs(it.absolutePath) }.getOrNull()
            } ?: continue

            out += VolumeEntry(
                id = runCatching { volume.uuid }.getOrNull() ?: dir.absolutePath,
                label = runCatching {
                    volume.getDescription(app)
                }.getOrNull() ?: if (volume.isPrimary) {
                    "Internal storage"
                } else {
                    "Removable storage"
                },
                path = dir.absolutePath,
                totalBytes = stats.totalBytes,
                freeBytes = stats.availableBytes,
                removable = volume.isRemovable,
                primary = volume.isPrimary,
            )
        }
        return out
    }

    fun list(path: String?): List<DirEntry> =
        if (path == null) roots() else children(File(path))

    /**
     * Internal storage, plus any removable volume that is mounted.
     *
     * From StorageManager rather than a guessed path. On a phone with an SD card
     * the second volume has a different id on every device, and hardcoding
     * /storage/sdcard1 was already wrong a decade ago.
     */
    private fun roots(): List<DirEntry> {
        val out = mutableListOf<DirEntry>()

        val internal = Environment.getExternalStorageDirectory()
        out += entryFor(internal, nameOverride = "Internal storage")

        if (Build.VERSION.SDK_INT >= 24) {
            val manager = app.getSystemService(StorageManager::class.java)
            manager?.storageVolumes?.forEach { volume ->
                if (!volume.isRemovable) return@forEach
                val dir = runCatching {
                    if (Build.VERSION.SDK_INT >= 30) volume.directory else null
                }.getOrNull() ?: return@forEach
                out += entryFor(
                    dir,
                    nameOverride = volume.getDescription(app) ?: dir.name,
                )
            }
        }
        return out
    }

    private fun children(dir: File): List<DirEntry> {
        if (!dir.isDirectory) return emptyList()

        // listFiles returns null for a folder the process may not read, which is
        // how Android/data behaves from API 30. An empty list would say the
        // folder is empty, which is a different and untrue statement.
        val entries = dir.listFiles() ?: return emptyList()

        return entries
            .map { entryFor(it) }
            .sortedWith(
                // Folders first, then by name, case insensitively. This is the
                // order every file manager uses and the one people expect
                // before they have chosen a sort.
                compareByDescending<DirEntry> { it.isDirectory }
                    .thenBy { it.name.lowercase() },
            )
    }

    private fun entryFor(file: File, nameOverride: String? = null): DirEntry {
        val isDir = file.isDirectory
        val readable = runCatching {
            if (isDir) file.listFiles() != null else file.canRead()
        }.getOrDefault(false)

        return DirEntry(
            path = file.absolutePath,
            name = nameOverride ?: file.name,
            isDirectory = isDir,
            // Zero for a directory, deliberately. See the class note.
            sizeBytes = if (isDir) 0L else runCatching { file.length() }
                .getOrDefault(0L),
            modifiedMillis = runCatching { file.lastModified() }.getOrDefault(0L),
            childCount = if (!isDir) {
                null
            } else {
                runCatching { file.listFiles()?.size?.toLong() }.getOrNull()
            },
            readable = readable,
            hidden = file.name.startsWith("."),
        )
    }
}
