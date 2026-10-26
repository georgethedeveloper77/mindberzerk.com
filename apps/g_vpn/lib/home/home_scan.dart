import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_network/g_network.dart';

import '../i18n/strings.g.dart';
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
  final level = (await ref.watch(rulesProvider.future)).shieldLevel;
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
    name: wifi ? snap.ssid : snap.transport == Transport.cellular ? (snap.carrierName ?? t.scan.mobile) : null,
    nameHidden: wifi && snap.ssid == null,
    chips: [
      _wifiChip(snap),
      ScanChip(
        t.scan.ping,
        lat.medianMs == null ? t.scan.noReply : t.scan.ms(n: lat.medianMs!.round()),
        lat.medianMs == null || lat.lossPercent > 20 ? Tone.warn : Tone.ok,
      ),
      if (on)
        ScanChip(t.scan.dns, level == ShieldLevel.malware ? t.scan.dnsQuad9 : t.scan.dnsTunnel, Tone.ok)
      else if (snap.privateDnsActive)
        ScanChip(t.scan.dns, t.scan.privateDns, Tone.ok)
      else
        ScanChip(t.scan.dns, t.scan.dnsIsp, Tone.warn),
    ],
  );
});

ScanChip _wifiChip(NetworkSnapshot s) {
  if (s.transport == Transport.cellular) {
    return ScanChip(t.scan.network, t.scan.mobile, Tone.ok);
  }
  if (s.transport != Transport.wifi) {
    return ScanChip(t.scan.network, t.scan.offline, Tone.warn);
  }
  final covered = s.vpnActive;
  final (value, tone) = switch (s.wifiSecurity) {
    WifiSecurity.open => (t.scan.open, Tone.bad),
    WifiSecurity.wep => (t.scan.wep, Tone.bad),
    WifiSecurity.owe => (t.scan.owe, Tone.warn),
    WifiSecurity.wpa2 => ('WPA2', Tone.ok),
    WifiSecurity.wpa3 => ('WPA3', Tone.ok),
    WifiSecurity.enterprise => (t.scan.enterprise, Tone.ok),
    WifiSecurity.unknown => (t.scan.unknown, Tone.warn),
  };
  if (s.captivePortal && tone == Tone.ok) {
    return ScanChip(t.scan.wifi, t.scan.signIn, covered ? Tone.ok : Tone.warn);
  }
  if (covered && tone != Tone.ok) {
    return ScanChip(t.scan.wifi, t.scan.covered(what: value.split(',').first), Tone.ok);
  }
  return ScanChip(t.scan.wifi, value, tone);
}

/// What sites see: refreshed on network change and on connect / disconnect.
final identityProvider = FutureProvider<PublicIdentity>((ref) async {
  ref.watch(networkChangesProvider);
  ref.watch(_phaseProvider);
  return lookupIdentity();
});
