import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../engine/theme_spec.dart' show ThemePalette;
import '../../dock/dock_metrics.dart';

/// One dock slot.
///
/// Holds a widget rather than a component name so the dock has no dependency on
/// the icon engine — it renders whatever `IconCache` hands it, and the dock's
/// golden tests don't need a live LauncherApps.
@immutable
class DockEntry {
  const DockEntry({
    required this.id,
    required this.label,
    required this.icon,
    this.isRunning = false,
    this.isPinned = false,
    this.onTap,
    this.onLongPress,
  });

  final String id;
  final String label;
  final Widget icon;

  /// Draws the orange running bar. Android has no public "is this running"
  /// API — light this only for what you actually KNOW (recents via the
  /// accessibility service). Default false; a running bar on an app that isn't
  /// running is a small lie, and small lies are how people stop trusting a
  /// shell.
  final bool isRunning;

  /// Pinned by the user (vs shown because it's frequent). The long-press sheet
  /// uses it to offer "Unpin" vs "Pin".
  final bool isPinned;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
}

/// The dock. Mockup geometry throughout, scaled by [slotSize]:
/// translucent `rgba(32,27,33,.74)` with a 12px backdrop blur, 1px white-10%
/// border, 18px radius, 9/7 padding, 9px gaps. Running apps get an orange bar on
/// their outer edge, centred from the slot size (not a literal).
///
/// **Axis-aware.** A left dock is a Column with the running bar to the icon's
/// left; a bottom dock is a Row with the bar underneath. The grid button sits
/// at [gridButton] — start, end, or absent — separated by a hairline.
///
/// Capacity is the CALLER's problem (`DockMetrics.capacityFor` from the real
/// inset-adjusted length); this widget renders exactly what it's given and
/// never scrolls. A dock you have to scroll has lost the argument.
class GnomeDock extends StatelessWidget {
  const GnomeDock({
    super.key,
    required this.entries,
    required this.side,
    required this.gridButton,
    required this.slotSize,
    required this.palette,
    required this.onActivities,
    this.activitiesIconBuilder,
  });

  final List<DockEntry> entries;
  final DockSide side;
  final GridButtonPosition gridButton;

  /// The per-render slot size (see [DockMetrics.slotFor]): large when the dock
  /// is near-empty, shrinking as it fills. The glyph and the running-bar
  /// centring are both derived from it, so nothing here is a hardcoded literal.
  final double slotSize;

  /// The active theme's palette. The dock fill ([ThemePalette.dock]), the grid
  /// glyph colour ([ThemePalette.onDark]) and the running-bar accent
  /// ([ThemePalette.accent]) all come from here, so a non-Ubuntu dock isn't
  /// Ubuntu-coloured.
  final ThemePalette palette;

  final VoidCallback onActivities;

  /// Builds the Activities (app-drawer) button's icon at the dock-owned glyph
  /// size. When null, the button falls back to the 9-dot grid glyph.
  ///
  /// This is the seam for the per-theme distro logo: the CALLER passes a builder
  /// (typically `LauncherBrandIcon`) only when the active theme ships a logo, so
  /// the dock stays free of the icon engine / flutter_svg and its golden tests
  /// keep rendering the plain glyph. Passing it only for logo-bearing themes is
  /// deliberate: it keeps `LauncherBrandIcon`'s Mindhunter fallback out of the
  /// dock, where a bare square reads worse than the universally-understood grid.
  final Widget Function(double glyphSize)? activitiesIconBuilder;

  @override
  Widget build(BuildContext context) {
    final vertical = side.isVertical;
    final glyph = DockMetrics.gridGlyphFor(slotSize);

    // Was Ubuntu.separator. Same reasoning as the border: a hairline that is
    // hardcoded to Ubuntu's chrome is invisible on some palettes and glaring on
    // others.
    final separatorColor = palette.onDark.withValues(alpha: 0.14);

    // The Activities button's icon: the theme's logo when the caller supplies a
    // builder, otherwise the 9-dot grid glyph. Both draw at the dock-owned glyph
    // size, so a logo lands the same size as the grid it replaces.
    Widget activitiesIcon() =>
        activitiesIconBuilder?.call(glyph) ??
        Icon(Icons.apps_rounded, size: glyph, color: palette.onDark);

    final children = <Widget>[];

    void addGridButton() {
      children.add(_Separator(vertical: vertical, color: separatorColor));
      children.add(_gapBox(vertical));
      children.add(_DockSlot(
        vertical: vertical,
        slotSize: slotSize,
        entry: DockEntry(
          id: '__activities__',
          label: 'Activities',
          icon: activitiesIcon(),
          onTap: onActivities,
        ),
        accent: palette.accent,
        plate: palette.onDark.withValues(alpha: 0.10),
      ));
    }

    void addGridButtonStart() {
      children.add(_DockSlot(
        vertical: vertical,
        slotSize: slotSize,
        entry: DockEntry(
          id: '__activities__',
          label: 'Activities',
          icon: activitiesIcon(),
          onTap: onActivities,
        ),
        accent: palette.accent,
        plate: palette.onDark.withValues(alpha: 0.10),
      ));
      children.add(_gapBox(vertical));
      children.add(_Separator(vertical: vertical, color: separatorColor));
    }

    if (gridButton == GridButtonPosition.start) addGridButtonStart();

    for (var i = 0; i < entries.length; i++) {
      if (children.isNotEmpty) children.add(_gapBox(vertical));
      children.add(_DockSlot(
        vertical: vertical,
        slotSize: slotSize,
        entry: entries[i],
        accent: palette.accent,
      ));
    }

    if (gridButton == GridButtonPosition.end && entries.isNotEmpty) {
      children.add(_gapBox(vertical));
      addGridButton();
    } else if (gridButton == GridButtonPosition.end && entries.isEmpty) {
      // A dock with nothing but the grid button still shows it — it's the only
      // way into Activities if gestures are off.
      addGridButtonStart();
      children.removeLast(); // no trailing separator when it's alone
      children.removeLast();
    }

    final flow = vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: children)
        : Row(mainAxisSize: MainAxisSize.min, children: children);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        // The blur earns its keep — the dock sits on an arbitrary photograph —
        // but it is also the single most expensive thing on the desktop. If the
        // launcher ever janks on a Tecno, measure this first.
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: vertical
              ? const EdgeInsets.symmetric(horizontal: 7, vertical: 9)
              : const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: palette.dock,
            // Was Ubuntu.dockBorder, a fixed white-10% hairline. Derived from
            // the palette now, so a light-chrome distro gets a hairline that is
            // actually visible against it instead of Ubuntu's.
            border: Border.all(color: palette.onDark.withValues(alpha: 0.10)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: flow,
        ),
      ),
    );
  }

  static Widget _gapBox(bool vertical) => vertical
      ? const SizedBox(height: DockMetrics.gap)
      : const SizedBox(width: DockMetrics.gap);
}

class _DockSlot extends StatelessWidget {
  const _DockSlot({
    required this.entry,
    required this.vertical,
    required this.slotSize,
    required this.accent,
    this.plate,
  });

  final DockEntry entry;
  final bool vertical;
  final double slotSize;

  /// Running-bar colour, from the theme palette's accent.
  final Color accent;
  final Color? plate;

  @override
  Widget build(BuildContext context) {
    // Centre the running bar along the slot's long axis, COMPUTED from the live
    // slot size — a hardcoded offset de-centres it the moment the dock resizes.
    final barCentre = (slotSize - DockMetrics.runningBar) / 2;

    return Semantics(
      button: true,
      label: entry.label,
      child: GestureDetector(
        onTap: entry.onTap,
        onLongPress: entry.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: slotSize,
          height: slotSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: plate,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: entry.icon,
                ),
              ),
              if (entry.isRunning)
                // Left dock: bar to the icon's left (outer edge, per GNOME).
                // Bottom dock: bar underneath — same meaning, rotated world.
                vertical
                    ? Positioned(
                        left: -7,
                        top: barCentre,
                        child: _RunningBar(vertical: true, color: accent),
                      )
                    : Positioned(
                        bottom: -7,
                        left: barCentre,
                        child: _RunningBar(vertical: false, color: accent),
                      ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunningBar extends StatelessWidget {
  const _RunningBar({required this.vertical, required this.color});

  final bool vertical;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: vertical ? 3 : DockMetrics.runningBar,
      height: vertical ? DockMetrics.runningBar : 3,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.vertical, required this.color});

  final bool vertical;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return vertical
        ? Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            color: color,
          )
        : Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 5),
            color: color,
          );
  }
}
