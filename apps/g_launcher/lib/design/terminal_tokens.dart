import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Terminal palette, straight from the mockup's `:root`.
///
///   --tm-bg  #080D08   --tm-grn #52F088   --tm-dim #2E7A48
///   --tm-amb #E8B84B   --tm-mut #5C7C66
///
/// Note the background is NOT black — it's a very dark desaturated green. That
/// 5-point shift is most of why the screen reads as a terminal rather than as a
/// dark-mode app, and it is the first thing that gets "corrected" to #000 by
/// someone who thinks it's a mistake. It isn't.
abstract final class Term {
  static const bg = Color(0xFF080D08);
  static const green = Color(0xFF52F088);
  static const dim = Color(0xFF2E7A48);
  static const amber = Color(0xFFE8B84B);
  static const muted = Color(0xFF5C7C66);

  /// The selected-row wash: rgba(82,240,136,.13)
  static const selection = Color(0x2152F088);

  /// The hint rule: rgba(82,240,136,.14)
  static const rule = Color(0x2452F088);

  /// Ubuntu orange, for the fastfetch logo and keys.
  static const accent = Color(0xFFE95420);

  static const mono = 'UbuntuMono';
  static const size = 13.5;
  static const lineHeight = 1.6;
}

/// The fastfetch header's contents.
///
/// Everything nullable, everything hides its own line when absent — same rule as
/// the conky. A fastfetch block reading `device ~ unknown` is worse than a
/// fastfetch block with one fewer line, and this screen is the flagship, so it
/// does not get to look broken on a device we failed to identify.
@immutable
class DeviceInfo {
  const DeviceInfo({
    this.user = 'user',
    this.host,
    this.deviceModel,
    this.uptime,
    this.batteryPercent,
  });

  /// `george` in `george@infinix`. There is no way to get a username on Android
  /// — this is a *preference*, and a nice one: let people set their prompt.
  /// TODO(george): a Settings row, defaulting to 'user'.
  final String user;

  /// `infinix` — lowercased manufacturer. From `Build.MANUFACTURER`.
  final String? host;

  /// `Infinix NOTE 40` — from `Build.MANUFACTURER` + `Build.MODEL`.
  final String? deviceModel;

  /// From `SystemClock.elapsedRealtime()`. Cheap, no permission — but native
  /// only, so it stays null on the package-based path below (the row hides).
  final Duration? uptime;

  final int? batteryPercent;

  String get prompt => host == null ? user : '$user@$host';

  /// `3h 12m`
  String? get uptimeLabel {
    final u = uptime;
    if (u == null) return null;
    final h = u.inHours;
    final m = u.inMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

/// Real device identity, no native code of our own.
///
/// `device_info_plus` gives manufacturer + model; `battery_plus` gives the
/// charge. Both are plugins with their own platform channels, so we add zero
/// Kotlin and touch no Pigeon — which is the whole reason we took this path over
/// a hand-rolled `getDeviceInfo()`.
///
/// The one thing packages can't give is **uptime** (`SystemClock.elapsedRealtime`
/// is native-only). It stays null, so the fastfetch `uptime` line hides itself
/// under the nullable-field rule — deliberate, not broken. To bring it back
/// without abandoning this approach, add a ~4-line MethodChannel:
///
///   // Kotlin, in LauncherActivity.configureFlutterEngine:
///   MethodChannel(messenger, "g_launcher/uptime").setMethodCallHandler { _, r ->
///     r.success(android.os.SystemClock.elapsedRealtime())
///   }
///   // Dart, here:
///   final ms = await const MethodChannel('g_launcher/uptime').invokeMethod<int>('get');
///   // → uptime: Duration(milliseconds: ms)
///
/// Android-only by design (this is the Android launcher; iOS is a separate,
/// thinner client). If this ever runs on iOS, branch on Platform first.
final deviceInfoProvider = FutureProvider<DeviceInfo>((ref) async {
  final android = await DeviceInfoPlugin().androidInfo;
  final manufacturer = android.manufacturer.trim();
  final model = android.model.trim();

  int? battery;
  try {
    final level = await Battery().batteryLevel;
    // batteryLevel can report -1 on devices that won't say; treat as unknown so
    // the status line drops it rather than printing a nonsense "-1%".
    if (level >= 0 && level <= 100) battery = level;
  } catch (_) {
    // Emulator, or a device that refuses the read — the battery segment hides.
  }

  return DeviceInfo(
    host: manufacturer.isEmpty ? null : manufacturer.toLowerCase(),
    deviceModel: _deviceModel(manufacturer, model),
    batteryPercent: battery,
  );
});

/// `Infinix NOTE 40`, but without the `Samsung Samsung SM-…` double-brand: some
/// OEMs already prefix the model with the make, so only join when they differ.
String? _deviceModel(String manufacturer, String model) {
  if (model.isEmpty) return manufacturer.isEmpty ? null : manufacturer;
  if (manufacturer.isEmpty ||
      model.toLowerCase().startsWith(manufacturer.toLowerCase())) {
    return model;
  }
  return '$manufacturer $model';
}
