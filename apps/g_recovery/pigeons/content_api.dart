import 'package:pigeon/pigeon.dart';

/// THE SOURCE OF TRUTH for the content bridge: signed packs from the CDN.
///
/// Regenerate after ANY edit here:
///
///   cd apps/g_recovery
///   dart run pigeon --input pigeons/content_api.dart
///
/// Outputs (both generated, never hand-edit):
///   lib/bridge/content_api.g.dart
///   android/app/src/main/kotlin/com/mindhunter/g_recovery/content/ContentApi.g.kt
///
/// Fourth schema, own subpackage, because Pigeon emits a `FlutterError` class
/// into every generated Kotlin file.
///
/// NO SHELL GLOBS IN DOC COMMENTS. A star before a slash closes the generated
/// KDoc early and the rest lands inside a Kotlin constructor.
///
/// ─── DECLARATION ORDER IS THE WIRE FORMAT ───────────────────────────────────
///
///   129 ContentPackInfo    130 ContentSyncResult
///
/// ADD NEW TYPES AT THE END. No enums, ever.
///
/// ─── WHY THIS IS A BRIDGE AND NOT DART HTTP ─────────────────────────────────
///
/// Fetching JSON in Dart would be less code. Verification is the reason it is
/// not: the ed25519 check has to run on the same side that writes the file, or
/// there is a window where unverified bytes are on disk and something else can
/// read them. The launcher already proved this pipeline against the real
/// signing key, and the Kotlin here is a port of it rather than a second
/// implementation of the same rules.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/bridge/content_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/mindhunter/g_recovery/content/ContentApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.mindhunter.g_recovery.content'),
    dartPackageName: 'g_recovery',
  ),
)

/// One content pack, as the client sees it. Codec 129.
class ContentPackInfo {
  ContentPackInfo({
    required this.packId,
    required this.packType,
    required this.version,
    required this.installedVersion,
    required this.sizeBytes,
  });

  /// "trashmap", "learn-en", "oem-guide".
  final String packId;

  /// "registry" for the trashmap, "article" for Learn. A String, because an
  /// enum would renumber the schema.
  final String packType;

  /// What the signed index advertises. 0 when the index has not been read.
  final int version;

  /// What is on disk and verified. 0 when nothing is installed and the app is
  /// running on its bundled copy.
  final int installedVersion;

  final int sizeBytes;
}

/// The outcome of one sync. Codec 130.
class ContentSyncResult {
  ContentSyncResult({
    required this.status,
    required this.detail,
    required this.changed,
    required this.packs,
  });

  /// "updated" | "upToDate" | "offline" | "rejected" | "failed"
  ///
  /// A RESULT OBJECT RATHER THAN A THROWN ERROR, and the statuses are not
  /// interchangeable. `offline` is the ordinary case on a phone in a lift and
  /// deserves silence. `rejected` means a signature failed, which should be
  /// reported and NEVER retried, because retrying a bad signature just fetches
  /// the same bad bytes again. Only `failed` is worth a retry button.
  final String status;

  final String detail;

  /// True when something on disk changed and callers should re-read.
  final bool changed;

  final List<ContentPackInfo> packs;
}

@HostApi()
abstract class ContentHostApi {
  /// The CDN root, for example the g-recovery folder under the Mindberzerk CDN.
  ///
  /// Pushed from Dart so the host can move without a Kotlin change, exactly as
  /// the launcher does it. Validated natively before use: https only, no path
  /// traversal. A base URL that arrives from anywhere other than a constant is
  /// still a value to check, not a value to trust.
  @async
  void setBaseUrl(String url);

  /// Fetch the signed index, verify it, and install any pack that is newer.
  ///
  /// Safe to call on every launch: the index request carries an ETag, so the
  /// common case is a 304 with no body.
  @async
  ContentSyncResult sync();

  /// The verified JSON for a content id, or null when nothing is installed.
  ///
  /// Null is the ORDINARY answer, not an error. It means the app should use its
  /// bundled copy, which is what happens on first launch and whenever the CDN
  /// is unreachable.
  @async
  String? readContent(String packId);

  /// What is installed right now, without touching the network.
  @async
  List<ContentPackInfo> packs();
}
