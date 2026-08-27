// ─── ONLY pigeon.dart MAY BE IMPORTED HERE ──────────────────────────────────
//
// This file is a SCHEMA, parsed by Pigeon rather than compiled, and Pigeon
// refuses any other import outright:
//
//     Unsupported import 'dart:typed_data', only imports of
//     'package:pigeon/pigeon.dart' are supported.
//
// I added `dart:typed_data` for `Uint8List`, which is unnecessary twice over:
// `pigeon.dart` re-exports it, and the analyzer had already said so as an
// `unnecessary_import` info. The cost was not a warning: generation ABORTED,
// wrote a zero-length `pack_api.g.dart`, and the next `flutter analyze` reported
// forty errors about `PackInfo` not being a type. Nothing was wrong with the
// schema; the generator never ran.
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
    // OPTIONAL, like `sku`, and last. Every existing construction of this class
    // keeps compiling untouched, which matters because the Kotlin side builds
    // one per index entry and a required field would have broken all of them
    // before the mapping that supplies these even existed.
    this.previewShell,
    this.previewBgTop,
    this.previewBgBottom,
    this.previewBar,
    this.previewDock,
    this.previewAccent,
    // AFTER the preview six, for the same reason they sit after `sku`: append
    // only. Inserting mid-class shifts every field below it in the codec and
    // the wire format silently reinterprets one type as another.
    this.features,
    // LAST here too, matching the field order above.
    this.tint,
    // AND NOW THIS ONE IS LAST. Appended after `tint` for the reason stated
    // three lines up: inserting mid-class shifts every field below it in the
    // codec and the wire silently reinterprets one type as another.
    this.previewLayout,
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


  // ─── THE PREVIEW BLOCK ────────────────────────────────────────────────────
  //
  // APPENDED, all six, after every existing field. Field order IS the decode
  // index, so anything inserted above would renumber the rest and every device
  // running an older build would misread the whole class. Same rule
  // `AppEntry.category` follows in the other schema.
  //
  // ─── SIX FLAT STRINGS, NOT A PreviewSpec CLASS ────────────────────────────
  //
  // A nested class would read better and it would cost a CODEC ID. Enums are
  // numbered before classes in the generated codec, so a new class shifts every
  // existing class's id and breaks the bridge in a way that compiles cleanly
  // and fails at runtime. Six nullable strings on a class that already exists
  // cost nothing.
  //
  // ─── WHY THE CARD NEEDS THEM AT ALL ───────────────────────────────────────
  //
  // `theme_catalog` can already draw a miniature desktop for any shell: the
  // renderer takes a palette and a layout and the bundled distros use it. What
  // it cannot do is draw one for a pack it has never installed, because the
  // index carries a title and a summary and no colours. So every CDN distro
  // renders `PreviewLayout.unknown`, which is a flat rectangle, and a paid
  // distro is the emptiest card on the storefront.
  //
  // Roughly 120 bytes per entry, and it is what turns a name and a price into
  // something that looks like a product.

  /// The shell this distro draws: "gnome" | "plasma" | "aqua" | "tiling" |
  /// "tui". Picks WHICH miniature the card renders.
  ///
  /// Null on every pack published before this field existed, and the card falls
  /// back to the flat rectangle it draws today. Optional the whole way down, so
  /// nothing already in the index has to be republished.
  final String? previewShell;

  /// The six palette colours, as "#RRGGBB" or "#AARRGGBB", exactly as they
  /// appear in the pack's own theme.json.
  ///
  /// Strings rather than ints because that is how they are authored, how they
  /// travel in the index, and how the panel already stores them. Parsing them
  /// once on the Dart side beats three representations of the same colour.
  final String? previewBgTop;
  final String? previewBgBottom;
  final String? previewBar;
  final String? previewDock;
  final String? previewAccent;

  /// The rows the storefront card names, in AUTHORED ORDER.
  ///
  /// ─── A CLASS, NOT NINE FLAT FIELDS ────────────────────────────────────────
  ///
  /// The preview above is six flat scalars because it is exactly six things and
  /// always will be. A feature list is not: the card shows the first two
  /// exclusive rows and the detail page shows the rest, so flattening would
  /// have meant picking a cap and baking it into the wire format. Three rows is
  /// the current editorial habit, not a limit anyone chose.
  ///
  /// [PackFeature] is declared LAST in this file, so Pigeon assigns it codec id
  /// 133 and the four existing classes keep 129 through 132. Nothing renumbers,
  /// which is the same constraint that keeps `brandTreatment` a String in the
  /// other schema.
  ///
  /// Null on every entry published before this field existed, which is every
  /// entry today. The card falls back to whatever its floor card authored, so
  /// the three bundled distros keep their rows and nothing must be republished
  /// to stay correct.
  final List<PackFeature?>? features;

  /// The pack's colour, as `#rrggbb`, or null for a pack that has none.
  ///
  /// ─── LAST, AND THAT IS NOT A STYLE CHOICE ─────────────────────────────────
  ///
  /// Field order IS the decode index. This first went in after `sku`, which
  /// renumbered the six preview fields and `features` beneath it, and every
  /// device on an older build would have read `previewShell` where `tint` now
  /// sits: no crash, no parse error, just a colour interpreted as a shell name
  /// and six fields shifted by one.
  ///
  /// The same rule the preview block above states about itself, and the same
  /// one `AppEntry.category` follows in the other schema.
  ///
  /// ─── WHY THE CATALOGUE CARRIES IT AT ALL ──────────────────────────────────
  ///
  /// The fourteen official packs share one geometry and differ in exactly this,
  /// so the colour IS the product and the thing listing products has to know it.
  ///
  /// Practically it lets the storefront preview a pack on the user's real apps
  /// WITHOUT installing it: a derived pack is 207 bytes of hex and the geometry
  /// it points at is already on the device, free and required. Without this,
  /// showing someone what they would buy would mean downloading it first.
  ///
  /// Null for hero packs, third-party packs and Simple Icons, all of which
  /// carry their colours inside the art.
  final String? tint;

  /// What the storefront card should DRAW, decided at publish time.
  ///
  /// ─── WHY THIS IS ONE STRING AND NOT FIVE FIELDS ─────────────────────────
  ///
  /// The card used to pick its picture from `previewShell` alone, because that
  /// was the only layout signal the index carried. It was right when a shell
  /// decided everything and wrong for ten of fifteen distros once `dock`,
  /// `dockStyle`, `dockReveal` and `homeLayout` became real: KDE and Mint were
  /// drawn with docks they do not have, Kali and Manjaro with the dock on the
  /// wrong edge, elementary and Pocket magnifying when neither swells.
  ///
  /// Carrying the five source fields instead would put the derivation on the
  /// device, in a second place, where it would drift from the panel's. The
  /// panel holds the whole theme.json and the device holds only the index, so
  /// the decision belongs at the only point that has the source.
  ///
  /// ─── AND IT ENCODES THE BAR TOO ─────────────────────────────────────────
  ///
  /// A bottom DOCK and a bottom PANEL are different pictures, and no preview
  /// has ever drawn the bar from data: every card painted one at the top
  /// whether the distro had it at the bottom or had none at all. Four have a
  /// bottom panel and three have no bar.
  ///
  /// Values: `dockLeft`, `dockBottom`, `dockFlat`, `dockMagnified`, `noDock`,
  /// `barBottom`, `dash`, `tiled`, `terminal`. A STRING, not an enum, for the
  /// reason `packType` gives: a value a older client does not recognise must
  /// degrade to a neutral picture rather than fail to parse.
  final String? previewLayout;
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
  /// "cancelled" | "rejected" | "notEntitled" | "missingDependency" | "failed"
  ///
  /// THIS LIST IS THE CONTRACT, and it is the thing to update first. Dart
  /// switches on these strings with a `default` arm that says "try again", so a
  /// status native starts sending and this list never learned about is not a
  /// compile error: it is a specific, already-diagnosed failure quietly
  /// rendered as a generic one. `missingDependency` did exactly that on its
  /// first run.
  final String status;

  /// Human-readable, for logs and for the rare case worth showing. Never the
  /// primary thing the UI branches on; branch on [status].
  final String detail;

  final int installedVersion;
}

/// One row on a storefront card.
///
/// DECLARED LAST ON PURPOSE. Pigeon assigns codec ids in declaration order and
/// the four classes above hold 129 to 132; appending here takes 133 and leaves
/// them alone. Moving this above [PackInfo] would renumber all four and every
/// message already in flight would decode as the wrong type.
class PackFeature {
  PackFeature({
    required this.title,
    required this.body,
    required this.exclusive,
  });

  /// Two or three words. The bold half of the row.
  final String title;

  /// One short sentence, set beside the title on a phone card. A second
  /// sentence is a second line nobody reads.
  final String body;

  /// Whether the all-access settings can reproduce this.
  ///
  /// The whole price argument lives in this bool. A paid distro whose rows are
  /// all false is selling a palette, and the card should not be asking for
  /// money. Non-null because a missing answer here reads as `true` by accident,
  /// which is the flattering direction and therefore the wrong default; the
  /// panel decides and states it.
  final bool exclusive;
}

/// How much of THIS DEVICE'S app list a pack actually draws.
///
/// ─── APPENDED LAST, AFTER [PackFeature] ─────────────────────────────────────
///
/// Codec ids are positional and the five classes above hold 129 to 133. This
/// takes 134 and moves nothing. Declaring it anywhere earlier renumbers every
/// class below it, which compiles cleanly and misdecodes at runtime.
///
/// ─── WHY THIS IS MEASURED AND NOT ADVERTISED ────────────────────────────────
///
/// The catalogue can say "13,622 icons" and it is true of the pack and useless
/// to the person holding the phone: what they want to know is how many of THEIR
/// apps get a drawing. Those are different numbers by two orders of magnitude,
/// and the second one is the only one the wearing card can honestly show.
///
/// So both halves come from the device. [covered] is the intersection of the
/// pack's glyph map with the launchable app list; [total] is that list's size.
/// Neither is a figure from the index.
class PackCoverage {
  PackCoverage({
    required this.packId,
    required this.covered,
    required this.total,
  });

  final String packId;

  /// Launchable packages this pack has a drawing for.
  final int covered;

  /// Launchable packages on this device. The denominator, never zero when the
  /// call succeeds, because a device with no launchable apps cannot be running
  /// a launcher.
  final int total;
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

  /// Tell native which distro theme is applied right now.
  ///
  /// ─── INCLUSION IS NOT OWNERSHIP ───────────────────────────────────────────
  ///
  /// Every distro ships an icon pack in its own colour, free with that distro,
  /// and priced for anyone running a different one. Both are true at once, and
  /// which applies depends on the theme currently applied.
  ///
  /// `isUnlocked` cannot answer that and must not learn to: its inputs are a
  /// pack id and Play's record, and one function answering two questions is one
  /// that eventually gives a pack away and charges twice for it. `isAvailable`
  /// ORs `isUnlocked` with `isIncludedWith`, and this is the second fact it
  /// needs.
  ///
  /// PUSHED FROM DART for the same reason [setOwnedSkus] is: Dart owns the
  /// theme selection, native has no way to read it, and the install path
  /// re-checks entitlement immediately before transferring. Without this, that
  /// check refuses a pack the user is entitled to and the message is "needs to
  /// be purchased first" on the icons that came free with the distro underneath
  /// it.
  ///
  /// Empty string clears it. Never persisted: the applied theme is Dart's
  /// state, and a stale copy surviving a restart would grant a pack for a distro
  /// no longer in use.
  @async
  void setActiveTheme(String themeId);


  /// The resolved CDN base URL, written where the headless sync worker can read
  /// it. Called once after Remote Config resolves.
  @async
  void setCdnBaseUrl(String url);

  // ─── THE RENDER BRIDGE ─────────────────────────────────────────────────────
  //
  // Everything above this line downloads content. These two read it back, and
  // without them the whole panel publishes into a void: `activeThemeSpecProvider`
  // only ever knew how to open a bundled asset, so a verified, installed,
  // paid-for Kali pack sat on disk and the phone kept rendering Ubuntu.
  //
  // TWO METHODS RATHER THAN ONE RETURNING A SMALL CLASS, deliberately. A new
  // Pigeon class appended here would be safe (ids are positional and this would
  // land last), but "safe if appended" is a rule someone has to remember at 1am
  // and two plain methods need no rule at all. The cost is one extra round trip
  // per theme SWITCH, which is not a hot path.

  /// The raw `theme.json` of an installed theme pack, or null when the pack is
  /// not on disk (never downloaded, uninstalled, or its files were swept).
  ///
  /// Returns the BYTES AS TEXT and parses nothing. Dart already owns
  /// `ThemeSpec.fromJson`, and a second parser in Kotlin is a second thing to
  /// keep in step with the schema — the exact drift that made the icon
  /// `IconStyle` data class a hand-written twin of the Pigeon one.
  ///
  /// Signature verification is NOT repeated here. The pack was verified when it
  /// installed; re-verifying on every theme resolve would put an ed25519 check
  /// on the home screen's critical path for no additional guarantee, since the
  /// file lives in app-private storage.
  @async
  String? readInstalledTheme(String themeId);

  /// Absolute path to an installed pack's file directory, or null.
  ///
  /// Dart needs this because a downloaded theme's wallpapers and logo are FILES,
  /// not bundled assets: `AssetImage('wall.jpg')` on an installed theme resolves
  /// to nothing and renders an empty box with no error. `ThemeSource` turns this
  /// directory into the right ImageProvider per asset.
  ///
  /// Pack files are BARE FILENAMES by construction (`PackPaths.installedFile`
  /// refuses separators), so joining is always one `/` and never a traversal.
  @async
  String? installedPackDir(String packId);

  /// Where a pack's `preview.png` can be drawn from, or null when it has none.
  ///
  /// A `file://` URI once the pack is installed, an https URL from the CDN
  /// before it. Display-only bytes that go through Flutter's image cache,
  /// never the pack pipeline, so nothing about verification changes.
  ///
  /// A METHOD rather than a field on [PackInfo], deliberately: that class
  /// documents itself as the presentation subset that does NOT carry the CDN
  /// path, and a single URL to one image keeps that promise while an appended
  /// field carrying `path` would quietly break it. Appended last, which is the
  /// safe position, and it is a method so not even the codec moves.
  @async
  String? packPreviewUrl(String packId);

  /// How many of this device's apps the pack draws, or null when it cannot say.
  ///
  /// Null rather than a zeroed [PackCoverage] for the cases that are not an
  /// answer: the pack is not on disk, it is a theme rather than an icon set, or
  /// its json failed to parse. The card renders no row at all for null, which
  /// is the convention nullable stats follow everywhere in this app; a
  /// `0 of 46` would read as a pack that covers nothing.
  ///
  /// SLOW ON FIRST CALL for a line pack, because answering means parsing the
  /// geometry the pack points at. Memoised natively per pack and per app-list
  /// size, and called from a FutureProvider that renders the row when it
  /// arrives, so nothing waits on it.
  @async
  PackCoverage? packCoverage(String packId);
}

@FlutterApi()
abstract class PackFlutterApi {
  /// Fires on the platform thread during a download, roughly per chunk.
  void onPackProgress(PackProgress progress);

  /// Fires after a pack lands, so the storefront can re-read without polling.
  void onPackInstalled(String packId, int version);
}
