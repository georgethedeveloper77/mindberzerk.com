import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'discovery.dart';
import 'lan.dart';

/// A device seen on a network before, kept so it can be listed while away.
@immutable
class KnownDevice {
  const KnownDevice({required this.ip, required this.lastSeen, this.name, this.model, this.kind = DeviceKind.unknown});

  final String ip;
  final String? name;
  final String? model;
  final DeviceKind kind;
  final DateTime lastSeen;

  LanDevice get asLan => LanDevice(ip: ip, rttMs: 0, name: name, model: model, kind: kind);

  Map<String, Object> toJson() => {
        'ip': ip,
        if (name != null) 'n': name!,
        if (model != null) 'm': model!,
        'k': kind.name,
        't': lastSeen.millisecondsSinceEpoch,
      };

  static KnownDevice? fromJson(Object? j) {
    if (j is! Map || j['ip'] is! String || j['t'] is! int) return null;
    return KnownDevice(
      ip: j['ip'] as String,
      name: j['n'] is String ? j['n'] as String : null,
      model: j['m'] is String ? j['m'] as String : null,
      kind: DeviceKind.values.where((k) => k.name == j['k']).firstOrNull ?? DeviceKind.unknown,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
    );
  }
}

/// What the phone remembers about devices, all keyed by [deviceKey]
/// ("HomeNet|192.168.1.57"), kept on this phone only.
@immutable
class DeviceMemory {
  const DeviceMemory({this.known = const {}, this.mine = const {}, this.kinds = const {}});

  /// Per network, every device seen there.
  final Map<String, Map<String, KnownDevice>> known;

  /// The user's answer to "Is this yours?": true mine, false not mine.
  final Map<String, bool> mine;

  /// Types the user corrected.
  final Map<String, DeviceKind> kinds;
}

/// The key a device is remembered under on a network.
String deviceKey(String? network, String ip) => '${network ?? 'lan'}|$ip';

final deviceMemoryProvider = AsyncNotifierProvider<DeviceMemoryController, DeviceMemory>(DeviceMemoryController.new);

class DeviceMemoryController extends AsyncNotifier<DeviceMemory> {
  static const _key = 'gvpn.device_memory.v1';

  /// Devices unseen for longer than this are forgotten.
  static const _keep = Duration(days: 30);

  @override
  Future<DeviceMemory> build() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return const DeviceMemory();
    try {
      final j = jsonDecode(raw) as Map;
      final known = <String, Map<String, KnownDevice>>{};
      for (final e in (j['known'] as Map? ?? const {}).entries) {
        final devices = <String, KnownDevice>{};
        for (final d in (e.value as List? ?? const []).map(KnownDevice.fromJson).whereType<KnownDevice>()) {
          devices[d.ip] = d;
        }
        known['${e.key}'] = devices;
      }
      return DeviceMemory(
        known: known,
        mine: {for (final e in (j['mine'] as Map? ?? const {}).entries) if (e.value is bool) '${e.key}': e.value as bool},
        kinds: {
          for (final e in (j['kinds'] as Map? ?? const {}).entries)
            if (DeviceKind.values.where((k) => k.name == e.value).firstOrNull case final k?) '${e.key}': k,
        },
      );
    } on Object {
      return const DeviceMemory();
    }
  }

  /// Records a finished scan of [network].
  Future<void> recordScan(String? network, List<LanDevice> devices) async {
    final current = await future;
    final now = DateTime.now();
    final net = network ?? 'lan';
    final kept = {
      for (final e in (current.known[net] ?? const <String, KnownDevice>{}).entries)
        if (now.difference(e.value.lastSeen) < _keep) e.key: e.value,
    };
    for (final d in devices) {
      if (d.isSelf) continue;
      kept[d.ip] = KnownDevice(ip: d.ip, name: d.name, model: d.model, kind: d.kind, lastSeen: now);
    }
    await _save(DeviceMemory(known: {...current.known, net: kept}, mine: current.mine, kinds: current.kinds));
  }

  /// Answers "Is this yours?"; null clears the answer.
  Future<void> setMine(String key, bool? mine) async {
    final current = await future;
    final next = {...current.mine};
    if (mine == null) {
      next.remove(key);
    } else {
      next[key] = mine;
    }
    await _save(DeviceMemory(known: current.known, mine: next, kinds: current.kinds));
  }

  /// Corrects a device's type; null goes back to the detected one.
  Future<void> setKind(String key, DeviceKind? kind) async {
    final current = await future;
    final next = {...current.kinds};
    if (kind == null) {
      next.remove(key);
    } else {
      next[key] = kind;
    }
    await _save(DeviceMemory(known: current.known, mine: current.mine, kinds: next));
  }

  /// Forgets which devices each network had (Clear tool history).
  Future<void> forgetSeen() async {
    final current = await future;
    await _save(DeviceMemory(mine: current.mine, kinds: current.kinds));
  }

  Future<void> _save(DeviceMemory m) async {
    state = AsyncData(m);
    await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode({
        'known': {for (final e in m.known.entries) e.key: [for (final d in e.value.values) d.toJson()]},
        'mine': m.mine,
        'kinds': {for (final e in m.kinds.entries) e.key: e.value.name},
      }),
    );
  }
}
