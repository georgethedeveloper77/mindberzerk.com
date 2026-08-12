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
/// falls back to correct English rather than to nothing.
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
  /// constraint worth keeping.
  String one(String english, Object value) =>
      call(english).replaceFirst('{}', '$value');
}

/// Every language the app can present.
///
/// The list is compiled in rather than discovered, because a picker has to name
/// the languages before their packs are downloaded, and a person choosing
/// Kiswahili should see it whether or not the phone has been online yet.
class GLanguage {
  const GLanguage({
    required this.code,
    required this.englishName,
    required this.nativeName,
  });

  final String code;
  final String englishName;

  /// Shown in the picker in its own language. A person who cannot read the
  /// current language cannot find their own in a list written in it.
  final String nativeName;

  static const List<GLanguage> all = <GLanguage>[
    GLanguage(code: 'en', englishName: 'English', nativeName: 'English'),
    GLanguage(code: 'sw', englishName: 'Swahili', nativeName: 'Kiswahili'),
    GLanguage(code: 'fr', englishName: 'French', nativeName: 'Francais'),
    GLanguage(code: 'pt', englishName: 'Portuguese', nativeName: 'Portugues'),
  ];

  static GLanguage forCode(String code) =>
      all.firstWhere((GLanguage l) => l.code == code, orElse: () => all.first);
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
