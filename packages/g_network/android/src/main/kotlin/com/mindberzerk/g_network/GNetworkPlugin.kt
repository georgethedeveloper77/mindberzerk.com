package com.mindberzerk.g_network

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Registers the g_network bridge, and pushes network changes to Dart while an
 * engine is attached. The callback lives exactly as long as the engine:
 * nothing listens once the app's UI is gone.
 */
class GNetworkPlugin : FlutterPlugin {
    private var cm: ConnectivityManager? = null
    private var callback: ConnectivityManager.NetworkCallback? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        NetworkHostApi.setUp(binding.binaryMessenger, NetworkProbe(binding.applicationContext))

        val events = NetworkEventsApi(binding.binaryMessenger)
        val main = Handler(Looper.getMainLooper())
        // Pigeon FlutterApi calls must happen on the platform thread.
        val notify = { main.post { events.onNetworkChanged { } } }
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                notify()
            }

            override fun onLost(network: Network) {
                notify()
            }
        }
        val manager = binding.applicationContext.getSystemService(ConnectivityManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            manager.registerDefaultNetworkCallback(cb)
        } else {
            manager.registerNetworkCallback(NetworkRequest.Builder().build(), cb)
        }
        cm = manager
        callback = cb
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        NetworkHostApi.setUp(binding.binaryMessenger, null)
        callback?.let { cb ->
            try {
                cm?.unregisterNetworkCallback(cb)
            } catch (_: IllegalArgumentException) {
                // Already gone.
            }
        }
        callback = null
        cm = null
    }
}
