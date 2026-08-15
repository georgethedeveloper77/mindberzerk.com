/// Where a parsed colour meets a theme.
///
/// [AnsiParser] deliberately knows nothing about Flutter or about palettes: it
/// reports that a run wanted colour 4, or 38;5;208, or 38;2;255;0;0. This is
/// the only place that turns those into something paintable, and it is the
/// direction the dependency has to run: a feature may import the engine, the
/// engine may not import a feature.
///
/// ─── THE 256-COLOUR CUBE IS ARITHMETIC, NOT DESIGN ──────────────────────────
///
/// Slots 0 to 15 are the sixteen the theme authors, and they are the only ones
/// a distro gets to choose. 16 to 231 are a 6x6x6 cube and 232 to 255 a
/// greyscale ramp, both FIXED by xterm. A theme that could redefine them would
/// be redefining arithmetic, and any program using them expects the standard
/// values, so they are computed here and never authored.
library;

import 'dart:ui';

import '../../engine/terminal_spec.dart';
import 'ansi.dart';

/// The resolved appearance of a run, after inverse and the palette are applied.
class ResolvedAnsiStyle {
  const ResolvedAnsiStyle({
    required this.fg,
    required this.bg,
    required this.bold,
    required this.italic,
    required this.underline,
    required this.strike,
  });

  final Color fg;

  /// Null means "paint nothing", which is not the same as painting the
  /// background colour: the terminal runs over the theme's own surface, and
  /// filling every cell with an opaque background would flatten it.
  final Color? bg;

  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;

  @override
  bool operator ==(Object other) =>
      other is ResolvedAnsiStyle &&
      other.fg == fg &&
      other.bg == bg &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.strike == strike;

  @override
  int get hashCode => Object.hash(fg, bg, bold, italic, underline, strike);
}

extension AnsiPaletteResolution on TerminalPalette {
  /// One ANSI colour, resolved.
  ///
  /// [isBackground] decides only what "default" means, since the default
  /// foreground and the default background are different colours.
  Color resolveAnsi(AnsiColor c, {bool isBackground = false}) => switch (c) {
        AnsiDefaultColor() => isBackground ? bg : fg,
        AnsiRgbColor(:final r, :final g, :final b) =>
          Color.fromARGB(0xFF, r, g, b),
        AnsiIndexedColor(:final index) => _indexed(index),
      };

  Color _indexed(int i) {
    // The sixteen the theme owns.
    if (i >= 0 && i < 16) return i < ansi.length ? ansi[i] : fg;

    // The 6x6x6 cube. The levels are NOT evenly spaced: xterm uses 0 then 95
    // and 40 apart after that, and an even ramp gets the dark end visibly
    // wrong in exactly the region terminal colour schemes live in.
    if (i >= 16 && i <= 231) {
      const levels = [0, 95, 135, 175, 215, 255];
      final n = i - 16;
      return Color.fromARGB(
        0xFF,
        levels[n ~/ 36],
        levels[(n ~/ 6) % 6],
        levels[n % 6],
      );
    }

    // The greyscale ramp, 24 steps from near black to near white. Neither end
    // reaches the extreme, which is why this is not just i * 255 / 23.
    if (i >= 232 && i <= 255) {
      final v = 8 + (i - 232) * 10;
      return Color.fromARGB(0xFF, v, v, v);
    }

    // Out of range. The foreground is the safe answer: text stays readable,
    // which a fallback to the background would not manage.
    return fg;
  }

  /// A full style, resolved.
  ///
  /// INVERSE IS APPLIED HERE and not at parse, because a later `27` has to be
  /// able to undo it, which means the swap cannot be baked into the parsed
  /// style. When inverse is set and no explicit background was given, the
  /// background becomes the foreground colour and the text becomes the
  /// terminal's background, which is what makes a selected menu row in a
  /// remote program look selected.
  ///
  /// BOLD IS NOT BRIGHTENED. Historic terminals mapped bold onto the bright
  /// half of the palette, and a lot of software still assumes it. Doing that
  /// here means a theme's carefully chosen colour 1 never appears the moment
  /// any program emits bold red, which is most of them. Bold renders as weight,
  /// the palette stays the palette, and `90` to `97` remain the way to ask for
  /// bright.
  ResolvedAnsiStyle resolveStyle(AnsiStyle s) {
    var fgColor = resolveAnsi(s.fg);
    Color? bgColor =
        s.bg is AnsiDefaultColor ? null : resolveAnsi(s.bg, isBackground: true);

    if (s.inverse) {
      final newBg = fgColor;
      fgColor = bgColor ?? bg;
      bgColor = newBg;
    }

    // Faint is a real attribute with no colour of its own, so it is expressed
    // as transparency against whatever is behind the terminal.
    if (s.faint) fgColor = fgColor.withValues(alpha: 0.55);

    // Hidden keeps its cells and paints nothing, which is how a password echo
    // suppresses itself without the column count going wrong.
    if (s.hidden) fgColor = fgColor.withValues(alpha: 0.0);

    return ResolvedAnsiStyle(
      fg: fgColor,
      bg: bgColor,
      bold: s.bold,
      italic: s.italic,
      underline: s.underline,
      strike: s.strike,
    );
  }
}
