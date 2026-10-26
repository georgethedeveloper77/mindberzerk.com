import 'package:flutter/material.dart';

/// MERIDIAN, the G VPN design language.
///
/// One layout, two moods: light mode is "Soft" (airy, rounded, the logo blue
/// on white) and dark mode is "Bento" (near-black cards, the same blue as the
/// single accent). The story every screen tells is exposed versus protected:
/// red and restless while traffic is readable, green and calm once it is
/// inside the tunnel. The globe and the waves exist to make that visible.
///
/// Read colours ONLY through `context.mer`, never as literals in widgets, so
/// both modes stay in step from one place.
@immutable
class Meridian extends ThemeExtension<Meridian> {
  const Meridian({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.text,
    required this.muted,
    required this.line,
    required this.dot,
    required this.globe,
    required this.brand,
    required this.brandSoft,
    required this.onBrand,
    required this.good,
    required this.goodWave,
    required this.bad,
    required this.badSoft,
    required this.warn,
    required this.warnSoft,
    required this.buttonOff,
    required this.buttonOn,
    required this.onButtonOn,
    required this.shadow,
    required this.globeShade,
    required this.violet,
    required this.teal,
    required this.pink,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color text;
  final Color muted;
  final Color line;

  /// World-map dots and the globe they sit on.
  final Color dot;
  final Color globe;

  final Color brand;
  final Color brandSoft;
  final Color onBrand;

  /// Protected. `goodWave` is the brighter tone for strokes; `good` is the
  /// one that passes contrast as text.
  final Color good;
  final Color goodWave;

  /// Exposed.
  final Color bad;
  final Color badSoft;

  /// Connecting, and anything that needs a look but is not dangerous.
  final Color warn;
  final Color warnSoft;

  final Color buttonOff;
  final Color buttonOn;
  final Color onButtonOn;
  final Color shadow;

  /// The rim shading that turns a flat panning map into a globe.
  final Color globeShade;

  /// Extra accents for things the user tells apart by colour (presets).
  /// Never used to mean protected or exposed.
  final Color violet;
  final Color teal;
  final Color pink;

  static const soft = Meridian(
    bg: Color(0xFFF3F5FA),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEEF1F7),
    text: Color(0xFF0F172A),
    muted: Color(0xFF5B6478),
    line: Color(0xFFE3E7EF),
    dot: Color(0xFFAFC0E6),
    globe: Color(0xFFE7EDFB),
    brand: Color(0xFF2457F5),
    brandSoft: Color(0xFFE8EDFE),
    onBrand: Color(0xFFFFFFFF),
    good: Color(0xFF0E7C3F),
    goodWave: Color(0xFF12A150),
    bad: Color(0xFFC8232F),
    badSoft: Color(0xFFFDECEE),
    warn: Color(0xFFB76E00),
    warnSoft: Color(0xFFFFF4E0),
    buttonOff: Color(0xFFFFFFFF),
    buttonOn: Color(0xFF0E7C3F),
    onButtonOn: Color(0xFFFFFFFF),
    shadow: Color(0x2E0F172A),
    globeShade: Color(0xD9F3F5FA),
    violet: Color(0xFF7A3FD1),
    teal: Color(0xFF0B7F86),
    pink: Color(0xFFC0306B),
  );

  static const bento = Meridian(
    bg: Color(0xFF0A0B0F),
    surface: Color(0xFF10131B),
    surface2: Color(0xFF151925),
    text: Color(0xFFF2F4F8),
    muted: Color(0xFF9AA1B2),
    line: Color(0xFF1F2230),
    dot: Color(0xFF3A5BB0),
    globe: Color(0xFF0E1530),
    brand: Color(0xFF3D7BFF),
    brandSoft: Color(0x243D7BFF),
    onBrand: Color(0xFFFFFFFF),
    good: Color(0xFF34D399),
    goodWave: Color(0xFF34D399),
    bad: Color(0xFFF87171),
    badSoft: Color(0x1FF87171),
    warn: Color(0xFFFBBF24),
    warnSoft: Color(0x1FFBBF24),
    buttonOff: Color(0xFF151925),
    buttonOn: Color(0xFF34D399),
    onButtonOn: Color(0xFF04140D),
    shadow: Color(0x99000000),
    globeShade: Color(0xE60A0B0F),
    violet: Color(0xFFB794F6),
    teal: Color(0xFF2DD4BF),
    pink: Color(0xFFF472B6),
  );

  /// Corner radii: cards, tiles, pills. Generous everywhere, per Soft.
  static const rCard = 22.0;
  static const rTile = 18.0;
  static const rChip = 12.0;

  static const sans = 'PlusJakartaSans';
  static const mono = 'GeistMono';

  /// Numbers that change while you watch (timer, IP, speeds) use the mono
  /// face so digits do not jitter as they tick.
  TextStyle monoStyle({double size = 14, FontWeight weight = FontWeight.w500, Color? color}) =>
      TextStyle(fontFamily: mono, fontSize: size, fontWeight: weight, color: color ?? text);

  @override
  Meridian copyWith() => this;

  @override
  Meridian lerp(Meridian? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return Meridian(
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surface2: c(surface2, other.surface2),
      text: c(text, other.text),
      muted: c(muted, other.muted),
      line: c(line, other.line),
      dot: c(dot, other.dot),
      globe: c(globe, other.globe),
      brand: c(brand, other.brand),
      brandSoft: c(brandSoft, other.brandSoft),
      onBrand: c(onBrand, other.onBrand),
      good: c(good, other.good),
      goodWave: c(goodWave, other.goodWave),
      bad: c(bad, other.bad),
      badSoft: c(badSoft, other.badSoft),
      warn: c(warn, other.warn),
      warnSoft: c(warnSoft, other.warnSoft),
      buttonOff: c(buttonOff, other.buttonOff),
      buttonOn: c(buttonOn, other.buttonOn),
      onButtonOn: c(onButtonOn, other.onButtonOn),
      shadow: c(shadow, other.shadow),
      globeShade: c(globeShade, other.globeShade),
      violet: c(violet, other.violet),
      teal: c(teal, other.teal),
      pink: c(pink, other.pink),
    );
  }
}

extension MeridianContext on BuildContext {
  Meridian get mer => Theme.of(this).extension<Meridian>()!;
}

ThemeData meridianTheme(Brightness brightness) {
  final m = brightness == Brightness.light ? Meridian.soft : Meridian.bento;
  final base = ThemeData(brightness: brightness, useMaterial3: true, fontFamily: Meridian.sans);
  return base.copyWith(
    scaffoldBackgroundColor: m.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: m.brand,
      brightness: brightness,
      primary: m.brand,
      onPrimary: m.onBrand,
      surface: m.surface,
      onSurface: m.text,
      error: m.bad,
    ),
    textTheme: base.textTheme.apply(bodyColor: m.text, displayColor: m.text),
    appBarTheme: AppBarTheme(
      backgroundColor: m.bg,
      foregroundColor: m.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: Meridian.sans,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -.4,
        color: m.text,
      ),
    ),
    cardTheme: CardThemeData(
      color: m.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Meridian.rCard),
        side: BorderSide(color: m.line),
      ),
    ),
    dividerTheme: DividerThemeData(color: m.line, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: m.brand,
        foregroundColor: m.onBrand,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: Meridian.sans, fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: m.surface,
      indicatorColor: m.brandSoft,
      height: 72,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? m.brand : m.muted),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: Meridian.sans,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: s.contains(WidgetState.selected) ? m.text : m.muted,
        ),
      ),
    ),
    extensions: [m],
  );
}
