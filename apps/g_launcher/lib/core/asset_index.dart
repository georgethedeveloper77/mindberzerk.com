/// Which asset keys are actually bundled in this APK.
///
/// ─── WHY A BUNDLED PATH HAS TO BE CHECKED BEFORE IT IS DRAWN ────────────────
///
/// `ThemeAsset.existsSync` answers true for every bundled path, because an
/// asset cannot be probed synchronously. For raster artwork that is fine:
/// `Image.errorBuilder` catches the miss. For SVG it is not. vector_graphics
/// keeps a `whenComplete` future off the load that nothing listens to, so a
/// missing asset escapes to PlatformDispatcher.onError as an uncaught async
/// error even when the widget has an errorBuilder. That is the
/// `_VectorGraphicWidgetState._loadPicture.<fn>` crash: 208 events on 6.0.0.
///
/// The only reliable fix is to never start the load, which needs the answer
/// synchronously, which is what this holds.
library;

import 'package:flutter/services.dart';

abstract final class AssetIndex {
  /// Null until [warm] completes, or when the manifest could not be read.
  static Set<String>? _keys;

  /// Reads the manifest once. Started in `main` right after `bootstrap()` so it
  /// overlaps Firebase init instead of adding to the time before first frame.
  static Future<void> warm() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _keys = manifest.listAssets().toSet();
    } catch (_) {
      // Unknown is not the same as absent. Leaving this null makes [has]
      // answer true, which is exactly the behaviour before this file existed.
      _keys = null;
    }
  }

  /// True when [key] is bundled, or when the manifest is not loaded.
  static bool has(String key) => _keys?.contains(key) ?? true;
}
