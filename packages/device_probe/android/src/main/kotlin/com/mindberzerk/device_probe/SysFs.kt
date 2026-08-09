package com.mindberzerk.device_probe

import java.io.File

/**
 * Every sysfs and procfs read in this package goes through here.
 *
 * The single rule: a read that fails returns null. It never throws, never logs
 * at error, and never retries.
 *
 * That is not defensive coding, it is the actual contract of these files on
 * Android. SELinux policy is per-ROM, so `/sys/devices/system/cpu/cpu0/cpufreq`
 * is world-readable on many Transsion and Xiaomi builds and denied on a
 * hardened Samsung, at the same API level. There is no permission to request
 * and no version to check. The only way to know is to try the read, and the
 * only correct response to a denial is to report the capability as absent.
 */
internal object SysFs {

    /** Trimmed contents, or null if the path is missing, denied, or empty. */
    fun readText(path: String): String? = try {
        val file = File(path)
        if (!file.exists() || !file.canRead()) {
            null
        } else {
            file.readText().trim().ifEmpty { null }
        }
    } catch (_: Throwable) {
        // SecurityException, FileNotFoundException, IOException, and on some
        // kernels an EACCES surfacing as a raw Error. All mean the same thing.
        null
    }

    fun readLong(path: String): Long? = readText(path)?.toLongOrNull()

    fun readInt(path: String): Int? = readText(path)?.toIntOrNull()

    /** Line-by-line, or null. Used for /proc/stat and /proc/meminfo. */
    fun readLines(path: String): List<String>? = try {
        val file = File(path)
        if (!file.exists() || !file.canRead()) null else file.readLines()
    } catch (_: Throwable) {
        null
    }

    /** Directory entries matching [prefix] followed by digits, sorted by index. */
    fun numberedDirs(parent: String, prefix: String): List<Int> = try {
        File(parent).listFiles()
            ?.asSequence()
            ?.filter { it.isDirectory && it.name.startsWith(prefix) }
            ?.mapNotNull { it.name.removePrefix(prefix).toIntOrNull() }
            ?.sorted()
            ?.toList()
            ?: emptyList()
    } catch (_: Throwable) {
        emptyList()
    }

    /**
     * Parses a sysfs cpu list such as "0-3" or "0 1 2 3" or "4-6,8" into indices.
     * Three formats because three kernels write it three ways.
     */
    fun parseCpuList(raw: String): List<Int> {
        val out = LinkedHashSet<Int>()
        raw.split(',', ' ').forEach { token ->
            val part = token.trim()
            if (part.isEmpty()) return@forEach
            if (part.contains('-')) {
                val bounds = part.split('-')
                val from = bounds.getOrNull(0)?.trim()?.toIntOrNull()
                val to = bounds.getOrNull(1)?.trim()?.toIntOrNull()
                if (from != null && to != null && to >= from) {
                    for (i in from..to) out.add(i)
                }
            } else {
                part.toIntOrNull()?.let(out::add)
            }
        }
        return out.sorted()
    }
}
