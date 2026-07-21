# AndroidManifest.xml — one line to add

Add beside the other normal permissions, after VIBRATE:

```xml
<!--
  ConnectivityManager transport lookup (wifi / cellular / ethernet / vpn) for
  the network desklet. NORMAL permission: auto-granted, no runtime prompt, no
  Play declaration, same class as SET_WALLPAPER and VIBRATE above.

  This is the transport ONLY. Reading the Wi-Fi network NAME needs location
  permission on Android 10+, and this ecosystem does not ask for location to
  draw a desktop widget — so the desklet says "wifi", never which one.

  TrafficStats (the byte counters) needs no permission at all and is not
  covered by this line.
-->
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

Without it, `DeviceStatsReader.transport()` returns null, `StatCapabilities
.networkTransport` comes back false, and the throughput rows still work. It
degrades rather than breaks, which is why it is not a hard dependency.
