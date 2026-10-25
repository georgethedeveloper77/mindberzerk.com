package com.mindberzerk.gvpn

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import de.blinkt.openvpn.core.ConfigParser
import de.blinkt.openvpn.core.ConnectionStatus
import de.blinkt.openvpn.core.IOpenVPNServiceInternal
import de.blinkt.openvpn.core.LogItem
import de.blinkt.openvpn.core.OpenVPNService
import de.blinkt.openvpn.core.ProfileManager
import de.blinkt.openvpn.core.VPNLaunchHelper
import de.blinkt.openvpn.core.VpnStatus
import java.io.StringReader

/**
 * OpenVPN, for Community (VPN Gate) and provider servers. WireGuard stays
 * the engine for G Servers and "Your Server"; only one runs at a time.
 *
 * The engine runs in its own `:openvpn` process. State reaches this process
 * through VpnStatus, relayed by the status service GVpnApplication sets up.
 */
object OpenVpnEngine : VpnStatus.StateListener, VpnStatus.ByteCountListener, VpnStatus.LogListener {

    private const val TAG = "GVpnOpenVpn"

    /**
     * Give up on a server that has not connected in this long. Community
     * servers that are offline never answer at all, so waiting longer only
     * delays "try another one".
     */
    private const val CONNECT_TIMEOUT_MS = 30_000L

    /** Per-attempt TCP/UDP connect timeout handed to OpenVPN (its default is 120 s). */
    private const val SOCKET_TIMEOUT_S = 12

    private val main = Handler(Looper.getMainLooper())
    private var listening = false
    private var pending: ((Result<Unit>) -> Unit)? = null
    private var sawProgress = false
    private var appContext: Context? = null

    /** The engine's recent log, so a failure can say why it failed. */
    private val recentLog = ArrayDeque<String>()
    private var lastError: String? = null
    private val timeout = Runnable { finish(Result.failure(error("timeout", "The server did not answer in time"))) }

    @Volatile var level: ConnectionStatus = ConnectionStatus.LEVEL_NOTCONNECTED
        private set
    @Volatile var rxBytes = 0L
        private set
    @Volatile var txBytes = 0L
        private set

    val isActive: Boolean get() = level != ConnectionStatus.LEVEL_NOTCONNECTED
    val isConnected: Boolean get() = level == ConnectionStatus.LEVEL_CONNECTED

    /**
     * Running but not passing traffic, with no connect attempt of ours in
     * flight: OpenVPN is recovering from a network change or the phone
     * waking up. The UI must say "reconnecting", not "off".
     */
    val isReconnecting: Boolean get() = isActive && !isConnected && pending == null

    /**
     * Called once when the app's main process starts. The engine lives in
     * its own process and survives the UI being closed; listening from the
     * start means a reopened app immediately learns a tunnel is still up
     * (VpnStatus replays the last state to a new listener).
     */
    fun attach(context: Context) {
        appContext = context.applicationContext
        main.post { listen() }
    }

    private fun listen() {
        if (listening) return
        VpnStatus.addStateListener(this)
        VpnStatus.addByteCountListener(this)
        VpnStatus.addLogListener(this)
        listening = true
    }

    /**
     * Starts a tunnel from .ovpn text. Resolves once traffic flows, or fails
     * with a reason the UI can show. App rules and Shield map onto the
     * engine's own per-app and DNS settings, so both engines behave the same.
     */
    fun connect(
        context: Context,
        configText: String,
        name: String,
        excludedApps: List<String>,
        dnsServers: List<String>,
        done: (Result<Unit>) -> Unit,
    ) {
        main.post {
            appContext = context.applicationContext
            listen()
            recentLog.clear()
            lastError = null
            pending?.invoke(Result.failure(error("replaced", "Another connection was started")))
            val profile = try {
                ConfigParser().run {
                    parseConfig(StringReader(configText))
                    convertProfile()
                }
            } catch (e: Exception) {
                done(Result.failure(error("bad_config", e.message ?: "This server's config could not be read")))
                return@post
            }
            profile.mName = name
            profile.mAllowedAppsVpnAreDisallowed = true
            profile.mAllowedAppsVpn = HashSet(excludedApps)
            profile.mConnections.forEach { it.mConnectTimeout = SOCKET_TIMEOUT_S }
            // The engine's default search domain is its author's; never send it.
            profile.mSearchDomain = ""
            if (dnsServers.isNotEmpty()) {
                // Shield: our resolvers ONLY. Without the filter the server's
                // pushed DNS is added alongside and can answer first.
                profile.mOverrideDNS = true
                profile.mDNS1 = dnsServers[0]
                profile.mDNS2 = dnsServers.getOrElse(1) { "" }
                profile.mUseCustomConfig = true
                profile.mCustomConfigOptions =
                    profile.mCustomConfigOptions.orEmpty() + "\npull-filter ignore \"dhcp-option DNS\"\n"
            }
            ProfileManager.setTemporaryProfile(context, profile)

            pending = done
            sawProgress = false
            main.postDelayed(timeout, CONNECT_TIMEOUT_MS)
            VPNLaunchHelper.startOpenVpn(profile, context.applicationContext, "G VPN", true)
        }
    }

    /** Stops the tunnel; resolves immediately when nothing is running. */
    fun disconnect(context: Context, done: (Result<Unit>) -> Unit) {
        main.post {
            finish(Result.failure(error("cancelled", "Disconnected")))
            stopEngine(context, done = done)
        }
    }

    /**
     * Stops the engine even when this process has not heard its status yet:
     * a notification button can start the app's process cold, while the
     * engine's own process is still running the tunnel.
     */
    fun forceStop(context: Context, done: (Result<Unit>) -> Unit) {
        main.post {
            finish(Result.failure(error("cancelled", "Disconnected")))
            stopEngine(context, force = true, done = done)
        }
    }

    private fun stopEngine(context: Context, force: Boolean = false, done: (Result<Unit>) -> Unit) {
        if (!isActive && !force) {
            done(Result.success(Unit))
            return
        }
        val app = context.applicationContext
        val intent = Intent(app, OpenVPNService::class.java).setAction(OpenVPNService.START_SERVICE)
        val connection = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName, binder: IBinder) {
                runCatching { IOpenVPNServiceInternal.Stub.asInterface(binder).stopVPN(false) }
                app.unbindService(this)
                done(Result.success(Unit))
            }

            override fun onServiceDisconnected(name: ComponentName) = Unit
        }
        if (!app.bindService(intent, connection, Context.BIND_AUTO_CREATE)) done(Result.success(Unit))
    }

    override fun updateState(state: String?, logmessage: String?, localizedResId: Int, level: ConnectionStatus, intent: Intent?) {
        val moved = this.level != level
        this.level = level
        if (moved) appContext?.let(GvpnFamily::changed)
        main.post {
            when (level) {
                ConnectionStatus.LEVEL_CONNECTED -> finish(Result.success(Unit))
                ConnectionStatus.LEVEL_AUTH_FAILED ->
                    finish(Result.failure(error("auth_failed", "The server refused the connection")))
                ConnectionStatus.LEVEL_NOTCONNECTED ->
                    // NOTCONNECTED is also the state before anything starts;
                    // it only means failure once the attempt was under way.
                    if (sawProgress) finish(Result.failure(error("failed", lastError ?: logmessage ?: "Could not connect")))
                else -> sawProgress = true
            }
        }
    }

    override fun updateByteCount(`in`: Long, out: Long, diffIn: Long, diffOut: Long) {
        rxBytes = `in`
        txBytes = out
    }

    override fun setConnectedVPN(uuid: String?) = Unit

    override fun newLog(logItem: LogItem) {
        val context = appContext ?: return
        val line = runCatching { logItem.getString(context) }.getOrNull() ?: return
        Log.i(TAG, line)
        main.post {
            recentLog.addLast(line)
            while (recentLog.size > 40) recentLog.removeFirst()
            if (logItem.logLevel == VpnStatus.LogLevel.ERROR) lastError = line.trim()
        }
    }

    private fun finish(result: Result<Unit>) {
        val callback = pending ?: return
        pending = null
        main.removeCallbacks(timeout)
        // A failed attempt must not keep trying in the background: the UI
        // has already said "not connected", and a tunnel appearing later
        // would contradict it.
        if (result.isFailure) appContext?.let { stopEngine(it) {} }
        callback(result)
    }

    private fun error(code: String, message: String) = FlutterError(code, message, null)
}
