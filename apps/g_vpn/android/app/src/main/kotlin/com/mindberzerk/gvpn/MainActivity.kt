package com.mindberzerk.gvpn

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var host: VpnHost? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val vpnHost = VpnHost(this)
        host = vpnHost
        VpnHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, vpnHost)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        VpnHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        host?.detach()
        host = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    // FlutterActivity is a plain Activity, not a ComponentActivity, so VPN
    // consent, the file picker and permissions all arrive through the
    // classic callbacks.
    @Deprecated("Forwarded from the platform callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (host?.onActivityResult(requestCode, resultCode, data) == true) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (host?.onRequestPermissionsResult(requestCode) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
