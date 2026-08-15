// Both conversions in this file fail in ways that look like something else: a
// malformed key presents as a server rejecting you for no reason, and a
// malformed signature presents as a wrong key. Neither produces a useful error
// anywhere, which is why they are tested against fixed vectors here rather than
// discovered against a real host.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/terminal/ssh_key_encoding.dart';

/// `30 <len> 02 <len> r 02 <len> s`, built the way a keystore would.
Uint8List der(List<int> r, List<int> s) {
  List<int> integer(List<int> v) {
    var b = [...v];
    var i = 0;
    while (i < b.length - 1 && b[i] == 0) {
      i++;
    }
    b = b.sublist(i);
    if (b[0] & 0x80 != 0) b = [0, ...b];
    return [0x02, b.length, ...b];
  }

  final body = [...integer(r), ...integer(s)];
  return Uint8List.fromList([0x30, body.length, ...body]);
}

void main() {
  group('normaliseCoordinate', () {
    test('a full coordinate is unchanged', () {
      final x = List.filled(32, 0x01);
      expect(normaliseCoordinate(x).length, 32);
      expect(normaliseCoordinate(x), x);
    });

    test('the BigInteger sign byte is stripped', () {
      // getAffineX adds a leading zero when the top bit is set. SSH wants 32
      // bytes, and 33 is rejected.
      final x = [0x00, ...List.filled(32, 0xff)];
      final out = normaliseCoordinate(x);
      expect(out.length, 32);
      expect(out.first, 0xff);
    });

    test('a short coordinate is LEFT padded', () {
      // A small number, not a short key. Padding on the wrong side changes the
      // value, which is the version of this bug that still produces 32 bytes
      // and still fails.
      final out = normaliseCoordinate([0x01, 0x02, 0x03]);
      expect(out.length, 32);
      expect(out.sublist(0, 29), List.filled(29, 0));
      expect(out.sublist(29), [0x01, 0x02, 0x03]);
    });

    test('a value that cannot be a coordinate throws', () {
      // Truncating would produce a key that is subtly not the key generated,
      // and it would be accepted by nothing while looking correct.
      expect(
        () => normaliseCoordinate(List.filled(40, 0x01)),
        throwsArgumentError,
      );
    });
  });

  group('the public key', () {
    // A fixed point, so the expected bytes below are arithmetic rather than
    // whatever the code happens to produce.
    final x = List.generate(32, (i) => i + 1);
    final y = List.generate(32, (i) => i + 33);

    test('the point is uncompressed and 65 bytes', () {
      final p = encodeP256Point(x, y);
      expect(p.length, 65);
      expect(p.first, 0x04);
    });

    test('the blob is three length-prefixed fields', () {
      // 4+19 for the name, 4+8 for the curve, 4+65 for the point.
      expect(encodeP256PublicKeyBlob(x: x, y: y).length, 104);
    });

    test('the blob names the algorithm first', () {
      final blob = encodeP256PublicKeyBlob(x: x, y: y);
      expect(utf8.decode(blob.sublist(4, 4 + 19)), kEcdsaP256);
    });

    test('the curve name is not the algorithm name', () {
      // A copy-paste between the two produces a key no server accepts, and the
      // two strings look similar enough to make that easy.
      expect(kEcdsaP256Curve, 'nistp256');
      expect(kEcdsaP256, 'ecdsa-sha2-nistp256');
      final blob = encodeP256PublicKeyBlob(x: x, y: y);
      expect(utf8.decode(blob.sublist(27, 27 + 8)), kEcdsaP256Curve);
    });

    test('the authorized_keys line round trips', () {
      final line = openSshPublicKeyLine(x: x, y: y, comment: 'george@pixel');
      final parts = line.split(' ');

      expect(parts.length, 3);
      expect(parts[0], kEcdsaP256);
      expect(parts[2], 'george@pixel');
      expect(base64.decode(parts[1]), encodeP256PublicKeyBlob(x: x, y: y));
    });

    test('a known point produces a known line', () {
      // Fixed vector. If this changes, the encoding changed, and every key
      // already installed on a server stops matching.
      expect(
        openSshPublicKeyLine(x: x, y: y),
        'ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAA'
        'ABBBAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vM'
        'DEyMzQ1Njc4OTo7PD0+P0A=',
      );
    });

    test('an empty comment is omitted rather than leaving a trailing space', () {
      expect(openSshPublicKeyLine(x: x, y: y).endsWith('='), isTrue);
      expect(openSshPublicKeyLine(x: x, y: y, comment: '   ').split(' ').length,
          2);
    });
  });

  group('encodeMpint', () {
    test('a value with the top bit clear is unchanged', () {
      expect(encodeMpint([0x7f]), [0x7f]);
    });

    test('a value with the top bit set gains a sign byte', () {
      // Not padding. Without it the value reads as negative and the signature
      // is rejected, which is the failure that looks like a wrong key.
      expect(encodeMpint([0x80]), [0x00, 0x80]);
      expect(encodeMpint([0xff, 0xff]), [0x00, 0xff, 0xff]);
    });

    test('leading zeros are stripped, because mpint is minimal', () {
      expect(encodeMpint([0x00, 0x00, 0x01]), [0x01]);
    });

    test('zero is the empty string', () {
      expect(encodeMpint([0x00]), isEmpty);
    });
  });

  group('parseEcdsaDer', () {
    test('reads r and s', () {
      final d = der([0x01, 0x02], [0x03, 0x04]);
      final parsed = parseEcdsaDer(d);
      expect(parsed.r, [0x01, 0x02]);
      expect(parsed.s, [0x03, 0x04]);
    });

    test('keeps the DER sign byte, which mpint will handle', () {
      final d = der([0x80, 0x11], [0x01]);
      expect(parseEcdsaDer(d).r.first, 0x00);
    });

    test('rejects anything that is not a SEQUENCE of two INTEGERs', () {
      expect(() => parseEcdsaDer([0x31, 0x02, 0x02, 0x00]),
          throwsA(isA<FormatException>()));
      expect(() => parseEcdsaDer([0x30]), throwsA(isA<FormatException>()));
      expect(() => parseEcdsaDer([0x30, 0x02, 0x04, 0x00]),
          throwsA(isA<FormatException>()));
    });

    test('a truncated buffer throws rather than reading past the end', () {
      final d = der(List.filled(32, 0x11), List.filled(32, 0x22));
      expect(() => parseEcdsaDer(d.sublist(0, d.length - 5)),
          throwsA(isA<FormatException>()));
    });
  });

  group('ecdsaDerToSshSignature', () {
    test('produces the two-field wire form', () {
      final r = [0x80, ...List.filled(31, 0x11)];
      final s = [0x00, 0x00, ...List.filled(30, 0x22)];
      final sig = ecdsaDerToSshSignature(der(r, s));

      // The name comes first.
      expect(utf8.decode(sig.sublist(4, 4 + 19)), kEcdsaP256);

      // Then a string wrapping BOTH mpints. The inner wrapper is the part
      // that is easy to miss, and omitting it is rejected with no explanation.
      final innerLen = (sig[23] << 24) | (sig[24] << 16) | (sig[25] << 8) | sig[26];
      expect(innerLen, sig.length - 27);
    });

    test('the inner length is exactly the two framed mpints', () {
      final parsed = parseEcdsaDer(der([0x80, 0x11], [0x22]));
      final expected =
          4 + encodeMpint(parsed.r).length + 4 + encodeMpint(parsed.s).length;

      final sig = ecdsaDerToSshSignature(der([0x80, 0x11], [0x22]));
      final innerLen = (sig[23] << 24) | (sig[24] << 16) | (sig[25] << 8) | sig[26];
      expect(innerLen, expected);
    });

    test('a full-size signature is the length OpenSSH produces', () {
      // Both coordinates with the top bit set, so both gain a sign byte:
      // 4+19 name, 4 inner, then 4+33 twice.
      final sig = ecdsaDerToSshSignature(
        der(List.filled(32, 0xff), List.filled(32, 0xff)),
      );
      expect(sig.length, 4 + 19 + 4 + (4 + 33) * 2);
    });

    test('malformed DER throws rather than producing a plausible signature', () {
      // A signature that looks well formed and is wrong would be rejected by
      // the server with no diagnosis available on either side.
      expect(() => ecdsaDerToSshSignature([0x00, 0x01]),
          throwsA(isA<FormatException>()));
    });
  });
}
