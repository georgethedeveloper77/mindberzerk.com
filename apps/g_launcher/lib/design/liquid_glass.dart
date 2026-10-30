/// Liquid Glass: the one surface iOS 26 draws its Home Screen on.
///
/// The dock, the Search button, folders, card widgets, the App Library's tiles
/// and the search sheet all share it, so they read as one material rather than
/// six translucent boxes that each picked their own alpha.
///
/// Three layers, in order:
///   1. a strong blur of whatever is behind, so the wallpaper's colour carries
///      through without its detail;
///   2. a pale tint graded from top to bottom, which is what makes it read as a
///      pane rather than a hole;
///   3. a bright rim, strongest along the top edge where light would catch it.
///
/// ─── A FIXED HIGHLIGHT, NOT A TILTING ONE ───────────────────────────────────
///
/// On iOS the highlight moves as the phone tilts. That needs the motion sensor
/// running for as long as the home screen is up, which is a battery cost on a
/// surface people leave open all day. The rim sits where light from above would
/// put it, which is the frame people remember from screenshots.
///
/// ─── ONE BLUR PER SURFACE ───────────────────────────────────────────────────
///
/// A BackdropFilter is the most expensive thing on a home screen. Each glass
/// surface costs one, so this widget is used for the few large panes and never
/// per icon: the Clear icon look draws its glass in the native renderer, where
/// it is a bitmap and costs nothing to scroll.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    required this.radius,
    this.dark = false,
    this.padding = EdgeInsets.zero,
    this.width,
    this.height,
  });

  final Widget child;
  final BorderRadius radius;

  /// The darker glass of the Dark and Clear-dark looks: the same rim over a
  /// smoked pane instead of a pale one.
  final bool dark;

  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;

  /// How hard the backdrop is blurred. Enough to lose every edge in a photo
  /// and keep its colour, which is the whole effect.
  static const blurSigma = 20.0;

  /// The pane's tint, for a surface that already owns its blur (the dock).
  static LinearGradient fill({required bool dark}) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? const [Color(0x33000000), Color(0x59000000)]
            : const [Color(0x42FFFFFF), Color(0x14FFFFFF)],
      );

  /// The hairline round the pane.
  static const edge = Color(0x47FFFFFF);

  /// The specular rim: a light band hugging the top edge that fades within the
  /// first few pixels. Drawn as a FOREGROUND, over the content, so it reads as
  /// the edge of the glass rather than as a line under it.
  static BoxDecoration rim(BorderRadius radius) => BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment(0, -0.82),
          colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: fill(dark: dark),
            border: Border.all(color: edge),
          ),
          foregroundDecoration: rim(radius),
          child: child,
        ),
      ),
    );
  }
}
