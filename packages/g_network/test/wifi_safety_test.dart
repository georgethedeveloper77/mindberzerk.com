import 'package:flutter_test/flutter_test.dart';
import 'package:g_network/g_network.dart';

NetworkSnapshot snap({
  Transport transport = Transport.wifi,
  WifiSecurity security = WifiSecurity.wpa2,
  bool vpn = false,
  bool captive = false,
  bool validated = true,
}) =>
    NetworkSnapshot(
      transport: transport,
      vpnActive: vpn,
      validated: validated,
      captivePortal: captive,
      metered: false,
      privateDnsActive: false,
      dnsServers: const [],
      addresses: const [],
      wifiSecurity: security,
    );

void main() {
  test('open Wi-Fi without a VPN is a risk', () {
    expect(assessWifi(snap(security: WifiSecurity.open)).level, SafetyLevel.risk);
  });

  test('the same open Wi-Fi under the VPN is safe, and says why', () {
    final v = assessWifi(snap(security: WifiSecurity.open, vpn: true));
    expect(v.level, SafetyLevel.safe);
    expect(v.reasons.last, contains('VPN'));
  });

  test('a captive portal on WPA2 is a caution', () {
    expect(assessWifi(snap(captive: true)).level, SafetyLevel.caution);
  });

  test('mobile data is not a Wi-Fi verdict', () {
    expect(assessWifi(snap(transport: Transport.cellular)).level, SafetyLevel.notApplicable);
  });
}
