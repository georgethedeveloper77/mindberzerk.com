import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Have I Been Pwned's public breach catalogue: free, no key, CC BY 4.0
/// (credited in Licences). Only the catalogue: no email is ever sent.
const _catalogueUrl = 'https://haveibeenpwned.com/api/v3/breaches';

/// One published breach.
@immutable
class Breach {
  const Breach({
    required this.name,
    required this.title,
    required this.domain,
    required this.breachDate,
    required this.addedDate,
    required this.pwnCount,
    required this.dataClasses,
    required this.logo,
    required this.verified,
    required this.description,
  });

  /// Unique, stable id ("Adobe").
  final String name;
  final String title;
  final String domain;
  final DateTime? breachDate;
  final DateTime addedDate;
  final int pwnCount;

  /// What leaked, in HIBP's words ("Email addresses", "Passwords").
  final List<String> dataClasses;
  final String? logo;
  final bool verified;

  /// Plain text, HIBP's HTML removed.
  final String description;

  bool get hasPasswords =>
      dataClasses.any((d) => d.toLowerCase().contains('password'));
  bool get hasPhones =>
      dataClasses.any((d) => d.toLowerCase().contains('phone'));

  Map<String, Object?> toJson() => {
        'n': name,
        't': title,
        'd': domain,
        'b': breachDate?.toIso8601String(),
        'a': addedDate.toIso8601String(),
        'c': pwnCount,
        'k': dataClasses,
        'l': logo,
        'v': verified,
        's': description,
      };

  static Breach? fromCache(Object? j) {
    if (j is! Map || j['n'] is! String) return null;
    final added = DateTime.tryParse('${j['a']}');
    if (added == null) return null;
    return Breach(
      name: j['n'] as String,
      title: '${j['t']}',
      domain: '${j['d'] ?? ''}',
      breachDate: DateTime.tryParse('${j['b']}'),
      addedDate: added,
      pwnCount: (j['c'] as num?)?.toInt() ?? 0,
      dataClasses: [for (final d in (j['k'] as List? ?? const [])) '$d'],
      logo: j['l'] as String?,
      verified: j['v'] == true,
      description: '${j['s'] ?? ''}',
    );
  }

  /// From HIBP's own JSON, or null for entries not worth showing (spam
  /// lists, fabricated, retired, or sensitive).
  static Breach? fromHibp(Map j) {
    if (j['IsSpamList'] == true ||
        j['IsFabricated'] == true ||
        j['IsRetired'] == true ||
        j['IsSensitive'] == true) {
      return null;
    }
    final added = DateTime.tryParse('${j['AddedDate']}');
    if (added == null || j['Name'] is! String) return null;
    return Breach(
      name: j['Name'] as String,
      title: '${j['Title'] ?? j['Name']}',
      domain: '${j['Domain'] ?? ''}',
      breachDate: DateTime.tryParse('${j['BreachDate']}'),
      addedDate: added,
      pwnCount: (j['PwnCount'] as num?)?.toInt() ?? 0,
      dataClasses: [
        for (final d in (j['DataClasses'] as List? ?? const [])) '$d'
      ],
      logo: j['LogoPath'] is String &&
              (j['LogoPath'] as String).startsWith('https://')
          ? j['LogoPath'] as String
          : null,
      verified: j['IsVerified'] == true,
      description: _plain('${j['Description'] ?? ''}'),
    );
  }
}

/// HIBP descriptions are HTML: tags out, entities decoded.
String _plain(String html) => html
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .trim();

/// The catalogue, newest first. Fetched at most twice a day; the newest
/// [_keep] are kept on the phone so the screen opens instantly.
abstract final class BreachCatalogue {
  static const _cacheKey = 'gvpn.breaches.cache.v1';
  static const _fetchedKey = 'gvpn.breaches.fetched.v1';
  static const _keep = 150;
  static const _fresh = Duration(hours: 12);

  static Future<List<Breach>> cached() async {
    final raw = (await SharedPreferences.getInstance()).getString(_cacheKey);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map(Breach.fromCache)
          .whereType<Breach>()
          .toList();
    } on FormatException {
      return const [];
    }
  }

  /// Fresh from HIBP when the cache is old (or [force]); the cache when the
  /// network fails.
  static Future<List<Breach>> load({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final fetched =
        DateTime.fromMillisecondsSinceEpoch(prefs.getInt(_fetchedKey) ?? 0);
    if (!force && DateTime.now().difference(fetched) < _fresh) {
      final cache = await cached();
      if (cache.isNotEmpty) return cache;
    }
    try {
      final res = await http.get(Uri.parse(_catalogueUrl), headers: const {
        'user-agent': 'G-VPN-Android'
      }).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return cached();
      final all = (jsonDecode(res.body) as List)
          .whereType<Map>()
          .map(Breach.fromHibp)
          .whereType<Breach>()
          .toList()
        ..sort((a, b) => b.addedDate.compareTo(a.addedDate));
      final keep = all.take(_keep).toList();
      await prefs.setString(
          _cacheKey, jsonEncode([for (final b in keep) b.toJson()]));
      await prefs.setInt(_fetchedKey, DateTime.now().millisecondsSinceEpoch);
      return keep;
    } on Object {
      return cached();
    }
  }
}

final breachesProvider =
    FutureProvider.autoDispose<List<Breach>>((ref) => BreachCatalogue.load());

/// "12.4M", "891K".
String compactCount(int n) {
  if (n >= 1000000000) return '${(n / 1e9).toStringAsFixed(1)}B';
  if (n >= 1000000) return '${(n / 1e6).toStringAsFixed(n >= 1e7 ? 0 : 1)}M';
  if (n >= 1000) return '${(n / 1e3).round()}K';
  return '$n';
}
