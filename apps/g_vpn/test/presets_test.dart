import 'package:flutter_test/flutter_test.dart';
import 'package:g_vpn/presets/presets.dart';
import 'package:g_vpn/rules/rules_store.dart';
import 'package:g_vpn/vpn/community_server.dart';
import 'package:g_vpn/vpn/config_rules.dart';

CommunityServer _server(String id, String cc, {bool sstp = false}) => CommunityServer(
      id: id,
      country: cc,
      countryCode: cc,
      proto: 'udp',
      port: 1194,
      speedMbps: 50,
      pingMs: 40,
      sessions: 10,
      quality: 1,
      grade: 'fast',
      sstpHost: sstp ? '$id.example' : null,
      sstpPort: sstp ? 443 : null,
    );

void main() {
  final servers = [
    _server('a', 'KE'),
    _server('b', 'JP', sstp: true),
    _server('c', 'US'),
    _server('d', 'KR', sstp: true),
    _server('e', 'US', sstp: true),
  ];

  test('fastest takes the top three in ranking order', () {
    final picked = presetCandidates(builtInPresets.first, servers, null);
    expect(picked.map((s) => s.id), ['a', 'b', 'c']);
  });

  test('skip my country leaves it out', () {
    const p = Preset(id: 'x', skipMyCountry: true);
    expect(presetCandidates(p, servers, 'KE').map((s) => s.id), ['b', 'c', 'd']);
  });

  test('SSTP keeps only servers that offer it', () {
    const p = Preset(id: 'x', protocol: PresetProtocol.sstp);
    expect(presetCandidates(p, servers, null).map((s) => s.id), ['b', 'd', 'e']);
  });

  test('OpenVPN strips SSTP so the server connects over OpenVPN', () {
    const p = Preset(id: 'x', protocol: PresetProtocol.openvpn);
    expect(presetCandidates(p, servers, null).every((s) => s.sstpHost == null), isTrue);
  });

  test('a country preset stays in that country', () {
    const p = Preset(id: 'x', place: PresetPlace.country, country: 'us', tryNext: false);
    expect(presetCandidates(p, servers, null).map((s) => s.id), ['c']);
  });

  test('the old Shield switch becomes a level', () {
    expect(RulesState.fromJson({'shield': true}).shieldLevel, ShieldLevel.malware);
    expect(RulesState.fromJson({'shield': false}).shieldLevel, ShieldLevel.off);
    expect(RulesState.fromJson({'shieldLevel': 'family'}).dnsServers, familyResolvers);
  });

  test('preset overrides apply on top of the rules', () {
    const rules = RulesState(excluded: {'com.bank'}, shieldLevel: ShieldLevel.off);
    final applied = const RulesOverride(shield: ShieldLevel.malware, allApps: true).applyTo(rules);
    expect(applied.shieldLevel, ShieldLevel.malware);
    expect(applied.excluded, isEmpty);
  });

  test('custom DNS accepts IP addresses only', () {
    expect(isIpAddress('1.1.1.1'), isTrue);
    expect(isIpAddress('2606:4700:4700::1111'), isTrue);
    expect(isIpAddress('256.1.1.1'), isFalse);
    expect(isIpAddress('dns.google'), isFalse);
  });
}
