/// The keys this install holds, and which one it uses.
///
/// ─── ONE ACTIVE KEY, NOT ONE PER HOST ───────────────────────────────────────
///
/// A key is per DEVICE, not per server. That is the whole reason the public key
/// line carries a comment: when a phone is lost you delete one line from every
/// `authorized_keys` rather than working out which servers that phone reached.
///
/// So there is one active key and every connection uses it. Binding a different
/// key to each host is a real feature and it is not this one; it would also mean
/// a biometric prompt per host with no benefit, since the key that opens them is
/// the same phone either way.
///
/// ─── THE PLATFORM IS THE SOURCE OF TRUTH ────────────────────────────────────
///
/// The list of keys is read from the keystore, never from preferences. A key can
/// be destroyed outside this app: enrolling a fingerprint invalidates it, and a
/// restore to a new device brings the preference across without the key. A
/// cached list would show a key that cannot sign, and the failure would arrive
/// mid-connection instead of in the key manager.
///
/// Only the ACTIVE ALIAS is stored, and it is checked against the real list
/// before it is used.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../platform/keys_api.g.dart';
import 'ssh_keystore_key.dart';

/// Persisted under this key. Global, like the hosts and the locale: a key
/// belongs to the person, not to the distro they are looking at.
const String _kActiveKeyPref = 'sshActiveKey.v1';

final keysApiProvider = Provider<KeysHostApi>((ref) => KeysHostApi());

/// Every key in the keystore, by alias.
class SshKeyStore extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    return ref.read(keysApiProvider).listKeys();
  }

  /// Make a key. Returns the failure message, or null on success.
  Future<String?> generate(String alias) async {
    final result = await ref.read(keysApiProvider).generateKey(alias);
    if (result.failure != null) {
      return result.message ?? 'The key could not be created.';
    }
    ref.invalidateSelf();
    await future;

    // The FIRST key becomes active automatically. Making someone generate a key
    // and then separately activate it is a step with no decision in it.
    final active = await activeKeyAlias();
    if (active == null) await setActiveKeyAlias(alias);
    return null;
  }

  Future<bool> remove(String alias) async {
    final removed = await ref.read(keysApiProvider).deleteKey(alias);
    if (!removed) return false;

    if (await activeKeyAlias() == alias) {
      await setActiveKeyAlias(null);
    }
    ref.invalidateSelf();
    return true;
  }
}

final sshKeysProvider =
    AsyncNotifierProvider<SshKeyStore, List<String>>(SshKeyStore.new);

Future<String?> activeKeyAlias() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kActiveKeyPref);
}

Future<void> setActiveKeyAlias(String? alias) async {
  final prefs = await SharedPreferences.getInstance();
  if (alias == null) {
    await prefs.remove(_kActiveKeyPref);
  } else {
    await prefs.setString(_kActiveKeyPref, alias);
  }
}

/// The identity a connection should offer, or null.
///
/// Returns null rather than throwing when the stored alias names a key that is
/// gone, and clears the stale preference on the way past. A key destroyed by a
/// fingerprint enrolment is the common case, and the right outcome is falling
/// back to a password rather than failing to connect at all.
Future<SshKeystoreKeyPair?> activeIdentity(KeysHostApi api) async {
  final alias = await activeKeyAlias();
  if (alias == null) return null;

  final info = await api.publicKey(alias);
  if (info == null) {
    await setActiveKeyAlias(null);
    return null;
  }

  return SshKeystoreKeyPair(alias: alias, info: info, api: api);
}
