import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging.dart';

/// Thin wrapper over SharedPreferences. JSON in, JSON out, no Drift.
///
/// Reads are synchronous because the instance is resolved once in bootstrap and
/// injected. That is what lets the theme paint correctly on the very first
/// frame with no flash of the wrong colours.
class PrefsStore {
  const PrefsStore(this._prefs);

  final SharedPreferences _prefs;

  String? readString(String key) => _prefs.getString(key);

  Future<void> writeString(String key, String value) =>
      _prefs.setString(key, value);

  bool readBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;

  Future<void> writeBool(String key, {required bool value}) =>
      _prefs.setBool(key, value);

  int readInt(String key, {int fallback = 0}) => _prefs.getInt(key) ?? fallback;

  Future<void> writeInt(String key, int value) => _prefs.setInt(key, value);

  /// Empty map when the key is absent or the blob is corrupt. A corrupt blob is
  /// logged and treated as absent, never thrown: losing a preference is
  /// recoverable, crashing on launch is not.
  Map<String, Object?> readJson(String key) {
    final String? raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return <String, Object?>{};
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) return decoded;
      GLog.w('prefs key $key held a ${decoded.runtimeType}', scope: 'prefs');
    } on FormatException catch (cause) {
      GLog.w('prefs key $key is not valid json', scope: 'prefs', cause: cause);
    }
    return <String, Object?>{};
  }

  Future<void> writeJson(String key, Map<String, Object?> value) =>
      _prefs.setString(key, jsonEncode(value));

  Future<void> remove(String key) => _prefs.remove(key);
}

/// Overridden in bootstrap. Reading it without the override is a programming
/// error, so it throws rather than handing back a silent no-op store.
final Provider<PrefsStore> prefsStoreProvider = Provider<PrefsStore>((Ref ref) {
  throw StateError('prefsStoreProvider was not overridden in bootstrap');
});
