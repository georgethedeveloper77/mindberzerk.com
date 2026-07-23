import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// An immutable snapshot of one language's strings.
///
/// English is always carried alongside as the guaranteed fallback, mirroring
/// how EffectiveTheme keeps Ubuntu as the fallback theme: a missing key never
/// throws and never renders blank.
@immutable
class Translations {
  const Translations._(this.code, this._strings, this._fallback);

  /// The active language code these strings belong to ('en', 'es', ...).
  final String code;
  final Map<String, String> _strings;
  final Map<String, String> _fallback; // always English

  static const String _fallbackCode = 'en';

  /// A do-nothing snapshot used before the real language is loaded (and in
  /// tests). Every key resolves to itself, so nothing crashes if this is
  /// somehow rendered before bootstrap swaps in the loaded strings.
  factory Translations.empty([String code = _fallbackCode]) =>
      Translations._(code, const {}, const {});

  /// Loads `<code>.json` plus `en.json` (the latter is skipped when code is
  /// already 'en'). Never throws: a missing or malformed file yields an empty
  /// map, so its keys simply fall through to English, then to the key itself.
  static Future<Translations> load(String code) async {
    final fallback = await _readMap(_fallbackCode);
    final strings = code == _fallbackCode ? fallback : await _readMap(code);
    return Translations._(code, strings, fallback);
  }

  static Future<Map<String, String>> _readMap(String code) async {
    try {
      final raw = await rootBundle.loadString('assets/i18n/$code.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      // Values are coerced to String so a stray number in the JSON does not
      // blow up at read time.
      return decoded.map((k, v) => MapEntry(k, '$v'));
    } catch (_) {
      return const {};
    }
  }

  /// Resolve [key] for the active language.
  ///
  /// Order: active language, then English, then the key text itself. Optional
  /// [vars] fills `{name}` placeholders, e.g.
  ///   t('setup.homeRole.attempt', {'n': '2'})  with  "Attempt {n} of 3".
  String t(String key, [Map<String, String>? vars]) {
    final raw = _strings[key] ?? _fallback[key] ?? key;
    if (vars == null || vars.isEmpty) return raw;
    var out = raw;
    vars.forEach((name, value) => out = out.replaceAll('{$name}', value));
    return out;
  }
}
