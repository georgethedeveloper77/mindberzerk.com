import 'package:pigeon/pigeon.dart';

/// The keystore bridge, in a file of its OWN.
///
/// ─── WHY NOT APPEND TO launcher_api OR pack_api ─────────────────────────────
///
/// Pigeon numbers enums before classes and assigns codec ids positionally, so
/// adding a class in the middle of an existing schema shifts the id of
/// everything after it. The failure is silent and total: both sides compile,
/// and every message decodes as the wrong type at runtime.
///
/// A separate schema has its own codec and cannot collide with either existing
/// one. It also costs nothing: the generated files are small and the channel
/// names are namespaced by the api class.
///
/// ─── WHAT CROSSES THIS BRIDGE, AND WHAT NEVER DOES ──────────────────────────
///
/// Across: an alias, a public key's two coordinates, a challenge to sign, and a
/// signature.
///
/// NEVER: the private key. It is generated inside the secure element and is
/// non-extractable by construction, so there is no method here that could
/// return it even by mistake. That absence is the whole security property, and
/// it is worth noticing that this file cannot express it.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/keys_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/mindhunter/g_launcher/keys/KeysApi.g.kt',
    // ITS OWN KOTLIN PACKAGE, for the reason pack_api.dart spells out: Pigeon
    // emits a `FlutterError` class into every generated Kotlin file, and two in
    // one package is a redeclaration error that only appears at compile time.
    kotlinOptions: KotlinOptions(package: 'com.mindhunter.g_launcher.keys'),
    dartPackageName: 'g_launcher',
  ),
)
/// A key that exists in the keystore.
class KeyInfo {
  KeyInfo({
    required this.alias,
    required this.x,
    required this.y,
    required this.hardwareBacked,
    required this.strongBoxBacked,
    required this.createdAtMillis,
  });

  /// The name the user gave it. One key per device, so this is usually the
  /// device: revoking a lost phone is then deleting one line from
  /// `authorized_keys` rather than rotating everything.
  String alias;

  /// The affine coordinates of the public point.
  ///
  /// RAW, exactly as the platform produced them, INCLUDING a BigInteger sign
  /// byte or missing leading zeros. Normalising them here would put that logic
  /// in Kotlin where it cannot be tested against fixed vectors; Dart does it in
  /// `ssh_key_encoding.dart`, which has them.
  Uint8List x;
  Uint8List y;

  /// Whether the private key is held in hardware rather than in software.
  ///
  /// Surfaced because it is the difference between two SECURITY CLAIMS, and the
  /// key manager says which one applies. Claiming hardware backing on a device
  /// that does not have it is worse than not claiming it.
  bool hardwareBacked;

  /// Whether it landed in StrongBox specifically, which is a dedicated secure
  /// chip rather than the TEE. Most phones have a TEE, far fewer have this.
  bool strongBoxBacked;

  int createdAtMillis;
}

/// Why a keystore operation failed, in a form the caller can act on.
///
/// An enum rather than a message, because the three cases need three different
/// responses and only one of them is an error worth showing as one.
enum KeyFailure {
  /// The person dismissed the biometric prompt. Not an error: a cancel.
  cancelled,

  /// A new fingerprint or face was enrolled, so the key was destroyed by the
  /// platform. `setInvalidatedByBiometricEnrollment(true)` is what causes this
  /// and it is the right default; what it needs is copy that explains it and an
  /// offer to regenerate.
  invalidatedByEnrollment,

  /// No biometric or device credential is set up at all, so a key that requires
  /// one cannot be created.
  noAuthenticationConfigured,

  /// Below API 28, where there is no BiometricPrompt to carry a CryptoObject.
  /// The honest answer on such a device is that it cannot hold this kind of
  /// key, not a silently weaker one.
  unsupportedPlatform,

  /// Anything else. [KeyResult.message] carries the detail.
  unknown,
}

/// The outcome of an operation that can fail in a way worth naming.
class KeyResult {
  KeyResult({this.info, this.signature, this.failure, this.message});

  KeyInfo? info;

  /// An ASN.1 DER ECDSA signature, `SEQUENCE { INTEGER r, INTEGER s }`.
  ///
  /// Converted to the SSH wire form in Dart, by `ecdsaDerToSshSignature`. Doing
  /// it here would mean the mpint rules living in Kotlin, untested; there they
  /// are pinned to fixed vectors.
  Uint8List? signature;

  /// Null on success.
  KeyFailure? failure;

  String? message;
}

@HostApi()
abstract class KeysHostApi {
  /// Aliases of every key this app holds.
  List<String> listKeys();

  /// The public part of one key, or null when the alias is unknown.
  KeyInfo? publicKey(String alias);

  /// Generate a P-256 key, non-extractable, requiring authentication per use.
  ///
  /// P-256 rather than Ed25519 because AndroidKeyStore does not support
  /// Ed25519 at all. OpenSSH accepts `ecdsa-sha2-nistp256`, so this works
  /// against any server that has not stripped ECDSA.
  ///
  /// Not async: generation itself needs no prompt. Only signing does.
  KeyResult generateKey(String alias);

  /// Forget a key. Returns false when the alias was already unknown.
  ///
  /// The key is destroyed in the keystore and cannot be recovered, which is why
  /// the caller should say so before calling this and remind the person to
  /// remove the line from `authorized_keys` afterwards.
  bool deleteKey(String alias);

  /// Sign a challenge, behind a biometric prompt.
  ///
  /// ASYNC, and that single word is the reason dartssh2 had to be forked: a
  /// prompt takes as long as a person takes, and `SSHKeyPair.sign` was declared
  /// to return synchronously.
  @async
  KeyResult sign(String alias, Uint8List challenge);
}
