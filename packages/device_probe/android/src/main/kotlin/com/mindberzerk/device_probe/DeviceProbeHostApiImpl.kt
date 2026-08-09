package com.mindberzerk.device_probe

import android.content.Context
import android.os.Build
import android.os.SystemClock

/**
 * The bridge implementation. Assembles the Pigeon types from the probes.
 *
 * Everything here runs on the platform thread and every call is bounded: the
 * heaviest is a few dozen small sysfs reads. No coroutine scope, no executor,
 * no cancellation. `@async` in the schema exists so Dart is not blocked, not
 * because there is background work to manage.
 */
internal class DeviceProbeHostApiImpl(context: Context) : DeviceProbeHostApi {

    private val app: Context = context.applicationContext

    private val cpu = CpuProbe()
    private val thermal = ThermalProbe(app)
    private val battery = BatteryProbe(app)
    private val memory = MemoryProbe(app)
    private val sensors = SensorProbe(app)

    /**
     * NOT a `by lazy`, unlike everything above it.
     *
     * Every other probe here answers a question the device cannot change its
     * mind about. All Files Access is a toggle in Settings the user can flip
     * while this app is in the background, so the probe is constructed once and
     * READ on every call.
     */
    private val storage = StorageAccessProbe(app)

    /**
     * Probed once and held for the process.
     *
     * Every field is the result of an ACTUAL ATTEMPTED READ rather than a
     * version check, because SELinux policy is per-ROM: the same API level reads
     * core frequencies on a Tecno and refuses on a hardened Samsung. The cost is
     * one extra round of reads at startup, and the alternative is a UI that
     * cannot tell "this phone says no" from "not sampled yet".
     */
    private val capabilities: ProbeCapabilities by lazy {
        ProbeCapabilities(
            coreFrequencies = cpu.canReadFrequencies(),
            cpuClusters = cpu.clustersAreAuthoritative,
            cpuGovernor = cpu.canReadGovernor(),
            cpuJiffies = cpu.jiffies() != null,
            thermalZones = thermal.hasZones(),
            thermalStatus = thermal.hasStatus(),
            battery = battery.hasBattery(),
            batteryDetail = battery.hasDetail(),
            batteryCycleCount = battery.hasCycleCount(),
            memory = memory.hasMemory(),
            swap = memory.hasSwap(),
            sensorCount = sensors.count().toLong(),
        )
    }

    private val cpuInfo: CpuInfo by lazy {
        CpuInfo(
            coreCount = cpu.coreCount().toLong(),
            clusters = cpu.clusters.map { spec ->
                CpuCluster(
                    label = spec.label,
                    coreIds = spec.coreIds.map { it.toLong() },
                    minKhz = spec.minKhz,
                    maxKhz = spec.maxKhz,
                    governor = spec.governor,
                )
            },
            socModel = if (Build.VERSION.SDK_INT >= 31) {
                Build.SOC_MODEL.takeIf { it.isNotBlank() && it != Build.UNKNOWN }
            } else {
                null
            },
            hardware = Build.HARDWARE?.takeIf { it.isNotBlank() },
            abi = Build.SUPPORTED_ABIS?.firstOrNull(),
        )
    }

    override fun capabilities(callback: (Result<ProbeCapabilities>) -> Unit) {
        callback(Result.success(capabilities))
    }

    override fun cpuInfo(callback: (Result<CpuInfo>) -> Unit) {
        callback(Result.success(cpuInfo))
    }

    override fun sensors(callback: (Result<List<SensorInfo>>) -> Unit) {
        val list = sensors.list().map { info ->
            SensorInfo(
                handle = info.handle,
                type = info.type,
                name = info.name,
                category = info.category,
                valueCount = info.valueCount,
                wakeUp = info.wakeUp,
                readable = info.readable,
                vendor = info.vendor,
                stringType = info.stringType,
                maxRange = info.maxRange,
                resolution = info.resolution,
                powerMilliAmp = info.powerMilliAmp,
                minDelayMicros = info.minDelayMicros,
            )
        }
        callback(Result.success(list))
    }

    override fun storageAccess(callback: (Result<StorageAccess>) -> Unit) {
        callback(Result.success(storage.read()))
    }

    override fun readSnapshot(callback: (Result<DeviceSnapshot>) -> Unit) {
        // Read the clock FIRST. It is the divisor every rate is computed
        // against, and taking it after several dozen file reads would attribute
        // the read time itself to the sample interval.
        val clock = SystemClock.elapsedRealtime()

        callback(
            Result.success(
                DeviceSnapshot(
                    elapsedRealtimeMillis = clock,
                    cpu = cpuSample(),
                    thermal = thermalSample(),
                    battery = batterySnapshot(),
                    memory = memorySnapshot(),
                )
            )
        )
    }

    /**
     * A whole section comes back NULL rather than as an object full of nulls
     * when the device will not serve it. That lets the UI drop an entire card
     * instead of drawing an empty one, which is the difference between "this
     * phone does not report thermal zones" and a card of blank rows.
     */
    private fun cpuSample(): CpuSample? {
        if (!capabilities.coreFrequencies && !capabilities.cpuJiffies) return null
        val count = cpu.coreCount()
        val jiffies = cpu.jiffies()
        return CpuSample(
            coreKhz = (0 until count).map { cpu.currentKhz(it) },
            coreOnline = (0 until count).map { cpu.isOnline(it) },
            idleJiffies = jiffies?.first,
            totalJiffies = jiffies?.second,
        )
    }

    private fun thermalSample(): ThermalSample? {
        if (!capabilities.thermalZones && !capabilities.thermalStatus) return null
        return ThermalSample(
            zones = thermal.zones().map { zone ->
                ThermalZone(
                    zoneId = zone.zoneId.toLong(),
                    label = zone.label,
                    category = zone.category,
                    milliCelsius = zone.milliCelsius,
                )
            },
            status = thermal.status()?.toLong(),
        )
    }

    private fun batterySnapshot(): BatterySnapshot? {
        if (!capabilities.battery) return null
        val snapshot = battery.read()
        return BatterySnapshot(
            percent = snapshot.percent,
            charging = snapshot.charging,
            status = snapshot.status,
            health = snapshot.health,
            technology = snapshot.technology,
            tempDeciC = snapshot.tempDeciC,
            currentMicroA = snapshot.currentMicroA,
            voltageMilliV = snapshot.voltageMilliV,
            cycleCount = snapshot.cycleCount,
            chargeCounterMicroAh = snapshot.chargeCounterMicroAh,
        )
    }

    private fun memorySnapshot(): MemorySnapshot? {
        if (!capabilities.memory && !capabilities.swap) return null
        val snapshot = memory.read()
        return MemorySnapshot(
            totalBytes = snapshot.totalBytes,
            availBytes = snapshot.availBytes,
            thresholdBytes = snapshot.thresholdBytes,
            lowMemory = snapshot.lowMemory,
            swapTotalBytes = snapshot.swapTotalBytes,
            swapFreeBytes = snapshot.swapFreeBytes,
        )
    }
}
