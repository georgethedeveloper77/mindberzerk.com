/// The families a user can choose from, and what the two special choices mean.
///
/// ─── THREE STATES, AND ONLY ONE OF THEM IS A FAMILY NAME ────────────────────
///
/// A stored override is a `String?` on [LauncherPrefs], and it carries three
/// meanings:
///
///   null                the distro's own font. Kali stays in Kali's face.
///   [systemChoice]      the platform typeface, whatever the phone is set to.
///   anything else       that family, fetched from the Play Services provider.
///
/// [systemChoice] is a real stored value rather than a second null, because
/// "follow the phone" and "follow the distro" are different answers and a single
/// null cannot hold both. It resolves to a null `fontFamily`, which is how
/// Flutter spells "use the platform default".
///
/// [systemMonoChoice] is NOT the same thing and the difference is load-bearing.
/// The platform default is proportional, and `terminal_screen.dart` derives the
/// PTY column count by measuring a run of glyphs in the mono family. A
/// proportional face there does not just look wrong: the column count goes out
/// too generous, the remote host formats for a width the screen does not have,
/// and its own output wraps mid-field. So the mono picker offers Android's
/// `monospace` alias instead, which the platform resolves to the device's own
/// fixed-advance face.
///
/// ─── VENDORED, NOT FETCHED ──────────────────────────────────────────────────
///
/// The list ships in the APK. It could have come down the CDN beside the pack
/// index, signed the same way, and that was considered and dropped: adding a
/// family is not urgent enough to be worth a second signed channel and a native
/// fetch path, and a curated eighty-five scrolls better than the full library.
/// Move it to the CDN the first time a family cannot wait for a release.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Families declared in `pubspec.yaml` and therefore present in the APK.
///
/// ─── WHY THIS LIST HAS TO EXIST ─────────────────────────────────────────────
///
/// Everything else a theme can name is fetched at runtime. These two are not,
/// and asking `google_fonts` for them is worse than pointless: `UbuntuMono` is
/// not a Google Fonts family at all (that one is spelled `Ubuntu Mono`), so the
/// request fails, and `Ubuntu` would fetch a second copy of a typeface already
/// sitting in the APK.
///
/// The launcher's default distro must also paint correctly on a first cold boot
/// with no network, which is exactly the case a fetch cannot serve.
const Set<String> bundledFamilies = <String>{'Ubuntu', 'UbuntuMono'};

/// Follow the phone's own typeface. See the note above on why this is not null.
const String systemChoice = 'system';

/// Follow the phone's own MONOSPACE typeface. `monospace` is an Android font
/// alias, not a family this app ships, and the platform resolves it.
const String systemMonoChoice = 'monospace';

/// True when [choice] names something the platform resolves rather than
/// something that has to be fetched and registered.
bool isPlatformChoice(String? choice) =>
    choice == systemChoice || choice == systemMonoChoice;

/// One family the picker can offer.
class FontEntry {
  const FontEntry({
    required this.family,
    required this.category,
    required this.licence,
  });

  final String family;

  /// `sans-serif`, `serif`, `display` or `monospace`. The mono picker filters on
  /// this, which is the only thing standing between a proportional face and the
  /// column-count bug described above.
  final String category;

  /// `ofl`, `apache` or `ufl`. Selects which text is registered with
  /// [LicenseRegistry] when this family is actually loaded; see `main.dart`.
  final String licence;

  bool get isMono => category == 'monospace';

  /// What the picker draws in this family.
  ///
  /// ─── THE SAMPLE BELONGS TO THE PICKER, NOT TO THE FAMILY ────────────────
  ///
  /// This took [mono] as a parameter after a first cut keyed it off the
  /// family's own category, which put the `0O1lI => != ===` strip on Anonymous
  /// Pro and Azeret Mono in the DISPLAY list, where it means nothing and is
  /// simply noise in a column of names.
  ///
  /// A monospace family appearing in the display picker is a perfectly ordinary
  /// choice: someone can want their app labels in a typewriter face. What they
  /// are deciding there is what the letters look like, and the name answers it.
  ///
  /// ─── WHY THE MONO SAMPLE IS LONGER ──────────────────────────────────────
  ///
  /// In the mono picker the name answers almost nothing. Someone choosing a
  /// terminal face is deciding two things that are invisible in the word
  /// itself: whether zero is distinguishable from capital O and one from lower
  /// case l, and whether the family ligates `=>` and `!=` into arrows. Fira Code
  /// and Fira Mono are the same typeface except for the ligatures, so without
  /// that strip the picker cannot tell them apart at all.
  String sampleFor({required bool mono}) =>
      mono ? '$family  0O1lI  => != ===' : family;

  static FontEntry fromJson(Map<String, dynamic> j) => FontEntry(
        family: (j['family'] as String?) ?? '',
        category: (j['category'] as String?) ?? 'sans-serif',
        licence: (j['licence'] as String?) ?? 'ofl',
      );
}

/// Loaded once and held, because the picker can be opened repeatedly and the
/// file does not change between openings.
class FontCatalogue {
  const FontCatalogue._(this.families);

  final List<FontEntry> families;

  static FontCatalogue? _cached;

  /// Every family, sorted as authored (alphabetical, done at generation time).
  static Future<FontCatalogue> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    try {
      final raw = await rootBundle.loadString('assets/fonts/catalogue.json');
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      final list = ((doc['families'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FontEntry.fromJson)
          .where((e) => e.family.isNotEmpty)
          .toList(growable: false);

      return _cached = FontCatalogue._(list);
    } catch (e) {
      // A missing or malformed catalogue means the picker offers the two
      // platform choices and nothing else, which is a thin picker rather than a
      // broken screen. NOT cached, so a transient read failure can recover.
      return const FontCatalogue._(<FontEntry>[]);
    }
  }

  /// Only the fixed-advance families. What the mono picker shows.
  List<FontEntry> get monospace =>
      families.where((e) => e.isMono).toList(growable: false);

  /// The licence id for [family], or null when it is not one of ours: a pack's
  /// own font, a platform choice, or a stale stored value from a catalogue that
  /// has since dropped it.
  String? licenceFor(String family) {
    for (final e in families) {
      if (e.family == family) return e.licence;
    }
    return null;
  }
}

/// What the settings rows watch.
///
/// A [FutureProvider] because a settings section builder returns widgets
/// synchronously and cannot await an asset read. It renders with an empty list
/// for the frame it takes to parse and rebuilds with the families, which nobody
/// sees and which is far simpler than making the whole section async.
final fontCatalogueProvider =
    FutureProvider<FontCatalogue>((ref) => FontCatalogue.load());
