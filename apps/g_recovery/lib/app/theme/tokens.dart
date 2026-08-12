import 'package:flutter/material.dart';

import 'accent.dart';

/// The only place in the app where a colour literal is allowed to exist.
///
/// Everything else reads GTokens off the theme. tool/no_constants.sh enforces
/// this: a Color(0x...) or Colors.* outside lib/app/theme fails the gate.
@immutable
class GTokens extends ThemeExtension<GTokens> {
  const GTokens._({
    required this.brightness,
    required this.accentKey,
    required this.ink,
    required this.panel,
    required this.panelAlt,
    required this.panelHigh,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.muted,
    required this.dim,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.accentText,
    required this.photo,
    required this.video,
    required this.audio,
    required this.docs,
    required this.chat,
    required this.apps,
    required this.success,
    required this.warning,
    required this.danger,
    required this.scrim,
  });

  final Brightness brightness;
  final GAccent accentKey;

  /// Surfaces, darkest to lightest in dark mode and the reverse in light mode.
  final Color ink;
  final Color panel;
  final Color panelAlt;
  final Color panelHigh;

  final Color line;
  final Color lineStrong;

  final Color text;
  final Color muted;
  final Color dim;

  final Color accent;
  final Color onAccent;

  /// Accent at low alpha, for tinted tiles and the nav indicator.
  final Color accentSoft;

  /// Accent when used as text or a glyph on a panel. Differs from [accent] in
  /// light mode only.
  final Color accentText;

  /// Category hues. Fixed, not derived from the accent: a user who picks a
  /// violet accent still needs Photos and Video to be distinguishable.
  final Color photo;
  final Color video;
  final Color audio;
  final Color docs;
  final Color chat;
  final Color apps;

  final Color success;
  final Color warning;
  final Color danger;

  final Color scrim;

  factory GTokens.dark(GAccent accentKey) => GTokens._(
    brightness: Brightness.dark,
    accentKey: accentKey,
    ink: const Color(0xFF0B0F14),
    panel: const Color(0xFF151C24),
    panelAlt: const Color(0xFF1C2630),
    panelHigh: const Color(0xFF24313D),
    line: const Color(0xFF243039),
    lineStrong: const Color(0xFF33434F),
    text: const Color(0xFFE4EBF1),
    muted: const Color(0xFF8496A4),
    dim: const Color(0xFF5A6B78),
    accent: accentKey.base,
    onAccent: GAccent.ink,
    accentSoft: accentKey.base.withValues(alpha: 0.16),
    accentText: accentKey.base,
    photo: GAccent.violet.base,
    video: GAccent.cyan.base,
    audio: GAccent.amber.base,
    docs: GAccent.mint.base,
    chat: GAccent.blue.base,
    apps: GAccent.coral.base,
    success: GAccent.mint.base,
    warning: GAccent.amber.base,
    danger: GAccent.coral.base,
    scrim: const Color(0xCC06090C),
  );

  factory GTokens.light(GAccent accentKey) => GTokens._(
    brightness: Brightness.light,
    accentKey: accentKey,
    ink: const Color(0xFFF5F7FA),
    panel: const Color(0xFFFFFFFF),
    panelAlt: const Color(0xFFF0F3F7),
    panelHigh: const Color(0xFFE4E9EF),
    line: const Color(0xFFE4E9EF),
    lineStrong: const Color(0xFFD2DAE3),
    text: const Color(0xFF101820),
    muted: const Color(0xFF65747F),
    dim: const Color(0xFF8D9BA6),
    accent: accentKey.base,
    onAccent: GAccent.ink,
    accentSoft: accentKey.base.withValues(alpha: 0.14),
    accentText: accentKey.onLight,
    photo: GAccent.violet.onLight,
    video: GAccent.cyan.onLight,
    audio: GAccent.amber.onLight,
    docs: GAccent.mint.onLight,
    chat: GAccent.blue.onLight,
    apps: GAccent.coral.onLight,
    success: GAccent.mint.onLight,
    warning: GAccent.amber.onLight,
    danger: GAccent.coral.onLight,
    scrim: const Color(0x99101820),
  );

  factory GTokens.of(Brightness brightness, GAccent accentKey) =>
      brightness == Brightness.dark
      ? GTokens.dark(accentKey)
      : GTokens.light(accentKey);

  /// Rebuilds from the factories rather than mutating 25 fields. Every token
  /// set is fully determined by (brightness, accent), so there is no valid
  /// state this cannot express.
  @override
  GTokens copyWith({Brightness? brightness, GAccent? accentKey}) =>
      GTokens.of(brightness ?? this.brightness, accentKey ?? this.accentKey);

  @override
  GTokens lerp(covariant GTokens? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? b;
    return GTokens._(
      brightness: t < 0.5 ? brightness : other.brightness,
      accentKey: t < 0.5 ? accentKey : other.accentKey,
      ink: mix(ink, other.ink),
      panel: mix(panel, other.panel),
      panelAlt: mix(panelAlt, other.panelAlt),
      panelHigh: mix(panelHigh, other.panelHigh),
      line: mix(line, other.line),
      lineStrong: mix(lineStrong, other.lineStrong),
      text: mix(text, other.text),
      muted: mix(muted, other.muted),
      dim: mix(dim, other.dim),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      accentSoft: mix(accentSoft, other.accentSoft),
      accentText: mix(accentText, other.accentText),
      photo: mix(photo, other.photo),
      video: mix(video, other.video),
      audio: mix(audio, other.audio),
      docs: mix(docs, other.docs),
      chat: mix(chat, other.chat),
      apps: mix(apps, other.apps),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
      scrim: mix(scrim, other.scrim),
    );
  }
}

/// Corner radii. Named for role, not for size, so a global rounding change is
/// one edit here.
class GRadius {
  const GRadius._();

  static const double card = 18;
  static const double button = 14;
  static const double tile = 12;
  static const double glyph = 11;
  static const double chip = 20;
  static const double sheet = 24;
  static const double phone = 30;

  static BorderRadius all(double value) => BorderRadius.circular(value);
}

class GSpace {
  const GSpace._();

  /// Horizontal page padding. Matches the mockup gutter.
  static const double gutter = 18;

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  /// Bottom bar. 62 to 68 to 78 to 88.
  ///
  /// Four tabs across a phone gives each cell about a quarter of the width, so
  /// the constraint was never horizontal. It was that a 21 dp glyph, a pill
  /// around it and a 10.5 dp label were being asked to share 68 dp with the
  /// system gesture inset underneath them, which left the label sitting on the
  /// bar's own edge.
  /// 100, up from 88.
  ///
  /// The bar is the only control on screen at every moment of the app's life,
  /// and on a 6.6 inch phone held one handed it is the furthest thing from the
  /// thumb's resting position. Height here buys target area where it is hardest
  /// to reach.
  ///
  /// The gesture inset is added UNDERNEATH this by the widget, so on a phone
  /// with a navigation bar the whole thing is taller again. That is correct: the
  /// inset is unusable space, not padding.
  static const double navHeight = 100;

  /// Nav cell internals. Lifted out of the widget so the bar can be retuned
  /// from one place.
  ///
  /// Scaled with the height rather than left behind. A 26 dp glyph in a 100 dp
  /// bar reads as a small icon adrift in a large space, which looks like a
  /// mistake even when the target is bigger.
  static const double navIcon = 28;
  static const double navPillWidth = 64;
  static const double navPillHeight = 38;
}

class GMotion {
  const GMotion._();

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 420);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
}

/// Type ramp. Colour is never baked in: callers apply a token colour with
/// copyWith so one style can serve both themes.
///
/// The mono styles set no fontFamily. They fall back to the platform monospace
/// face and enable tabular figures, which is what actually matters for numbers
/// that update live without the row jittering. Swap in JetBrains Mono (OFL,
/// licence-clean) by adding the family to the fallback list once the font ships
/// in assets.
class GType {
  const GType._();

  static const List<String> _monoStack = <String>[
    'JetBrains Mono',
    'Roboto Mono',
    'monospace',
  ];

  static const TextStyle display = TextStyle(
    fontSize: 31,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.7,
  );

  static const TextStyle title = TextStyle(
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );

  static const TextStyle heading = TextStyle(
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12.5,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle label = TextStyle(
    fontSize: 11.5,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle micro = TextStyle(
    fontSize: 10.5,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  /// Bottom bar label. Larger than [micro] because it is the only text in the
  /// app a user reads at arm's length while reaching with a thumb.
  static const TextStyle navLabel = TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle monoDisplay = TextStyle(
    fontSize: 34,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
    fontFamilyFallback: _monoStack,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  static const TextStyle monoNumber = TextStyle(
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w500,
    fontFamilyFallback: _monoStack,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  static const TextStyle monoSmall = TextStyle(
    fontSize: 10.5,
    height: 1.35,
    fontWeight: FontWeight.w400,
    fontFamilyFallback: _monoStack,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /// The uppercase section label from the mockup.
  static const TextStyle overline = TextStyle(
    fontSize: 9.5,
    height: 1.3,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.4,
    fontFamilyFallback: _monoStack,
  );

  static const TextStyle badge = TextStyle(
    fontSize: 9,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    fontFamilyFallback: _monoStack,
  );
}

/// Sugar so widgets read `context.g.accent` instead of a Theme.of lookup.
extension GThemeX on BuildContext {
  GTokens get g {
    final GTokens? tokens = Theme.of(this).extension<GTokens>();
    if (tokens == null) {
      throw StateError(
        'GTokens missing from the theme. Widgets must sit under GRecoveryApp.',
      );
    }
    return tokens;
  }
}
