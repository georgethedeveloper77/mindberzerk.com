package com.mindberzerk.device_probe

import android.app.ActivityManager
import android.content.Context

/**
 * RAM from ActivityManager and swap from /proc/meminfo.
 *
 * ActivityManager.MemoryInfo needs no file read and no permission, which is why
 * it is used in place of /proc/meminfo for the RAM figures. meminfo is still
 * read, but only for swap: it carries no per-process information, so it survives
 * the SELinux tightening that took /proc/stat away, and zram is present on
 * nearly every budget device this targets.
 */
internal class MemoryProbe(private val context: Context) {

    private val activityManager: ActivityManager? =
        context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager

    internal data class Snapshot(
        val totalBytes: Long?,
        val availBytes: Long?,
        val thresholdBytes: Long?,
        val lowMemory: Boolean?,
        val swapTotalBytes: Long?,
        val swapFreeBytes: Long?,
    )

    fun hasMemory(): Boolean = read().totalBytes != null

    fun hasSwap(): Boolean = read().swapTotalBytes != null

    fun read(): Snapshot {
        val info = try {
            ActivityManager.MemoryInfo().also { activityManager?.getMemoryInfo(it) }
        } catch (_: Throwable) {
            null
        }

        val meminfo = SysFs.readLines("/proc/meminfo")
        return Snapshot(
            totalBytes = info?.totalMem?.takeIf { it > 0 },
            availBytes = info?.availMem?.takeIf { it > 0 },
            thresholdBytes = info?.threshold?.takeIf { it > 0 },
            lowMemory = info?.lowMemory,
            swapTotalBytes = meminfoKb(meminfo, "SwapTotal:"),
            swapFreeBytes = meminfoKb(meminfo, "SwapFree:"),
        )
    }

    /** meminfo reports kB. Returns bytes, or null for absent or zero. */
    private fun meminfoKb(lines: List<String>?, key: String): Long? {
        val line = lines?.firstOrNull { it.startsWith(key) } ?: return null
        val kb = line.split(Regex("\\s+")).getOrNull(1)?.toLongOrNull() ?: return null
        return if (kb > 0) kb * 1024 else null
    }
}
