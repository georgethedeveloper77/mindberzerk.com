package com.mindhunter.g_launcher.system

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.TrafficStats
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.os.StatFs
import android.os.SystemClock
import com.mindhunter.g_launcher.DeviceStats
import com.mindhunter.g_launcher.StatCapabilities
import java.io.File

/**
 * PHASE D1 — the one place the device is asked how it is doing.
 *
 * ─── WHY THIS IS NATIVE AT ALL ──────────────────────────────────────────────
 *
 * It used to be Dart reading `/proc` directly, and that was fine right up until
 * a Galaxy S22 returned nothing from `/proc/stat`. That is not a bug to fix: proc
 * access has been progressively restricted by SELinux and OEMs restrict further
 * on top. The APIs that still work — ActivityManager, StatFs, TrafficStats,
 * BatteryManager, PowerManager — have no Dart equivalent, so the read moves here.
 *
 * Nothing in this file needs a runtime permission. ACCESS_NETWORK_STATE (for the
 * transport lookup) is a NORMAL permission: auto-granted, no prompt, no Play
 * declaration. If a future row here would need a runtime prompt, it does not
 * belong in this file — it belongs behind an explicit opt-in.
 *
 * ─── STATELESS BY DESIGN ────────────────────────────────────────────────────
 *
 * [read] returns cumulative counters and never a rate. Rates need two samples,
 * and the ticker that owns the interval lives in Dart. Keeping the delta
 * arithmetic on one side keeps it testable and keeps this class from growing a
 * lifecycle it would then have to be told about.
 *
 * The ONLY state is [cachedCaps], and that is a probe result that cannot change
 * without a reboot or an OS upgrade — both of which restart the process.
 *
 * ─── EVERY READ IS INDIVIDUALLY WRAPPED ─────────────────────────────────────
 *
 * Not one big try/catch. A `StatFs` throwing on an exotic ROM must cost the
 * storage row and nothing else; a single wrapper would take the whole snapshot
 * down with it and the desklet would show an empty panel instead of five good
 * rows and one missing one.
 */
class DeviceStatsReader(context: Context) {

    private val app = context.applicationContext

    private val activityManager =
        app.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    private val batteryManager =
        app.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
    private val powerManager =
        app.getSystemService(Context.POWER_SERVICE) as PowerManager
    private val connectivity =
        app.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager?

    @Volatile
    private var cachedCaps: StatCapabilities? = null

    // ---- capabilities ----------------------------------------------------

    /**
     * Attempt each source once, remember what worked.
     *
     * Deliberately probes by ACTUALLY READING rather than by checking
     * `Build.VERSION` or a permission. A version check tells you what the API
     * level promises; only the read tells you what this particular ROM allows,
     * and the gap between those two is the entire reason this exists.
     */
    fun capabilities(): StatCapabilities {
        cachedCaps?.let { return it }

        val battery = batteryIntent() != null
        val detail = batteryTempDeciC() != null || batteryCurrentMicroA() != null

        val caps = StatCapabilities(
            battery = battery,
            batteryDetail = detail,
            memory = memInfo() != null,
            storage = statFs() != null,
            network = trafficRx() != null,
            networkTransport = transport() != null,
            thermal = thermalStatus() != null,
            cpu = cpuTimes() != null,
        )
        cachedCaps = caps
        return caps
    }

    // ---- snapshot --------------------------------------------------------

    fun read(): DeviceStats {
        val intent = batteryIntent()
        val mem = memInfo()
        val fs = statFs()
        // Skip the read entirely once the probe has said no. Otherwise a Galaxy
        // pays for a failing file open every three seconds, forever, to learn
        // something it already established at startup. `!= false` rather than
        // `== true` so the very first snapshot (taken before any probe) still
        // attempts it.
        val cpu = if (cachedCaps?.cpu != false) cpuTimes() else null

        return DeviceStats(
            // Read FIRST and returned even if everything else fails, because it
            // is both the uptime row and the clock the Dart-side deltas divide
            // by. A snapshot without it would produce a divide-by-zero rate.
            elapsedRealtimeMillis = SystemClock.elapsedRealtime(),

            batteryPercent = intent?.let { batteryPercentOf(it) },
            batteryCharging = intent?.let { chargingOf(it) },
            batteryTempDeciC = batteryTempDeciC(),
            batteryCurrentMicroA = batteryCurrentMicroA(),

            memAvailBytes = mem?.availMem,
            memTotalBytes = mem?.totalMem,

            storageFreeBytes = fs?.let { it.availableBlocksLong * it.blockSizeLong },
            storageTotalBytes = fs?.let { it.blockCountLong * it.blockSizeLong },

            netRxBytes = trafficRx(),
            netTxBytes = trafficTx(),
            netTransport = transport(),

            thermalStatus = thermalStatus()?.toLong(),

            cpuIdleJiffies = cpu?.first,
            cpuTotalJiffies = cpu?.second,
        )
    }

    // ---- battery ---------------------------------------------------------

    /**
     * The STICKY broadcast, which is why passing a null receiver is correct and
     * not a trick: ACTION_BATTERY_CHANGED is retained by the system, so this
     * returns the last value immediately without ever registering anything. No
     * receiver to leak, no permission, no callback.
     */
    private fun batteryIntent(): Intent? = runCatching {
        app.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
    }.getOrNull()

    private fun batteryPercentOf(intent: Intent): Long? {
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        if (level < 0 || scale <= 0) return null
        return (level * 100L / scale).coerceIn(0L, 100L)
    }

    private fun chargingOf(intent: Intent): Boolean {
        val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
        return status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL
    }

    /** Tenths of a degree C. Kept in the platform's unit; Dart converts once. */
    private fun batteryTempDeciC(): Long? {
        val t = batteryIntent()?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
            ?: return null
        // Some emulators report 0 and some report MIN_VALUE. A phone at exactly
        // 0.0C is not a reading worth trusting either, so both are dropped.
        if (t == Int.MIN_VALUE || t == 0) return null
        return t.toLong()
    }

    /**
     * Microamps. Widely absent on budget hardware, which is precisely why
     * `batteryDetail` is a separate capability from `battery`.
     *
     * Int.MIN_VALUE is the documented "not supported" sentinel, and 0 from a
     * device that is actively discharging is the undocumented one. Both drop.
     */
    private fun batteryCurrentMicroA(): Long? = runCatching {
        val v = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
        if (v == Int.MIN_VALUE || v == 0) null else v.toLong()
    }.getOrNull()

    // ---- memory ----------------------------------------------------------

    /**
     * `ActivityManager.MemoryInfo`, not `/proc/meminfo`.
     *
     * `availMem` is not "free RAM" in the `free -h` sense — it is what the
     * system believes it can hand out without killing anything, which is the
     * number a user actually cares about. The terminal shell's `free -h` skin
     * renders it as the "available" column, which is honest.
     */
    private fun memInfo(): ActivityManager.MemoryInfo? = runCatching {
        ActivityManager.MemoryInfo().also { activityManager.getMemoryInfo(it) }
    }.getOrNull()

    // ---- storage ---------------------------------------------------------

    /**
     * The DATA partition, not external storage.
     *
     * This is the number Settings shows and the number G Recovery will report,
     * and those two agreeing matters more than technical completeness: a
     * storage desklet that disagrees with the OS is a storage desklet nobody
     * trusts. Requires no permission on any API level.
     */
    private fun statFs(): StatFs? = runCatching {
        StatFs(Environment.getDataDirectory().absolutePath)
    }.getOrNull()

    // ---- network ---------------------------------------------------------

    /**
     * Device-wide bytes since boot. `TrafficStats` needs no permission at all.
     *
     * UNSUPPORTED (-1) is a real answer on emulators and a few ROMs, and it must
     * become null rather than be published as a counter — a -1 fed into a delta
     * produces a spectacular fake spike on the first tick.
     */
    private fun trafficRx(): Long? = runCatching {
        TrafficStats.getTotalRxBytes().takeIf { it != TrafficStats.UNSUPPORTED.toLong() }
    }.getOrNull()

    private fun trafficTx(): Long? = runCatching {
        TrafficStats.getTotalTxBytes().takeIf { it != TrafficStats.UNSUPPORTED.toLong() }
    }.getOrNull()

    /**
     * Transport only, never the SSID.
     *
     * Reading the Wi-Fi network name needs location permission on Android 10+.
     * A launcher that also carries the ecosystem's privacy positioning does not
     * ask for location to draw a desktop widget, so the network desklet says
     * "wifi", not which one. VPN is checked FIRST because a VPN connection also
     * reports the underlying transport, and "vpn" is the more useful answer.
     */
    private fun transport(): String? = runCatching {
        val cm = connectivity ?: return@runCatching null
        val network = cm.activeNetwork ?: return@runCatching "none"
        val caps = cm.getNetworkCapabilities(network) ?: return@runCatching "none"
        when {
            caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> "vpn"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            else -> "none"
        }
    }.getOrNull()

    // ---- thermal ---------------------------------------------------------

    /** API 29+. Null below, and the row simply does not exist there. */
    private fun thermalStatus(): Int? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            runCatching { powerManager.currentThermalStatus }.getOrNull()
        } else {
            null
        }

    // ---- cpu -------------------------------------------------------------

    /**
     * Aggregate `cpu` line of `/proc/stat`, as (idle+iowait, grand total).
     *
     * FAILS ON A GALAXY S22 AND THAT IS EXPECTED. It is attempted anyway because
     * SELinux policy is per-ROM and the budget Infinix/Tecno/Xiaomi devices this
     * launcher targets are frequently laxer than Samsung. The probe runs once;
     * after that `capabilities().cpu` is false and the ticker never asks again.
     *
     * There is no alternative API. `Debug`/`Process` CPU calls report THIS
     * process only, which is not what a system monitor means, and publishing our
     * own process time as "CPU" would be the exact fabrication the null-means-
     * absent rule exists to prevent.
     */
    private fun cpuTimes(): Pair<Long, Long>? = runCatching {
        val line = File("/proc/stat").bufferedReader().use { it.readLine() }
            ?: return@runCatching null
        if (!line.startsWith("cpu ")) return@runCatching null

        val nums = line.trim().split(Regex("\\s+")).drop(1).mapNotNull { it.toLongOrNull() }
        if (nums.size < 4) return@runCatching null

        // user nice system idle iowait irq softirq steal ...
        val idle = nums[3] + (if (nums.size > 4) nums[4] else 0L)
        val total = nums.sum()
        if (total <= 0L) return@runCatching null
        Pair(idle, total)
    }.getOrNull()
}
