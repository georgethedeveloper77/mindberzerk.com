package com.mindberzerk.device_probe

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build

/**
 * Sensor enumeration.
 *
 * Enumeration only in this phase. Streaming needs registration lifecycle tied to
 * a visible screen, and getting that wrong drains a battery in the background,
 * which is a bad look for an app whose Device tab is about power. HostApi
 * methods are not codec-numbered, so adding `startSensorStream` later moves no
 * ids and costs nothing.
 */
internal class SensorProbe(private val context: Context) {

    private val sensorManager: SensorManager? =
        context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager

    internal data class Info(
        val handle: Long,
        val type: Long,
        val name: String,
        val category: String,
        val valueCount: Long,
        val wakeUp: Boolean,
        val readable: Boolean,
        val vendor: String?,
        val stringType: String?,
        val maxRange: Double?,
        val resolution: Double?,
        val powerMilliAmp: Double?,
        val minDelayMicros: Long?,
    )

    fun count(): Int = list().size

    fun list(): List<Info> {
        val sensors = try {
            sensorManager?.getSensorList(Sensor.TYPE_ALL) ?: emptyList()
        } catch (_: Throwable) {
            emptyList()
        }

        val bodyGranted = hasBodySensors()

        return sensors.mapIndexed { index, sensor ->
            val category = categorise(sensor.type)
            Info(
                // The list index, not Sensor.getId(). getId() is API 29+ and
                // returns 0 for every sensor on a large number of devices, which
                // makes it useless as a key. The index is stable for the process,
                // which is all a UI session needs.
                handle = index.toLong(),
                type = sensor.type.toLong(),
                name = sensor.name ?: "Sensor $index",
                category = category,
                valueCount = valueCount(sensor.type).toLong(),
                wakeUp = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    runCatching { sensor.isWakeUpSensor }.getOrDefault(false)
                } else {
                    false
                },
                // Present but not registerable. Reported rather than filtered:
                // a user looking for their heart rate sensor needs to see
                // "present, blocked by the system" instead of an unexplained
                // absence.
                readable = category != "body" || bodyGranted,
                vendor = sensor.vendor?.takeIf { it.isNotBlank() },
                stringType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                    sensor.stringType?.takeIf { it.isNotBlank() }
                } else {
                    null
                },
                maxRange = sensor.maximumRange.toDouble().takeIf { it != 0.0 },
                resolution = sensor.resolution.toDouble().takeIf { it != 0.0 },
                powerMilliAmp = sensor.power.toDouble().takeIf { it != 0.0f.toDouble() },
                minDelayMicros = sensor.minDelay.toLong().takeIf { it > 0 },
            )
        }
    }

    private fun hasBodySensors(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return try {
            context.checkSelfPermission(Manifest.permission.BODY_SENSORS) ==
                PackageManager.PERMISSION_GRANTED
        } catch (_: Throwable) {
            false
        }
    }

    /**
     * How many floats the sensor reports. Drives whether the UI draws a single
     * number or a three axis sparkline, so guessing wrong is visible.
     * Unknown OEM types default to 1, which renders a number rather than three
     * empty traces.
     */
    private fun valueCount(type: Int): Int = when (type) {
        Sensor.TYPE_ACCELEROMETER,
        Sensor.TYPE_GRAVITY,
        Sensor.TYPE_GYROSCOPE,
        Sensor.TYPE_LINEAR_ACCELERATION,
        Sensor.TYPE_MAGNETIC_FIELD,
        Sensor.TYPE_ORIENTATION -> 3
        Sensor.TYPE_ROTATION_VECTOR,
        Sensor.TYPE_GAME_ROTATION_VECTOR -> 4
        Sensor.TYPE_MAGNETIC_FIELD_UNCALIBRATED,
        Sensor.TYPE_GYROSCOPE_UNCALIBRATED -> 6
        else -> 1
    }

    private fun categorise(type: Int): String = when (type) {
        Sensor.TYPE_ACCELEROMETER,
        Sensor.TYPE_GRAVITY,
        Sensor.TYPE_GYROSCOPE,
        Sensor.TYPE_GYROSCOPE_UNCALIBRATED,
        Sensor.TYPE_LINEAR_ACCELERATION,
        Sensor.TYPE_SIGNIFICANT_MOTION,
        Sensor.TYPE_STEP_COUNTER,
        Sensor.TYPE_STEP_DETECTOR -> "motion"

        Sensor.TYPE_MAGNETIC_FIELD,
        Sensor.TYPE_MAGNETIC_FIELD_UNCALIBRATED,
        Sensor.TYPE_ORIENTATION,
        Sensor.TYPE_PROXIMITY,
        Sensor.TYPE_ROTATION_VECTOR,
        Sensor.TYPE_GAME_ROTATION_VECTOR -> "position"

        Sensor.TYPE_AMBIENT_TEMPERATURE,
        Sensor.TYPE_LIGHT,
        Sensor.TYPE_PRESSURE,
        Sensor.TYPE_RELATIVE_HUMIDITY -> "environment"

        Sensor.TYPE_HEART_RATE -> "body"

        else -> "other"
    }
}
