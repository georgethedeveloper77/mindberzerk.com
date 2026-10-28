/// The one definition of "these two strings are the same search term".
///
/// Every search surface in the launcher (the search page, the drawer filter,
/// Library, Kickoff, rofi, the terminal palette, settings, the desklet picker
/// and the hidden-apps rule) folds text through here, so "G VPN", "gvpn",
/// "GVPN" and "g-vpn" are one term everywhere at once. Before this, each
/// surface lowercased on its own and none of them ignored spacing, so a query
/// typed without the space found nothing.
///
/// Three layers:
///  - [fold]    case and Latin diacritics folded, LENGTH-PRESERVING, so a
///              matcher can map hits back to indices in the original label
///              (the terminal paints matched characters).
///  - [compact] [fold] with every separator removed: spaces, punctuation,
///              dashes, underscores. This is what equality is judged on.
///  - [rank]    prefix, then word start, then anywhere, the order every
///              list-style surface already used.
abstract final class SearchText {
  /// Lowercase plus diacritic folding, one output unit per input unit.
  static String fold(String s) {
    if (s.isEmpty) return s;
    final out = List<int>.filled(s.length, 0);
    for (var i = 0; i < s.length; i++) {
      out[i] = foldUnit(s.codeUnitAt(i));
    }
    return String.fromCharCodes(out);
  }

  /// [fold] with separators dropped. "Pop!_OS" -> "popos", "G VPN" -> "gvpn".
  static String compact(String s) {
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final u = s.codeUnitAt(i);
      if (isSeparator(u)) continue;
      b.writeCharCode(foldUnit(u));
    }
    return b.toString();
  }

  /// Folds a single UTF-16 unit. Surrogates and anything unmapped pass
  /// through lowercased when that stays one unit, unchanged otherwise.
  static int foldUnit(int u) {
    // ASCII fast path: the overwhelmingly common case on every keystroke.
    if (u < 0x80) return (u >= 0x41 && u <= 0x5A) ? u + 0x20 : u;
    final mapped = _diacritics[u];
    if (mapped != null) return mapped;
    if (u >= 0xD800 && u <= 0xDFFF) return u;
    final lower = String.fromCharCode(u).toLowerCase();
    return lower.length == 1 ? lower.codeUnitAt(0) : u;
  }

  /// Spaces, ASCII punctuation and the common Unicode punctuation OEMs put in
  /// app names. Letters and digits of every script are kept.
  static bool isSeparator(int u) {
    if (u <= 0x20) return true;
    if (u < 0x80) {
      final isDigit = u >= 0x30 && u <= 0x39;
      final isLetter = (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A);
      return !isDigit && !isLetter;
    }
    return _unicodeSeparators.contains(u);
  }

  /// Whether [label] contains [query] once both are compacted. An empty
  /// query matches everything; a query of only separators matches nothing.
  static bool contains(String label, String query) {
    if (query.isEmpty) return true;
    final q = compact(query);
    if (q.isEmpty) return false;
    return compact(label).contains(q);
  }

  /// Whether any of [terms] matches [query] (settings keywords, aliases).
  static bool anyContains(Iterable<String> terms, String query) {
    if (query.isEmpty) return true;
    final q = compact(query);
    if (q.isEmpty) return false;
    for (final t in terms) {
      if (compact(t).contains(q)) return true;
    }
    return false;
  }

  /// Whole-name equality, the hidden-apps admission test.
  ///
  /// A label made only of separators (an emoji or "#") compacts to nothing;
  /// those fall back to trimmed [fold] equality so they stay reachable by
  /// their exact name and never match an empty query.
  static bool sameName(String label, String query) {
    final q = compact(query);
    final l = compact(label);
    if (l.isNotEmpty) return q == l;
    final t = fold(query.trim());
    return t.isNotEmpty && t == fold(label.trim());
  }

  /// 0 prefix, 1 a word inside the label starts with it, 2 anywhere, -1 none.
  static int rank(String label, String query) {
    final q = compact(query);
    if (q.isEmpty) return query.isEmpty ? 0 : -1;

    final starts = <int>[];
    final b = StringBuffer();
    var prevSep = true;
    var prevLower = false;
    for (var i = 0; i < label.length; i++) {
      final u = label.codeUnitAt(i);
      if (isSeparator(u)) {
        prevSep = true;
        prevLower = false;
        continue;
      }
      final isUpper = u >= 0x41 && u <= 0x5A;
      // A word starts after a separator or at a camel hump ("WhatsApp").
      if (prevSep || (isUpper && prevLower)) starts.add(b.length);
      b.writeCharCode(foldUnit(u));
      prevSep = false;
      prevLower = u >= 0x61 && u <= 0x7A;
    }
    final l = b.toString();

    if (l.startsWith(q)) return 0;
    var at = l.indexOf(q, 1);
    if (at < 0) return -1;
    final startSet = starts.toSet();
    while (at >= 0) {
      if (startSet.contains(at)) return 1;
      at = l.indexOf(q, at + 1);
    }
    return 2;
  }

  /// Latin letters with marks, folded to their base. Covers the launcher's
  /// purchasing markets first (es, pt-BR, fr, de, tr, pl).
  static final Map<int, int> _diacritics = _buildDiacritics();

  static Map<int, int> _buildDiacritics() {
    const groups = <String, String>{
      'a': 'àáâãäåāăąÀÁÂÃÄÅĀĂĄ',
      'c': 'çćčĉċÇĆČĈĊ',
      'd': 'ďđĎĐ',
      'e': 'èéêëēĕėęěÈÉÊËĒĔĖĘĚ',
      'g': 'ğĝġģĞĜĠĢ',
      'i': 'ìíîïīĭįıÌÍÎÏĪĬĮİ',
      'l': 'łľĺļŁĽĹĻ',
      'n': 'ñńňņÑŃŇŅ',
      'o': 'òóôõöøōŏőÒÓÔÕÖØŌŎŐ',
      'r': 'řŕŗŘŔŖ',
      's': 'śšşŝșßŚŠŞŜȘ',
      't': 'ťţțŤŢȚ',
      'u': 'ùúûüūŭůűųÙÚÛÜŪŬŮŰŲ',
      'y': 'ýÿŷÝŸŶ',
      'z': 'źżžŹŻŽ',
    };
    final map = <int, int>{};
    groups.forEach((base, chars) {
      final b = base.codeUnitAt(0);
      for (final u in chars.codeUnits) {
        map[u] = b;
      }
    });
    return map;
  }

  static const Set<int> _unicodeSeparators = {
    0x00A0, // no-break space
    0x00B7, // middle dot
    0x2010, 0x2011, 0x2012, 0x2013, 0x2014, 0x2015, // dashes
    0x2018, 0x2019, 0x201C, 0x201D, // curly quotes
    0x2022, 0x2026, 0x2027, // bullet, ellipsis, hyphenation point
    0x2122, 0x00AE, 0x00A9, // trademark, registered, copyright
    0x3000, 0x30FB, // ideographic space, katakana middle dot
    0xFF1A, 0xFF5C, 0xFF0D, // fullwidth colon, bar, hyphen
  };
}
