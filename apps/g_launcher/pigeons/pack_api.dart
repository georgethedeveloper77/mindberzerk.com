import 'package:pigeon/pigeon.dart';

/// PHASE C — the pack and storefront bridge.
///
/// A SEPARATE SCHEMA FILE, NOT AN ADDITION TO `launcher_api.dart`, and that is
/// the whole reason this exists as its own file.
///
/// Pigeon generates ONE codec per schema, assigning ids to classes and enums by
/// their order in the file. `launcher_api.dart` carries ids 129-133 for
/// AppEntry, IconStyle and friends, and those ids are baked into a shipped APK
/// on one side and a Kotlin data class on the other. Appending is safe;
/// inserting is not, and neither is adding an enum, because enum ids are
/// positional too. Giving the store its own schema removes the chance entirely:
/// nothing here can shift anything there.
///
/// It also keeps the surfaces honest. The app list and the icon engine are one
/// concern; downloading and paying for content is another, and it has a
/// different implementation, a different thread model and a different failure
/// vocabulary.
///
/// Regenerate with:
///   dart run pigeon --input pigeons/pack_api.dart
///
/// KEEP THIS FILE. The schema source for `launcher_api.dart` was lost once and
/// had to be reconstructed by hand from the generated output. Generated code is
/// not a backup of its own source.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/pack_api.g.dart',
    // ITS OWN KOTLIN PACKAGE, and this is not cosmetic.
    //
    // Pigeon emits a `FlutterError` class into every generated Kotlin file. Two
    // schemas in the same package is a straight redeclaration error, and it
    // only appears at COMPILE time, long after both files look fine.
    //
    // The codec is already isolated by being a separate schema; this isolates
    // the generated types too, which is the half I missed first time round.
    kotlinOut:
        'android/app/src/main/kotlin/com/mindhunter/g_launcher/pack/PackApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.mindhunter.g_launcher.pack'),
    dartPackageName: 'g_launcher',
  ),
)
/// A pack, as the storefront needs to draw it.
///
/// Deliberately NOT a mirror of Kotlin's `CdnPack`. That type carries the
/// remote path and the signed file list, and a screen that knows the CDN path
/// is a screen that could be tempted to fetch it. This is the presentation
/// subset and nothing more.
class PackInfo {
  PackInfo({
    required this.packId,
    required this.packType,
    required this.title,
    required this.summary,
    required this.version,
    required this.installedVersion,
    required this.sizeBytes,
    required this.state,
    required this.unlocked,
    this.sku,
  });

  final String packId;

  /// "theme", "brand", "hero", "icon".
  ///
  /// A STRING, NOT AN ENUM, on purpose. Pigeon assigns enum ids positionally,
  /// so adding a pack type later would renumber the codec; and a pack type the
  /// client does not recognise must degrade to "ignore it", not "fail to
  /// parse". Same rule `brandTreatment` follows in the other schema.
  final String packType;

  final String title;
  final String summary;

  /// What the catalogue advertises.
  final int version;

  /// What is on disk. 0 when nothing is installed.
  final int installedVersion;

  final int sizeBytes;

  /// "available" | "installed" | "updateAvailable" | "bundled" |
  /// "requiresAppUpdate". String for the same reason as [packType].
  ///
  /// `requiresAppUpdate` is a state and not an error because the action differs:
  /// the user must update the app, and a storefront that shows a Get button
  /// there is lying to them.
  final String state;

  /// Whether this device may install it.
  ///
  /// Resolved NATIVELY against the signed index's entitlement grants and the
  /// owned-SKU set, so the rule lives in exactly one place
  /// (`CdnIndex.isUnlocked`) rather than being reimplemented in Dart where it
  /// would drift. Free packs are always true.
  final bool unlocked;

  /// null = free. PRESENTATION ONLY: it tells the card which price to draw.
  /// Ownership is Play's answer and is already folded into [unlocked].
  final String? sku;
}

/// A purchasable bundle, as advertised by the signed index.
class BundleInfo {
  BundleInfo({
    required this.sku,
    required this.title,
    required this.summary,
    required this.grantsAll,
    required this.grantedPackIds,
    required this.owned,
  });

  final String sku;
  final String title;
  final String summary;

  /// True when the bundle grants every pack, present AND FUTURE. Surfaced as a
  /// flag rather than an expanded list because expanding it would quietly break
  /// the promise the store listing makes: buy the complete collection and packs
  /// that ship later are covered.
  final bool grantsAll;

  /// Explicit grants. Empty when [grantsAll]. May name a pack that has not
  /// shipped yet, so a bundle can be announced before its contents are live.
  final List<String> grantedPackIds;

  final bool owned;
}

/// Progress for one in-flight download.
class PackProgress {
  PackProgress({
    required this.packId,
    required this.bytesDone,
    required this.bytesTotal,
  });

  final String packId;
  final int bytesDone;

  /// From the SIGNED manifest, so it is a real number rather than a
  /// Content-Length the origin can lie about.
  final int bytesTotal;
}

/// The outcome of an install attempt.
///
/// A RESULT OBJECT RATHER THAN A THROWN ERROR, because most of these are not
/// errors. `upToDate` is the common case and must be silent; `noSpace` and
/// `appTooOld` are user-actionable and need different copy; `rejected` means a
/// signature failed and should be reported, never retried; only `failed` is
/// worth a retry button. Collapsing them into an exception produces the
/// "Download failed" dialog that tells nobody anything.
class PackResult {
  PackResult({
    required this.packId,
    required this.status,
    required this.detail,
    required this.installedVersion,
  });

  final String packId;

  /// "installed" | "upToDate" | "notOffered" | "appTooOld" | "noSpace" |
  /// "cancelled" | "rejected" | "notEntitled" | "failed"
  final String status;

  /// Human-readable, for logs and for the rare case worth showing. Never the
  /// primary thing the UI branches on; branch on [status].
  final String detail;

  final int installedVersion;
}

@HostApi()
abstract class PackHostApi {
  /// Everything the catalogue knows, merged with what is on disk.
  ///
  /// Reads the CACHED index only. It never touches the network, so the
  /// storefront opens instantly and works on a plane. [refreshCatalogue] is the
  /// explicit network call.
  @async
  List<PackInfo> catalogue();

  /// The bundles, with ownership already resolved.
  @async
  List<BundleInfo> bundles();

  /// Fetch a newer index if there is one. Returns true when the catalogue
  /// changed and the caller should re-read it.
  ///
  /// Safe to call on every storefront open: it sends an ETag, so the common
  /// case is a 304 with no body.
  @async
  bool refreshCatalogue();

  /// Download, verify and install. Progress arrives on [PackFlutterApi].
  ///
  /// Entitlement is re-checked HERE, natively, immediately before the
  /// download. Not because the UI cannot be trusted, but because the UI's copy
  /// of the answer can be stale by minutes and a refund is a worse outcome than
  /// a redundant check.
  @async
  PackResult installPack(String packId);

  /// Stop an in-flight download. Staging is discarded; nothing partial is kept.
  @async
  void cancelInstall(String packId);

  /// Remove an installed pack. Refuses the active theme, which would leave the
  /// home screen resolving a theme that is no longer on disk.
  @async
  bool uninstallPack(String packId);

  /// Tell native which SKUs Play says are owned.
  ///
  /// PUSHED FROM DART, because Play Billing lives in `g_account` on the Dart
  /// side and native has no billing client of its own. Native holds the set
  /// only to answer `unlocked`; it never decides ownership and never persists
  /// it. A restart re-asks Play, which is the only source that can be trusted.
  @async
  void setOwnedSkus(List<String> skus);

  /// The resolved CDN base URL, written where the headless sync worker can read
  /// it. Called once after Remote Config resolves.
  @async
  void setCdnBaseUrl(String url);
}

@FlutterApi()
abstract class PackFlutterApi {
  /// Fires on the platform thread during a download, roughly per chunk.
  void onPackProgress(PackProgress progress);

  /// Fires after a pack lands, so the storefront can re-read without polling.
  void onPackInstalled(String packId, int version);
}
