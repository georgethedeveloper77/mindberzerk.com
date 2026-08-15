// Target parsing and the host key verdict are the two pieces here that can be
// wrong in a way nobody notices: a mangled port connects to the wrong service,
// and a wrong verdict is the difference between refusing a machine in the
// middle and handing it a password.
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/terminal/ssh_host.dart';

void main() {
  group('parseTarget', () {
    test('user@host', () {
      final h = SshHost.parseTarget('g@example.com')!;
      expect(h.user, 'g');
      expect(h.host, 'example.com');
      expect(h.port, 22);
    });

    test('user@host:port', () {
      final h = SshHost.parseTarget('g@example.com:2222')!;
      expect(h.port, 2222);
      expect(h.host, 'example.com');
    });

    test('a bare host has no user', () {
      final h = SshHost.parseTarget('example.com')!;
      expect(h.user, '');
      expect(h.host, 'example.com');
    });

    test('an IPv4 address', () {
      final h = SshHost.parseTarget('root@164.90.201.79')!;
      expect(h.host, '164.90.201.79');
      expect(h.user, 'root');
    });

    test('a colon with a bad port is refused, not treated as a hostname', () {
      // Connecting to port 22 of something that was meant to be 2222 is the
      // silent failure this prevents.
      expect(SshHost.parseTarget('g@example.com:'), isNull);
      expect(SshHost.parseTarget('g@example.com:abc'), isNull);
      expect(SshHost.parseTarget('g@example.com:0'), isNull);
      expect(SshHost.parseTarget('g@example.com:70000'), isNull);
    });

    test('IPv6 in brackets is refused rather than mangled', () {
      // It needs its own grammar. Half-parsing it would fail at connect time
      // with a DNS error naming a string the user never typed.
      expect(SshHost.parseTarget('g@[::1]:22'), isNull);
      expect(SshHost.parseTarget('[2001:db8::1]'), isNull);
    });

    test('an empty user is refused', () {
      expect(SshHost.parseTarget('@example.com'), isNull);
    });

    test('a user containing @ takes the last one, as OpenSSH does', () {
      // Some providers use an email as the login.
      final h = SshHost.parseTarget('g@corp.com@gateway.example')!;
      expect(h.user, 'g@corp.com');
      expect(h.host, 'gateway.example');
    });

    test('rubbish is refused', () {
      expect(SshHost.parseTarget(''), isNull);
      expect(SshHost.parseTarget('   '), isNull);
      expect(SshHost.parseTarget('g@'), isNull);
      expect(SshHost.parseTarget('g@ex ample.com'), isNull);
      expect(SshHost.parseTarget('g@example.com/path'), isNull);
    });

    test('the alias defaults to the host and is lowercased', () {
      expect(SshHost.parseTarget('g@Example.COM')!.alias, 'example.com');
      expect(SshHost.parseTarget('g@x.com', alias: 'MyServer')!.alias,
          'myserver');
    });
  });

  group('target', () {
    test('hides port 22 and shows anything else', () {
      // A target reading g@example.com:22 looks configured when nothing was.
      expect(
        const SshHost(alias: 'a', user: 'g', host: 'x.com').target,
        'g@x.com',
      );
      expect(
        const SshHost(alias: 'a', user: 'g', host: 'x.com', port: 2222).target,
        'g@x.com:2222',
      );
    });
  });

  group('isValidAlias', () {
    test('accepts what someone would actually type', () {
      for (final a in ['myserver', 'build-box', 'web_01', 'a']) {
        expect(SshHost.isValidAlias(a), isTrue, reason: a);
      }
    });

    test('rejects what would need quoting or would never resolve', () {
      // An alias is typed at a prompt. One with a space needs quoting, and one
      // starting with a digit reads as an address.
      for (final a in ['My Server', '1box', '-box', '', 'a' * 40, 'BOX']) {
        expect(SshHost.isValidAlias(a), isFalse, reason: a);
      }
    });
  });

  group('SshHost json', () {
    test('round trips', () {
      const h = SshHost(alias: 'ms', user: 'g', host: 'x.com', port: 2222);
      expect(SshHost.fromJson(h.toJson()), h);
    });

    test('a row with no host is dropped rather than taking the list with it', () {
      expect(SshHost.fromJson({'alias': 'a', 'user': 'g'}), isNull);
      expect(SshHost.fromJson({'user': 'g', 'host': 'x.com'}), isNull);
    });

    test('an out of range port falls back to 22 rather than failing the row', () {
      final h = SshHost.fromJson({'alias': 'a', 'host': 'x.com', 'port': 0})!;
      expect(h.port, 22);
    });
  });

  group('KnownHost', () {
    KnownHost k({
      String host = 'x.com',
      int port = 22,
      String type = 'ssh-ed25519',
      String fp = 'SHA256:abc',
    }) =>
        KnownHost(
          host: host,
          port: port,
          keyType: type,
          fingerprint: fp,
          acceptedAt: DateTime.utc(2026, 8, 14),
        );

    test('identity is host and port, never the alias', () {
      // Two aliases for one machine are one machine. Re-confirming its key
      // because a bookmark was renamed teaches people to tap through the one
      // prompt that matters.
      expect(k().id, 'x.com:22');
      expect(k(port: 2222).id, 'x.com:2222');
    });

    test('matches on both type and fingerprint', () {
      expect(k().matches('ssh-ed25519', 'SHA256:abc'), isTrue);
      expect(k().matches('ssh-ed25519', 'SHA256:zzz'), isFalse);
      expect(k().matches('ecdsa-sha2-nistp256', 'SHA256:abc'), isFalse);
    });

    test('round trips through json', () {
      expect(KnownHost.fromJson(k().toJson()), k());
    });

    test('a row missing the fingerprint is dropped', () {
      // The fingerprint is the security-bearing field. A pin without one is
      // not a pin.
      final j = k().toJson()..remove('fingerprint');
      expect(KnownHost.fromJson(j), isNull);
    });

    test('an unparseable date keeps the pin rather than discarding it', () {
      // The date is for display. Dropping a pinned key over a bad timestamp
      // would silently downgrade a known host to an unknown one.
      final j = k().toJson()..['acceptedAt'] = 'not a date';
      final parsed = KnownHost.fromJson(j);
      expect(parsed, isNotNull);
      expect(parsed!.fingerprint, 'SHA256:abc');
    });
  });
}
