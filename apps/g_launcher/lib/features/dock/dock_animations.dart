/// The dock's three animation axes, as data.
///
/// ─── ONE LIST, NOT ONE PER READER ──────────────────────────────────────────
///
/// Four things need to agree about these: the parser in `theme_spec.dart`, the
/// allow-list in `layout_resolver.dart`, the settings sheet that offers them,
/// and the docks that draw them. `PanelModule` learned this the expensive way,
/// where a value the device parsed and the resolver's set omitted resolved to
/// the default forever behind a dock that looked like it was working.
///
/// The two string lists in the engine stay, because they are the parse boundary
/// and a `const` set is what `_pick` wants. This is the list everything ABOVE
/// that boundary reads, so a new mode is a row here plus two strings there
/// rather than five edits in five files.
///
/// ─── THREE AXES, BECAUSE THEY ARE THREE QUESTIONS ──────────────────────────
///
/// A dock that magnifies under the finger and sinks on a tap is an ordinary
/// combination, and so is one that does neither but slides in on first paint.
/// A single "animation style" field would have offered the combinations
/// somebody thought of and hidden the rest.
library;

import 'package:flutter/material.dart';

/// One selectable mode on one axis.
class DockAnimation {
  const DockAnimation(this.id, this.icon);

  /// The stored value. Matches the parse arm in `theme_spec.dart` exactly.
  final String id;

  final IconData icon;

  /// The i18n key for this mode's name, e.g. `settings.dockHover.magnify`.
  ///
  /// Derived rather than stored: the id is already unique within its axis and a
  /// second string per mode is a second thing to get out of step.
  String labelKey(String axis) => 'settings.$axis.$id';

  /// The i18n key for the one-line description under the name.
  String hintKey(String axis) => 'settings.$axis.$id.hint';
}

/// How the dock responds to a finger moving over it.
///
/// `magnify` is where `dockStyle: "magnified"` went. That value also carries a
/// corner radius, so it stays on `dockStyle` and only the SWELL reads from
/// here; see `LayoutResolver`, which seeds this from it.
const dockHoverModes = [
  DockAnimation('none', Icons.remove),
  DockAnimation('magnify', Icons.zoom_in),
  DockAnimation('lift', Icons.arrow_upward),
  DockAnimation('tilt', Icons.threed_rotation),
  DockAnimation('part', Icons.unfold_more),
  DockAnimation('focus', Icons.blur_on),
  DockAnimation('arc', Icons.waves),
];

/// What an icon does when it is tapped.
const dockPressModes = [
  DockAnimation('sink', Icons.vertical_align_bottom),
  DockAnimation('bounce', Icons.sports_basketball_outlined),
  DockAnimation('jelly', Icons.bubble_chart_outlined),
  DockAnimation('pop', Icons.open_in_full),
  DockAnimation('flip', Icons.flip),
  DockAnimation('swing', Icons.swap_calls),
  DockAnimation('pulse', Icons.radio_button_checked),
  DockAnimation('ripple', Icons.wifi_tethering),
  DockAnimation('wave', Icons.graphic_eq),
  DockAnimation('launch', Icons.rocket_launch_outlined),
];

/// How the dock arrives, on first paint and when an autohiding dock returns.
const dockEntranceModes = [
  DockAnimation('none', Icons.remove),
  DockAnimation('slide', Icons.swipe_up_outlined),
  DockAnimation('expand', Icons.open_in_full),
  DockAnimation('blur', Icons.blur_linear),
  DockAnimation('stagger', Icons.view_week_outlined),
  DockAnimation('gloss', Icons.gradient),
];

/// The mode on [modes] with this [id], or the first one.
///
/// Falling back to the first rather than returning null, because every caller
/// wants something to draw: a settings row showing a blank subtitle for a value
/// a newer build wrote is worse than one showing the default's name.
DockAnimation dockAnimationFor(List<DockAnimation> modes, String id) {
  for (final m in modes) {
    if (m.id == id) return m;
  }
  return modes.first;
}
