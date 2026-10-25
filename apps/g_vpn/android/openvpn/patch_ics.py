#!/usr/bin/env python3
"""Turn OpenVPN for Android's app module into a library G VPN can embed.

Upstream ships `main` as an application. We keep every line of its engine
code and change only what an application has and a library must not:

  * the Android plugin (application -> library) and app-only settings
    (versionCode, signing, ABI splits, bundle config);
  * the manifest: upstream's declares an exported control API
    (ExternalOpenVPNService) that would let OTHER apps on the phone start or
    stop our VPN, plus QUERY_ALL_PACKAGES and storage permissions Play
    restricts. Ours declares only the VPN service, its status service and
    the notification's disconnect screen, none exported.

Every edit asserts it matched, so an upstream change fails loudly here
instead of producing a subtly different build.

Usage: patch_ics.py <ics-openvpn checkout>
"""
import pathlib
import sys

root = pathlib.Path(sys.argv[1])


def edit(path: pathlib.Path, old: str, new: str, count: int = 1) -> None:
    text = path.read_text()
    found = text.count(old)
    if found != count:
        sys.exit(f"patch_ics: expected {count} match(es) in {path.name} for:\n{old}\nfound {found}")
    path.write_text(text.replace(old, new))


def cut_block(path: pathlib.Path, start: str) -> None:
    """Remove a `name { ... }` block by brace matching, from `start`."""
    text = path.read_text()
    i = text.find(start)
    if i < 0:
        sys.exit(f"patch_ics: block not found in {path.name}: {start}")
    depth, j = 0, text.index("{", i)
    while True:
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                break
        j += 1
    path.write_text(text[:i] + text[j + 1:])


toml = root / "gradle/libs.versions.toml"
edit(toml,
     'android-application = { id = "com.android.application", version.ref = "android-gradle-plugin" }',
     'android-application = { id = "com.android.application", version.ref = "android-gradle-plugin" }\n'
     'android-library = { id = "com.android.library", version.ref = "android-gradle-plugin" }')

edit(root / "build.gradle.kts",
     "alias(libs.plugins.android.application) apply false",
     "alias(libs.plugins.android.application) apply false\n    alias(libs.plugins.android.library) apply false")

gradle = root / "main/build.gradle.kts"
edit(gradle, "alias(libs.plugins.android.application)", "alias(libs.plugins.android.library)")
# Upstream compiles against the newest SDK, which stamps the .aar as
# "consumers must compile against it too". Nothing in the engine needs it at
# runtime, so declare what G VPN's toolchain actually supports.
edit(gradle, "        targetSdk = 37\n",
     "        aarMetadata {\n            minCompileSdk = 36\n        }\n")
edit(gradle, '        versionCode = 224\n        versionName = "0.7.68"\n', "")
edit(gradle, '            versionNameSuffix = "-o2"\n', "")
cut_block(gradle, "    signingConfigs {")
cut_block(gradle, "            if (project.hasProperty(\"icsopenvpnDebugSign\")) {")
cut_block(gradle, "    splits {")
cut_block(gradle, "    bundle {")

# The if-block cut above leaves its `else { ... }` behind; remove it too.
text = gradle.read_text()
marker = " else {\n                productFlavors[\"ovpn23\"]"
if marker in text:
    cut_block(gradle, marker.strip(" "))
text = gradle.read_text()
for leftover in ("signingConfig", "versionCode", "versionNameSuffix", "splits", "bundle {"):
    if leftover in text:
        sys.exit(f"patch_ics: '{leftover}' still present in main/build.gradle.kts")

manifest = root / "main/src/main/AndroidManifest.xml"
manifest.write_text('''<?xml version="1.0" encoding="utf-8"?>
<!-- G VPN's trimmed manifest for the embedded OpenVPN for Android engine (GPLv2). -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application>
        <activity
            android:name=".activities.DisconnectVPN"
            android:autoRemoveFromRecents="true"
            android:excludeFromRecents="true"
            android:noHistory="true"
            android:exported="false"
            android:taskAffinity=".DisconnectVPN"
            android:theme="@style/blinkt.dialog" />

        <!-- Own process: a native crash in OpenVPN never takes the UI down. -->
        <service
            android:name=".core.OpenVPNService"
            android:exported="false"
            android:permission="android.permission.BIND_VPN_SERVICE"
            android:foregroundServiceType="specialUse"
            android:process=":openvpn">
            <intent-filter>
                <action android:name="android.net.VpnService" />
            </intent-filter>
            <property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE" android:value="vpn" />
        </service>

        <service
            android:name=".core.OpenVPNStatusService"
            android:exported="false"
            android:process=":openvpn" />

        <!-- Reconnect watchdog the engine schedules with JobScheduler.
             Exported only so the system can bind it; BIND_JOB_SERVICE means
             no app can. -->
        <service
            android:name=".core.keepVPNAlive"
            android:exported="true"
            android:permission="android.permission.BIND_JOB_SERVICE"
            android:process=":openvpn" />

        <!-- Opened by the engine when it needs the VPN permission again.
             Not exported: only G VPN itself can start it. -->
        <activity
            android:name=".LaunchVPN"
            android:autoRemoveFromRecents="true"
            android:excludeFromRecents="true"
            android:exported="false"
            android:label="@string/vpn_launch_title"
            android:taskAffinity=".LaunchVPN"
            android:theme="@style/blinkt.dialog" />
    </application>
</manifest>
''')

# Notification buttons: Pause 15m, Pause 1h, Disconnect, all handled by the
# app's GvpnSessionService. Upstream's own pause keeps the tunnel half-open
# with no countdown; G VPN's pause fully stops it, shows when it resumes, and
# reconnects on time. Disconnect skips upstream's confirmation screen.
service = root / "main/src/main/java/de/blinkt/openvpn/core/OpenVPNService.java"
text = service.read_text()
start = text.index("    private void addVpnActionsToNotification(Notification.Builder nbuilder) {")
end = text.index("    PendingIntent getUserInputIntent(String needed) {")
service.write_text(text[:start] + """    private void addVpnActionsToNotification(Notification.Builder nbuilder) {
        // G VPN: buttons handled by the app's session service.
        nbuilder.addAction(R.drawable.ic_menu_pause, getString(R.string.gvpn_pause_15),
                gvpnAction("com.mindberzerk.gvpn.PAUSE", 15, 0x6701));
        nbuilder.addAction(R.drawable.ic_menu_pause, getString(R.string.gvpn_pause_60),
                gvpnAction("com.mindberzerk.gvpn.PAUSE", 60, 0x6702));
        nbuilder.addAction(R.drawable.ic_menu_close_clear_cancel, getString(R.string.gvpn_disconnect),
                gvpnAction("com.mindberzerk.gvpn.STOP", 0, 0x6703));
    }

    private PendingIntent gvpnAction(String action, int minutes, int requestCode) {
        Intent intent = new Intent(action)
                .setClassName(getPackageName(), "com.mindberzerk.gvpn.GvpnSessionService")
                .putExtra("minutes", minutes);
        int flags = PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT;
        return android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O
                ? PendingIntent.getForegroundService(this, requestCode, intent, flags)
                : PendingIntent.getService(this, requestCode, intent, flags);
    }

""" + text[end:])

# The button labels, in the engine's own resources so it compiles alone; the
# app's copies (same names) win at merge time and carry the translations.
(root / "main/src/main/res/values/gvpn_strings.xml").write_text("""<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="gvpn_pause_15">Pause 15m</string>
    <string name="gvpn_pause_60">Pause 1h</string>
    <string name="gvpn_disconnect">Disconnect</string>
</resources>
""")

# The skeleton flavour's manifest exports a placeholder activity; not needed.
(root / "main/src/skeleton/AndroidManifest.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n<manifest />\n')

print("patch_ics: OK")
