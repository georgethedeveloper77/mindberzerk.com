# The key manager

Companion to `docs/terminal_commands.md`.

## The fork, and why there is one

An Android keystore key is non-extractable: the private key never leaves the
secure element, and signing means asking the platform, which means a biometric
prompt and a channel hop. Both are futures.

`SSHKeyPair.sign` is declared to return `SSHSignature` synchronously, so a
keystore key cannot satisfy the interface. That is the only reason for the fork
and it is the whole of it.

    cp -R ~/.pub-cache/hosted/pub.dev/dartssh2-2.22.5 third_party/dartssh2
    python3 tools/fork_dartssh2.py third_party/dartssh2

Then in `pubspec.yaml`:

    dependency_overrides:
      dartssh2:
        path: third_party/dartssh2

Twenty-two changed lines, most of them comments. `FutureOr` rather than `Future`
is what keeps it small: every existing implementation keeps its synchronous body
and still satisfies the new signature, so only the one path that awaits changes.
`_catch` already exists and is already how `_authWithPassword` is dispatched, so
the error handling is the package's own.

One edit is not in the auth path at all: `lib/dartssh2.dart` does not export
`src/ssh_hostkey.dart`, so `SSHSignature` and `SSHHostKey` are invisible outside
the package. `SSHKeyPair` IS exported, and its `sign` returns an `SSHSignature`,
which means the interface is public and two of the types in its own signature
are not. Implementing it from application code is impossible without that
export, so the fork adds it rather than reaching into
`package:dartssh2/src/...`, which works today and breaks on any upgrade that
moves the file.

Another edit is in `ssh_agent.dart` rather than the auth path, and it goes
the other way: agent forwarding stays SYNCHRONOUS and refuses an asynchronous
identity. Forwarding exposes your keys to the remote host, this app does not use
it, and `SSHClient` only consults `agentHandler` when opening a channel rather
than when authenticating. Making it async would have doubled the fork for a
feature that is not shipped, and a hardware-backed key that cannot be forwarded
is correct anyway: the point of a non-extractable key is that it signs only
where it lives.

Re-run the script after any version bump. Every edit asserts its anchor matched
exactly once, so a version that moved the code fails loudly rather than
silently reverting the fork.

## Why P-256 and not Ed25519

AndroidKeyStore supports RSA and EC, not Ed25519. So the choice was:

**EC P-256 in the keystore**, hardware-backed, non-extractable, biometric per
use. OpenSSH accepts `ecdsa-sha2-nistp256`, so it works against any server that
has not stripped ECDSA, and the droplet has not.

**Ed25519 encrypted at rest** under a keystore AES key. The key material exists
in process memory for each signature.

Both fall to root-level malware on the phone, and it is tempting to call them
equivalent. They are not, and the difference is what happens after. A software
key can be taken and used from anywhere, indefinitely, silently, long after the
phone is wiped. A non-extractable key cannot be taken: signatures happen inside
the secure element and only while the attacker is resident AND the person
approves each one. That is the difference between a breach and a permanent
invisible credential leak, and for a key that opens a server it is worth a fork.

## The two encodings

`lib/features/terminal/ssh_key_encoding.dart`, and both fail in ways that look
like something else.

**The public key.** `ECPoint.getAffineX` returns a `BigInteger`, which drops
leading zero bytes and can add one for sign. SSH wants exactly 32 bytes per
coordinate. Wrong, and roughly one key in 256 is silently malformed, which
presents as a server rejecting you for no visible reason. Short values are LEFT
padded: a short coordinate is a small number, and padding the wrong side still
gives 32 bytes and still fails.

**The signature.** The keystore returns DER, `SEQUENCE { INTEGER r, INTEGER s }`.
SSH wants two mpints wrapped in a string. Hand over the DER and every signature
is rejected with no useful error anywhere. The mpint leading zero is a sign bit
rather than padding, and the wrapper around both mpints is easy to miss.

Both are pure functions with fixed vectors, so they are checked in a test rather
than against a server.

## Keystore parameters

    KeyGenParameterSpec.Builder("gl_ssh_$alias", PURPOSE_SIGN)
        .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
        .setDigests(DIGEST_SHA256)
        .setUserAuthenticationRequired(true)
        .setInvalidatedByBiometricEnrollment(true)

`minSdk` is 26, and the per-use authentication API is not the same across that
range:

- API 30 and above: `setUserAuthenticationParameters(0, AUTH_BIOMETRIC_STRONG or
  AUTH_DEVICE_CREDENTIAL)`. A timeout of zero means per use, which is what makes
  a `CryptoObject` mandatory and therefore meaningful.
- API 26 to 29: `setUserAuthenticationValidityDurationSeconds(-1)`, the
  deprecated spelling of the same thing.

Getting this wrong does not fail: a non-zero timeout authenticates once and
signs freely for the window, silently weaker than intended.

Try `setIsStrongBoxBacked(true)` first and catch `StrongBoxUnavailableException`.
Most phones have a TEE, far fewer have StrongBox, and a generate that just fails
on a mid-range device is worse than one that quietly lands in the TEE. Record
which was used and show it in the key manager, because it is the difference
between two security claims.

`setInvalidatedByBiometricEnrollment(true)` means enrolling a new fingerprint
destroys the key. That is the right default and it needs copy that says so:
catch `KeyPermanentlyInvalidatedException` on `initSign`, say the key was
invalidated by a biometric change, offer to regenerate, and remind the person to
remove the old line from `authorized_keys`.

`initSign` happens BEFORE the prompt. The `CryptoObject` has to wrap an already
initialised `Signature`, and calling `update` on a per-use key without
authenticating throws `UserNotAuthenticatedException`.

## Retiring password auth

Once keys work, on the droplet:

    # delete the Match User gphone block from /etc/ssh/sshd_config
    sshd -t && systemctl reload sshd

Keep a session open until a key login succeeds. Password auth exists only
because keys were one phase away, and it is the weakest thing about the current
setup.

## One key per device

Never share one across phones. Revoking a lost device is then deleting one line
from `authorized_keys` rather than rotating everything, which is the entire
reason the public key line carries a comment.
