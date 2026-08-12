package com.mindhunter.g_recovery.hardware

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.NetworkCapabilities
import android.net.TrafficStats
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.telephony.SubscriptionManager
import android.util.DisplayMetrics
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.net.Inet4Address
import java.net.Inet6Address
import java.util.concurrent.Executors

/**
 * THE HARDWARE PAGES.
 *
 * ─── PLACEHOLDERS ARE TURNED BACK INTO NULLS ─────────────────────────────────
 *
 * From Android 10 the Wi-Fi APIs do not fail without location permission, they
 * LIE POLITELY: SSID comes back as "<unknown ssid>" and MAC as
 * 02:00:00:00:00:00. Every device info app on Play prints those verbatim, which
 * tells a user their MAC is a string of zeroes.
 *
 * This maps both back to null, so the UI can leave the row out and name the
 * permission that would fill it.
 *
 * ─── RATES ARE COMPUTED HERE, NOT IN DART ────────────────────────────────────
 *
 * TrafficStats returns counters. A rate needs the previous counter and the time
 * since it was read, and doing that subtraction across a platform channel makes
 * every reading wrong by however long the UI thread was busy.
 */
internal class HardwareReader(context: Context) {

    private val app: Context = context.applicationContext

    /** Previous counter read, for the throughput rate. */
    private var lastRx = -1L
    private var lastTx = -1L
    private var lastAt = 0L

    fun hasLocation(): Boolean =
        ContextCompat.checkSelfPermission(
            app,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED

    // ─── DISPLAY ─────────────────────────────────────────────────────────────

    fun display(): DisplayInfo {
        val wm = app.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()

        @Suppress("DEPRECATION")
        val display = wm.defaultDisplay
        @Suppress("DEPRECATION")
        display.getRealMetrics(metrics)

        val modes = runCatching {
            display.supportedModes
                .map { it.refreshRate.toDouble() }
                .distinct()
                .sortedDescending()
        }.getOrDefault(listOf(display.refreshRate.toDouble()))

        val hdr = runCatching {
            @Suppress("DEPRECATION")
            display.hdrCapabilities
        }.getOrNull()

        return DisplayInfo(
            widthPx = metrics.widthPixels.toLong(),
            heightPx = metrics.heightPixels.toLong(),
            densityDpi = metrics.densityDpi.toLong(),
            refreshHz = display.refreshRate.toDouble(),
            supportedHz = modes,
            hdr = hdr != null && hdr.supportedHdrTypes.isNotEmpty(),
            wideColour = runCatching {
                display.isWideColorGamut
            }.getOrDefault(false),
            hdrTypes = hdr?.supportedHdrTypes?.map { hdrName(it) } ?: emptyList(),
            // Only meaningful on a panel that declares HDR. A zero from a non
            // HDR screen is not a measurement, so it becomes null.
            maxLuminance = hdr?.desiredMaxLuminance?.toDouble()?.takeIf { it > 0 },
            minLuminance = hdr?.desiredMinLuminance?.toDouble()?.takeIf { it > 0 },
            averageLuminance =
                hdr?.desiredMaxAverageLuminance?.toDouble()?.takeIf { it > 0 },
        )
    }

    private fun hdrName(type: Int): String = when (type) {
        1 -> "Dolby Vision"
        2 -> "HDR10"
        3 -> "HLG"
        4 -> "HDR10+"
        else -> "Type $type"
    }

    // ─── NETWORK ─────────────────────────────────────────────────────────────

    fun network(): NetworkInfo {
        val cm = app.getSystemService(ConnectivityManager::class.java)
        val active = cm?.activeNetwork
        val caps: NetworkCapabilities? = active?.let { cm.getNetworkCapabilities(it) }
        val link: LinkProperties? = active?.let { cm.getLinkProperties(it) }

        val type = when {
            caps == null -> "none"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> "vpn"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            else -> "none"
        }

        var v4: String? = null
        var v6: String? = null
        link?.linkAddresses?.forEach { address ->
            when (address.address) {
                is Inet4Address -> if (v4 == null) v4 = address.address.hostAddress
                is Inet6Address -> if (v6 == null) v6 = address.address.hostAddress
                else -> Unit
            }
        }

        return NetworkInfo(
            type = type,
            connected = caps?.hasCapability(
                NetworkCapabilities.NET_CAPABILITY_INTERNET,
            ) ?: false,
            metered = cm?.isActiveNetworkMetered ?: false,
            ipv4 = v4,
            ipv6 = v6,
            rxBytesTotal = TrafficStats.getTotalRxBytes().coerceAtLeast(0),
            txBytesTotal = TrafficStats.getTotalTxBytes().coerceAtLeast(0),
        )
    }

    fun throughput(): ThroughputSample {
        val rx = TrafficStats.getTotalRxBytes().coerceAtLeast(0)
        val tx = TrafficStats.getTotalTxBytes().coerceAtLeast(0)
        val at = SystemClock.elapsedRealtime()

        // First call has nothing to subtract from. Zero rates and real totals is
        // the honest answer; inventing a rate from one sample is not.
        val seconds = if (lastAt == 0L) 0.0 else (at - lastAt) / 1000.0
        val rxRate = if (seconds <= 0 || lastRx < 0) 0L
        else ((rx - lastRx) / seconds).toLong().coerceAtLeast(0)
        val txRate = if (seconds <= 0 || lastTx < 0) 0L
        else ((tx - lastTx) / seconds).toLong().coerceAtLeast(0)

        lastRx = rx
        lastTx = tx
        lastAt = at

        return ThroughputSample(
            rxBytesPerSecond = rxRate,
            txBytesPerSecond = txRate,
            rxBytesTotal = rx,
            txBytesTotal = tx,
        )
    }

    // ─── WI-FI ───────────────────────────────────────────────────────────────

    @Suppress("DEPRECATION")
    fun wifi(): WifiInfo {
        val wm = app.applicationContext
            .getSystemService(Context.WIFI_SERVICE) as? WifiManager
        val granted = hasLocation()

        val info = runCatching { wm?.connectionInfo }.getOrNull()
        val connected = info != null && info.networkId != -1

        return WifiInfo(
            connected = connected,
            // scrub, not pass through. Android hands back a placeholder rather
            // than failing, and printing it would tell the user their network
            // is called "<unknown ssid>".
            ssid = scrub(info?.ssid?.trim('"')),
            bssid = scrub(info?.bssid),
            macAddress = scrub(info?.macAddress),
            standard = if (Build.VERSION.SDK_INT >= 30) {
                standardName(runCatching { info?.wifiStandard }.getOrNull())
            } else {
                null
            },
            frequencyMhz = info?.frequency?.toLong()?.takeIf { it > 0 },
            linkSpeedMbps = info?.linkSpeed?.toLong()?.takeIf { it > 0 },
            rxLinkSpeedMbps = if (Build.VERSION.SDK_INT >= 29) {
                runCatching { info?.rxLinkSpeedMbps?.toLong() }
                    .getOrNull()?.takeIf { it > 0 }
            } else {
                null
            },
            signalPercent = info?.rssi?.let {
                WifiManager.calculateSignalLevel(it, 100).toLong()
            },
            security = null,
            supports5Ghz = runCatching { wm?.is5GHzBandSupported }
                .getOrNull() ?: false,
            supports6Ghz = if (Build.VERSION.SDK_INT >= 30) {
                runCatching { wm?.is6GHzBandSupported }.getOrNull() ?: false
            } else {
                false
            },
            hasLocationPermission = granted,
        )
    }

    /** Turns Android's polite lies back into nulls. */
    private fun scrub(value: String?): String? {
        if (value.isNullOrBlank()) return null
        if (value == "<unknown ssid>" || value == "0x") return null
        if (value == "02:00:00:00:00:00") return null
        return value
    }

    private fun standardName(standard: Int?): String? = when (standard) {
        1 -> "802.11 legacy"
        2 -> "802.11a/b/g"
        4 -> "802.11n"
        5 -> "802.11ac"
        6 -> "802.11ax"
        7 -> "802.11ad"
        8 -> "802.11be"
        else -> null
    }

    // ─── CAMERAS ─────────────────────────────────────────────────────────────

    fun cameras(): List<CameraInfo> {
        val manager = app.getSystemService(CameraManager::class.java)
            ?: return emptyList()

        val out = mutableListOf<CameraInfo>()
        val ids = runCatching { manager.cameraIdList }.getOrDefault(emptyArray())

        for (id in ids) {
            // One camera that refuses must not lose the others: a logical
            // multi camera can throw on a physical id that is not directly
            // openable.
            val info = runCatching {
                val c = manager.getCameraCharacteristics(id)
                val size = c.get(CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE)
                val iso = c.get(
                    CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE,
                )
                val caps = c.get(
                    CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES,
                )

                CameraInfo(
                    id = id,
                    facing = when (c.get(CameraCharacteristics.LENS_FACING)) {
                        CameraCharacteristics.LENS_FACING_FRONT -> "front"
                        CameraCharacteristics.LENS_FACING_BACK -> "back"
                        else -> "external"
                    },
                    megapixels = if (size == null) {
                        0.0
                    } else {
                        (size.width.toLong() * size.height) / 1_000_000.0
                    },
                    widthPx = (size?.width ?: 0).toLong(),
                    heightPx = (size?.height ?: 0).toLong(),
                    focalLengthsMm = c.get(
                        CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS,
                    )?.map { it.toDouble() } ?: emptyList(),
                    apertures = c.get(
                        CameraCharacteristics.LENS_INFO_AVAILABLE_APERTURES,
                    )?.map { it.toDouble() } ?: emptyList(),
                    isoMin = iso?.lower?.toLong(),
                    isoMax = iso?.upper?.toLong(),
                    supportsRaw = caps?.contains(
                        CameraCharacteristics
                            .REQUEST_AVAILABLE_CAPABILITIES_RAW,
                    ) ?: false,
                    hasFlash = c.get(
                        CameraCharacteristics.FLASH_INFO_AVAILABLE,
                    ) ?: false,
                )
            }.getOrNull()

            if (info != null) out += info
        }
        // Back cameras first, largest sensor first. The main camera is the one
        // a person is looking for.
        return out.sortedWith(
            compareBy<CameraInfo> { it.facing != "back" }
                .thenByDescending { it.megapixels },
        )
    }

    // ─── LIVE SENSORS ────────────────────────────────────────────────────────

    private val sensors = app.getSystemService(Context.SENSOR_SERVICE)
        as? SensorManager

    /** Latest reading per sensor type, written by the listener, read by polls. */
    private val readings = java.util.concurrent.ConcurrentHashMap<Int, FloatArray>()
    private val listeners = mutableListOf<SensorEventListener>()

    /**
     * Registers listeners for the requested types.
     *
     * SENSOR_DELAY_UI, not FASTEST. The screen updates a few times a second and
     * the fastest rate wakes the CPU hundreds of times a second to produce
     * numbers nobody will see.
     */
    fun startSensors(types: List<String>) {
        stopSensors()
        val manager = sensors ?: return

        for (name in types) {
            val type = sensorType(name) ?: continue
            val sensor = manager.getDefaultSensor(type) ?: continue

            val listener = object : SensorEventListener {
                override fun onSensorChanged(event: SensorEvent) {
                    readings[event.sensor.type] = event.values.copyOf()
                }

                override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
            }
            manager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_UI)
            listeners += listener
        }
    }

    fun stopSensors() {
        val manager = sensors
        listeners.forEach { runCatching { manager?.unregisterListener(it) } }
        listeners.clear()
        // Cleared too. A stale reading returned after a stop would look live.
        readings.clear()
    }

    fun sensorValues(): List<SensorReading> {
        val manager = sensors ?: return emptyList()
        val out = mutableListOf<SensorReading>()

        for ((type, values) in readings) {
            val sensor = manager.getDefaultSensor(type) ?: continue
            out += SensorReading(
                type = sensorName(type),
                name = sensor.name,
                values = values.map { it.toDouble() },
                unit = unitFor(type),
                maxRange = sensor.maximumRange.toDouble().takeIf { it > 0 },
            )
        }
        return out.sortedBy { it.type }
    }

    private fun sensorType(name: String): Int? = when (name) {
        "accelerometer" -> Sensor.TYPE_ACCELEROMETER
        "gyroscope" -> Sensor.TYPE_GYROSCOPE
        "magnetometer" -> Sensor.TYPE_MAGNETIC_FIELD
        "light" -> Sensor.TYPE_LIGHT
        "proximity" -> Sensor.TYPE_PROXIMITY
        "pressure" -> Sensor.TYPE_PRESSURE
        else -> null
    }

    private fun sensorName(type: Int): String = when (type) {
        Sensor.TYPE_ACCELEROMETER -> "accelerometer"
        Sensor.TYPE_GYROSCOPE -> "gyroscope"
        Sensor.TYPE_MAGNETIC_FIELD -> "magnetometer"
        Sensor.TYPE_LIGHT -> "light"
        Sensor.TYPE_PROXIMITY -> "proximity"
        Sensor.TYPE_PRESSURE -> "pressure"
        else -> "type$type"
    }

    private fun unitFor(type: Int): String = when (type) {
        Sensor.TYPE_ACCELEROMETER -> "m/s2"
        Sensor.TYPE_GYROSCOPE -> "rad/s"
        Sensor.TYPE_MAGNETIC_FIELD -> "uT"
        Sensor.TYPE_LIGHT -> "lux"
        Sensor.TYPE_PROXIMITY -> "cm"
        Sensor.TYPE_PRESSURE -> "hPa"
        else -> ""
    }

    // ─── TONE ────────────────────────────────────────────────────────────────

    private var track: AudioTrack? = null

    /**
     * A sine wave, written straight into an AudioTrack.
     *
     * ─── ONE CHANNEL AT A TIME IS THE WHOLE TEST ─────────────────────────────
     *
     * A phone with one dead speaker sounds perfectly fine playing through both.
     * Writing silence into one side of a stereo buffer is the only way to find
     * that out without opening the phone.
     *
     * ─── AND IT FADES ────────────────────────────────────────────────────────
     *
     * A sine wave that starts and stops at full amplitude produces a click at
     * each end, which on a small speaker is indistinguishable from a rattle.
     * The first and last few milliseconds ramp, so what a person hears is the
     * speaker rather than the edit.
     */
    fun playTone(hertz: Double, milliseconds: Long, channel: String) {
        stopTone()

        val rate = 44100
        val frames = (rate * milliseconds / 1000).toInt().coerceAtLeast(1)
        val buffer = ShortArray(frames * 2)
        val fade = (rate * 0.01).toInt().coerceAtMost(frames / 2)

        for (i in 0 until frames) {
            val phase = 2.0 * Math.PI * hertz * i / rate
            var amplitude = Short.MAX_VALUE * 0.55
            if (i < fade) amplitude *= i.toDouble() / fade
            if (i > frames - fade) amplitude *= (frames - i).toDouble() / fade

            val value = (Math.sin(phase) * amplitude).toInt().toShort()
            buffer[i * 2] = if (channel == "right") 0 else value
            buffer[i * 2 + 1] = if (channel == "left") 0 else value
        }

        val player = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    // MEDIA, not NOTIFICATION. A test tone routed as a
                    // notification is silenced by Do Not Disturb, and a silent
                    // speaker test reads as a broken speaker.
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(rate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                    .build(),
            )
            .setBufferSizeInBytes(buffer.size * 2)
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()

        player.write(buffer, 0, buffer.size)
        player.play()
        track = player
    }

    fun stopTone() {
        val player = track ?: return
        runCatching {
            player.pause()
            player.flush()
            player.release()
        }
        track = null
    }

    // ─── VIBRATION ───────────────────────────────────────────────────────────

    fun vibrate(pattern: String): Boolean {
        val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= 31) {
            (app.getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            app.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

        if (vibrator == null || !vibrator.hasVibrator()) return false

        val effect = when (pattern) {
            "long" -> VibrationEffect.createOneShot(
                600,
                VibrationEffect.DEFAULT_AMPLITUDE,
            )
            "double" -> VibrationEffect.createWaveform(
                longArrayOf(0, 90, 120, 90),
                -1,
            )
            else -> VibrationEffect.createOneShot(
                60,
                VibrationEffect.DEFAULT_AMPLITUDE,
            )
        }

        return runCatching {
            vibrator.vibrate(effect)
            true
        }.getOrDefault(false)
    }

    // ─── SIM ─────────────────────────────────────────────────────────────────

    fun hasPhoneState(): Boolean =
        ContextCompat.checkSelfPermission(
            app,
            Manifest.permission.READ_PHONE_STATE,
        ) == PackageManager.PERMISSION_GRANTED

    /**
     * Every SIM, by slot.
     *
     * getActiveSubscriptionInfoList throws SecurityException without
     * READ_PHONE_STATE rather than returning an empty list, so the whole call is
     * wrapped and an empty result means either no permission or no SIM. The UI
     * uses the permission flag to tell those apart.
     */
    fun sims(): List<SimInfo> {
        if (!hasPhoneState()) return emptyList()

        val manager = app.getSystemService(SubscriptionManager::class.java)
            ?: return emptyList()

        val list = runCatching {
            manager.activeSubscriptionInfoList
        }.getOrNull() ?: return emptyList()

        val defaultData = runCatching {
            SubscriptionManager.getDefaultDataSubscriptionId()
        }.getOrDefault(-1)

        return list.map { info ->
            SimInfo(
                slot = info.simSlotIndex.toLong(),
                carrier = info.carrierName?.toString()?.takeIf { it.isNotBlank() },
                countryIso = info.countryIso?.takeIf { it.isNotBlank() }
                    ?.uppercase(),
                mcc = if (Build.VERSION.SDK_INT >= 29) {
                    runCatching { info.mccString }.getOrNull()
                } else {
                    null
                },
                mnc = if (Build.VERSION.SDK_INT >= 29) {
                    runCatching { info.mncString }.getOrNull()
                } else {
                    null
                },
                embedded = runCatching { info.isEmbedded }.getOrDefault(false),
                roaming = runCatching {
                    manager.isNetworkRoaming(info.subscriptionId)
                }.getOrDefault(false),
                dataDefault = info.subscriptionId == defaultData,
            )
        }.sortedBy { it.slot }
    }

    // ─── BLUETOOTH ───────────────────────────────────────────────────────────

    fun hasBluetoothPermission(): Boolean =
        if (Build.VERSION.SDK_INT < 31) {
            true
        } else {
            ContextCompat.checkSelfPermission(
                app,
                Manifest.permission.BLUETOOTH_CONNECT,
            ) == PackageManager.PERMISSION_GRANTED
        }

    fun bluetooth(): BluetoothInfo {
        val manager = app.getSystemService(BluetoothManager::class.java)
        val adapter = manager?.adapter
        val granted = hasBluetoothPermission()

        if (adapter == null) {
            return BluetoothInfo(
                available = false,
                enabled = false,
                name = null,
                hasPermission = granted,
                paired = emptyList(),
                leSupported = false,
                le2mSupported = false,
                leCodedSupported = false,
                leAudioSupported = false,
            )
        }

        val paired = if (!granted) {
            emptyList()
        } else {
            runCatching {
                adapter.bondedDevices.map { device ->
                    PairedDevice(
                        name = runCatching { device.name }.getOrNull()
                            ?: "Unnamed device",
                        // Last four only. A full MAC on screen is a tracking
                        // identifier, and nobody reading this page needs the
                        // other eight characters.
                        address = device.address.takeLast(5),
                        type = deviceType(device),
                        connected = false,
                    )
                }
            }.getOrDefault(emptyList())
        }

        return BluetoothInfo(
            available = true,
            enabled = runCatching { adapter.isEnabled }.getOrDefault(false),
            name = if (granted) {
                runCatching { adapter.name }.getOrNull()
            } else {
                null
            },
            hasPermission = granted,
            paired = paired.sortedBy { it.name.lowercase() },
            leSupported = app.packageManager.hasSystemFeature(
                PackageManager.FEATURE_BLUETOOTH_LE,
            ),
            le2mSupported = runCatching {
                adapter.isLe2MPhySupported
            }.getOrDefault(false),
            leCodedSupported = runCatching {
                adapter.isLeCodedPhySupported
            }.getOrDefault(false),
            leAudioSupported = if (Build.VERSION.SDK_INT >= 33) {
                runCatching {
                    adapter.isLeAudioSupported ==
                        android.bluetooth.BluetoothStatusCodes.FEATURE_SUPPORTED
                }.getOrDefault(false)
            } else {
                false
            },
        )
    }

    private fun deviceType(device: BluetoothDevice): String = runCatching {
        when (device.bluetoothClass?.majorDeviceClass) {
            BluetoothClass.Device.Major.AUDIO_VIDEO -> "audio"
            BluetoothClass.Device.Major.PHONE -> "phone"
            BluetoothClass.Device.Major.COMPUTER -> "computer"
            BluetoothClass.Device.Major.WEARABLE -> "wearable"
            BluetoothClass.Device.Major.PERIPHERAL -> "input"
            else -> "other"
        }
    }.getOrDefault("other")

    // ─── FEATURES ────────────────────────────────────────────────────────────

    fun features(): FeatureFlags {
        fun has(name: String): Boolean =
            runCatching { app.packageManager.hasSystemFeature(name) }
                .getOrDefault(false)

        return FeatureFlags(
            nfc = has(PackageManager.FEATURE_NFC),
            gps = has(PackageManager.FEATURE_LOCATION_GPS),
            uwb = if (Build.VERSION.SDK_INT >= 31) {
                has(PackageManager.FEATURE_UWB)
            } else {
                false
            },
            usbHost = has(PackageManager.FEATURE_USB_HOST),
            fingerprint = has(PackageManager.FEATURE_FINGERPRINT),
            bluetooth = has(PackageManager.FEATURE_BLUETOOTH),
            bluetoothLe = has(PackageManager.FEATURE_BLUETOOTH_LE),
            telephony = has(PackageManager.FEATURE_TELEPHONY),
        )
    }
}

/** The bridge for the hardware pages. */
internal class HardwareHostApiImpl(
    context: Context,
    private val activity: () -> Activity?,
) : HardwareHostApi {

    private val reader = HardwareReader(context)
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun dispose() {
        // Unregister first. A listener that survives the engine keeps the CPU
        // waking for a screen that no longer exists.
        runCatching { reader.stopSensors() }
        // A track still playing when the engine goes holds an audio focus and
        // a buffer for a screen that no longer exists.
        runCatching { reader.stopTone() }
        worker.shutdownNow()
    }

    override fun display(callback: (Result<DisplayInfo>) -> Unit) {
        worker.execute { reply(callback, reader.display()) }
    }

    override fun network(callback: (Result<NetworkInfo>) -> Unit) {
        worker.execute { reply(callback, reader.network()) }
    }

    override fun wifi(callback: (Result<WifiInfo>) -> Unit) {
        worker.execute { reply(callback, reader.wifi()) }
    }

    override fun cameras(callback: (Result<List<CameraInfo>>) -> Unit) {
        worker.execute { reply(callback, reader.cameras()) }
    }

    override fun features(callback: (Result<FeatureFlags>) -> Unit) {
        worker.execute { reply(callback, reader.features()) }
    }

    override fun throughput(callback: (Result<ThroughputSample>) -> Unit) {
        // On the worker, but never queued behind a camera enumeration: this is
        // polled once a second and a two second stall would show as a flat line.
        worker.execute { reply(callback, reader.throughput()) }
    }

    override fun startSensors(
        types: List<String>,
        callback: (Result<Unit>) -> Unit,
    ) {
        // On the main thread, not the worker. registerListener wants a Looper,
        // and the worker has none.
        main.post {
            reader.startSensors(types)
            callback(Result.success(Unit))
        }
    }

    override fun stopSensors(callback: (Result<Unit>) -> Unit) {
        main.post {
            reader.stopSensors()
            callback(Result.success(Unit))
        }
    }

    override fun sensorValues(callback: (Result<List<SensorReading>>) -> Unit) {
        main.post { callback(Result.success(reader.sensorValues())) }
    }

    override fun playTone(
        hertz: Double,
        milliseconds: Long,
        channel: String,
        callback: (Result<Unit>) -> Unit,
    ) {
        worker.execute {
            runCatching { reader.playTone(hertz, milliseconds, channel) }
            reply(callback, Unit)
        }
    }

    override fun stopTone(callback: (Result<Unit>) -> Unit) {
        worker.execute {
            runCatching { reader.stopTone() }
            reply(callback, Unit)
        }
    }

    override fun vibrate(pattern: String, callback: (Result<Boolean>) -> Unit) {
        worker.execute { reply(callback, reader.vibrate(pattern)) }
    }

    override fun sims(callback: (Result<List<SimInfo>>) -> Unit) {
        worker.execute { reply(callback, reader.sims()) }
    }

    override fun bluetooth(callback: (Result<BluetoothInfo>) -> Unit) {
        worker.execute { reply(callback, reader.bluetooth()) }
    }

    override fun requestBluetooth(callback: (Result<Boolean>) -> Unit) {
        ask(Manifest.permission.BLUETOOTH_CONNECT, REQUEST_BLUETOOTH, callback)
    }

    override fun requestPhoneState(callback: (Result<Boolean>) -> Unit) {
        ask(Manifest.permission.READ_PHONE_STATE, REQUEST_PHONE, callback)
    }

    /**
     * One path for every runtime ask, so a new permission cannot arrive with a
     * slightly different null check.
     */
    private fun ask(
        permission: String,
        code: Int,
        callback: (Result<Boolean>) -> Unit,
    ) {
        val host = activity()
        if (host == null) {
            main.post { callback(Result.success(false)) }
            return
        }
        ActivityCompat.requestPermissions(host, arrayOf(permission), code)
        main.post { callback(Result.success(true)) }
    }

    override fun requestLocation(callback: (Result<Boolean>) -> Unit) {
        val host = activity()
        if (host == null) {
            main.post { callback(Result.success(false)) }
            return
        }
        // Fires the dialog and returns at once. The result arrives as a
        // lifecycle resume, and the caller re-reads rather than waiting: an
        // Activity result plumbed through Pigeon is three more moving parts for
        // an answer that a re-read gives for free.
        ActivityCompat.requestPermissions(
            host,
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
            REQUEST_LOCATION,
        )
        main.post { callback(Result.success(true)) }
    }

    private fun <T> reply(callback: (Result<T>) -> Unit, value: T) {
        main.post { callback(Result.success(value)) }
    }

    private companion object {
        const val REQUEST_LOCATION = 7301
        const val REQUEST_BLUETOOTH = 7302
        const val REQUEST_PHONE = 7303
    }
}
