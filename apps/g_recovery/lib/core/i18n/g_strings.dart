import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging.dart';
import '../prefs/prefs_store.dart';

/// EVERY WORD THE USER READS.
///
/// ─── THE ENGLISH IS THE KEY ──────────────────────────────────────────────────
///
/// `context.s('Nothing deleted here')` rather than
/// `context.s('empty.recovery.title')`.
///
/// With 467 strings across 56 files, a key scheme means inventing and
/// maintaining 467 names, and every call site becomes unreadable: a reviewer
/// looking at a screen would have to open a second file to find out what it
/// says. Worse, a wrong key silently renders a key, which is the failure mode
/// people ship to production.
///
/// With the English as the key, an app with no translation loaded is exactly
/// the app that exists today. There is no failure mode where a screen renders
/// blank or shows an identifier.
///
/// The cost is that editing English copy orphans that translation. That is the
/// right trade here: copy changes are reviewed, and an orphaned translation
/// falls back to correct English rather than to nothing. tool/i18n/translate.py
/// retires the orphan on its next run, so the cost is paid automatically.
///
/// ─── ENGLISH IS COMPILED IN, TRANSLATIONS ARE DOWNLOADED ─────────────────────
///
/// The English never comes from a pack, because a first run with no network
/// would then be an app with no words. Translations arrive as content, which is
/// how a language can ship without a release.
class GStrings {
  const GStrings({required this.locale, required this.table});

  /// English, with nothing to look up.
  const GStrings.english() : locale = 'en', table = const <String, String>{};

  final String locale;

  /// English source to translation. Empty for English itself.
  final Map<String, String> table;

  bool get isEnglish => locale == 'en';

  /// The translation, or the English that was passed in.
  ///
  /// Never returns null and never returns a key. A missing entry means the
  /// screen reads in English, which is a degraded experience rather than a
  /// broken one.
  String call(String english) => table[english] ?? english;

  /// With one placeholder substituted.
  ///
  /// The placeholder is `{}`, not a positional index, because a translator
  /// reordering `{0}` and `{1}` is a class of bug nobody catches until a user
  /// reports a sentence that reads backwards. One slot per string is a
  /// constraint worth keeping, and tool/i18n/extract.py rejects a second slot
  /// at build time because this substitutes only the first.
  String one(String english, Object value) =>
      call(english).replaceFirst('{}', '$value');
}

/// Every language the app can present.
///
/// The list is compiled in rather than discovered, because a picker has to name
/// the languages before their packs are downloaded, and a person choosing
/// Kiswahili should see it whether or not the phone has been online yet.
///
/// ─── THIS LIST IS THE BUILD INPUT ────────────────────────────────────────────
///
/// tool/i18n/translate.py reads these entries out of this file to decide what
/// to translate. Adding a language is one line here and one run of that script.
/// A code added here with no pack on disk falls back to English rather than
/// failing, so the two can never be out of step in a way a user would notice.
///
/// ─── ORDER ───────────────────────────────────────────────────────────────────
///
/// English first because it is the source and the fallback. Everything after it
/// is alphabetical by English name, which is the only ordering that stays
/// predictable across 24 scripts. Sorting by native name would scatter the
/// non Latin entries according to code point rather than anything a person
/// could scan.
class GLanguage {
  const GLanguage({
    required this.code,
    required this.englishName,
    required this.nativeName,
    this.rtl = false,
  });

  final String code;
  final String englishName;

  /// Shown in the picker in its own language. A person who cannot read the
  /// current language cannot find their own in a list written in it.
  final String nativeName;

  /// Right to left. Arabic and Urdu only, for now.
  ///
  /// Reading this is not enough on its own: the direction has to reach
  /// MaterialApp so that Directionality flips for every screen at once.
  final bool rtl;

  /// The flag, bundled rather than an emoji.
  ///
  /// Emoji flags come from the system emoji font, and on the budget devices
  /// this app is built for that font often has no flag glyphs, so a row renders
  /// as two boxed letters or an empty box. A bundled image renders the same on
  /// every phone. 72 by 48, which is 3x for the 24 by 16 the picker draws.
  ///
  /// The country behind each language is a choice, not a fact. Portuguese shows
  /// Brazil because that is where the install base is, and Hindi, Tamil and
  /// Telugu all show India because they genuinely share one. The flag is an
  /// anchor for the eye; the native name is what identifies the language.
  String get flag => 'assets/flags/$code.webp';

  static const List<GLanguage> all = <GLanguage>[
    GLanguage(code: 'en', englishName: 'English', nativeName: 'English'),
    GLanguage(code: 'am', englishName: 'Amharic', nativeName: 'አማርኛ'),
    GLanguage(
      code: 'ar',
      englishName: 'Arabic',
      nativeName: 'العربية',
      rtl: true,
    ),
    GLanguage(code: 'bn', englishName: 'Bengali', nativeName: 'বাংলা'),
    GLanguage(code: 'zh', englishName: 'Chinese', nativeName: '简体中文'),
    GLanguage(code: 'nl', englishName: 'Dutch', nativeName: 'Nederlands'),
    GLanguage(code: 'fil', englishName: 'Filipino', nativeName: 'Filipino'),
    GLanguage(code: 'fr', englishName: 'French', nativeName: 'Français'),
    GLanguage(code: 'de', englishName: 'German', nativeName: 'Deutsch'),
    GLanguage(code: 'ha', englishName: 'Hausa', nativeName: 'Hausa'),
    GLanguage(code: 'hi', englishName: 'Hindi', nativeName: 'हिन्दी'),
    GLanguage(
      code: 'id',
      englishName: 'Indonesian',
      nativeName: 'Bahasa Indonesia',
    ),
    GLanguage(code: 'it', englishName: 'Italian', nativeName: 'Italiano'),
    GLanguage(code: 'ko', englishName: 'Korean', nativeName: '한국어'),
    GLanguage(code: 'pl', englishName: 'Polish', nativeName: 'Polski'),
    GLanguage(code: 'pt', englishName: 'Portuguese', nativeName: 'Português'),
    GLanguage(code: 'ru', englishName: 'Russian', nativeName: 'Русский'),
    GLanguage(code: 'es', englishName: 'Spanish', nativeName: 'Español'),
    GLanguage(code: 'sw', englishName: 'Swahili', nativeName: 'Kiswahili'),
    GLanguage(code: 'ta', englishName: 'Tamil', nativeName: 'தமிழ்'),
    GLanguage(code: 'te', englishName: 'Telugu', nativeName: 'తెలుగు'),
    GLanguage(code: 'th', englishName: 'Thai', nativeName: 'ไทย'),
    GLanguage(code: 'tr', englishName: 'Turkish', nativeName: 'Türkçe'),
    GLanguage(code: 'ur', englishName: 'Urdu', nativeName: 'اردو', rtl: true),
    GLanguage(
      code: 'vi',
      englishName: 'Vietnamese',
      nativeName: 'Tiếng Việt',
    ),
  ];

  static GLanguage forCode(String code) =>
      all.firstWhere((GLanguage l) => l.code == code, orElse: () => all.first);

  /// The languages the phone itself is set to, in the order the system ranks
  /// them, and only the ones this app can actually present.
  ///
  /// Twenty five rows is long enough that the one a person wants may be well
  /// below the fold, and the phone already knows the answer.
  static List<GLanguage> suggested(List<Locale> systemLocales) {
    final List<GLanguage> found = <GLanguage>[];
    for (final Locale locale in systemLocales) {
      for (final GLanguage language in all) {
        if (language.code == locale.languageCode &&
            !found.any((GLanguage f) => f.code == language.code)) {
          found.add(language);
        }
      }
    }
    return found.take(3).toList();
  }
}

/// The chosen language code, remembered.
class GLocaleController extends Notifier<String> {
  /// Its own key, stored as JSON.
  ///
  /// readJson and writeJson are the pair this app already uses everywhere. A
  /// readString would be one line shorter and would mean adding a method to
  /// PrefsStore for a single caller.
  static const String _key = 'g.locale';

  @override
  String build() {
    final Map<String, Object?> stored = ref
        .watch(prefsStoreProvider)
        .readJson(_key);
    final Object? code = stored['code'];
    return code is String ? code : 'en';
  }

  Future<void> select(String code) async {
    state = code;
    await ref.read(prefsStoreProvider).writeJson(_key, <String, Object?>{
      'code': code,
    });
  }
}

final NotifierProvider<GLocaleController, String> gLocaleProvider =
    NotifierProvider<GLocaleController, String>(GLocaleController.new);

/// The reading direction of the chosen language.
///
/// Kept next to the locale so that MaterialApp has one thing to watch. Nothing
/// else in the app should test a language code against a list of its own.
final Provider<TextDirection> gDirectionProvider = Provider<TextDirection>((
  Ref ref,
) {
  final GLanguage language = GLanguage.forCode(ref.watch(gLocaleProvider));
  return language.rtl ? TextDirection.rtl : TextDirection.ltr;
});

/// The table for the chosen language.
///
/// Bundled assets for now. When the content pipeline carries these, the read
/// moves there and this provider is the only thing that changes: nothing at a
/// call site knows where the words came from.
final FutureProvider<GStrings> gStringsProvider = FutureProvider<GStrings>((
  Ref ref,
) async {
  final String code = ref.watch(gLocaleProvider);
  if (code == 'en') return const GStrings.english();

  try {
    final String raw = await rootBundle.loadString(
      'assets/content/strings-$code.json',
    );
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    final Map<String, dynamic> entries =
        json['strings'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return GStrings(
      locale: code,
      table: <String, String>{
        for (final MapEntry<String, dynamic> e in entries.entries)
          if (e.value is String && (e.value as String).isNotEmpty)
            e.key: e.value as String,
      },
    );
  } catch (error) {
    // A missing or broken pack falls back to English rather than failing.
    // Someone who picked Kiswahili and got English has a working app; someone
    // who got an exception has none.
    GLog.w('no strings for $code', scope: 'i18n', cause: '$error');
    return const GStrings.english();
  }
});

/// The lookup, without a provider read at every call site.
///
/// Held in an InheritedWidget so `context.s('...')` costs one lookup up the
/// tree rather than a Riverpod read, and so a language change rebuilds every
/// screen at once instead of screen by screen as each happens to rebuild.
class GStringsScope extends InheritedWidget {
  const GStringsScope({required this.strings, required super.child, super.key});

  final GStrings strings;

  static GStrings of(BuildContext context) {
    final GStringsScope? scope = context
        .dependOnInheritedWidgetOfExactType<GStringsScope>();
    return scope?.strings ?? const GStrings.english();
  }

  @override
  bool updateShouldNotify(GStringsScope oldWidget) =>
      oldWidget.strings.locale != strings.locale;
}

extension GStringsContext on BuildContext {
  /// The translation of [english], or [english] itself.
  String s(String english) => GStringsScope.of(this)(english);

  /// With one `{}` substituted.
  String s1(String english, Object value) =>
      GStringsScope.of(this).one(english, value);
}
