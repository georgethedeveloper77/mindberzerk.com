import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/countries.dart';
import 'lat_lon.dart';
import '../gservers/gservers.dart';
import '../home/home_scan.dart';
import '../i18n/strings.g.dart';
import '../pro/billing.dart';
import '../servers/community.dart';
import '../vpn/community_server.dart';
import '../vpn/tunnel_store.dart';
import '../vpn/vpn_controller.dart';
import 'g_map.dart';

/// Every server in one country: G Servers first, then free servers, best
/// ranked first.
class CountryServers {
  const CountryServers({required this.code, required this.at, this.servers = const [], this.gservers = const []});

  /// ISO alpha-2, upper case.
  final String code;
  final LatLon at;

  /// Free servers, in the Worker's ranking order.
  final List<CommunityServer> servers;

  /// G Servers that are up.
  final List<GServer> gservers;

  int get count => servers.length + gservers.length;
  String get name => countryName(code, servers.firstOrNull?.country ?? code);

  MapMarker get marker => MapMarker(id: code, at: at, code: code, count: count);
}

/// Servers grouped by country for the map: free countries in the Worker's
/// ranking order, then countries with only G Servers. Countries with no
/// known centre are left off the map; they stay in the list.
final countryServersProvider = Provider<List<CountryServers>>((ref) {
  final free = ref.watch(communityProvider).value?.servers ?? const <CommunityServer>[];
  final info = ref.watch(gServersProvider).value;
  final gs = info != null && info.available ? info.servers.where((s) => s.online) : const <GServer>[];

  final freeBy = <String, List<CommunityServer>>{};
  for (final s in free) {
    freeBy.putIfAbsent(s.countryCode.toUpperCase(), () => []).add(s);
  }
  final gBy = <String, List<GServer>>{};
  for (final s in gs) {
    gBy.putIfAbsent(s.country.toUpperCase(), () => []).add(s);
  }
  final codes = [...freeBy.keys, ...gBy.keys.where((c) => !freeBy.containsKey(c))];
  return [
    for (final code in codes)
      if (countryCentres[code] case final c?)
        CountryServers(code: code, at: LatLon(c.$1, c.$2), servers: freeBy[code] ?? const [], gservers: gBy[code] ?? const []),
  ];
});

/// The ISO alpha-2 code from a lookup, upper case, or null.
String? isoOf(String? country) =>
    country != null && country.length == 2 ? country.toUpperCase() : null;

/// A lookup's position: its city coordinates when the Worker sends them,
/// else the centre of its country (Cloudflare's fallback has no city).
LatLon? placeOf({double? latitude, double? longitude, String? country}) {
  if (latitude != null && longitude != null) return LatLon(latitude, longitude);
  final c = countryCentres[isoOf(country)];
  return c == null ? null : LatLon(c.$1, c.$2);
}

/// Where the user really is: remembered from the last lookup made with
/// the VPN off, so it survives while the lookup answers for the server.
final homePlaceProvider = NotifierProvider<HomePlace, ({LatLon? at, String? country})>(HomePlace.new);

class HomePlace extends Notifier<({LatLon? at, String? country})> {
  @override
  ({LatLon? at, String? country}) build() {
    ref.listen(identityProvider, (_, next) {
      final id = next.value;
      if (id == null || next.isLoading || ref.read(vpnProvider).phase != VpnPhase.off) return;
      state = (at: placeOf(latitude: id.latitude, longitude: id.longitude, country: id.country), country: isoOf(id.country));
    });
    final id = ref.read(identityProvider).value;
    final exposed = ref.read(vpnProvider).phase == VpnPhase.off;
    if (id == null || !exposed) return (at: null, country: null);
    return (at: placeOf(latitude: id.latitude, longitude: id.longitude, country: id.country), country: isoOf(id.country));
  }
}

/// Where the user is, where the traffic comes out, and the story mood.
/// Shared by Home, the full map and the Servers map so they agree.
final mapSceneProvider = Provider<MapScene>((ref) {
  final phase = ref.watch(vpnProvider.select((s) => s.phase));
  final choice = ref.watch(tunnelsProvider).value?.choice;
  final identity = ref.watch(identityProvider);
  final home = ref.watch(homePlaceProvider);
  final on = phase == VpnPhase.on;

  // Once protected, a lookup still in flight may be the pre-connect answer
  // (the user's own country), so only a settled one places the server.
  final id = on && !identity.isLoading ? identity.value : null;
  final choiceCode = isoOf(choice?.countryCode);
  final serverCountry = !on ? null : choiceCode ?? isoOf(id?.country);
  final server = !on
      ? null
      : choiceCode != null
          ? placeOf(country: choiceCode)
          : placeOf(latitude: id?.latitude, longitude: id?.longitude, country: id?.country);

  return MapScene(
    mood: switch (phase) {
      // Keeps turning until we know where the traffic comes out.
      VpnPhase.on => server == null ? MapMood.connecting : MapMood.protected,
      VpnPhase.connecting => MapMood.connecting,
      // Straight home on disconnect: no spin on the way out.
      VpnPhase.disconnecting || VpnPhase.off => MapMood.exposed,
    },
    you: home.at,
    youCountry: home.country,
    server: server,
    serverCountry: serverCountry,
  );
});

/// Selects [server] and connects to it, switching over if another tunnel
/// is up. Shared by every Connect on the maps.
///
/// Everything is read from [ref] before the first await, so the caller may
/// close its screen straight after calling this.
Future<void> connectCommunity(WidgetRef ref, CommunityServer server) async {
  final choice = CommunityChoice(server);
  final tunnels = ref.read(tunnelsProvider.notifier);
  final vpn = ref.read(vpnProvider.notifier);
  final current = ref.read(vpnProvider);
  await tunnels.selectCommunity(server);
  if (current.phase == VpnPhase.on) {
    if (current.tunnelId == choice.id) return;
    await vpn.disconnect();
  }
  await vpn.connect(choice);
}

/// Registers this phone with [server] (or confirms it still is), then
/// switches to it. Problems are shown through [messenger], captured by the
/// caller before its screen closes.
Future<void> connectGServerFromMap(WidgetRef ref, GServer server, ScaffoldMessengerState? messenger) async {
  final api = ref.read(vpnApiProvider);
  final token = ref.read(billingProvider).purchaseToken;
  final tunnels = ref.read(tunnelsProvider.notifier);
  final vpn = ref.read(vpnProvider.notifier);
  final current = ref.read(vpnProvider);
  if (current.phase == VpnPhase.on && current.tunnelId == '$gserverPrefix${server.id}') return;
  try {
    // Registered first, so the current tunnel stays up until we can switch.
    final tunnel = await registerGServer(api, server, purchaseToken: token);
    if (current.phase == VpnPhase.on) await vpn.disconnect();
    await tunnels.selectGServer(tunnel);
    await vpn.connect(OwnServer(tunnel));
  } on GServerException catch (e) {
    final message = switch (e.code) {
      'limit' => t.gs.fullTitle(n: e.limit ?? e.devices.length),
      'pro_required' => t.gs.proRequired,
      'busy' => t.gs.busyNow,
      'full' => t.gs.serverFull,
      'off' => t.gs.off,
      _ => t.gs.network,
    };
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}
