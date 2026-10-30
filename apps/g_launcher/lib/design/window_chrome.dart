/// A tiled window's frame: the gap, the rounded border, and on the focused one
/// a coloured border. What a Hyprland or COSMIC desktop draws around every
/// window, drawn here around a tiled app or a terminal desklet.
///
/// ─── ONE FRAME FOR TILES AND DESKLETS ──────────────────────────────────────
///
/// An Arch rice is a screen of windows that all look alike: kitty, btop and an
/// app side by side with the same gap and the same border. Drawing the tiles
/// and the desklet windows through two widgets is how they would stop matching.
///
/// ─── THE FOCUSED BORDER IS THE DISTRO'S ────────────────────────────────────
///
/// With an `accentGradient` the focused window gets it, which for Arch is
/// Hyprland's own cyan to green. Without one it is the flat accent. Unfocused
/// windows get a faint rule in the theme's ink, never a colour.
library;

import 'package:flutter/material.dart';

import '../engine/effective_theme.dart';

/// The gap between two tiled windows, and between a window and the screen.
const double windowGap = 8;

/// The border's width, focused or not.
const double windowBorder = 2;

class WindowChrome extends StatelessWidget {
  const WindowChrome({
    super.key,
    required this.theme,
    required this.child,
    this.focused = false,
    this.title,
  });

  final EffectiveTheme theme;
  final Widget child;
  final bool focused;

  /// A title strip, as a terminal emulator draws one. Null for app tiles, which
  /// a tiling compositor draws without decorations.
  final String? title;

  /// The distro's corner, from its surfaces, else Hyprland's default rounding.
  double get _radius => theme.spec.surfaces?.radius ?? 10;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;
    final radius = BorderRadius.circular(_radius);
    final gradient = theme.spec.accentGradient;

    final inner = ClipRRect(
      borderRadius: BorderRadius.circular(
        (_radius - windowBorder).clamp(0.0, double.infinity),
      ),
      child: ColoredBox(
        color: palette.bar.withValues(alpha: 0.94),
        child: title == null
            ? child
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TitleStrip(theme: theme, title: title!),
                  Expanded(child: child),
                ],
              ),
      ),
    );

    // ─── A GRADIENT BORDER IS A PADDED GRADIENT ───────────────────────────
    //
    // Flutter's Border takes a colour, not a shader. The frame is therefore a
    // gradient box with the window inset by the border's width, which also
    // keeps the unfocused and focused frames the same size so focus moving
    // between windows does not shift anything by two pixels.
    final Decoration frame = focused && gradient.length >= 2
        ? BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          )
        : BoxDecoration(
            borderRadius: radius,
            color: focused
                ? palette.accent
                : palette.onDark.withValues(alpha: 0.12),
          );

    return Padding(
      padding: const EdgeInsets.all(windowGap / 2),
      child: DecoratedBox(
        decoration: frame,
        child: Padding(
          padding: const EdgeInsets.all(windowBorder),
          child: inner,
        ),
      ),
    );
  }
}

class _TitleStrip extends StatelessWidget {
  const _TitleStrip({required this.theme, required this.title});

  final EffectiveTheme theme;
  final String title;

  @override
  Widget build(BuildContext context) {
    final onDark = theme.palette.onDark;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      color: onDark.withValues(alpha: 0.05),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: theme.typography.mono,
          fontSize: 11,
          color: onDark.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
