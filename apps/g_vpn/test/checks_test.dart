import 'package:flutter_test/flutter_test.dart';
import 'package:g_vpn/checks/link_check.dart';
import 'package:g_vpn/checks/password_check.dart';

void main() {
  test('range answers match only the exact suffix', () {
    const body = '0018A45C4D1DEF81644B54AB7F969B88D65:3\r\n'
        '00D4F6E8FA6EECAD2A3AA415EEC418D38EC:0\r\n'
        '011053FD0102E94D6AE2F8B83D76FAF94F6:12\r\n';
    expect(countInRange(body, '011053FD0102E94D6AE2F8B83D76FAF94F6'), 12);
    expect(countInRange(body, '00D4F6E8FA6EECAD2A3AA415EEC418D38EC'), 0, reason: 'padding row');
    expect(countInRange(body, 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'), 0);
  });

  test('links are normalised before checking', () {
    expect(normaliseLink('bit.ly/abc'), 'https://bit.ly/abc');
    expect(normaliseLink('  http://example.com/x  '), 'http://example.com/x');
    expect(normaliseLink('ftp://example.com'), isNull);
    expect(normaliseLink('not a link'), isNull);
    expect(normaliseLink('localhost'), isNull);
  });
}
