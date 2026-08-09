package com.mindberzerk.device_probe

import android.content.Context
import android.os.Build
import android.os.PowerManager
import kotlin.math.abs

/**
 * Thermal zones from sysfs, plus the framework's own thermal status.
 *
 * These are two independent sources and both are worth having. `/sys/class/
 * thermal` gives per-zone numbers and is denied on most recent Samsung and
 * Pixel builds. `PowerManager.getCurrentThermalStatus()` gives a single
 * coarse level, needs no permission, and works everywhere from API 29. On a
 * hardened device it is the only thermal signal available at all.
 */
internal class ThermalProbe(private val context: Context) {

    private val powerManager: PowerManager? =
        context.getSystemService(Context.POWER_SERVICE) as? PowerManager

    /** Zone ids discovered once. An empty list means sysfs is denied. */
    private val zoneIds: List<Int> by lazy {
        SysFs.numberedDirs("/sys/class/thermal", "thermal_zone")
            .filter { SysFs.readText("/sys/class/thermal/thermal_zone$it/type") != null }
    }

    fun hasZones(): Boolean = zoneIds.isNotEmpty()

    fun hasStatus(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && powerManager != null

    fun status(): Int? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        return try {
            powerManager?.currentThermalStatus
        } catch (_: Throwable) {
            null
        }
    }

    internal data class Zone(
        val zoneId: Int,
        val label: String,
        val category: String,
        val milliCelsius: Long,
    )

    fun zones(): List<Zone> {
        val out = mutableListOf<Zone>()
        for (id in zoneIds) {
            val base = "/sys/class/thermal/thermal_zone$id"
            val label = SysFs.readText("$base/type") ?: continue
            val raw = SysFs.readLong("$base/temp") ?: continue
            val milli = normalise(raw) ?: continue
            out.add(Zone(id, label, categorise(label), milli))
        }
        return out
    }

    /**
     * Kernels report zone temperature in millidegrees, decidegrees or whole
     * degrees, and there is no file that says which. Normalising by magnitude
     * is the only option, and it is done ONCE here so every consumer sees
     * millidegrees.
     *
     * The bounds also throw away obvious garbage: a zone reading -40 C or
     * +200 C is a disconnected or unpopulated sensor, and several devices ship
     * zones permanently pinned at a sentinel value. Showing those as real
     * temperatures is worse than omitting them.
     */
    private fun normalise(raw: Long): Long? {
        val milli = when {
            abs(raw) >= 1_000 -> raw
            abs(raw) >= 100 -> raw * 100
            else -> raw * 1_000
        }
        return if (milli in -30_000..150_000) milli else null
    }

    /**
     * Substring match against the raw zone name. OEM naming is wildly
     * inconsistent (mtktsbattery, VIRTUAL-SKIN, sdm-therm, cpu-1-0-usr), so
     * this catches the common families and everything else honestly becomes
     * "other" rather than being guessed at.
     */
    private fun categorise(label: String): String {
        val name = label.lowercase()
        return when {
            name.contains("batt") -> "battery"
            name.contains("gpu") -> "gpu"
            name.contains("cpu") || name.contains("core") || name.contains("soc") ||
                name.contains("bigcore") || name.contains("apc") -> "cpu"
            name.contains("skin") || name.contains("shell") || name.contains("case") ||
                name.contains("quiet") -> "skin"
            name.contains("modem") || name.contains("mdm") || name.contains("rf") ||
                name.contains("pa-") -> "modem"
            name.contains("ambient") || name.contains("usb") -> "ambient"
            else -> "other"
        }
    }
}
