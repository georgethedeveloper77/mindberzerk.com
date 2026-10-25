import 'package:shared_preferences/shared_preferences.dart';

import 'vpn_api.g.dart';

/// Stored secrets (WireGuard private keys, server configs, the G Servers
/// device token), encrypted with the phone's Android Keystore key through the
/// native SecretBox. Values saved before encryption existed are read as they
/// are and written back encrypted on first read.
abstract final class Secrets {
  static final _api = VpnHostApi();

  /// Reads [key]; null when absent or unreadable.
  static Future<String?> read(SharedPreferences prefs, String key) async {
    final stored = prefs.getString(key);
    if (stored == null) return null;
    if (!stored.startsWith('gv1:')) {
      // Saved before encryption: seal it now, return it as it was.
      await prefs.setString(key, await _api.seal(stored));
      return stored;
    }
    return _api.unseal(stored);
  }

  static Future<void> write(SharedPreferences prefs, String key, String plain) async =>
      prefs.setString(key, await _api.seal(plain));
}
