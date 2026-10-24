import 'network_api.g.dart';

enum SafetyLevel { safe, caution, risk, notApplicable }

/// A verdict plus the plain reasons behind it. Every reason is a fact the
/// device reported, never a guess: no "hackers detected" theatre.
class WifiVerdict {
  const WifiVerdict(this.level, this.reasons);

  final SafetyLevel level;
  final List<String> reasons;
}

WifiVerdict assessWifi(NetworkSnapshot s) {
  if (s.transport != Transport.wifi) {
    return const WifiVerdict(SafetyLevel.notApplicable, ['Not connected to Wi-Fi.']);
  }

  var level = SafetyLevel.safe;
  final reasons = <String>[];
  void raise(SafetyLevel to, String reason) {
    reasons.add(reason);
    if (to.index > level.index) level = to;
  }

  switch (s.wifiSecurity) {
    case WifiSecurity.open:
      raise(SafetyLevel.risk, 'No Wi-Fi password: people nearby can see unencrypted traffic.');
    case WifiSecurity.wep:
      raise(SafetyLevel.risk, 'WEP security is broken and can be cracked in minutes.');
    case WifiSecurity.owe:
      reasons.add('Open network with encryption (Enhanced Open).');
    case WifiSecurity.wpa2:
      reasons.add('Protected with WPA2.');
    case WifiSecurity.wpa3:
      reasons.add('Protected with WPA3, the current standard.');
    case WifiSecurity.enterprise:
      reasons.add('Enterprise Wi-Fi with individual sign-in.');
    case WifiSecurity.unknown:
      reasons.add('This Android version does not report Wi-Fi security.');
  }

  if (s.captivePortal) {
    raise(SafetyLevel.caution, 'Uses a sign-in page, typical of public hotspots.');
  }
  if (!s.validated) {
    raise(SafetyLevel.caution, 'Android could not confirm working internet on this network.');
  }
  if (s.privateDnsActive) {
    reasons.add('Private DNS is on${s.privateDnsServer == null ? '' : ' (${s.privateDnsServer})'}.');
  }

  // A tunnel covers the risks above for app traffic, so the verdict reflects
  // the user's actual exposure rather than the bare network.
  if (s.vpnActive && level != SafetyLevel.safe) {
    reasons.add('Your traffic is inside the VPN tunnel, so this network cannot read it.');
    level = SafetyLevel.safe;
  }

  return WifiVerdict(level, reasons);
}
