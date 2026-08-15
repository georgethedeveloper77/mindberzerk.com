/// Where hosts and pinned keys live.
///
/// ─── GLOBAL, NOT PER THEME ──────────────────────────────────────────────────
///
/// Every other preference in this app is per distro, because a distro is a skin
/// and your desktop arrangement under Ubuntu should not follow you to Kali. A
/// saved server is the opposite: it is a property of the PERSON, and losing your
/// hosts by switching theme would be indefensible.
///
/// So this writes global scalars through `shared_preferences` directly, which is
/// the same call `i18n.dart` makes for the selected locale and for the same
/// stated reason: language is a property of the user, not of the distro.
///
/// ─── SAVING PAST THE FREE LIMIT IS ALLOWED. CONNECTING IS NOT ───────────────
///
/// The obvious paywall refuses the save. This one takes it and refuses the
/// connect, so the ceiling is something the person can see on their own screen
/// with their own second server on it, rather than an abstract number in a
/// marketing list. It also means an unlock makes their existing hosts work
/// rather than asking them to type them again.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ssh_host.dart';
import 'terminal_entitlement.dart';

/// Persisted under these keys. Versioned in the name, like `appLocale.v1`, so a
/// future shape change is a new key rather than a migration that has to guess
/// what it is reading.
const String _kHostsKey = 'sshHosts.v1';
const String _kKnownHostsKey = 'sshKnownHosts.v1';

/// How many hosts you can CONNECT to without Terminal Pro.
///
/// One is deliberate rather than zero. A terminal that cannot reach a single
/// server is not a terminal with a paywall, it is a demo, and nobody keeps a
/// demo on their home screen long enough to buy anything.
const int kFreeHostLimit = 1;

/// Hosts, in the order they were added.
///
/// Insertion order rather than alphabetical: the first host is almost always
/// the one that matters, it is the one the free tier can reach, and sorting
/// would move it the day someone adds a server called `alpha`.
class SshHostStore extends AsyncNotifier<List<SshHost>> {
  @override
  Future<List<SshHost>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(_kHostsKey));
  }

  static List<SshHost> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final e in list)
          if (e is Map<String, dynamic>)
            if (SshHost.fromJson(e) case final h?) h,
      ];
    } catch (_) {
      // A corrupt blob loses the hosts, which is bad, and throwing here would
      // lose the whole terminal, which is worse. Returning empty at least lets
      // someone add them again.
      return const [];
    }
  }

  Future<void> _write(List<SshHost> hosts) async {
    state = AsyncData(hosts);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kHostsKey,
      jsonEncode([for (final h in hosts) h.toJson()]),
    );
  }

  /// Add, or replace an existing alias.
  ///
  /// Replacing rather than refusing a duplicate alias: `host add myserver` on
  /// an alias that exists is someone correcting it, and making them remove it
  /// first is a step with no purpose.
  Future<void> save(SshHost host) async {
    final current = state.value ?? const <SshHost>[];
    final next = [
      for (final h in current)
        if (h.alias != host.alias) h,
      host,
    ];
    await _write(next);
  }

  Future<bool> remove(String alias) async {
    final current = state.value ?? const <SshHost>[];
    final next = [
      for (final h in current)
        if (h.alias != alias) h,
    ];
    if (next.length == current.length) return false;
    await _write(next);
    return true;
  }

  SshHost? byAlias(String alias) {
    for (final h in state.value ?? const <SshHost>[]) {
      if (h.alias == alias) return h;
    }
    return null;
  }
}

final sshHostsProvider =
    AsyncNotifierProvider<SshHostStore, List<SshHost>>(SshHostStore.new);

/// Which saved hosts this install may actually connect to.
///
/// Pro reaches all of them. Free reaches the first [kFreeHostLimit], by
/// insertion order, so which host is free does not change when the list is
/// re-read or when another is added.
final connectableHostsProvider = Provider<List<SshHost>>((ref) {
  final hosts = ref.watch(sshHostsProvider).value ?? const <SshHost>[];
  if (ref.watch(terminalProProvider)) return hosts;
  return hosts.take(kFreeHostLimit).toList();
});

/// Can this alias be connected to right now?
///
/// Three answers, not two, because "not yours" and "beyond your limit" need
/// different words: one is a typo and the other is a paywall.
enum HostAccess { ok, unknownAlias, needsPro }

final hostAccessProvider = Provider.family<HostAccess, String>((ref, alias) {
  final hosts = ref.watch(sshHostsProvider).value ?? const <SshHost>[];
  final exists = hosts.any((h) => h.alias == alias);
  if (!exists) return HostAccess.unknownAlias;

  final connectable = ref.watch(connectableHostsProvider);
  return connectable.any((h) => h.alias == alias)
      ? HostAccess.ok
      : HostAccess.needsPro;
});

/// Pinned host keys.
///
/// Not gated by Pro, and that is not an oversight. This is the check that stops
/// a machine in the middle reading your password, and a security control behind
/// a paywall is a security control most people do not have.
class KnownHostStore extends AsyncNotifier<Map<String, KnownHost>> {
  @override
  Future<Map<String, KnownHost>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(_kKnownHostsKey));
  }

  static Map<String, KnownHost> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const {};
      final out = <String, KnownHost>{};
      for (final e in list) {
        if (e is! Map<String, dynamic>) continue;
        final k = KnownHost.fromJson(e);
        if (k != null) out[k.id] = k;
      }
      return out;
    } catch (_) {
      // Losing pins fails SAFE: an unknown host is asked about, it is not
      // trusted silently. The opposite failure, keeping a pin we cannot parse,
      // would be the dangerous one.
      return const {};
    }
  }

  Future<void> _write(Map<String, KnownHost> known) async {
    state = AsyncData(known);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKnownHostsKey,
      jsonEncode([for (final k in known.values) k.toJson()]),
    );
  }

  /// What to do about the key this host just presented.
  HostKeyVerdict verify({
    required String host,
    required int port,
    required String keyType,
    required String fingerprint,
  }) {
    final known = state.value ?? const <String, KnownHost>{};
    return verdictFor(
      known['$host:$port'],
      keyType: keyType,
      fingerprint: fingerprint,
    );
  }

  /// Pin a key the person confirmed.
  ///
  /// Only ever called after an explicit confirmation. There is no path that
  /// pins silently, because a client that pins whatever it is handed has the
  /// same security as one that checks nothing.
  Future<void> trust(KnownHost key) async {
    final known = {...(state.value ?? const <String, KnownHost>{})};
    known[key.id] = key;
    await _write(known);
  }

  /// Forget a pin, which is what someone does after genuinely rebuilding a
  /// server. Deliberate and manual, so the next connect asks again.
  Future<bool> forget(String host, int port) async {
    final known = {...(state.value ?? const <String, KnownHost>{})};
    if (known.remove('$host:$port') == null) return false;
    await _write(known);
    return true;
  }
}

final knownHostsProvider =
    AsyncNotifierProvider<KnownHostStore, Map<String, KnownHost>>(
  KnownHostStore.new,
);
