/// Android's own status bar, shown or hidden, in one place.
///
/// ─── WHY THERE WAS NOTHING HERE BEFORE ─────────────────────────────────────
///
/// Nothing in this app has ever called `SystemChrome`, so every distro ran
/// with whatever the device happened to be doing. That is the whole of the
/// Ubuntu duplication: `gnome_top_bar` already declines battery, wifi and
/// volume, so the icons on screen were Android's, sitting in the same row as
/// Activities. Two bars sharing a row, not one bar drawn twice.
///
/// ─── ONE CALL SITE, AND IT IS `HomeScreen` ─────────────────────────────────
///
/// Every shell resolves through the `data` branch of that build, which is the
/// same argument the widget stage and the single `PopScope` are placed there
/// by. A shell calling this itself would be five copies of a decision that is
/// the theme's.
///
/// ─── AND WHY THE APPLIED VALUE IS CACHED ───────────────────────────────────
///
/// It is read from a build, which runs on every prefs write. The channel call
/// is cheap but not free, and an unconditional one would cross the bridge a
/// few hundred times during a drag in edit mode.
library;

import 'package:flutter/services.dart';

class StatusBarMode {
  const StatusBarMode._();

  static bool? _applied;

  /// Show or hide the system status bar.
  ///
  /// HIDDEN keeps the navigation bar. `immersiveSticky` would take both and
  /// hand them back on a swipe, which on a launcher means the gesture that
  /// opens the drawer sometimes summons the system bars instead.
  ///
  /// CONSEQUENCE WORTH KNOWING: the mode is a window property, so a settings
  /// screen pushed from a distro that hides the bar is also drawn without one.
  /// Restoring it per route needs a navigator observer, which is a separate
  /// change and not obviously the right one: a desktop that owns the whole
  /// screen arguably owns its settings window too.
  static void apply({required bool visible}) {
    if (_applied == visible) return;
    _applied = visible;

    if (visible) {
      // Edge to edge rather than `manual` with every overlay: the wallpaper
      // runs under both bars, which is what the shells already lay out for by
      // reading `viewPadding`.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      return;
    }

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const [SystemUiOverlay.bottom],
    );
  }

  /// Forget the cached value.
  ///
  /// For the one case the cache gets wrong: another route or a plugin setting
  /// the mode behind our back, after which the next `apply` with an unchanged
  /// value would be skipped and the bar would stay where that other caller
  /// left it.
  static void invalidate() => _applied = null;
}
