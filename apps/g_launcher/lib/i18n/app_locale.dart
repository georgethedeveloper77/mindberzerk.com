import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

/// One selectable UI language.
///
/// [nativeName] is what we SHOW the user. Ubuntu's installer lists every
/// language in its own script, and a speaker recognises their own name far
/// faster than the English one, so the scripts and diacritics are
/// load-bearing, not decoration. [englishName] is kept only for logs and
/// analytics where a stable ASCII label is wanted.
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

  /// The pref value AND the JSON asset filename, e.g. 'en' or 'zh_CN'.
  /// Underscore, not hyphen, so it doubles as a valid filename.
  String get code => locale.countryCode == null
      ? locale.languageCode
      : '${locale.languageCode}_${locale.countryCode}';

  @override
  bool operator ==(Object other) => other is AppLocale && other.locale == locale;

  @override
  int get hashCode => locale.hashCode;
}

/// The languages bundled in the APK.
///
/// KEEP IN STEP with `LANGUAGES` in tool/i18n_translate.py: add a language in
/// both places, run the translate script, done — the setup list scrolls, so
/// the count never changes the screen's shape. Each JSON is ~25KB, so the
/// whole set costs about a megabyte of APK.
///
/// Scripts the bundled Ubuntu typeface has no glyphs for (CJK, Indic, Arabic,
/// Amharic...) fall back to Android's system Noto fonts automatically; the
/// launcher chrome stays correct, just not in the distro typeface, which is
/// the right trade.
const List<AppLocale> kBundledLocales = [
  AppLocale(locale: Locale('en'), englishName: 'English', nativeName: 'English'),

  // Europe / Americas
  AppLocale(locale: Locale('es'), englishName: 'Spanish', nativeName: 'Español'),
  AppLocale(locale: Locale('fr'), englishName: 'French', nativeName: 'Français'),
  AppLocale(locale: Locale('pt'), englishName: 'Portuguese', nativeName: 'Português'),
  AppLocale(locale: Locale('de'), englishName: 'German', nativeName: 'Deutsch'),
  AppLocale(locale: Locale('it'), englishName: 'Italian', nativeName: 'Italiano'),
  AppLocale(locale: Locale('nl'), englishName: 'Dutch', nativeName: 'Nederlands'),
  AppLocale(locale: Locale('pl'), englishName: 'Polish', nativeName: 'Polski'),
  AppLocale(locale: Locale('tr'), englishName: 'Turkish', nativeName: 'Türkçe'),
  AppLocale(locale: Locale('ru'), englishName: 'Russian', nativeName: 'Русский'),
  AppLocale(locale: Locale('uk'), englishName: 'Ukrainian', nativeName: 'Українська'),
  AppLocale(locale: Locale('ro'), englishName: 'Romanian', nativeName: 'Română'),
  AppLocale(locale: Locale('cs'), englishName: 'Czech', nativeName: 'Čeština'),
  AppLocale(locale: Locale('el'), englishName: 'Greek', nativeName: 'Ελληνικά'),
  AppLocale(locale: Locale('hu'), englishName: 'Hungarian', nativeName: 'Magyar'),
  AppLocale(locale: Locale('sv'), englishName: 'Swedish', nativeName: 'Svenska'),
  AppLocale(locale: Locale('da'), englishName: 'Danish', nativeName: 'Dansk'),
  AppLocale(locale: Locale('fi'), englishName: 'Finnish', nativeName: 'Suomi'),
  AppLocale(locale: Locale('no'), englishName: 'Norwegian', nativeName: 'Norsk'),

  // Asia-Pacific
  AppLocale(locale: Locale('id'), englishName: 'Indonesian', nativeName: 'Bahasa Indonesia'),
  AppLocale(locale: Locale('ms'), englishName: 'Malay', nativeName: 'Bahasa Melayu'),
  AppLocale(locale: Locale('vi'), englishName: 'Vietnamese', nativeName: 'Tiếng Việt'),
  AppLocale(locale: Locale('th'), englishName: 'Thai', nativeName: 'ไทย'),
  AppLocale(locale: Locale('tl'), englishName: 'Filipino', nativeName: 'Filipino'),
  AppLocale(locale: Locale('ja'), englishName: 'Japanese', nativeName: '日本語'),
  AppLocale(locale: Locale('ko'), englishName: 'Korean', nativeName: '한국어'),
  AppLocale(locale: Locale('zh', 'CN'), englishName: 'Chinese (Simplified)', nativeName: '简体中文'),
  AppLocale(locale: Locale('zh', 'TW'), englishName: 'Chinese (Traditional)', nativeName: '繁體中文'),

  // South Asia
  AppLocale(locale: Locale('hi'), englishName: 'Hindi', nativeName: 'हिन्दी'),
  AppLocale(locale: Locale('bn'), englishName: 'Bengali', nativeName: 'বাংলা'),
  AppLocale(locale: Locale('ur'), englishName: 'Urdu', nativeName: 'اردو'),
  AppLocale(locale: Locale('ta'), englishName: 'Tamil', nativeName: 'தமிழ்'),
  AppLocale(locale: Locale('te'), englishName: 'Telugu', nativeName: 'తెలుగు'),
  AppLocale(locale: Locale('ml'), englishName: 'Malayalam', nativeName: 'മലയാളം'),
  AppLocale(locale: Locale('mr'), englishName: 'Marathi', nativeName: 'मराठी'),
  AppLocale(locale: Locale('gu'), englishName: 'Gujarati', nativeName: 'ગુજરાતી'),
  AppLocale(locale: Locale('pa'), englishName: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ'),

  // Middle East
  AppLocale(locale: Locale('ar'), englishName: 'Arabic', nativeName: 'العربية'),
  AppLocale(locale: Locale('fa'), englishName: 'Persian', nativeName: 'فارسی'),
  AppLocale(locale: Locale('he'), englishName: 'Hebrew', nativeName: 'עברית'),

  // Africa
  AppLocale(locale: Locale('sw'), englishName: 'Swahili', nativeName: 'Kiswahili'),
  AppLocale(locale: Locale('am'), englishName: 'Amharic', nativeName: 'አማርኛ'),
  AppLocale(locale: Locale('ha'), englishName: 'Hausa', nativeName: 'Hausa'),
  AppLocale(locale: Locale('yo'), englishName: 'Yoruba', nativeName: 'Yorùbá'),
  AppLocale(locale: Locale('ig'), englishName: 'Igbo', nativeName: 'Igbo'),
  AppLocale(locale: Locale('zu'), englishName: 'Zulu', nativeName: 'isiZulu'),
  AppLocale(locale: Locale('af'), englishName: 'Afrikaans', nativeName: 'Afrikaans'),
];

/// Bundled locales sorted by native name for display, the way Ubuntu's
/// installer reads. Sorted at call sites, not stored: the sort key is
/// display-only.
List<AppLocale> localesForDisplay() {
  final list = [...kBundledLocales];
  list.sort((a, b) => a.nativeName.toLowerCase().compareTo(b.nativeName.toLowerCase()));
  return list;
}

/// 'zh_CN' -> Locale('zh','CN'), 'en' -> Locale('en').
Locale codeToLocale(String code) {
  final parts = code.split('_');
  return parts.length == 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
}

/// Best bundled match for the device language, falling back to English.
/// Language-code match first (en_GB gets 'en'); for Chinese the country code
/// decides between the two scripts, defaulting to simplified.
String systemMatchCode(Locale device) {
  if (device.languageCode == 'zh') {
    return device.countryCode == 'TW' || device.countryCode == 'HK'
        ? 'zh_TW'
        : 'zh_CN';
  }
  final hit = kBundledLocales
      .firstWhereOrNull((l) => l.locale.languageCode == device.languageCode);
  return hit?.code ?? 'en';
}

AppLocale? localeForCode(String? code) =>
    code == null ? null : kBundledLocales.firstWhereOrNull((l) => l.code == code);
