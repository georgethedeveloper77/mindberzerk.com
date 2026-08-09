package com.mindberzerk.device_probe

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build

/**
 * Battery detail from two sources: the sticky ACTION_BATTERY_CHANGED broadcast
 * for the values Android has always exposed, and BatteryManager properties for
 * the ones that need a real fuel gauge behind them.
 *
 * The sticky broadcast is read with a null receiver, which returns the last
 * value immediately without registering anything. No receiver to leak, no
 * lifecycle to manage, and it is current to within a few seconds.
 */
internal class BatteryProbe(private val context: Context) {

    private val batteryManager: BatteryManager? =
        context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager

    internal data class Snapshot(
        val percent: Long?,
        val charging: Boolean?,
        val status: String?,
        val health: String?,
        val technology: String?,
        val tempDeciC: Long?,
        val currentMicroA: Long?,
        val voltageMilliV: Long?,
        val cycleCount: Long?,
        val chargeCounterMicroAh: Long?,
    )

    fun hasBattery(): Boolean = sticky() != null

    /** Temperature, current draw and voltage. Present far less often than level. */
    fun hasDetail(): Boolean {
        val snapshot = read()
        return snapshot.tempDeciC != null ||
            snapshot.currentMicroA != null ||
            snapshot.voltageMilliV != null
    }

    fun hasCycleCount(): Boolean = read().cycleCount != null

    fun read(): Snapshot {
        val intent = sticky()

        // Scale is 100 on effectively every device, but reading it is one line
        // and assuming it produces a wrong percentage on the ones where it is
        // not.
        val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val percent = if (level >= 0 && scale > 0) {
            (level * 100L) / scale
        } else {
            null
        }

        val statusCode = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val healthCode = intent?.getIntExtra(BatteryManager.EXTRA_HEALTH, -1) ?: -1

        val tempRaw = intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
        val voltageRaw = intent?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, Int.MIN_VALUE)

        return Snapshot(
            percent = percent,
            charging = when (statusCode) {
                BatteryManager.BATTERY_STATUS_CHARGING,
                BatteryManager.BATTERY_STATUS_FULL -> true
                BatteryManager.BATTERY_STATUS_DISCHARGING,
                BatteryManager.BATTERY_STATUS_NOT_CHARGING -> false
                else -> null
            },
            status = statusName(statusCode),
            health = healthName(healthCode),
            technology = intent?.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY),
            tempDeciC = tempRaw?.takeIf { it != Int.MIN_VALUE && it != 0 }?.toLong(),
            currentMicroA = property(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW),
            voltageMilliV = voltageRaw?.takeIf { it != Int.MIN_VALUE && it > 0 }?.toLong(),
            cycleCount = cycleCount(),
            chargeCounterMicroAh = property(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER),
        )
    }

    private fun sticky(): Intent? = try {
        context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
    } catch (_: Throwable) {
        null
    }

    /**
     * Absent properties come back as Integer.MIN_VALUE or 0 depending on the
     * OEM, and some report Long.MIN_VALUE. All three mean "no fuel gauge answer"
     * and must become null rather than a number on screen.
     */
    private fun property(id: Int): Long? = try {
        val value = batteryManager?.getLongProperty(id)
        when (value) {
            null, Long.MIN_VALUE, Int.MIN_VALUE.toLong(), 0L -> null
            else -> value
        }
    } catch (_: Throwable) {
        null
    }

    private fun cycleCount(): Long? {
        if (Build.VERSION.SDK_INT < 34) return null
        // Literal 6, not the named constant, so this compiles against a
        // compileSdk below 34 as well. The value is frozen public API.
        return property(6)
    }

    private fun statusName(code: Int): String? = when (code) {
        BatteryManager.BATTERY_STATUS_CHARGING -> "charging"
        BatteryManager.BATTERY_STATUS_DISCHARGING -> "discharging"
        BatteryManager.BATTERY_STATUS_FULL -> "full"
        BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "notCharging"
        BatteryManager.BATTERY_STATUS_UNKNOWN -> "unknown"
        else -> null
    }

    private fun healthName(code: Int): String? = when (code) {
        BatteryManager.BATTERY_HEALTH_GOOD -> "good"
        BatteryManager.BATTERY_HEALTH_OVERHEAT -> "overheat"
        BatteryManager.BATTERY_HEALTH_DEAD -> "dead"
        BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "overVoltage"
        BatteryManager.BATTERY_HEALTH_UNSPECIFIED_FAILURE -> "failure"
        BatteryManager.BATTERY_HEALTH_COLD -> "cold"
        BatteryManager.BATTERY_HEALTH_UNKNOWN -> "unknown"
        else -> null
    }
}
