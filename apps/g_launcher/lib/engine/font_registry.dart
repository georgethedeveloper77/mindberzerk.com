import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'theme_spec.dart';

/// Registers a theme's own font families with Flutter at runtime.
///
/// ─── WHY THIS EXISTS ────────────────────────────────────────────────────────
///
/// A family name in `theme.json` only resolves if that family is declared in
/// pubspec.yaml. The three bundled faces are; a distro downloaded from the CDN
/// after the APK shipped can never be, because a pack cannot edit pubspec.
///
/// [FontLoader] is the only route from bytes to a resolvable family name, so a
/// pack carries its `.ttf` files and this hands them over. After that, every
/// existing `fontFamily: theme.typography.display` works unchanged, which is
/// the point: nothing downstream learns that some families arrived late.
///
/// ─── LOADED ONCE, PER FAMILY AND SOURCE ─────────────────────────────────────
///
/// `FontLoader.load()` registers globally and has no unregister. Calling it
/// twice for one family stacks a second copy of every glyph for the life of the
/// process, and the theme resolve runs on every prefs write, so "twice" would
/// really mean "hundreds of times in an afternoon".
///
/// The key includes the SOURCE directory, not just the family: two distros may
/// both ship "Fira Sans" from different packs, and the first one loaded should
/// not silently answer for the second.
///
/// ─── FAILURE IS SILENT AND THAT IS DELIBERATE ───────────────────────────────
///
/// A missing or corrupt font file means the text falls back to the platform
/// face, which is ugly and legible. Throwing here would take the whole theme
/// resolve down and leave the user on a black screen because a distro shipped a
/// bad file, and a launcher that cannot start is worse than one in the wrong
/// typeface.
class FontRegistry {
  const FontRegistry._();

  /// Families already handed to Flutter, keyed by source and family.
  static final Set<String> _loaded = <String>{};

  /// Register everything [spec] ships, if it has not been done already.
  ///
  /// Awaited by the theme resolve BEFORE the theme is published, so the first
  /// frame is already in the right face. Registering after paint is legal and
  /// looks like a flash of the wrong font on every cold start.
  static Future<void> ensure(ThemeSpec spec) async {
    if (spec.fonts.isEmpty) return;

    for (final font in spec.fonts) {
      final key = '${spec.source.dir ?? 'bundled'}|${font.family}';
      if (_loaded.contains(key)) continue;

      // Marked BEFORE the await, not after. Two resolves can overlap, and the
      // second must not start a duplicate load while the first is still
      // reading bytes off disk.
      _loaded.add(key);

      try {
        final loader = FontLoader(font.family);
        var added = 0;

        for (final file in font.files) {
          final asset = spec.asset(file);
          final bytes = asset.isFile
              ? await File(asset.path).readAsBytes()
              : (await rootBundle.load(asset.path)).buffer.asUint8List();

          if (bytes.isEmpty) continue;
          loader.addFont(Future.value(ByteData.view(bytes.buffer)));
          added++;
        }

        // Nothing readable. `load()` on an empty loader is not an error and
        // registers a family with no glyphs, which renders as blank text
        // rather than as a fallback: worse than not registering at all.
        if (added == 0) {
          _loaded.remove(key);
          continue;
        }

        await loader.load();
      } catch (e) {
        // Let it be tried again on a later resolve: a pack still being written
        // to disk is a real case, and one bad read should not condemn the
        // family for the life of the process.
        _loaded.remove(key);
        debugPrint('FontRegistry: ${font.family} did not load: $e');
      }
    }
  }
}
