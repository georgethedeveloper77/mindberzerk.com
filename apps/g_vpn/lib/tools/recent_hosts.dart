import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tool_settings.dart';

/// A host a tool was pointed at, with how it went last time.
@immutable
class RecentHost {
  const RecentHost({required this.host, required this.summary, required this.at});

  final String host;

  /// "8 hops · 151 ms": shown under the host.
  final String summary;
  final DateTime at;

  Map<String, Object> toJson() => {'h': host, 's': summary, 'at': at.millisecondsSinceEpoch};

  static RecentHost? fromJson(Object? j) => j is Map && j['h'] is String
      ? RecentHost(
          host: j['h'] as String,
          summary: j['s'] is String ? j['s'] as String : '',
          at: DateTime.fromMillisecondsSinceEpoch(j['at'] is int ? j['at'] as int : 0),
        )
      : null;
}

final recentHostsProvider = AsyncNotifierProvider<RecentHostsController, Map<String, List<RecentHost>>>(RecentHostsController.new);

/// Recent hosts per tool ("trace", ...), newest first, kept on this phone.
class RecentHostsController extends AsyncNotifier<Map<String, List<RecentHost>>> {
  static const _key = 'gvpn.tools.recent_hosts.v1';
  static const _keep = 6;

  @override
  Future<Map<String, List<RecentHost>>> build() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return const {};
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return const {};
      return {
        for (final e in j.entries)
          if (e.key is String && e.value is List)
            e.key as String: (e.value as List).map(RecentHost.fromJson).whereType<RecentHost>().toList(),
      };
    } on FormatException {
      return const {};
    }
  }

  /// Puts [host] first for [tool], unless the user turned this off.
  Future<void> add(String tool, String host, String summary) async {
    if (!(await ref.read(toolSettingsProvider.future)).rememberHosts) return;
    final all = {...await future};
    final list = [RecentHost(host: host, summary: summary, at: DateTime.now()), ...?all[tool]?.where((r) => r.host != host)];
    all[tool] = list.take(_keep).toList();
    await _save(all);
  }

  Future<void> clear([String? tool]) async {
    final all = {...await future};
    if (tool == null) {
      all.clear();
    } else {
      all.remove(tool);
    }
    await _save(all);
  }

  Future<void> _save(Map<String, List<RecentHost>> all) async {
    state = AsyncData(all);
    await (await SharedPreferences.getInstance())
        .setString(_key, jsonEncode({for (final e in all.entries) e.key: [for (final r in e.value) r.toJson()]}));
  }
}
