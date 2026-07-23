import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

/// One selectable UI language.
///
/// [nativeName] is what we SHOW the user. Ubuntu's installer lists every
/// language in its own script ("Español", "Français", "हिन्दी"), and a speaker
/// of a language recognises their own name far faster than the English one, so
/// the diacritics are load-bearing, not decoration. [englishName] is kept only
/// for logs / analytics where we want a stable ASCII label.
@immutable
class AppLocale {
  const AppLocale({
    required this.locale,
    required this.englishName,
    required this.nativeName,
  });

  final Locale locale;
  final String englishName;
  final String nativeName;

  /// The pref value AND the JSON asset filename, e.g. 'en' or 'pt_BR'.
  /// Kept flat (underscore, not hyphen) so it doubles as a valid filename.
  String get code => locale.countryCode == null
      ? locale.languageCode
      : '${locale.languageCode}_${locale.countryCode}';

  @override
  bool operator ==(Object other) => other is AppLocale && other.locale == locale;

  @override
  int get hashCode => locale.hashCode;
}

/// The languages bundled in the APK today.
///
/// Adding a language is three steps and no code:
///   1. add an entry here,
///   2. drop `assets/i18n/<code>.json` (start by copying en.json),
///   3. it is already covered by the `assets/i18n/` folder in pubspec.
///
/// Later, CDN-delivered languages can be merged on top of this list the same
/// way distro packs are merged on top of the bundled themes.
const List<AppLocale> kBundledLocales = [
  AppLocale(locale: Locale('en'), englishName: 'English', nativeName: 'English'),
  AppLocale(locale: Locale('es'), englishName: 'Spanish', nativeName: 'Español'),
  AppLocale(locale: Locale('fr'), englishName: 'French', nativeName: 'Français'),
  AppLocale(locale: Locale('pt'), englishName: 'Portuguese', nativeName: 'Português'),
  AppLocale(locale: Locale('sw'), englishName: 'Swahili', nativeName: 'Kiswahili'),
  AppLocale(locale: Locale('hi'), englishName: 'Hindi', nativeName: 'हिन्दी'),
  AppLocale(locale: Locale('ar'), englishName: 'Arabic', nativeName: 'العربية'),
];

/// Bundled locales sorted by their native name, so the setup list reads like
/// Ubuntu's installer. Sorted at call sites, not stored, because the sort key
/// is display-only.
List<AppLocale> localesForDisplay() {
  final list = [...kBundledLocales];
  list.sort((a, b) => a.nativeName.toLowerCase().compareTo(b.nativeName.toLowerCase()));
  return list;
}

/// 'pt_BR' -> Locale('pt','BR'), 'en' -> Locale('en').
Locale codeToLocale(String code) {
  final parts = code.split('_');
  return parts.length == 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
}

/// Best bundled match for the device language, falling back to English.
/// Matches on languageCode only (a device set to en_GB still gets our 'en').
String systemMatchCode(Locale device) {
  final hit = kBundledLocales
      .firstWhereOrNull((l) => l.locale.languageCode == device.languageCode);
  return hit?.code ?? 'en';
}

AppLocale? localeForCode(String? code) =>
    code == null ? null : kBundledLocales.firstWhereOrNull((l) => l.code == code);
