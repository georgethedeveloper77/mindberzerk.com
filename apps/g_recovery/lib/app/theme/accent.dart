import 'dart:ui' show Color;

/// The six user selectable accents.
///
/// [base] is used as-is in dark mode. [onLight] is a darkened variant used
/// wherever the accent has to sit as text or a small glyph on a light surface,
/// because the base tones are all too light to pass contrast there.
///
/// [ink] is the foreground colour for text sitting ON the accent (a filled
/// button, for example). All six bases are light enough that one dark ink works
/// for every accent, which keeps the token count down.
enum GAccent {
  amber(
    id: 'amber',
    label: 'Amber',
    base: Color(0xFFF2A93B),
    onLight: Color(0xFFC9832A),
  ),
  mint(
    id: 'mint',
    label: 'Mint',
    base: Color(0xFF5FD6A6),
    onLight: Color(0xFF2E9C71),
  ),
  cyan(
    id: 'cyan',
    label: 'Cyan',
    base: Color(0xFF4FC3DC),
    onLight: Color(0xFF2C9BB5),
  ),
  violet(
    id: 'violet',
    label: 'Violet',
    base: Color(0xFFA08CE8),
    onLight: Color(0xFF7B63D6),
  ),
  coral(
    id: 'coral',
    label: 'Coral',
    base: Color(0xFFF0705F),
    onLight: Color(0xFFD14E3C),
  ),
  blue(
    id: 'blue',
    label: 'Blue',
    base: Color(0xFF5B8DEF),
    onLight: Color(0xFF3D6FD1),
  );

  const GAccent({
    required this.id,
    required this.label,
    required this.base,
    required this.onLight,
  });

  /// Persisted string. Never persist the enum index: reordering the enum would
  /// silently reassign every user's accent.
  final String id;

  final String label;
  final Color base;
  final Color onLight;

  static const Color ink = Color(0xFF12181E);

  static const GAccent fallback = GAccent.amber;

  static GAccent fromId(String? id) {
    for (final GAccent accent in GAccent.values) {
      if (accent.id == id) return accent;
    }
    return fallback;
  }
}
