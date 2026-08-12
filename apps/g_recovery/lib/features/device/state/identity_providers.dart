import 'package:device_probe/device_probe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which phone this is.
///
/// Its own file rather than a line in `device_providers.dart`, because this is
/// read by the home app bar and by the Device tab, and the sampler providers
/// next door are wired to start and stop with a visible tab. Nothing here
/// samples anything.
///
/// Native caches the answer for the process, so this resolves once and every
/// later watcher is served from memory.
final FutureProvider<DeviceIdentity?> deviceIdentityProvider =
    FutureProvider<DeviceIdentity?>(
      (Ref ref) => DeviceProbe().deviceIdentity(),
    );

/// What to put in a title.
///
/// The ladder in Kotlin returns null when no OEM rung answered, and this is
/// where that null becomes a string. Composing the fallback here rather than
/// natively keeps the bridge honest about whether a real name was ever found.
///
/// `samsung` is lowercase in `Build.MANUFACTURER` on every Samsung device, so
/// the first letter is raised. Nothing else is touched: an OEM that ships
/// `HUAWEI` in capitals meant it.
String deviceTitle(DeviceIdentity? identity) {
  if (identity == null) return 'This device';
  final String? name = identity.marketingName;
  if (name != null && name.isNotEmpty) return name;
  final String maker = _capitalise(identity.manufacturer);
  return '$maker ${identity.model}'.trim();
}

/// The line under the title. Manufacturer and model code, which is the pair a
/// support message needs and the pair a marketing name hides.
String? deviceCaption(DeviceIdentity? identity) {
  if (identity == null) return null;
  return '${_capitalise(identity.manufacturer)}  ·  ${identity.model}';
}

String _capitalise(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

/// What this app is allowed to read.
///
/// NOT held across a resume. All Files Access is a toggle the user can flip from
/// a settings screen this app never sees, so any cached answer is a guess. The
/// shell already invalidates the recovery side of this on resume; this is the
/// same fact read through the probe, for the screen that explains it.
final FutureProvider<StorageAccess?> storageAccessProvider =
    FutureProvider<StorageAccess?>((Ref ref) => DeviceProbe().storageAccess());
