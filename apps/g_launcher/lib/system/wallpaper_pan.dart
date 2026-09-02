/// PHASE 5 PROBE: can this device's wallpaper be panned.
///
/// ─── WHAT PARALLAX ACTUALLY IS HERE ─────────────────────────────────────────
///
/// Not the launcher drawing a wallpaper and translating it. The launcher window
/// is transparent with `windowShowWallpaper` set, so the wallpaper is drawn by
/// WindowManager UNDERNEATH Flutter and Dart never holds it. `wallpaper_source`
/// says the same thing from the other side, and it is why a downloaded distro
/// with an unresolvable wallpaper path shows no wallpaper at all rather than a
/// broken image: there is no image, there is a window you can see through.
///
/// So panning it means asking the wallpaper service to pan, which is
/// `WallpaperManager.setWallpaperOffsets`, which needs a window token, which is
/// why the native half of this lives in `LauncherActivity` rather than on the
/// Pigeon bridge.
///
/// ─── AND WHY IT IS A PROBE RATHER THAN A FEATURE ────────────────────────────
///
/// The call may do nothing, and there is no API that says so in advance. A live
/// wallpaper receives the offset and honours it. A static one is panned by the
/// system only if the stored bitmap is wider than the screen, and One UI,
/// recent Pixel builds and most Transsion ROMs crop to screen when a wallpaper
/// is set. On those, this is correct code that moves nothing.
///
/// [diagnose] proves the negative case cheaply. [sweep] is for the rest, and
/// the instrument is your eyes.
///
/// DELETE OR PROMOTE. If offsets work, this file grows an interpolator and gets
/// wired to the workspace pager. If they do not, it goes, and parallax means
/// something else.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The one channel. Matches `WallpaperOffsets.CHANNEL` in Kotlin.
const _channel = MethodChannel('g_launcher/wallpaper_offsets');

/// What the system will admit about its own wallpaper.
@immutable
class WallpaperPanReport {
  const WallpaperPanReport({
    required this.hasToken,
    required this.liveWallpaper,
    required this.displayWidth,
    required this.desiredMinimumWidth,
    required this.likelyPannable,
  });

  /// False means the window was not attached when this was asked, which on a
  /// launcher means the call came too early rather than that anything is wrong.
  final bool hasToken;

  /// The package of the running live wallpaper, or null for a static bitmap.
  ///
  /// A live wallpaper is the good case: the offset is delivered straight to its
  /// engine and it decides what to do, which is almost always the right thing.
  final String? liveWallpaper;

  final int displayWidth;

  /// How wide the system believes the wallpaper is.
  ///
  /// ─── THE NUMBER THAT DECIDES IT, WITH ONE CAVEAT ──────────────────────────
  ///
  /// Not greater than [displayWidth] means a static wallpaper has nothing to
  /// slide, so the offset call is a no-op however correctly it is made.
  ///
  /// Some ROMs return 0, which means "no opinion" rather than "zero width". So
  /// it is reported rather than interpreted, and [likelyPannable] is a guess
  /// with the word likely in its name.
  final int desiredMinimumWidth;

  /// A live wallpaper, or a static one wider than the screen. LIKELY, because
  /// a wallpaper wide enough to pan may still have been cropped by the ROM at
  /// the point it was set, and nothing exposes that.
  final bool likelyPannable;

  @override
  String toString() => 'WallpaperPanReport(token: $hasToken, '
      'live: $liveWallpaper, display: $displayWidth, '
      'desired: $desiredMinimumWidth, pannable: $likelyPannable)';
}

/// Panning the system wallpaper, if this device allows it.
abstract final class WallpaperPan {
  /// Ask what can be asked. Null when the channel is not implemented, which is
  /// every non-Android platform and any build without the native half.
  static Future<WallpaperPanReport?> diagnose() async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('diagnose');
      if (raw == null) return null;
      return WallpaperPanReport(
        hasToken: raw['hasToken'] as bool? ?? false,
        liveWallpaper: raw['liveWallpaper'] as String?,
        displayWidth: raw['displayWidth'] as int? ?? 0,
        desiredMinimumWidth: raw['desiredMinimumWidth'] as int? ?? 0,
        likelyPannable: raw['likelyPannable'] as bool? ?? false,
      );
    } catch (_) {
      // Never throws. A launcher that fails to start because it could not
      // interrogate the wallpaper service is a bricked home screen, and this
      // whole file is optional decoration.
      return null;
    }
  }

  /// Push one offset. 0 is the far left of the wallpaper, 1 the far right.
  ///
  /// ─── NOT YET SAFE TO CALL PER SCROLL FRAME ────────────────────────────────
  ///
  /// This is a binder call. A pager's scroll listener fires at up to 120Hz, and
  /// Launcher3 deliberately does NOT drive offsets from its scroll: it runs a
  /// separate interpolator on its own choreographer that eases toward a target
  /// and skips when nothing has changed.
  ///
  /// Wiring this straight to a scroll listener is how the jank the last four
  /// phases removed would come straight back. The interpolator is the next step
  /// IF the probe says offsets work at all, which is the whole reason it has
  /// not been written yet.
  static Future<bool> setOffset(double x) async {
    try {
      final ok = await _channel.invokeMethod<bool>('setOffset', {'x': x});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Run the offset from 0 to 1 and back over about four seconds, and watch.
  ///
  /// Deliberately slower than any real parallax. At swipe speed on a device
  /// that is NOT panning, the eye cannot tell "it did not move" from "it moved
  /// and I missed it", and that ambiguity is the only thing this probe exists
  /// to remove.
  ///
  /// Ends where it started, so running it leaves nothing behind.
  static Future<void> sweep() async {
    try {
      await _channel.invokeMethod<void>('sweep');
    } catch (_) {
      // ignore
    }
  }

  /// Diagnose, log, then sweep. The whole probe in one call.
  ///
  /// `debugPrint` rather than the app logger: this is scaffolding with a known
  /// expiry, and threading it through Crashlytics context would be dressing up
  /// something that is meant to be deleted.
  static Future<void> probe() async {
    final report = await diagnose();
    debugPrint('wallpaper pan: ${report ?? 'channel not implemented'}');
    if (report != null && !report.likelyPannable) {
      debugPrint(
        'wallpaper pan: the system reports nothing wider than the screen, so '
        'the sweep below is expected to do nothing visible.',
      );
    }
    await sweep();
  }
}

/// TEMPORARY. Runs [WallpaperPan.probe] once, four seconds after startup.
///
/// ─── A PROVIDER, BECAUSE `_Root` IS NOT STATEFUL ────────────────────────────
///
/// `app.dart` already watches two providers for their side effect rather than
/// their value: `packBridgeProvider` registers a platform channel and
/// `crashContextProvider` sets Crashlytics keys. Both are documented there with
/// the same warning, that a provider nothing watches never runs. This follows
/// the same shape rather than converting `_Root` to a `ConsumerStatefulWidget`
/// for something with a known expiry.
///
/// ─── AND WHY IT WAITS ───────────────────────────────────────────────────────
///
/// `setWallpaperOffsets` needs an ATTACHED window token, and at first build the
/// decorView may not have one, so an immediate call returns false and proves
/// nothing. Four seconds also clears the boot sequence, which matters more:
/// the whole instrument here is somebody watching the wallpaper, and a sweep
/// that runs behind a boot animation is a sweep nobody saw.
///
/// DELETE THIS AND ITS `ref.watch` IN `app.dart` once the answer is known. It
/// is scaffolding, and scaffolding left up becomes architecture.
final wallpaperPanProbeProvider = Provider<void>((ref) {
  // Kept alive for the same reason `packBridgeProvider` is: the value is void,
  // so nothing holds it beyond the one watch, and a provider disposed before
  // its delay elapses is a probe that silently never fires.
  ref.keepAlive();
  Future<void>.delayed(const Duration(seconds: 4), WallpaperPan.probe);
});
