import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_scan.dart' show networkChangesProvider;
import '../tools/tools_providers.dart' show shareResultsProvider;
import '../vpn/vpn_controller.dart';

/// The gvpn-providers Worker. Overridable per build like the others.
const _base = String.fromEnvironment(
  'PROVIDERS_URL',
  defaultValue: 'https://gvpn-providers.mindberzerk.workers.dev',
);

/// Tags a rating can carry, in the order they are offered.
const ratingTags = ['fast', 'reliable', 'support', 'price', 'slowEvenings', 'drops', 'poorSupport', 'pricey'];

/// Tags that speak against a provider, shown in amber or red.
const badTags = {'slowEvenings', 'drops', 'poorSupport', 'pricey'};

/// A provider as the admin panel set it up (or as Cloudflare named it).
@immutable
class IspProfile {
  const IspProfile({required this.asn, required this.name, required this.org, this.color, this.logo, this.phone, this.website, this.outages});

  final int asn;
  final String name;
  final String org;

  /// "#2EB34A"; null until set in the admin panel.
  final String? color;
  final String? logo;
  final String? phone;
  final String? website;
  final String? outages;

  static IspProfile fromJson(Map j) => IspProfile(
        asn: (j['asn'] as num).toInt(),
        name: '${j['name'] ?? j['org']}',
        org: '${j['org']}',
        color: j['color'] as String?,
        logo: j['logo'] as String?,
        phone: j['phone'] as String?,
        website: j['website'] as String?,
        outages: j['outages'] as String?,
      );
}

@immutable
class RatingSummary {
  const RatingSummary({required this.count, required this.average, required this.spread, required this.tags});

  final int count;

  /// Null until there are enough ratings to mean anything.
  final double? average;

  /// Ratings per star, one star first.
  final List<int> spread;
  final Map<String, int> tags;

  static RatingSummary fromJson(Map j) => RatingSummary(
        count: (j['count'] as num?)?.toInt() ?? 0,
        average: (j['average'] as num?)?.toDouble(),
        spread: [for (final n in (j['spread'] as List? ?? const [0, 0, 0, 0, 0])) (n as num).toInt()],
        tags: {for (final e in (j['tags'] as Map? ?? const {}).entries) '${e.key}': (e.value as num).toInt()},
      );
}

/// The caller's provider, as seen by the Worker.
@immutable
class MyProvider {
  const MyProvider({
    required this.profile,
    required this.rating,
    required this.hidden,
    this.city,
    this.country,
    this.myStars,
    this.myTags = const [],
    this.cached = false,
  });

  final IspProfile profile;
  final RatingSummary rating;

  /// Not a home provider (hosting, VPN): no ratings.
  final bool hidden;
  final String? city;
  final String? country;
  final int? myStars;
  final List<String> myTags;

  /// From the last check without the VPN, shown while connected.
  final bool cached;

  static MyProvider fromJson(Map j, {bool cached = false}) => MyProvider(
        profile: IspProfile.fromJson(j['provider'] as Map),
        rating: RatingSummary.fromJson(j['rating'] as Map),
        hidden: j['hidden'] == true,
        city: j['city'] as String?,
        country: j['country'] as String?,
        myStars: (j['mine'] as Map?)?['stars'] as int?,
        myTags: [for (final t in ((j['mine'] as Map?)?['tags'] as List? ?? const [])) '$t'],
        cached: cached,
      );
}

@immutable
class NearbyProvider {
  const NearbyProvider({required this.profile, required this.average, required this.count});

  final IspProfile profile;
  final double average;
  final int count;
}

@immutable
class Nearby {
  const Nearby({required this.providers, required this.you, this.city, this.country, this.scope});

  final List<NearbyProvider> providers;

  /// The caller's network number, to mark "You".
  final int? you;
  final String? city;
  final String? country;

  /// "city" or "country".
  final String? scope;
}

/// A random id for this install, so one phone rates once a month. It says
/// nothing about the person and is never tied to an IP.
Future<String> _installId() async {
  final prefs = await SharedPreferences.getInstance();
  const key = 'gvpn.install_id.v1';
  final known = prefs.getString(key);
  if (known != null) return known;
  final r = math.Random.secure();
  final id = base64Url.encode(List.generate(18, (_) => r.nextInt(256))).replaceAll('=', '');
  await prefs.setString(key, id);
  return id;
}

const _cacheKey = 'gvpn.providers.me.v1';

/// The provider the phone is on. Through the VPN the Worker would see the
/// VPN's provider, so then the last answer without the VPN is shown.
final myProviderProvider = FutureProvider.autoDispose<MyProvider?>((ref) async {
  final vpnOn = ref.watch(vpnProvider.select((s) => s.phase)) == VpnPhase.on;
  final prefs = await SharedPreferences.getInstance();
  MyProvider? fromCache() {
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      return MyProvider.fromJson(jsonDecode(raw) as Map, cached: true);
    } on Object {
      return null;
    }
  }

  if (vpnOn) return fromCache();
  final body = await _fetchMe();
  return body == null ? fromCache() : MyProvider.fromJson(jsonDecode(body) as Map);
});

/// Asks the Worker who carries this connection, keeps the answer for when
/// the VPN is on, and returns it (null on failure).
Future<String?> _fetchMe() async {
  try {
    final res = await http
        .get(Uri.parse('$_base/me'), headers: {'x-device': await _installId()})
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, res.body);
    await prefs.setInt(_lastKey, DateTime.now().millisecondsSinceEpoch);
    return res.body;
  } on Object {
    return null;
  }
}

const _lastKey = 'gvpn.providers.last_seen.v1';

/// Watched by the shell: after the phone joins a network (without the
/// VPN), it tells the Worker which provider it is on, at most every half
/// hour. That is how the provider directory fills itself, country by
/// country, from ordinary use. Off with "Compare with providers nearby".
final providerRegistrarProvider = Provider<void>((ref) {
  ref.watch(networkChangesProvider);
  if (ref.watch(vpnProvider.select((s) => s.phase)) == VpnPhase.on) return;
  // Settle first: a network change fires several events in a row.
  final timer = Timer(const Duration(seconds: 8), () async {
    if (!ref.mounted) return;
    if (!(await ref.read(shareResultsProvider.future))) return;
    final prefs = await SharedPreferences.getInstance();
    final last = DateTime.fromMillisecondsSinceEpoch(prefs.getInt(_lastKey) ?? 0);
    if (DateTime.now().difference(last) < const Duration(minutes: 30)) return;
    await _fetchMe();
  });
  ref.onDispose(timer.cancel);
});

/// Providers rated near the phone. Only meaningful without the VPN.
final nearbyProvidersProvider = FutureProvider.autoDispose<Nearby?>((ref) async {
  if (ref.watch(vpnProvider.select((s) => s.phase)) == VpnPhase.on) return null;
  try {
    final res = await http.get(Uri.parse('$_base/nearby')).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body) as Map;
    return Nearby(
      scope: j['scope'] as String?,
      city: j['city'] as String?,
      country: j['country'] as String?,
      you: (j['you'] as num?)?.toInt(),
      providers: [
        for (final p in (j['providers'] as List? ?? const []))
          if (p is Map)
            NearbyProvider(
              profile: IspProfile.fromJson(p),
              average: (p['average'] as num).toDouble(),
              count: (p['count'] as num).toInt(),
            ),
      ],
    );
  } on Object {
    return null;
  }
});

/// Why a rating was not posted.
class RateException implements Exception {
  const RateException(this.code);

  /// busy, not_rateable, invalid or network.
  final String code;
}

/// Posts this month's rating for the provider the phone is on now.
Future<void> postRating({required int stars, required List<String> tags, double? down}) async {
  try {
    final res = await http
        .post(
          Uri.parse('$_base/rate'),
          headers: {'content-type': 'application/json', 'x-device': await _installId()},
          body: jsonEncode({'stars': stars, 'tags': tags, if (down != null) 'down': down}),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) return;
    final body = jsonDecode(res.body);
    throw RateException(res.statusCode == 429 ? 'busy' : body is Map && body['error'] is String ? body['error'] as String : 'network');
  } on RateException {
    rethrow;
  } on Object {
    throw const RateException('network');
  }
}
