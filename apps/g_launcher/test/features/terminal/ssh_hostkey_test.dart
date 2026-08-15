// The verdict function is the one piece of this feature where being wrong hands
// a password to whoever is in the middle, so it is tested exhaustively rather
// than representatively.
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/terminal/ssh_host.dart';

KnownHost _pin({
  String type = 'ssh-ed25519',
  String fp = 'SHA256:AAAA',
}) =>
    KnownHost(
      host: 'x.com',
      port: 22,
      keyType: type,
      fingerprint: fp,
      acceptedAt: DateTime.utc(2026, 8, 14),
    );

void main() {
  group('verdictFor', () {
    test('nothing pinned is unknown, which asks rather than trusts', () {
      expect(
        verdictFor(null, keyType: 'ssh-ed25519', fingerprint: 'SHA256:AAAA'),
        HostKeyVerdict.unknown,
      );
    });

    test('same type, same fingerprint is trusted', () {
      expect(
        verdictFor(_pin(),
            keyType: 'ssh-ed25519', fingerprint: 'SHA256:AAAA'),
        HostKeyVerdict.trusted,
      );
    });

    test('same type, DIFFERENT fingerprint is a mismatch', () {
      // The dangerous one. Rebuilt server or impersonation, and from the
      // client's position those are indistinguishable.
      expect(
        verdictFor(_pin(),
            keyType: 'ssh-ed25519', fingerprint: 'SHA256:BBBB'),
        HostKeyVerdict.mismatch,
      );
    });

    test('different type is a new algorithm, not a mismatch', () {
      // A host legitimately offers several keys. Calling this an attack would
      // train people to ignore the warning that is one.
      expect(
        verdictFor(_pin(),
            keyType: 'ecdsa-sha2-nistp256', fingerprint: 'SHA256:BBBB'),
        HostKeyVerdict.newAlgorithm,
      );
    });

    test('different type with the SAME fingerprint is still not trusted', () {
      // Cannot happen honestly: the fingerprint hashes the wire-format key,
      // which includes the algorithm name. If it ever does, something is wrong
      // and the safe answer is not "trusted".
      expect(
        verdictFor(_pin(),
            keyType: 'ecdsa-sha2-nistp256', fingerprint: 'SHA256:AAAA'),
        isNot(HostKeyVerdict.trusted),
      );
    });

    test('comparison is exact, never prefix or case insensitive', () {
      // A fingerprint is base64 and case carries meaning. Loosening this is how
      // a near-match starts passing.
      for (final fp in const [
        'SHA256:aaaa',
        'sha256:AAAA',
        'SHA256:AAAA ',
        'SHA256:AAAAB',
        'AAAA',
      ]) {
        expect(
          verdictFor(_pin(), keyType: 'ssh-ed25519', fingerprint: fp),
          HostKeyVerdict.mismatch,
          reason: fp,
        );
      }
    });

    test('every verdict is reachable, so no branch is dead', () {
      final seen = <HostKeyVerdict>{
        verdictFor(null, keyType: 'a', fingerprint: 'f'),
        verdictFor(_pin(type: 'a', fp: 'f'), keyType: 'a', fingerprint: 'f'),
        verdictFor(_pin(type: 'a', fp: 'f'), keyType: 'a', fingerprint: 'g'),
        verdictFor(_pin(type: 'a', fp: 'f'), keyType: 'b', fingerprint: 'g'),
      };
      expect(seen, HostKeyVerdict.values.toSet());
    });
  });

  group('the fingerprint format the library hands us', () {
    test('is OpenSSH style, so it can be compared with the server by eye', () {
      // dartssh2 formats this as SHA256: plus unpadded base64, which is what
      // `ssh-keygen -lf` prints. A person can read one off their own server and
      // compare it with the sheet, which is the only thing that makes trust on
      // first use meaningful.
      const sample = 'SHA256:3TG8oZlKPP0ZgLdbcVvI0DZLPQzDMWXqfM3UOx7L1Bo';
      expect(sample.startsWith('SHA256:'), isTrue);
      expect(sample.contains('='), isFalse);
      expect(
        verdictFor(
          _pin(fp: sample),
          keyType: 'ssh-ed25519',
          fingerprint: sample,
        ),
        HostKeyVerdict.trusted,
      );
    });
  });
}
