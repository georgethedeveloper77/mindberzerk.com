package com.mindberzerk.gvpn

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.net.wifi.ScanResult
import android.net.wifi.WifiManager
import androidx.core.content.ContextCompat
import java.util.concurrent.TimeUnit
import android.provider.OpenableColumns
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.codescanner.GmsBarcodeScannerOptions
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import com.wireguard.android.backend.BackendException
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.BadConfigException
import com.wireguard.config.Config
import java.io.BufferedReader
import java.io.StringReader
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Implements the Pigeon [VpnHostApi].
 *
 * Blocking work (tunnel state, package queries) runs on one background thread,
 * which also serialises connect and disconnect; every Pigeon callback is
 * posted back to the main thread, where the channel must be answered.
 */
class VpnHost(private var activity: Activity?) : VpnHostApi {
    private val app: Context = requireNotNull(activity).applicationContext
    private val worker: ExecutorService = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pendingPrepare: ((Result<Boolean>) -> Unit)? = null
    private var pendingNotify: ((Result<Boolean>) -> Unit)? = null
    private var pendingLocation: ((Result<Boolean>) -> Unit)? = null
    private var pendingFile: ((Result<PickedConfig?>) -> Unit)? = null

    private fun backend() = WireGuard.backend(app)

    private fun <T> onWorker(callback: (Result<T>) -> Unit, block: () -> T) {
        worker.execute {
            val result = try {
                Result.success(block())
            } catch (e: FlutterError) {
                Result.failure(e)
            } catch (e: Exception) {
                Result.failure(FlutterError("failed", e.message ?: e.javaClass.simpleName, null))
            }
            main.post { callback(result) }
        }
    }

    override fun prepare(callback: (Result<Boolean>) -> Unit) {
        val host = activity ?: return callback(Result.failure(FlutterError("detached", "No activity", null)))
        val consent = VpnService.prepare(host)
        if (consent == null) {
            callback(Result.success(true))
            return
        }
        if (pendingPrepare != null) {
            callback(Result.failure(FlutterError("busy", "Consent dialog already open", null)))
            return
        }
        pendingPrepare = callback
        @Suppress("DEPRECATION")
        host.startActivityForResult(consent, REQUEST_VPN_CONSENT)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            REQUEST_VPN_CONSENT -> {
                pendingPrepare?.invoke(Result.success(resultCode == Activity.RESULT_OK))
                pendingPrepare = null
            }
            REQUEST_FILE -> {
                val callback = pendingFile ?: return true
                pendingFile = null
                val uri = data?.data
                if (resultCode != Activity.RESULT_OK || uri == null) {
                    callback(Result.success(null))
                    return true
                }
                onWorker(callback) { readConfig(uri) }
            }
            REQUEST_IMAGE -> {
                val callback = pendingImage ?: return true
                pendingImage = null
                val uri = data?.data
                if (resultCode != Activity.RESULT_OK || uri == null) {
                    callback(Result.success(null))
                    return true
                }
                decodeQr(uri, callback)
            }
            else -> return false
        }
        return true
    }

    private var pendingImage: ((Result<String?>) -> Unit)? = null

    override fun scanQrFromImage(callback: (Result<String?>) -> Unit) {
        val host = activity ?: return callback(Result.failure(FlutterError("detached", "No activity", null)))
        if (pendingImage != null) {
            callback(Result.failure(FlutterError("busy", "Picker already open", null)))
            return
        }
        pendingImage = callback
        // Android's photo picker where available: no storage permission.
        val intent = if (Build.VERSION.SDK_INT >= 33 ||
            (Build.VERSION.SDK_INT >= 30 && android.os.ext.SdkExtensions.getExtensionVersion(Build.VERSION_CODES.R) >= 2)
        ) {
            Intent(android.provider.MediaStore.ACTION_PICK_IMAGES)
        } else {
            Intent(Intent.ACTION_GET_CONTENT).setType("image/*").addCategory(Intent.CATEGORY_OPENABLE)
        }
        @Suppress("DEPRECATION")
        host.startActivityForResult(intent, REQUEST_IMAGE)
    }

    override fun seal(plain: String): String = SecretBox.seal(plain)

    override fun unseal(stored: String): String? = SecretBox.open(stored)

    override fun generateWgKeyPair(): WgKeyPair {
        val pair = com.wireguard.crypto.KeyPair()
        return WgKeyPair(pair.privateKey.toBase64(), pair.publicKey.toBase64())
    }

    override fun deviceName(): String {
        val maker = Build.MANUFACTURER.replaceFirstChar { it.uppercase() }
        return if (Build.MODEL.startsWith(Build.MANUFACTURER, ignoreCase = true)) Build.MODEL else "$maker ${Build.MODEL}"
    }

    override fun takeSharedServer(callback: (Result<String?>) -> Unit) {
        when (val shared = SharedServer.take()) {
            null -> callback(Result.success(null))
            is SharedServer.Text -> callback(Result.success(shared.text))
            is SharedServer.Image -> decodeQr(shared.uri, callback)
        }
    }

    /** Reads a QR code from an image on the phone (Play services ML Kit). */
    private fun decodeQr(uri: android.net.Uri, callback: (Result<String?>) -> Unit) {
        val image = try {
            com.google.mlkit.vision.common.InputImage.fromFilePath(app, uri)
        } catch (e: Exception) {
            return callback(Result.failure(FlutterError("no_qr", "That image could not be opened.", null)))
        }
        val options = com.google.mlkit.vision.barcode.BarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
            .build()
        com.google.mlkit.vision.barcode.BarcodeScanning.getClient(options).process(image)
            .addOnSuccessListener { codes ->
                val text = codes.firstNotNullOfOrNull { it.rawValue }
                if (text == null) {
                    callback(Result.failure(FlutterError("no_qr", "No QR code found in that image.", null)))
                } else {
                    callback(Result.success(text))
                }
            }
            .addOnFailureListener { e ->
                callback(Result.failure(FlutterError("no_qr", e.message ?: "No QR code found in that image.", null)))
            }
    }


    override fun scanQr(callback: (Result<String?>) -> Unit) {
        val host = activity ?: return callback(Result.failure(FlutterError("detached", "No activity", null)))
        val options = GmsBarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
            .enableAutoZoom()
            .build()
        GmsBarcodeScanning.getClient(host, options).startScan()
            .addOnSuccessListener { callback(Result.success(it.rawValue)) }
            .addOnCanceledListener { callback(Result.success(null)) }
            .addOnFailureListener { e ->
                // Typically: no Google Play services (some Huawei phones), or
                // the scanner module still downloading on first use.
                callback(Result.failure(FlutterError("scan_failed", e.message ?: "Scanner unavailable", null)))
            }
    }

    override fun pickConfigFile(callback: (Result<PickedConfig?>) -> Unit) {
        val host = activity ?: return callback(Result.failure(FlutterError("detached", "No activity", null)))
        if (pendingFile != null) {
            callback(Result.failure(FlutterError("busy", "File picker already open", null)))
            return
        }
        pendingFile = callback
        // "*/*": .conf has no registered MIME type, so a narrower filter would
        // grey out the very files we want.
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("*/*")
        @Suppress("DEPRECATION")
        host.startActivityForResult(intent, REQUEST_FILE)
    }

    /** Runs on the worker. Capped: a WireGuard config is a few hundred bytes. */
    private fun readConfig(uri: android.net.Uri): PickedConfig {
        val resolver = app.contentResolver
        val name = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) c.getString(0) else null
        } ?: "Imported server"
        // Bounded by hand: InputStream.readNBytes only exists from Android 13.
        val out = java.io.ByteArrayOutputStream()
        resolver.openInputStream(uri)?.use { input ->
            val chunk = ByteArray(8192)
            while (true) {
                val n = input.read(chunk)
                if (n < 0) break
                if (out.size() + n > MAX_CONFIG_BYTES) {
                    throw FlutterError("too_large", "That file is too large to be a WireGuard config", null)
                }
                out.write(chunk, 0, n)
            }
        } ?: throw FlutterError("read_failed", "Could not open the file", null)
        return PickedConfig(name.substringBeforeLast('.'), out.toString(Charsets.UTF_8.name()))
    }

    override fun connect(configText: String, label: String, callback: (Result<Unit>) -> Unit) =
        onWorker(callback) {
            stopOpenVpnAndWait()
            val config = try {
                Config.parse(BufferedReader(StringReader(configText)))
            } catch (e: BadConfigException) {
                throw FlutterError("bad_config", e.message ?: "Invalid config", null)
            }
            try {
                backend().setState(GTunnel, Tunnel.State.UP, config)
            } catch (e: BackendException) {
                val code = if (e.reason == BackendException.Reason.VPN_NOT_AUTHORIZED) "not_authorized" else "connect_failed"
                throw FlutterError(code, e.reason.name, null)
            }
            // A deliberate connect lifts any "paused on this Wi-Fi" from an
            // earlier manual disconnect.
            AutoConnect.clearUserPause(app)
            // The notification (with Pause / Disconnect) and the Quick
            // Settings tile both work from this record.
            LastSession.save(app, LastSession.WireGuard(label, configText))
            main.post { GvpnSessionService.send(app, GvpnSessionService.ACTION_CONNECTED) }
            GvpnFamily.changed(app)
        }

    override fun appIcon(packageName: String, sizePx: Long, callback: (Result<ByteArray?>) -> Unit) =
        onWorker(callback) {
            val drawable = try {
                app.packageManager.getApplicationIcon(packageName)
            } catch (e: PackageManager.NameNotFoundException) {
                return@onWorker null
            }
            val size = sizePx.toInt().coerceIn(24, 192)
            val bitmap = android.graphics.Bitmap.createBitmap(size, size, android.graphics.Bitmap.Config.ARGB_8888)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(android.graphics.Canvas(bitmap))
            java.io.ByteArrayOutputStream().use { out ->
                bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, out)
                bitmap.recycle()
                out.toByteArray()
            }
        }

    override fun pause(minutes: Long) {
        GvpnSessionService.send(app, GvpnSessionService.ACTION_PAUSE, minutes.toInt())
    }

    override fun resume() {
        GvpnSessionService.send(app, GvpnSessionService.ACTION_RESUME)
    }

    override fun disconnect(callback: (Result<Unit>) -> Unit) =
        onWorker(callback) {
            // Remember the network so auto-connect does not undo the user's
            // choice the moment the tunnel drops.
            AutoConnect.markUserPaused(app)
            GvpnSessionService.end(app)
            backend().setState(GTunnel, Tunnel.State.DOWN, null)
            stopOpenVpnAndWait()
            stopSstpAndWait()
            GvpnFamily.changed(app)
        }

    override fun connectOpenVpn(configText: String, options: OpenVpnOptions, callback: (Result<Unit>) -> Unit) {
        // WireGuard down first (on the worker, it blocks), then hand over.
        worker.execute {
            runCatching { backend().setState(GTunnel, Tunnel.State.DOWN, null) }
            GvpnSessionService.end(app)
            OpenVpnEngine.connect(app, configText, options.name, options.excludedApps, options.dnsServers) { result ->
                if (result.isSuccess) {
                    AutoConnect.clearUserPause(app)
                    LastSession.save(
                        app,
                        LastSession.OpenVpn(options.name, configText, options.excludedApps, options.dnsServers),
                    )
                }
                callback(result)
            }
        }
    }

    /** Runs on the worker: waits for the OpenVPN engine to confirm it stopped. */
    private fun stopOpenVpnAndWait() {
        if (!OpenVpnEngine.isActive) return
        val latch = java.util.concurrent.CountDownLatch(1)
        OpenVpnEngine.disconnect(app) { latch.countDown() }
        latch.await(10, java.util.concurrent.TimeUnit.SECONDS)
    }

    @Volatile
    private var sstpConnecting = false

    override fun connectSstp(options: SstpOptions, callback: (Result<Unit>) -> Unit) =
        onWorker(callback) {
            // One engine at a time: the others down first.
            runCatching { backend().setState(GTunnel, Tunnel.State.DOWN, null) }
            stopOpenVpnAndWait()
            stopSstpAndWait()
            GvpnSessionService.end(app)

            val o = SstpEngine.Options(
                options.host, options.port.toInt(), options.username, options.password,
                options.excludedApps, options.dnsServers,
            )
            LastSession.save(
                app,
                LastSession.Sstp(options.name, o.host, o.port, o.username, o.password, o.excludedApps, o.dnsServers),
            )
            sstpConnecting = true
            try {
                SstpEngine.connect(app, o)
                // Up to 30 s for TLS, SSTP, PPP and the tunnel. The engine
                // stops its service on any failure, which ends the wait early.
                val deadline = System.currentTimeMillis() + 30_000
                Thread.sleep(400)
                while (!SstpEngine.isConnected(app)) {
                    if (!SstpEngine.isActive(app)) {
                        throw FlutterError("timeout", "The server did not answer.", null)
                    }
                    if (System.currentTimeMillis() > deadline) {
                        SstpEngine.disconnect(app)
                        throw FlutterError("timeout", "The server did not answer.", null)
                    }
                    Thread.sleep(250)
                }
                AutoConnect.clearUserPause(app)
                GvpnFamily.changed(app)
            } finally {
                sstpConnecting = false
            }
        }

    /** Runs on the worker: stops the SSTP engine and waits until it has. */
    private fun stopSstpAndWait() {
        if (!SstpEngine.isActive(app)) return
        SstpEngine.disconnect(app)
        val deadline = System.currentTimeMillis() + 5_000
        while (SstpEngine.isActive(app) && System.currentTimeMillis() < deadline) Thread.sleep(100)
    }

    /** Pigeon's Kotlin class has no defaults; this supplies them. */
    private fun status(
        phase: TunnelPhase,
        rx: Long = 0L,
        tx: Long = 0L,
        stoppedByUser: Boolean = false,
        pausedUntilMs: Long = 0L,
    ) = TunnelStatus(phase, rx, tx, stoppedByUser, pausedUntilMs)

    override fun status(): TunnelStatus {
        val pausedUntil = GvpnSessionService.pausedUntil
        if (pausedUntil > System.currentTimeMillis()) {
            return status(TunnelPhase.PAUSED, 0L, 0L, pausedUntilMs = pausedUntil)
        }
        if (OpenVpnEngine.isConnected) {
            return status(TunnelPhase.UP, OpenVpnEngine.rxBytes, OpenVpnEngine.txBytes)
        }
        if (OpenVpnEngine.isReconnecting) {
            return status(TunnelPhase.RECONNECTING, OpenVpnEngine.rxBytes, OpenVpnEngine.txBytes)
        }
        if (SstpEngine.isConnected(app)) return status(TunnelPhase.UP)
        // Running but not passing traffic, and not a connect of ours in
        // flight: the engine is retrying after a drop.
        if (SstpEngine.isActive(app) && !sstpConnecting) return status(TunnelPhase.RECONNECTING)
        val backend = backend()
        if (backend.getState(GTunnel) != Tunnel.State.UP) {
            // Reported once, so a later drop is judged on its own.
            val byUser = GvpnSessionService.userStoppedAt > 0
            GvpnSessionService.userStoppedAt = 0
            return status(TunnelPhase.DOWN, 0L, 0L, stoppedByUser = byUser)
        }
        return try {
            val stats = backend.getStatistics(GTunnel)
            status(TunnelPhase.UP, stats.totalRx(), stats.totalTx())
        } catch (e: Exception) {
            status(TunnelPhase.UP, 0L, 0L)
        }
    }

    override fun listApps(callback: (Result<List<InstalledApp>>) -> Unit) =
        onWorker(callback) {
            val pm = app.packageManager
            val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            val infos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.queryIntentActivities(launcher, PackageManager.ResolveInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                pm.queryIntentActivities(launcher, 0)
            }
            infos.map { it.activityInfo.applicationInfo }
                .distinctBy { it.packageName }
                .filter { it.packageName != app.packageName }
                .map {
                    InstalledApp(
                        packageName = it.packageName,
                        label = pm.getApplicationLabel(it).toString(),
                        system = (it.flags and ApplicationInfo.FLAG_SYSTEM) != 0,
                    )
                }
                .sortedBy { it.label.lowercase() }
        }

    override fun setAutoConnect(settings: AutoConnectSettings?) {
        AutoConnect.configure(app, settings)
    }

    override fun notificationsAllowed(): Boolean {
        val enabled = app.getSystemService(NotificationManager::class.java)?.areNotificationsEnabled() == true
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return enabled
        return enabled &&
            app.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }

    override fun requestNotifications(callback: (Result<Boolean>) -> Unit) {
        val host = activity
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || host == null || notificationsAllowed()) {
            callback(Result.success(notificationsAllowed()))
            return
        }
        if (pendingNotify != null) {
            callback(Result.failure(FlutterError("busy", "Permission dialog already open", null)))
            return
        }
        pendingNotify = callback
        host.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
    }

    override fun traceHop(host: String, ttl: Long, callback: (Result<TraceHop>) -> Unit) =
        onWorker(callback) {
            val started = System.nanoTime()
            // -n: no reverse lookups, so every line carries a plain address.
            val process = ProcessBuilder("/system/bin/ping", "-n", "-c", "1", "-W", "2", "-t", ttl.toString(), host)
                .redirectErrorStream(true)
                .start()
            val output = process.inputStream.bufferedReader().use { it.readText() }
            process.waitFor(4, TimeUnit.SECONDS)
            process.destroy()
            val elapsedMs = (System.nanoTime() - started) / 1_000_000.0

            val reached = Regex("""bytes from ([0-9a-fA-F:.]+).*?time=([\d.]+)""").find(output)
            val exceeded = Regex("""From ([0-9a-fA-F:.]+).*?(exceeded|Time to live)""", RegexOption.IGNORE_CASE).find(output)
            when {
                reached != null ->
                    TraceHop(ttl, reached.groupValues[1].trimEnd(':'), reached.groupValues[2].toDoubleOrNull(), true)
                // The tool prints no time for an expired hop; the measured
                // run time (minus a little process start-up) stands in.
                exceeded != null -> TraceHop(ttl, exceeded.groupValues[1].trimEnd(':'), elapsedMs, false)
                else -> TraceHop(ttl, null, null, false)
            }
        }

    override fun scanWifi(callback: (Result<List<WifiAccessPoint>>) -> Unit) {
        if (!wifiNamesAllowed()) {
            callback(Result.failure(FlutterError("no_permission", "Location permission is needed to scan Wi-Fi", null)))
            return
        }
        val wifi = app.getSystemService(WifiManager::class.java)
        if (wifi == null) {
            callback(Result.success(emptyList()))
            return
        }
        var finished = false
        lateinit var receiver: BroadcastReceiver
        val finish = Runnable {
            if (finished) return@Runnable
            finished = true
            runCatching { app.unregisterReceiver(receiver) }
            @Suppress("MissingPermission")
            callback(Result.success(wifi.scanResults.map(::toAccessPoint).sortedByDescending { it.level }))
        }
        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                main.post(finish)
            }
        }
        ContextCompat.registerReceiver(
            app, receiver, IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION), ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        // Android throttles scans (four per two minutes); when it refuses,
        // the last results are still useful, so return those at once.
        @Suppress("DEPRECATION")
        if (!wifi.startScan()) main.post(finish) else main.postDelayed(finish, 8_000)
    }

    private fun toAccessPoint(r: ScanResult): WifiAccessPoint {
        val ssid = if (Build.VERSION.SDK_INT >= 33) {
            r.wifiSsid?.toString()?.removeSurrounding("\"") ?: ""
        } else {
            @Suppress("DEPRECATION") r.SSID ?: ""
        }
        val caps = r.capabilities ?: ""
        val security = when {
            caps.contains("SAE") || caps.contains("WPA3") -> "WPA3"
            caps.contains("RSN") || caps.contains("WPA2") -> "WPA2"
            caps.contains("WPA") -> "WPA"
            caps.contains("WEP") -> "WEP"
            else -> "Open"
        }
        val f = r.frequency
        val channel = when {
            f == 2484 -> 14
            f in 2412..2472 -> (f - 2407) / 5
            f in 5150..5895 -> (f - 5000) / 5
            f in 5925..7125 -> (f - 5950) / 5
            else -> 0
        }
        val width = when (r.channelWidth) {
            ScanResult.CHANNEL_WIDTH_40MHZ -> 40
            ScanResult.CHANNEL_WIDTH_80MHZ -> 80
            ScanResult.CHANNEL_WIDTH_160MHZ, ScanResult.CHANNEL_WIDTH_80MHZ_PLUS_MHZ -> 160
            else -> 20
        }
        @Suppress("DEPRECATION")
        return WifiAccessPoint(ssid, r.BSSID ?: "", r.level.toLong(), f.toLong(), channel.toLong(), width.toLong(), security)
    }

    override fun locationServicesOn(): Boolean {
        val lm = app.getSystemService(android.location.LocationManager::class.java) ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lm.isLocationEnabled
        } else {
            @Suppress("DEPRECATION")
            android.provider.Settings.Secure.getInt(
                app.contentResolver, android.provider.Settings.Secure.LOCATION_MODE, 0,
            ) != 0
        }
    }

    override fun openLocationSettings() {
        val intent = Intent(android.provider.Settings.ACTION_LOCATION_SOURCE_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        (activity ?: app).startActivity(intent)
    }

    override fun openVpnSettings() {
        (activity ?: app).startActivity(
            Intent(android.provider.Settings.ACTION_VPN_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    override fun openBatterySettings() {
        // The list screen needs no special permission (unlike the direct
        // "exempt this app" prompt, which Play restricts).
        (activity ?: app).startActivity(
            Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    override fun batteryUnrestricted(): Boolean {
        val pm = app.getSystemService(android.os.PowerManager::class.java) ?: return true
        return pm.isIgnoringBatteryOptimizations(app.packageName)
    }

    override fun wifiNamesAllowed(): Boolean =
        app.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

    override fun requestWifiNames(callback: (Result<Boolean>) -> Unit) {
        val host = activity
        if (host == null || wifiNamesAllowed()) {
            callback(Result.success(wifiNamesAllowed()))
            return
        }
        if (pendingLocation != null) {
            callback(Result.failure(FlutterError("busy", "Permission dialog already open", null)))
            return
        }
        pendingLocation = callback
        // FINE is what unlocks the SSID; COARSE must be requested alongside
        // it on Android 12+, where the user may choose approximate instead.
        host.requestPermissions(
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
            REQUEST_LOCATION,
        )
    }

    fun onRequestPermissionsResult(requestCode: Int): Boolean = when (requestCode) {
        REQUEST_NOTIFICATIONS -> {
            pendingNotify?.invoke(Result.success(notificationsAllowed()))
            pendingNotify = null
            true
        }
        REQUEST_LOCATION -> {
            pendingLocation?.invoke(Result.success(wifiNamesAllowed()))
            pendingLocation = null
            true
        }
        else -> false
    }

    /** Called when the engine goes away. The tunnel itself keeps running. */
    fun detach() {
        pendingPrepare?.invoke(Result.success(false))
        pendingNotify?.invoke(Result.success(false))
        pendingLocation?.invoke(Result.success(false))
        pendingFile?.invoke(Result.success(null))
        pendingFile = null
        pendingPrepare = null
        pendingNotify = null
        pendingLocation = null
        activity = null
        worker.shutdown()
    }

    private companion object {
        const val REQUEST_VPN_CONSENT = 0x6770
        const val REQUEST_NOTIFICATIONS = 0x6772
        const val REQUEST_LOCATION = 0x6773
        const val REQUEST_FILE = 0x6774
        const val REQUEST_IMAGE = 0x6775
        const val MAX_CONFIG_BYTES = 64 * 1024
    }
}
