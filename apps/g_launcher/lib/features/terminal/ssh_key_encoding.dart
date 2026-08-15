/// Between the Android keystore and the SSH wire format.
///
/// ─── WHY THIS FILE EXISTS BEFORE ANYTHING ELSE IN THE KEY MANAGER ───────────
///
/// A keystore key never leaves the keystore. What crosses the boundary is a
/// public key and a signature, and both arrive in the shape Java produces
/// rather than the shape SSH expects. Two conversions sit in between, and both
/// fail in ways that look like something else:
///
///   THE PUBLIC KEY. `ECPoint.getAffineX()` hands back a BigInteger, which
///   drops leading zero bytes and can carry an extra one for sign. SSH wants
///   exactly 32 bytes per coordinate. Get it wrong and roughly one key in 256
///   is silently malformed, which presents as a server that rejects your key
///   for no reason anyone can see.
///
///   THE SIGNATURE. The keystore returns ASN.1 DER, `SEQUENCE { INTEGER r,
///   INTEGER s }`. SSH wants two mpints inside a string. Hand the DER over
///   directly and EVERY signature is rejected, with no useful error anywhere.
///
/// Both are pure byte manipulation, so both are tested here rather than
/// discovered on a server.
library;

import 'dart:convert';
import 'dart:typed_data';

/// The algorithm name, on the wire and in `authorized_keys`.
const String kEcdsaP256 = 'ecdsa-sha2-nistp256';

/// The curve identifier SSH uses inside the blob. Not the same string as the
/// algorithm name, and a copy-paste between the two is a key no server accepts.
const String kEcdsaP256Curve = 'nistp256';

/// Bytes per coordinate for P-256. Fixed by the curve, not by the key.
const int kP256CoordinateBytes = 32;

/// A length-prefixed field, which is how everything in SSH is framed.
Uint8List _sshString(List<int> bytes) {
  final out = BytesBuilder();
  out.add([
    (bytes.length >> 24) & 0xff,
    (bytes.length >> 16) & 0xff,
    (bytes.length >> 8) & 0xff,
    bytes.length & 0xff,
  ]);
  out.add(bytes);
  return out.toBytes();
}

/// Left-pad or trim a coordinate to exactly [kP256CoordinateBytes].
///
/// A BigInteger encoding is minimal and signed, so a coordinate whose top bit
/// is set gains a leading zero, and one with small leading bytes loses them.
/// Neither is what the wire format wants.
///
/// Throws on a value that cannot be a P-256 coordinate, because silently
/// truncating one would produce a key that is subtly not the key you generated.
Uint8List normaliseCoordinate(List<int> raw) {
  var bytes = raw;

  // Drop the sign byte a BigInteger adds when the top bit is set.
  while (bytes.length > kP256CoordinateBytes && bytes.first == 0) {
    bytes = bytes.sublist(1);
  }

  if (bytes.length > kP256CoordinateBytes) {
    throw ArgumentError(
      'coordinate is ${bytes.length} bytes, which is not a P-256 coordinate',
    );
  }

  if (bytes.length == kP256CoordinateBytes) return Uint8List.fromList(bytes);

  // Left-pad. A short coordinate is a small number, not a short key.
  final out = Uint8List(kP256CoordinateBytes);
  out.setRange(kP256CoordinateBytes - bytes.length, kP256CoordinateBytes, bytes);
  return out;
}

/// The uncompressed point, `0x04 || X || Y`.
///
/// The 0x04 prefix says uncompressed. SSH does not accept the compressed forms,
/// so it is a constant rather than a choice.
Uint8List encodeP256Point(List<int> x, List<int> y) {
  final out = BytesBuilder();
  out.addByte(0x04);
  out.add(normaliseCoordinate(x));
  out.add(normaliseCoordinate(y));
  return out.toBytes();
}

/// The public key blob: three length-prefixed fields.
Uint8List encodeP256PublicKeyBlob({required List<int> x, required List<int> y}) {
  final out = BytesBuilder();
  out.add(_sshString(utf8.encode(kEcdsaP256)));
  out.add(_sshString(utf8.encode(kEcdsaP256Curve)));
  out.add(_sshString(encodeP256Point(x, y)));
  return out.toBytes();
}

/// The single line that goes in `authorized_keys`.
///
/// `ecdsa-sha2-nistp256 <base64 blob> <comment>`. The comment is free text and
/// exists so a person can tell which device a key belongs to when they come to
/// revoke one, which is the whole reason keys are per device.
String openSshPublicKeyLine({
  required List<int> x,
  required List<int> y,
  String? comment,
}) {
  final blob = base64.encode(encodeP256PublicKeyBlob(x: x, y: y));
  final c = comment?.trim();
  return c == null || c.isEmpty
      ? '$kEcdsaP256 $blob'
      : '$kEcdsaP256 $blob $c';
}

/// An SSH mpint: big-endian, minimal, and zero-prefixed when the top bit is set.
///
/// The leading zero is not padding, it is a SIGN BIT. Without it a value above
/// 0x7f reads as negative and the signature is rejected, which is the failure
/// that looks like a wrong key rather than a wrong encoding.
Uint8List encodeMpint(List<int> value) {
  var bytes = value;

  // Minimal: strip leading zeros, but never down to nothing.
  var i = 0;
  while (i < bytes.length - 1 && bytes[i] == 0) {
    i++;
  }
  bytes = bytes.sublist(i);

  // Zero itself is an empty mpint.
  if (bytes.length == 1 && bytes[0] == 0) return Uint8List(0);

  if (bytes[0] & 0x80 != 0) {
    final out = Uint8List(bytes.length + 1);
    out.setRange(1, out.length, bytes);
    return out;
  }
  return Uint8List.fromList(bytes);
}

/// The two integers inside an ECDSA DER signature.
///
/// Structure: `30 <len> 02 <len> r 02 <len> s`. Deliberately a small hand
/// parser rather than a dependency: this reads exactly one shape, and anything
/// that is not that shape is rejected rather than half-understood.
({Uint8List r, Uint8List s}) parseEcdsaDer(List<int> der) {
  var i = 0;

  int readByte() {
    if (i >= der.length) throw FormatException('DER ended early at $i');
    return der[i++];
  }

  /// DER lengths are short form below 128, otherwise a count byte then the
  /// length itself. Long form is legal here and does appear, since a P-256
  /// signature sequence can exceed 127 bytes.
  int readLength() {
    final first = readByte();
    if (first & 0x80 == 0) return first;
    final count = first & 0x7f;
    if (count == 0 || count > 4) {
      throw FormatException('unsupported DER length form: $first');
    }
    var len = 0;
    for (var n = 0; n < count; n++) {
      len = (len << 8) | readByte();
    }
    return len;
  }

  if (readByte() != 0x30) {
    throw const FormatException('not a DER SEQUENCE');
  }
  final seqLen = readLength();
  if (seqLen > der.length - i) {
    throw const FormatException('DER sequence longer than the buffer');
  }

  Uint8List readInteger() {
    if (readByte() != 0x02) throw const FormatException('expected DER INTEGER');
    final len = readLength();
    if (len <= 0 || i + len > der.length) {
      throw const FormatException('DER integer out of bounds');
    }
    final v = Uint8List.fromList(der.sublist(i, i + len));
    i += len;
    return v;
  }

  final r = readInteger();
  final s = readInteger();
  return (r: r, s: s);
}

/// Turn a keystore signature into the one SSH expects.
///
/// `string "ecdsa-sha2-nistp256"` then `string (mpint r || mpint s)`. The inner
/// pair is itself wrapped, which is easy to miss and produces a signature the
/// server rejects without saying why.
Uint8List ecdsaDerToSshSignature(List<int> der) {
  final parsed = parseEcdsaDer(der);

  final inner = BytesBuilder()
    ..add(_sshString(encodeMpint(parsed.r)))
    ..add(_sshString(encodeMpint(parsed.s)));

  final out = BytesBuilder()
    ..add(_sshString(utf8.encode(kEcdsaP256)))
    ..add(_sshString(inner.toBytes()));

  return out.toBytes();
}
