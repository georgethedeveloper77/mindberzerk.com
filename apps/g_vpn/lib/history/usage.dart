import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../vpn/tunnel_store.dart';
import '../vpn/vpn_controller.dart';
import 'recents.dart';

/// One server's share of a day.
@immutable
class ServerUsage {
  const ServerUsage({required this.name, this.country, this.seconds = 0, this.bytes = 0});

  final String name;
  final String? country;
  final int seconds;
  final int bytes;

  ServerUsage add(int s, int b) => ServerUsage(name: name, country: country, seconds: seconds + s, bytes: bytes + b);

  Map<String, Object> toJson() => {'n': name, if (country != null) 'c': country!, 's': seconds, 'b': bytes};

  static ServerUsage? fromJson(Object? j) => j is Map && j['n'] is String
      ? ServerUsage(
          name: j['n'] as String,
          country: j['c'] is String ? j['c'] as String : null,
          seconds: j['s'] is int ? j['s'] as int : 0,
          bytes: j['b'] is int ? j['b'] as int : 0,
        )
      : null;
}

/// One local day: time protected and data through the tunnel, with the
/// share of each server.
@immutable
class UsageDay {
  const UsageDay({this.seconds = 0, this.rx = 0, this.tx = 0, this.servers = const {}});

  final int seconds;
  final int rx;
  final int tx;

  /// Keyed by [ServerChoice.id].
  final Map<String, ServerUsage> servers;

  int get bytes => rx + tx;

  UsageDay add({required int seconds, required int rx, required int tx, required String id, required ServerUsage label}) {
    final current = servers[id] ?? label;
    return UsageDay(
      seconds: this.seconds + seconds,
      rx: this.rx + rx,
      tx: this.tx + tx,
      servers: {...servers, id: current.add(seconds, rx + tx)},
    );
  }

  Map<String, Object> toJson() => {
        's': seconds,
        'rx': rx,
        'tx': tx,
        'srv': {for (final e in servers.entries) e.key: e.value.toJson()},
      };

  static UsageDay fromJson(Object? j) {
    if (j is! Map) return const UsageDay();
    final srv = j['srv'];
    return UsageDay(
      seconds: j['s'] is int ? j['s'] as int : 0,
      rx: j['rx'] is int ? j['rx'] as int : 0,
      tx: j['tx'] is int ? j['tx'] as int : 0,
      servers: srv is Map
          ? {
              for (final e in srv.entries)
                if (e.key is String && ServerUsage.fromJson(e.value) != null) e.key as String: ServerUsage.fromJson(e.value)!,
            }
          : const {},
    );
  }
}

/// The local date key, "2026-10-25".
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Where counting stopped last: the time, and the tunnel's byte counters
/// then. Persisted, so a tunnel that outlived the app is counted on return.
class _Cursor {
  const _Cursor(this.at, this.rx, this.tx);

  final DateTime at;
  final int rx;
  final int tx;

  Map<String, int> toJson() => {'at': at.millisecondsSinceEpoch, 'rx': rx, 'tx': tx};

  static _Cursor? fromJson(Object? j) => j is Map && j['at'] is int
      ? _Cursor(DateTime.fromMillisecondsSinceEpoch(j['at'] as int), (j['rx'] as int?) ?? 0, (j['tx'] as int?) ?? 0)
      : null;
}

final usageProvider = AsyncNotifierProvider<UsageController, Map<String, UsageDay>>(UsageController.new);

/// Protected time and data per day, for the stats. Kept on this phone
/// only: nothing here is sent anywhere.
///
/// Counted from the tunnel's own byte counters and the clock as the app
/// sees the VPN state. While the app is closed the tunnel keeps running;
/// the gap is counted when the app next sees the same tunnel (its counters
/// only ever grow within one session).
class UsageController extends AsyncNotifier<Map<String, UsageDay>> {
  static const _daysKey = 'gvpn.usage.days.v1';
  static const _cursorKey = 'gvpn.usage.cursor.v1';

  /// Two months are kept: enough for the Month view.
  static const _keepDays = 62;

  /// Saves at most this often while counting; always on start and stop.
  static const _saveEvery = Duration(seconds: 20);

  _Cursor? _cursor;
  DateTime _savedAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<Map<String, UsageDay>> build() async {
    final prefs = await SharedPreferences.getInstance();
    _cursor = _Cursor.fromJson(_decode(prefs.getString(_cursorKey)));
    final raw = _decode(prefs.getString(_daysKey));
    if (raw is! Map) return const {};
    return {for (final e in raw.entries) if (e.key is String) e.key as String: UsageDay.fromJson(e.value)};
  }

  static Object? _decode(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  /// A new session: count from when it connected, counters from zero.
  Future<void> begin(DateTime connectedAt) async {
    await future;
    _cursor = _Cursor(connectedAt, 0, 0);
    await _save(force: true);
  }

  /// Counts up to [vpn] for the server in [choice]. Called on every VPN
  /// state while on.
  Future<void> sample(VpnState vpn, ServerChoice? choice) async {
    await future;
    final days = state.value ?? const <String, UsageDay>{};
    final now = DateTime.now();
    final c = _cursor;
    // First sight of a tunnel that was already up, or counters that went
    // backwards (a new session we did not see start): start from here.
    if (c == null || vpn.rxBytes < c.rx || vpn.txBytes < c.tx) {
      _cursor = _Cursor(now, vpn.rxBytes, vpn.txBytes);
      await _save(force: true);
      return;
    }
    if (choice == null) {
      _cursor = _Cursor(now, vpn.rxBytes, vpn.txBytes);
      return;
    }
    // Paused time is not protected time.
    final seconds = vpn.pausedUntil != null ? 0 : now.difference(c.at).inSeconds;
    final rx = vpn.rxBytes - c.rx, tx = vpn.txBytes - c.tx;
    if (seconds <= 0 && rx == 0 && tx == 0) return;

    final label = ServerUsage(name: choice.name, country: choice.countryCode?.toUpperCase());
    final next = {...days};
    // Time is split across midnight; bytes land on today.
    var from = c.at;
    var left = seconds;
    while (left > 0) {
      final midnight = DateTime(from.year, from.month, from.day + 1);
      final span = left < midnight.difference(from).inSeconds ? left : midnight.difference(from).inSeconds;
      final key = dayKey(from);
      final isToday = key == dayKey(now);
      next[key] = (next[key] ?? const UsageDay()).add(
        seconds: span,
        rx: isToday ? rx : 0,
        tx: isToday ? tx : 0,
        id: choice.id,
        label: label,
      );
      left -= span;
      from = midnight;
    }
    if (seconds <= 0) {
      final key = dayKey(now);
      next[key] = (next[key] ?? const UsageDay()).add(seconds: 0, rx: rx, tx: tx, id: choice.id, label: label);
    }
    _cursor = _Cursor(now, vpn.rxBytes, vpn.txBytes);
    state = AsyncData(_trim(next, now));
    await _save();
  }

  /// The session ended: counted up to [last], then forgotten.
  Future<void> end(VpnState last, ServerChoice? choice) async {
    await sample(last, choice);
    _cursor = null;
    await _save(force: true);
  }

  /// Clears every day and the cursor.
  Future<void> reset() async {
    await future;
    _cursor = null;
    state = const AsyncData({});
    await _save(force: true);
  }

  Map<String, UsageDay> _trim(Map<String, UsageDay> days, DateTime now) {
    final oldest = dayKey(now.subtract(const Duration(days: _keepDays)));
    return {for (final e in days.entries) if (e.key.compareTo(oldest) > 0) e.key: e.value};
  }

  Future<void> _save({bool force = false}) async {
    final now = DateTime.now();
    if (!force && now.difference(_savedAt) < _saveEvery) return;
    _savedAt = now;
    final prefs = await SharedPreferences.getInstance();
    final days = state.value ?? const {};
    await prefs.setString(_daysKey, jsonEncode({for (final e in days.entries) e.key: e.value.toJson()}));
    final c = _cursor;
    if (c == null) {
      await prefs.remove(_cursorKey);
    } else {
      await prefs.setString(_cursorKey, jsonEncode(c.toJson()));
    }
  }
}

/// Feeds the VPN's state into Recents and the usage counts. Watched once,
/// by the shell, so it runs whatever tab is open.
final historyRecorderProvider = Provider<void>((ref) {
  ref.listen<VpnState>(vpnProvider, (prev, next) {
    final choice = ref.read(tunnelsProvider).value?.choice;
    // A tunnel found up after a restart has no id; the selected server is
    // still the one in use.
    final current = next.tunnelId == null || next.tunnelId == choice?.id ? choice : null;
    final usage = ref.read(usageProvider.notifier);
    final wasOn = prev?.phase == VpnPhase.on;
    if (next.phase == VpnPhase.on) {
      if (!wasOn && prev?.phase == VpnPhase.connecting) {
        if (current != null) ref.read(recentsProvider.notifier).record(current);
        usage.begin(next.connectedAt ?? DateTime.now()).then((_) => usage.sample(next, current));
      } else {
        usage.sample(next, current);
      }
    } else if (wasOn && prev != null) {
      usage.end(prev, current);
    }
  });
});
