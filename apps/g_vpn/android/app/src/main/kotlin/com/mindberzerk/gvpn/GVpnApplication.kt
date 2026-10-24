package com.mindberzerk.gvpn

import android.app.ActivityManager
import android.app.Application
import android.os.Build
import android.os.Process
import de.blinkt.openvpn.core.ICSOpenVPNApplication

/**
 * The OpenVPN engine expects its own Application: it creates the VPN
 * notification channels and connects the status relay between the engine's
 * `:openvpn` process and this one.
 *
 * In the MAIN process we also start listening for engine state right away,
 * so a tunnel that kept running while the app was closed shows as connected
 * the moment the app reopens.
 */
class GVpnApplication : ICSOpenVPNApplication() {

    override fun onCreate() {
        super.onCreate()
        if (isMainProcess()) OpenVpnEngine.attach(this)
    }

    private fun isMainProcess(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) return Application.getProcessName() == packageName
        val am = getSystemService(ActivityManager::class.java) ?: return true
        val me = Process.myPid()
        return am.runningAppProcesses?.firstOrNull { it.pid == me }?.processName?.let { it == packageName } ?: true
    }
}
