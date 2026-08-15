#!/usr/bin/env python3
"""Fork dartssh2 so a key can sign asynchronously.

Run against a VENDORED copy, never against ~/.pub-cache: a pub cache is
regenerated without warning and a fork living there disappears between machines.

    cp -R ~/.pub-cache/hosted/pub.dev/dartssh2-2.22.5 third_party/dartssh2
    python3 tools/fork_dartssh2.py third_party/dartssh2

Then in pubspec.yaml:

    dependency_overrides:
      dartssh2:
        path: third_party/dartssh2

── WHY THIS FORK EXISTS ──────────────────────────────────────────────────────

An Android keystore key is non-extractable by design: the private key never
leaves the secure element, and signing means asking the platform, which means a
biometric prompt and a channel hop. Both are futures.

`SSHKeyPair.sign` is declared to return `SSHSignature` synchronously, so a
keystore key cannot satisfy the interface at all. That is the whole reason a
fork is needed, and it is the only reason.

── WHY IT IS THIS SMALL ──────────────────────────────────────────────────────

Four edits. `FutureOr` rather than `Future` is the trick: every existing
implementation (Ed25519, RSA, EC from a PEM) keeps its synchronous body and
still satisfies the new signature, so nothing in the package changes except the
one path that now awaits. And `_catch` already exists, already takes a
`FutureOr`, and is already how `_authWithPassword` is dispatched, so the error
handling is the package's own rather than something invented.

Anything larger than this should be treated as suspicious. This sits in the
authentication path of a package handling credentials, and the diff being
readable in one sitting is most of what makes it safe to carry.

── ON UPGRADES ───────────────────────────────────────────────────────────────

Re-run this after bumping the vendored version. Every edit asserts its anchor
matched exactly once, so a version that moved the code fails loudly here rather
than silently reverting the fork.
"""

import sys
import pathlib

EDITS = [
    (
        "lib/src/ssh_key_pair.dart",
        "the abstract signature",
        "  SSHSignature sign(Uint8List data);",
        """  /// FORKED: was `SSHSignature sign(Uint8List data)`.
  ///
  /// FutureOr, not Future, so every implementation in this package keeps its
  /// synchronous body and still satisfies this. The one caller awaits, which is
  /// free for a sync return and is what lets a key that lives in a hardware
  /// keystore be an identity at all: signing there needs a biometric prompt and
  /// a platform channel, and both are asynchronous.
  FutureOr<SSHSignature> sign(Uint8List data);""",
    ),
    (
        "lib/src/ssh_key_pair.dart",
        "the dart:async import",
        "import 'dart:convert';",
        "import 'dart:async';\nimport 'dart:convert';",
    ),
    (
        "lib/src/ssh_client.dart",
        "awaiting the signature",
        """  void _authWithNextPublicKey() {
    printDebug?.call('SSHClient._authWithPublicKey');

    final keyPair = _keyPairsLeft.removeFirst();

    final challenge = _transport.composeChallenge(
      username: username,
      service: 'ssh-connection',
      publicKeyAlgorithm: keyPair.type,
      publicKey: keyPair.toPublicKey().encode(),
    );

    _sendMessage(
      SSH_Message_Userauth_Request.publicKey(
        username: username,
        publicKeyAlgorithm: keyPair.type,
        publicKey: keyPair.toPublicKey().encode(),
        signature: keyPair.sign(challenge).encode(),
        // signature: null,
      ),
    );
  }""",
        """  /// FORKED: was synchronous.
  ///
  /// The challenge is composed before the await and the message is sent after
  /// it, which is the same order as before. What changed is that the signature
  /// may now take as long as a biometric prompt takes, and the transport is
  /// simply idle in the meantime rather than blocked.
  Future<void> _authWithNextPublicKey() async {
    printDebug?.call('SSHClient._authWithPublicKey');

    final keyPair = _keyPairsLeft.removeFirst();

    final challenge = _transport.composeChallenge(
      username: username,
      service: 'ssh-connection',
      publicKeyAlgorithm: keyPair.type,
      publicKey: keyPair.toPublicKey().encode(),
    );

    final signature = await keyPair.sign(challenge);

    _sendMessage(
      SSH_Message_Userauth_Request.publicKey(
        username: username,
        publicKeyAlgorithm: keyPair.type,
        publicKey: keyPair.toPublicKey().encode(),
        signature: signature.encode(),
      ),
    );
  }""",
    ),
    (
        "lib/src/ssh_client.dart",
        "the two dispatch sites",
        """    if (_currentAuthMethod == SSHAuthMethod.publicKey) {
      if (_keyPairsLeft.isNotEmpty) {
        return _authWithNextPublicKey();
      }
    }""",
        """    if (_currentAuthMethod == SSHAuthMethod.publicKey) {
      if (_keyPairsLeft.isNotEmpty) {
        // FORKED: wrapped, because this is now a Future and a rejection inside
        // it would otherwise be an unhandled error rather than a closed
        // transport. `_catch` is the package's own handling, and it is already
        // how _authWithPassword is dispatched two lines below.
        return _catch(() => _authWithNextPublicKey());
      }
    }""",
    ),
    (
        "lib/dartssh2.dart",
        "exporting the host key types",
        """export 'src/ssh_forward.dart';
export 'src/ssh_key_pair.dart';""",
        """export 'src/ssh_forward.dart';
// FORKED.
//
// `SSHKeyPair` is exported and its `sign` returns an `SSHSignature`, but the
// file declaring `SSHSignature` and `SSHHostKey` is not. So the interface is
// public and two of the types in its signature are not, which means it cannot
// be implemented from outside the package at all.
//
// That is almost certainly an oversight upstream rather than a decision: every
// other type reachable from a public signature is exported. Either way, an
// application implementing `SSHKeyPair` needs these names, and the alternative
// is importing `package:dartssh2/src/ssh_hostkey.dart` directly, which works
// today and breaks on any upgrade that moves the file.
export 'src/ssh_hostkey.dart';
export 'src/ssh_key_pair.dart';""",
    ),
    (
        "lib/src/ssh_agent.dart",
        "the agent path, which stays synchronous",
        "  return identity.sign(data);",
        """  // FORKED.
  //
  // This is AGENT FORWARDING: exposing your identities to the remote host so
  // that it can sign on your behalf. This app does not use it. `SSHClient` only
  // consults `agentHandler` when opening a channel, never when authenticating,
  // which is why the async signer did not need this path in the first place.
  //
  // It stays SYNCHRONOUS on purpose. Making it async means making
  // `_handleSignRequest` async, and `handleRequest` above it, which roughly
  // doubles the fork for a feature that is not shipped.
  //
  // A hardware-backed key therefore cannot be forwarded, and that is correct
  // rather than a limitation: the point of a non-extractable key is that it
  // signs only where it lives, and forwarding it to a server is the nearest
  // thing to lending it out. Failing loudly here beats a cast that throws
  // somewhere less obvious.
  final signature = identity.sign(data);
  if (signature is! SSHSignature) {
    throw UnsupportedError(
      'This identity signs asynchronously and cannot be used over agent '
      'forwarding.',
    );
  }
  return signature;""",
    ),
    (
        "lib/src/ssh_client.dart",
        "the switch arm",
        """      case SSHAuthMethod.publicKey:
        return _authWithNextPublicKey();""",
        """      case SSHAuthMethod.publicKey:
        // FORKED: see above.
        return _catch(() => _authWithNextPublicKey());""",
    ),
]


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2

    root = pathlib.Path(sys.argv[1])
    if not (root / "lib" / "src" / "ssh_client.dart").exists():
        print(f"not a dartssh2 checkout: {root}")
        return 2

    already = 0
    for rel, label, old, new in EDITS:
        path = root / rel
        text = path.read_text(encoding="utf-8")

        if new in text:
            print(f"  already applied  {label}")
            already += 1
            continue

        count = text.count(old)
        if count != 1:
            print(f"  FAILED  {label}: anchor matched {count} times in {rel}")
            print("  The vendored version moved. Re-read the source before")
            print("  forcing this through: it is the authentication path.")
            return 1

        path.write_text(text.replace(old, new), encoding="utf-8")
        print(f"  applied          {label}")

    if already == len(EDITS):
        print("\nNothing to do; the fork is already in place.")
    else:
        print("\nForked. Run `flutter analyze` before anything else.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
