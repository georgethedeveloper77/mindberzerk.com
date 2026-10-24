import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_network/g_network.dart';

import '../design/world_map.dart';
import '../rules/rules_store.dart';
import '../tools/tools_providers.dart';
import '../vpn/vpn_controller.dart';

/// Fires on every network change (debounced). Watching this re-runs a
/// provider when the phone joins a new network: that is the auto-scan.
final networkChangesProvider = StreamProvider<void>((ref) => NetworkEvents.instance.changes);

/// Re-reads whenever the network or the tunnel changes, never on a timer.
final _phaseProvider = Provider<VpnPhase>((ref) => ref.watch(vpnProvider.select((s) => s.phase)));

enum Tone { ok, warn, bad }

class ScanChip {
  const ScanChip(this.label, this.value, this.tone);

  final String label;
  final String value;
  final Tone tone;
}

class NetworkScan {
  const NetworkScan({required this.name, required this.nameHidden, required this.chips, required this.at});

  /// Wi-Fi name or mobile carrier. Null when Android hides it.
  final String? name;

  /// On Wi-Fi, but the name needs the location permission (Android's rule,
  /// not ours) or Location is switched off.
  final bool nameHidden;
  final List<ScanChip> chips;
  final DateTime at;
}

/// The automatic "this network" check: Wi-Fi security, ping, DNS. A few
/// kilobytes, no consent needed. The full speed test is never automatic: it
/// costs real data and publishes the IP to M-Lab.
final networkScanProvider = FutureProvider<NetworkScan>((ref) async {
  ref.watch(networkChangesProvider);
  final phase = ref.watch(_phaseProvider);
  final shield = (await ref.watch(rulesProvider.future)).shield;
  final results = await Future.wait([
    ref.read(networkProbeProvider).snapshot(),
    measureLatency(count: 5),
  ]);
  final snap = results[0] as NetworkSnapshot;
  final lat = results[1] as LatencyResult;
  final on = phase == VpnPhase.on;

  final wifi = snap.transport == Transport.wifi;
  return NetworkScan(
    at: DateTime.now(),
    name: wifi ? snap.ssid : snap.transport == Transport.cellular ? (snap.carrierName ?? 'Mobile data') : null,
    nameHidden: wifi && snap.ssid == null,
    chips: [
      _wifiChip(snap),
      ScanChip(
        'PING',
        lat.medianMs == null ? 'No reply' : '${lat.medianMs!.round()} ms',
        lat.medianMs == null || lat.lossPercent > 20 ? Tone.warn : Tone.ok,
      ),
      if (on)
        ScanChip('DNS', shield ? 'Quad9, tunnel' : 'In the tunnel', Tone.ok)
      else if (snap.privateDnsActive)
        const ScanChip('DNS', 'Private DNS', Tone.ok)
      else
        const ScanChip('DNS', 'ISP, visible', Tone.warn),
    ],
  );
});

ScanChip _wifiChip(NetworkSnapshot s) {
  if (s.transport == Transport.cellular) return const ScanChip('NETWORK', 'Mobile data', Tone.ok);
  if (s.transport != Transport.wifi) return const ScanChip('NETWORK', 'Offline', Tone.warn);
  final covered = s.vpnActive;
  final (value, tone) = switch (s.wifiSecurity) {
    WifiSecurity.open => ('Open, no password', Tone.bad),
    WifiSecurity.wep => ('WEP, broken', Tone.bad),
    WifiSecurity.owe => ('Open, encrypted', Tone.warn),
    WifiSecurity.wpa2 => ('WPA2', Tone.ok),
    WifiSecurity.wpa3 => ('WPA3', Tone.ok),
    WifiSecurity.enterprise => ('Enterprise', Tone.ok),
    WifiSecurity.unknown => ('Unknown', Tone.warn),
  };
  if (s.captivePortal && tone == Tone.ok) return ScanChip('WI-FI', 'Sign-in page', covered ? Tone.ok : Tone.warn);
  if (covered && tone != Tone.ok) return ScanChip('WI-FI', '${value.split(',').first}, covered', Tone.ok);
  return ScanChip('WI-FI', value, tone);
}

/// What sites see: refreshed on network change and on connect / disconnect.
final identityProvider = FutureProvider<PublicIdentity>((ref) async {
  ref.watch(networkChangesProvider);
  ref.watch(_phaseProvider);
  return lookupIdentity();
});

/// The user's REAL location, remembered from the last lookup made without
/// the tunnel. Once connected, the lookup returns the server's location,
/// which becomes the second pin.
final homeLocationProvider = NotifierProvider<HomeLocation, LatLon?>(HomeLocation.new);

class HomeLocation extends Notifier<LatLon?> {
  @override
  LatLon? build() {
    ref.listen(identityProvider, (_, next) {
      final id = next.value;
      final exposed = ref.read(vpnProvider).phase == VpnPhase.off;
      if (id != null && exposed && id.latitude != null && id.longitude != null) {
        state = LatLon(id.latitude!, id.longitude!);
      }
    });
    return null;
  }
}
