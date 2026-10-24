import 'package:flutter_test/flutter_test.dart';
import 'package:g_vpn/rules/banking.dart';
import 'package:g_vpn/vpn/config_rules.dart';
import 'package:g_vpn/vpn/vpn_api.g.dart';

const _base = '''[Interface]
PrivateKey = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa=
Address = 10.0.0.2/32
DNS = 192.168.1.1

[Peer]
PublicKey = bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb=
AllowedIPs = 0.0.0.0/0
Endpoint = vpn.example.com:51820''';

void main() {
  test('no rules returns the config untouched', () {
    expect(applyRules(_base), _base);
  });

  test('Shield replaces DNS inside [Interface] only', () {
    final out = applyRules(_base, dns: shieldResolvers);
    expect(out, isNot(contains('192.168.1.1')));
    expect(out, contains('DNS = 9.9.9.9, 149.112.112.112'));
    expect(out.indexOf('DNS ='), lessThan(out.indexOf('[Peer]')));
    expect(out, contains('Endpoint = vpn.example.com:51820'));
  });

  test('excluded apps are sorted, and replace IncludedApplications', () {
    final withIncluded = _base.replaceFirst('DNS = 192.168.1.1', 'DNS = 192.168.1.1\nIncludedApplications = com.x');
    final out = applyRules(withIncluded, excludedApps: ['com.b', 'com.a']);
    expect(out, contains('ExcludedApplications = com.a, com.b'));
    expect(out, isNot(contains('IncludedApplications')));
    // DNS untouched when Shield is off.
    expect(out, contains('DNS = 192.168.1.1'));
  });

  test('works when [Interface] is the last section', () {
    const tail = '[Peer]\nPublicKey = k\n\n[Interface]\nPrivateKey = p';
    final out = applyRules(tail, dns: ['9.9.9.9']);
    expect(out.trim().endsWith('DNS = 9.9.9.9'), isTrue);
  });

  test('banking hints match labels and packages, not everything', () {
    InstalledApp app(String pkg, String label) => InstalledApp(packageName: pkg, label: label, system: false);
    expect(looksLikeMoneyApp(app('com.safaricom.mpesa.lifestyle', 'M-PESA')), isTrue);
    expect(looksLikeMoneyApp(app('ke.co.example.mobile', 'KCB App')), isTrue);
    expect(looksLikeMoneyApp(app('com.whatsapp', 'WhatsApp')), isFalse);
  });
}
