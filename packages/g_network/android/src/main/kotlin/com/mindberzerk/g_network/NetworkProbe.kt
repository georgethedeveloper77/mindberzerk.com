package com.mindberzerk.g_network

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.TelephonyManager

/**
 * One read-only snapshot of the device's network state.
 *
 * Two networks matter at once when a VPN is up: the ACTIVE one (the tunnel,
 * whose DNS servers apps really use) and the PHYSICAL one under it (the Wi-Fi
 * whose security we want to judge). Reporting only the active network would
 * describe the tunnel and hide the open cafe Wi-Fi it is protecting you from.
 */
class NetworkProbe(context: Context) : NetworkHostApi {
    private val app = context.applicationContext
    private val cm = app.getSystemService(ConnectivityManager::class.java)

    override fun snapshot(): NetworkSnapshot {
        val active = cm.activeNetwork
        val activeCaps = active?.let { cm.getNetworkCapabilities(it) }
        val activeLink = active?.let { cm.getLinkProperties(it) }
        val vpnActive = activeCaps?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true

        val physical = if (vpnActive) underlyingNetwork() else active
        val caps = physical?.let { cm.getNetworkCapabilities(it) }
        val link = physical?.let { cm.getLinkProperties(it) }
        val transport = transportOf(caps)

        val wifi = if (transport == Transport.WIFI) wifiInfo(caps) else null

        return NetworkSnapshot(
            transport = transport,
            vpnActive = vpnActive,
            validated = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true,
            captivePortal = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL) == true,
            metered = caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) == false,
            privateDnsActive = privateDnsActive(activeLink),
            dnsServers = activeLink?.dnsServers?.mapNotNull { it.hostAddress } ?: emptyList(),
            addresses = link?.linkAddresses?.mapNotNull { it.address?.hostAddress } ?: emptyList(),
            wifiSecurity = wifi?.let { securityOf(it) } ?: WifiSecurity.UNKNOWN,
            privateDnsServer = privateDnsServer(activeLink),
            interfaceName = link?.interfaceName,
            gateway = gatewayOf(link),
            downKbps = caps?.linkDownstreamBandwidthKbps?.toLong(),
            upKbps = caps?.linkUpstreamBandwidthKbps?.toLong(),
            rssi = wifi?.rssi?.toLong(),
            linkSpeedMbps = wifi?.linkSpeed?.takeIf { it > 0 }?.toLong(),
            frequencyMhz = wifi?.frequency?.takeIf { it > 0 }?.toLong(),
            carrierName = if (transport == Transport.CELLULAR) carrierName() else null,
            ssid = if (transport == Transport.WIFI) ssid() else null,
        )
    }

    /** The validated, internet-capable, non-VPN network, if any. */
    @Suppress("DEPRECATION")
    private fun underlyingNetwork(): Network? {
        val candidates = cm.allNetworks.filter { n ->
            val c = cm.getNetworkCapabilities(n) ?: return@filter false
            !c.hasTransport(NetworkCapabilities.TRANSPORT_VPN) &&
                c.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        }
        return candidates.firstOrNull {
            cm.getNetworkCapabilities(it)?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
        } ?: candidates.firstOrNull()
    }

    private fun transportOf(caps: NetworkCapabilities?): Transport = when {
        caps == null -> Transport.NONE
        caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> Transport.WIFI
        caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> Transport.CELLULAR
        caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> Transport.ETHERNET
        else -> Transport.OTHER
    }

    /**
     * Android 12+ exposes WifiInfo through the capabilities without location
     * access; SSID and BSSID come back redacted, which is fine, we never show
     * them. Older releases fall back to WifiManager.
     */
    @SuppressLint("MissingPermission")
    private fun wifiInfo(caps: NetworkCapabilities?): WifiInfo? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return caps?.transportInfo as? WifiInfo
        }
        @Suppress("DEPRECATION")
        return app.getSystemService(WifiManager::class.java)?.connectionInfo
    }

    private fun securityOf(info: WifiInfo): WifiSecurity {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return WifiSecurity.UNKNOWN
        return when (info.currentSecurityType) {
            WifiInfo.SECURITY_TYPE_OPEN -> WifiSecurity.OPEN
            WifiInfo.SECURITY_TYPE_WEP -> WifiSecurity.WEP
            WifiInfo.SECURITY_TYPE_PSK -> WifiSecurity.WPA2
            WifiInfo.SECURITY_TYPE_SAE -> WifiSecurity.WPA3
            WifiInfo.SECURITY_TYPE_OWE -> WifiSecurity.OWE
            WifiInfo.SECURITY_TYPE_EAP,
            WifiInfo.SECURITY_TYPE_EAP_WPA3_ENTERPRISE,
            WifiInfo.SECURITY_TYPE_EAP_WPA3_ENTERPRISE_192_BIT -> WifiSecurity.ENTERPRISE
            else -> WifiSecurity.UNKNOWN
        }
    }

    private fun gatewayOf(link: LinkProperties?): String? =
        link?.routes
            ?.firstOrNull { it.isDefaultRoute && it.gateway?.isAnyLocalAddress == false }
            ?.gateway?.hostAddress

    private fun privateDnsActive(link: LinkProperties?): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && link?.isPrivateDnsActive == true

    private fun privateDnsServer(link: LinkProperties?): String? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) link?.privateDnsServerName else null

    /**
     * The Wi-Fi name, only when the APP already holds location permission
     * (asked for in G VPN with a disclosure). This package never asks.
     * WifiManager is used on every version: the capabilities' WifiInfo
     * carries a redacted SSID unless registered with location flags.
     */
    @SuppressLint("MissingPermission")
    private fun ssid(): String? {
        if (app.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            return null
        }
        @Suppress("DEPRECATION")
        val raw = app.getSystemService(WifiManager::class.java)?.connectionInfo?.ssid ?: return null
        if (raw.isBlank() || raw == WifiManager.UNKNOWN_SSID) return null
        return raw.removeSurrounding("\"")
    }

    /** Operator name needs no permission, unlike signal strength or network type. */
    private fun carrierName(): String? =
        app.getSystemService(TelephonyManager::class.java)
            ?.networkOperatorName
            ?.takeIf { it.isNotBlank() }
}
