import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'font_catalogue.dart';
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

        // Recorded in the SAME map the fetched families use, so one lookup
        // answers for all of them and a miss genuinely means "not registered".
        // A pack font is registered under exactly the name it declares, so it
        // maps to itself; only google_fonts renames.
        _overrides[font.family] = font.family;
      } catch (e) {
        // Let it be tried again on a later resolve: a pack still being written
        // to disk is a real case, and one bad read should not condemn the
        // family for the life of the process.
        _loaded.remove(key);
        debugPrint('FontRegistry: ${font.family} did not load: $e');
      }
    }
  }

  // ─── THE USER'S OWN CHOICE ────────────────────────────────────────────────
  //
  // Everything above serves a family a DISTRO ships, which arrives as bytes in a
  // pack and is registered from disk. This half serves one the USER picked in
  // Settings, which is a Google Fonts family that no theme.json has heard of and
  // that nothing on the device has yet.
  //
  // `google_fonts` owns that fetch: HTTP to fonts.gstatic.com, cached to the
  // app's support directory, one line to ask for. It does its own `FontLoader`
  // registration internally, so there is no second copy of the logic above.
  //
  // THE FAMILY NAME IT REGISTERS UNDER IS NOT NECESSARILY THE ONE ASKED FOR.
  // That is the whole reason this indirection exists: `EffectiveTheme.typography`
  // hands a plain string to `fontFamily`, and a string the package did not
  // register resolves to nothing and silently paints Roboto. So the resolved name
  // is taken off the TextStyle the package hands back and kept here.

  /// Requested family -> the family name Flutter can actually resolve.
  ///
  /// Holds BOTH pack-shipped families, which map to themselves, and families
  /// fetched by `google_fonts`, which do not: the package registers under a name
  /// of its own choosing. One map for both so that an absent key means exactly
  /// one thing, "nothing has registered this", which is what lets the caller
  /// fall back rather than hand `fontFamily` a name that resolves to nothing.
  static final Map<String, String> _overrides = <String, String>{};

  /// What [choice] should be handed to `fontFamily` as, or null if nothing has
  /// registered it: still fetching, fetch failed, or a name no one ships.
  ///
  /// Null is not an error and the caller must NOT treat it as one: it means the
  /// fetch has not finished, and the right thing to paint until it does is the
  /// distro's own face rather than the platform fallback.
  static String? resolvedFamily(String choice) => _overrides[choice];

  /// Fetch and register a user-chosen family.
  ///
  /// Awaited by `effectiveThemeProvider` before the theme is published, which
  /// matters more than it looks. `terminal_screen.dart` derives the PTY column
  /// count by measuring a run of glyphs in the mono family and sends that number
  /// to the remote host. Publish a theme naming a family whose bytes have not
  /// arrived and the first layout measures a fallback, the count comes out too
  /// generous, and the host formats for a width the screen does not have. That
  /// has been seen on device; see the comment above the probe.
  ///
  /// Silent on failure, like everything else here. No network on a cold boot is
  /// the ordinary case, not an exceptional one, and the cost of it is that the
  /// launcher comes up in the distro's font.
  static Future<void> ensureFamily(String? choice) async {
    if (choice == null || choice.isEmpty) return;

    // Both platform choices are resolved by Android itself and have nothing to
    // fetch: `systemChoice` becomes a null fontFamily, `systemMonoChoice` is an
    // Android family alias.
    if (isPlatformChoice(choice)) return;

    // Already in the APK. Asking google_fonts for `UbuntuMono` fails outright,
    // because that family is spelled `Ubuntu Mono` there and is a different
    // file; asking for `Ubuntu` would fetch a second copy of something already
    // shipped. Either way it would put a network round trip in front of the
    // default distro's first cold boot.
    if (bundledFamilies.contains(choice)) return;

    if (_overrides.containsKey(choice)) return;

    try {
      // Returns synchronously with a fallback style and starts the fetch.
      final style = GoogleFonts.getFont(choice);

      // Without this the first frame paints before the bytes land. The package
      // relayouts when they do, so the text corrects itself either way, but the
      // terminal's column count is computed ONCE from that first layout and does
      // not.
      await GoogleFonts.pendingFonts();

      final family = style.fontFamily;
      if (family != null && family.isNotEmpty) {
        _overrides[choice] = family;
      }
    } catch (e) {
      // A family the package's manifest does not carry, or no network. Left out
      // of the map so a later resolve tries again.
      debugPrint('FontRegistry: override $choice did not load: $e');
    }
  }

  /// Bring in whatever a THEME names, when the pack did not ship it.
  ///
  /// ─── THE HALF THAT WAS MISSING ────────────────────────────────────────────
  ///
  /// `ensure` above registers the faces a pack CARRIES. `ensureFamily` fetches
  /// the one a USER picked. Between them sat the case the admin panel actually
  /// produces: a distro that simply NAMES a family, shipping no files and
  /// leaving the user's choice untouched.
  ///
  /// Until this existed, `spec.typography.display` went straight to
  /// `fontFamily`, nothing had registered it, and the text silently rendered in
  /// the platform default. A Kali theme set to Fira Code validated in the
  /// panel, signed, published, downloaded, and came up in Roboto with no error
  /// anywhere in the chain.
  ///
  /// ─── WHAT IS DELIBERATELY SKIPPED ─────────────────────────────────────────
  ///
  /// Bundled families, handled in `ensureFamily`. And any family the pack ships
  /// itself: `ensure` has already registered those from disk under their own
  /// names, and fetching a same-named family from Google Fonts would replace a
  /// face the author chose with a different cut of it.
  ///
  /// ─── OFFLINE ──────────────────────────────────────────────────────────────
  ///
  /// A pack installed and then used offline before the font arrives renders in
  /// the platform default until the first successful fetch, after which it is
  /// cached. That window is narrow, since the pack itself came over the network
  /// minutes earlier. A distro that cannot tolerate it should SHIP its font
  /// instead, which is what the `fonts` block is for and why this skips those.
  static Future<void> ensureSpecFonts(ThemeSpec spec) async {
    final shipped = spec.fonts.map((f) => f.family).toSet();

    // Plain collection-if rather than the null-aware element form: this app's
    // SDK constraint is ^3.6.0 and `?expr` inside a collection needs 3.8.
    final display = spec.typography.display;
    final mono = spec.typography.mono;

    final wanted = <String>{
      if (display != null) display,
      if (mono != null) mono,
    }..removeWhere((f) => f.isEmpty || shipped.contains(f));

    if (wanted.isEmpty) return;

    await Future.wait(wanted.map(ensureFamily));
  }
}
