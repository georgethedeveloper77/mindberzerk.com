# Open SSTP Client engine, as used in G VPN

Source: https://github.com/kittoku/Open-SSTP-Client (MIT, see
LICENSE-open-sstp-client.txt). Only the protocol code is included (SSL, SSTP,
PPP, authentication, IP); the original app's screens, settings UI, tile and
log export are not.

Settings are read from the app's default SharedPreferences under the
original keys (OscPrefKey). G VPN writes them before each connection; see
com.mindberzerk.gvpn.SstpEngine.

Changes from the original:

1. terminal/SSLTerminal.kt: notifyUntrustedCertificate() is a no-op. The
   original opens its own certificate-saving screen. G VPN connects to
   VPN Gate servers, which use self-signed certificates, with verification off.
2. service/SstpVpnService.kt: the foreground notification is G VPN's (icon,
   server name, Pause 15m / Pause 1h / Disconnect via GvpnSessionService),
   started with the specialUse foreground-service type on Android 14+; the
   original app's tile is not referenced.
