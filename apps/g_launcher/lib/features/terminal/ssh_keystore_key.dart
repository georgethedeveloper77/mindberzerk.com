/// An SSH identity whose private key is not in this process.
///
/// ─── THE ONE REASON dartssh2 IS FORKED ──────────────────────────────────────
///
/// [sign] returns a Future, because signing means a biometric prompt and a
/// platform channel. `SSHKeyPair.sign` was declared to return synchronously, so
/// this class could not have existed at all. The fork widens that to `FutureOr`
/// and awaits at the one call site; see `tools/fork_dartssh2.py`.
///
/// ─── WHAT THIS OBJECT DOES NOT HOLD ─────────────────────────────────────────
///
/// No private key, and no way to obtain one. It holds an alias and a public
/// point. Every signature is a round trip to the secure element, which is
/// slower than a software key by exactly the time a person takes to approve it,
/// and that time is the feature.
library;

import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../../platform/keys_api.g.dart';
import 'ssh_key_encoding.dart';

/// Raised when a signature could not be produced, with a reason worth showing.
class SshKeyException implements Exception {
  const SshKeyException(this.failure, this.message);

  final KeyFailure failure;
  final String message;

  /// Should this be shown as an error at all?
  ///
  /// A dismissed prompt is a decision, not a failure. Someone who backed out
  /// knows what they did, and telling them about it is noise.
  bool get isCancellation => failure == KeyFailure.cancelled;

  @override
  String toString() => message;
}

class SshKeystoreKeyPair extends SSHKeyPair {
  SshKeystoreKeyPair({
    required this.alias,
    required this.info,
    required KeysHostApi api,
  }) : _api = api;

  final String alias;
  final KeyInfo info;
  final KeysHostApi _api;

  /// The algorithm, on the wire.
  ///
  /// P-256 rather than Ed25519 because AndroidKeyStore does not support
  /// Ed25519. OpenSSH accepts this, so it works against any server that has not
  /// stripped ECDSA.
  @override
  String get name => kEcdsaP256;

  @override
  String get type => kEcdsaP256;

  @override
  SSHHostKey toPublicKey() {
    // Built from the RAW coordinates the platform gave us, normalised here.
    // Kotlin hands them over untouched precisely so this conversion lives where
    // it is tested against fixed vectors.
    return _EncodedHostKey(
      Uint8List.fromList(encodeP256PublicKeyBlob(x: info.x, y: info.y)),
    );
  }

  /// The line to paste into `authorized_keys`.
  ///
  /// The comment is the alias, which is the device, because one key per device
  /// is what makes revoking a lost phone a single deletion rather than a
  /// rotation of everything.
  String get authorizedKeysLine =>
      openSshPublicKeyLine(x: info.x, y: info.y, comment: alias);

  @override
  Future<SSHSignature> sign(Uint8List data) async {
    final result = await _api.sign(alias, data);

    final failure = result.failure;
    if (failure != null || result.signature == null) {
      throw SshKeyException(
        failure ?? KeyFailure.unknown,
        result.message ?? 'The key could not sign.',
      );
    }

    // The keystore returns ASN.1 DER. SSH wants two mpints wrapped in a string,
    // and handing the DER over directly is rejected by every server with no
    // useful error on either side.
    return _EncodedSignature(
      Uint8List.fromList(ecdsaDerToSshSignature(result.signature!)),
    );
  }

  /// Never. There is no PEM: the private key cannot leave the keystore, which
  /// is the entire point of using one.
  ///
  /// dartssh2 only calls this when SAVING a key, which this app never does for
  /// a keystore identity. Throwing rather than returning something plausible
  /// means a future call site fails loudly instead of writing a file that looks
  /// like a private key and is not.
  @override
  String toPem() => throw UnsupportedError(
        'A keystore key has no exportable form. That is the point of it.',
      );
}


/// ─── WHY THESE TWO EXIST ────────────────────────────────────────────────────
///
/// `SSHHostKey` and `SSHSignature` are abstract and declare exactly one method
/// each: `Uint8List encode()`. There is no `decode` factory and no public
/// constructor, because the package builds its own concrete types internally
/// while parsing, and nothing was ever meant to arrive from outside.
///
/// That turns out to be the easy case. `ssh_client.dart` only ever calls
/// `toPublicKey().encode()` and `signature.encode()`, so a wrapper around bytes
/// satisfies the entire contract. It is also more durable than a factory would
/// have been: this depends on one method name rather than on the shape of a
/// constructor that upstream is free to change.
///
/// The bytes themselves come from `ssh_key_encoding.dart`, where the framing
/// rules are pinned to fixed vectors. Nothing here builds a wire format.

class _EncodedHostKey implements SSHHostKey {
  const _EncodedHostKey(this._bytes);

  final Uint8List _bytes;

  @override
  Uint8List encode() => _bytes;
}

class _EncodedSignature implements SSHSignature {
  const _EncodedSignature(this._bytes);

  final Uint8List _bytes;

  @override
  Uint8List encode() => _bytes;
}
