/// THE SETUP STAGE: one preview that CHANGES rather than one that is replaced.
///
/// ─── WHY THIS IS NOT A CHANGE TO DevicePreview ──────────────────────────────
///
/// [DevicePreview] is drawn in six places: settings rows, chooser tiles, folder
/// pickers, a value chip at thumbnail size. Every one of those wants an instant,
/// cheap repaint, and a 300ms cross-fade inside a settings row that is already
/// animating its own expansion is jank rather than polish. So the animation
/// lives in a WRAPPER that setup uses and nothing else does, and the widget
/// every other screen depends on is untouched.
///
/// It also means this file can be deleted without taking six screens with it,
/// which is the right property for the newest idea in the flow.
///
/// ─── A CROSS-FADE, NOT A TWEEN, AND THAT IS DELIBERATE ──────────────────────
///
/// The obvious version interpolates: slide the dock across, morph the palette,
/// grow the grid from four columns to five. Two of those three cannot honestly
/// be done.
///
/// A column count is an INTEGER. There is no state between four columns and
/// five, so "animating" it means drawing 4.5 columns for 200ms, which is a
/// layout no shell will ever produce and reads as a glitch. The dock side is
/// the same: left and bottom are different layouts, not different values of one
/// layout, and sliding one into the other means rendering arrangements that do
/// not exist.
///
/// A palette COULD be tweened, and doing it alone would be worse than not: the
/// colours would drift while the geometry snapped, so the two halves of one
/// answer would land at different times.
///
/// So every change is one cross-fade of the whole picture. It is honest about
/// what changed (all of it, at once), it costs one extra DevicePreview for the
/// duration, and it reads as the desktop being rebuilt, which is what setup is
/// actually claiming to do.
///
/// ─── THE SIGNATURE IS SUPPLIED, NOT DERIVED ─────────────────────────────────
///
/// [AnimatedSwitcher] needs to know when the child is a different child, and a
/// `ThemePalette` cannot answer that: this file would have to reach into its
/// fields, and every field added to it later would be one this key silently
/// stopped noticing. A palette that changed without the key changing is a stage
/// that does not repaint, which is the exact failure this widget exists to
/// prevent.
///
/// So the caller passes [themeId], which is the one value that genuinely
/// identifies a palette, and the rest of the key is built from the primitives
/// this widget already receives. Adding a new visual parameter means adding it
/// to [_signature], and the comment there says so.
library;

import 'package:flutter/material.dart';

import '../engine/theme_spec.dart';
import 'device_preview.dart';

class DeviceStage extends StatelessWidget {
  const DeviceStage({
    super.key,
    required this.themeId,
    required this.palette,
    required this.mode,
    this.dock = DockSide.left,
    this.gridButton = 'end',
    this.cols = 4,
    this.rows = 4,
    this.tileRadiusFraction = 0.22,
    this.framed = false,
    this.background,
    this.clockLabel,
    this.dateLabel,
    this.tiles = const <Widget>[],
    this.overlay,
    this.duration = const Duration(milliseconds: 260),
  });

  /// Identifies [palette]. See the note above: this is the switcher's key, not
  /// decoration, and a stale one means a stage that stops repainting.
  final String themeId;

  final ThemePalette palette;
  final DevicePreviewMode mode;
  final DockSide dock;

  /// 'start' | 'end' | 'off'.
  final String gridButton;

  final int cols;
  final int rows;
  final double tileRadiusFraction;

  /// Defaults to FALSE here, unlike [DevicePreview]. The stage is the screen,
  /// so a phone frame would be a picture of a phone inside a phone.
  final bool framed;

  final ImageProvider? background;
  final String? clockLabel;
  final String? dateLabel;

  /// Real grid content. See [DevicePreview.tiles].
  final List<Widget> tiles;

  /// Drawn over the canvas. See [DevicePreview.overlay].
  final Widget? overlay;

  /// Long enough to read as a change, short enough not to sit between a tap and
  /// its result. Below about 200ms a cross-fade reads as a flicker; above about
  /// 350ms the control feels unresponsive on the tap that caused it.
  final Duration duration;

  /// Every value that changes what is DRAWN, joined.
  ///
  /// ADD TO THIS WHENEVER YOU ADD A PARAMETER ABOVE. A parameter missing from
  /// here is a setting that silently does nothing on this screen: the value
  /// reaches [DevicePreview], but the switcher decides the child is unchanged
  /// and keeps the old one on screen. That failure looks like the setting being
  /// broken rather than the animation being wrong, which is why it is worth a
  /// paragraph.
  ///
  /// [background] contributes its identity rather than its bytes: two different
  /// ImageProviders for the same file compare equal, and an ImageProvider is
  /// the one thing here that already knows how to answer that question.
  String get _signature => [
        themeId,
        mode.name,
        dock.name,
        gridButton,
        '$cols',
        '$rows',
        tileRadiusFraction.toStringAsFixed(3),
        '$framed',
        '${background?.hashCode}',
        // COUNT ONLY, and that is the honest limit. Two different apps produce
        // two different widgets that no cheap comparison can tell apart, so a
        // deeper key would be a promise this cannot keep. The app list does
        // not change mid-setup, which is the only case a count would miss.
        '${tiles.length}',
        '${overlay?.runtimeType}${overlay.hashCode}',
        clockLabel ?? '',
        dateLabel ?? '',
      ].join('|');

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      // The outgoing copy leaves faster than the incoming one arrives, so the
      // two never sit at half opacity together over the same wallpaper. Equal
      // curves produce a visible grey dip mid-transition on a dark palette.
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          ...previous,
          if (current != null) current,
        ],
      ),
      child: KeyedSubtree(
        key: ValueKey<String>(_signature),
        child: DevicePreview(
          palette: palette,
          mode: mode,
          dock: dock,
          gridButton: gridButton,
          cols: cols,
          rows: rows,
          tileRadiusFraction: tileRadiusFraction,
          framed: framed,
          background: background,
          clockLabel: clockLabel,
          dateLabel: dateLabel,
          tiles: tiles,
          overlay: overlay,
        ),
      ),
    );
  }
}
