import 'package:pigeon/pigeon.dart';

/// THE SOURCE OF TRUTH for the recovery bridge.
///
/// Regenerate after ANY edit here:
///
///   cd apps/g_recovery
///   dart run pigeon --input pigeons/recovery_api.dart
///
/// Outputs (both generated, never hand-edit):
///   lib/bridge/recovery_api.g.dart
///   android/app/src/main/kotlin/com/mindhunter/g_recovery/recovery/RecoveryApi.g.kt
///
/// ─── ITS OWN KOTLIN PACKAGE ──────────────────────────────────────────────────
///
/// `com.mindhunter.g_recovery.recovery`, a subpackage rather than the app's own.
/// Pigeon emits a `FlutterError` class into every generated Kotlin file, so two
/// schemas in one package is a redeclaration error that surfaces only at compile
/// time. Any future schema in this app gets its own subpackage too.
///
/// ─── NEVER WRITE A SHELL GLOB IN A DOC COMMENT HERE ──────────────────────────
///
/// Pigeon copies these comments verbatim into Kotlin KDoc, which is delimited by
/// slash-star and star-slash. A path written the natural way, with a star
/// immediately before a slash, closes the block early and the rest of the
/// sentence lands inside a generated constructor as stray tokens. The error
/// names a parameter that does not exist in this file. Write `.trashN`, or name
/// the path in prose.
///
/// ─── DECLARATION ORDER IS THE WIRE FORMAT ────────────────────────────────────
///
///   129 RecoveryAccess    130 RecoverySource    131 RecoverableItem
///   132 ScanProgress      133 RestoreOutcome    134 RecoverySummary
///
/// ADD NEW TYPES AT THE END. There are NO ENUMS in this schema and there never
/// will be: Pigeon numbers enums before classes, so one added here would push
/// every class up by one. Every enum-shaped value is a String that degrades on
/// an unrecognised value.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/bridge/recovery_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/mindhunter/g_recovery/recovery/RecoveryApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.mindhunter.g_recovery.recovery'),
    dartPackageName: 'g_recovery',
  ),
)

/// What this app is currently allowed to see. Codec 129.
class RecoveryAccess {
  RecoveryAccess({
    required this.allFilesAccess,
    required this.canSeeOtherAppsTrash,
    required this.storageManagerAvailable,
  });

  /// `Environment.isExternalStorageManager()`.
  final bool allFilesAccess;

  /// THE FACT THE WHOLE FEATURE RESTS ON.
  ///
  /// On Android 11 and above a MediaStore query with MATCH_INCLUDE returns only
  /// the items THIS app trashed. Another app's trashed photo is invisible
  /// without All Files Access. A freshly installed G Recovery has trashed
  /// nothing, so without the grant the ledger is empty on every device forever.
  ///
  /// Currently identical to [allFilesAccess]. It is a separate field because it
  /// is a separate claim: if a future Android adds a narrower permission that
  /// buys the same visibility, this flips and the UI needs no change.
  final bool canSeeOtherAppsTrash;

  /// Whether the settings screen for the grant can be opened at all. False on
  /// the rare build with the activity stripped, where the UI must stop offering
  /// a button that goes nowhere.
  final bool storageManagerAvailable;
}

/// One place deleted data can still be hiding. Codec 130.
class RecoverySource {
  RecoverySource({
    required this.sourceId,
    required this.label,
    required this.fidelity,
    required this.available,
    required this.itemCount,
    required this.totalBytes,
    this.detail,
    this.retentionDays,
  });

  /// Stable id: "media_trash", "app_trash", "thumbnails".
  final String sourceId;

  final String label;

  /// "full" | "preview" | "none".
  ///
  /// THE HONESTY STAMP, and it is data rather than a UI decision. A thumbnail
  /// scan can only ever return a 512 px preview, and a card that does not say so
  /// is the lie this app exists not to tell. Carried on the item too, because a
  /// single source can mix fidelities once the trashmap grows.
  final String fidelity;

  /// False when the source cannot be read at all on this device, for example
  /// app trash without All Files Access. The row is still shown, with [detail]
  /// explaining why, rather than being silently dropped.
  final bool available;

  final int itemCount;
  final int totalBytes;

  /// Human readable reason when [available] is false, or a qualifier when it is
  /// true. Never the thing the UI branches on.
  final String? detail;

  /// Days the OS keeps items here before permanent deletion. Null when the
  /// source has no expiry, which is true of thumbnails and of most app trash
  /// folders.
  final int? retentionDays;
}

/// One recoverable thing. Codec 131.
class RecoverableItem {
  RecoverableItem({
    required this.itemId,
    required this.sourceId,
    required this.name,
    required this.kind,
    required this.fidelity,
    required this.sizeBytes,
    this.relativePath,
    this.mimeType,
    this.dateDeletedMillis,
    this.dateAddedMillis,
    this.expiresInDays,
    this.previewUri,
    this.width,
    this.height,
    this.durationMillis,
    this.origin,
    this.role,
  });

  /// Opaque handle minted natively. Dart must never parse it.
  ///
  /// A MediaStore item and a loose file need completely different restore paths,
  /// and encoding that difference in a string the UI can read invites a caller
  /// to branch on it. Native holds the index; Dart hands the id back.
  final String itemId;

  final String sourceId;
  final String name;

  /// "image" | "video" | "audio" | "document" | "other".
  final String kind;

  /// "full" or "preview". Per item, not just per source.
  final String fidelity;

  final int sizeBytes;

  /// Where it was, when that is knowable. Null for a loose file in a trash
  /// folder, because the original location is genuinely not recorded anywhere
  /// and guessing it would put files back in the wrong place.
  final String? relativePath;

  final String? mimeType;
  final int? dateDeletedMillis;
  final int? dateAddedMillis;

  /// Days until the OS deletes this permanently. Null means no expiry is known,
  /// which is not the same as no expiry.
  final int? expiresInDays;

  /// A URI the UI can draw a thumbnail from. Display bytes only, through
  /// Flutter's image cache.
  final String? previewUri;

  final int? width;
  final int? height;
  final int? durationMillis;

  /// Which app or folder this came from, for display. "WhatsApp Status", "MIUI
  /// Gallery". Null for MediaStore trash, where the folder path already says it.
  ///
  /// APPENDED IN PHASE 6b, at the end of the class, which is the only safe
  /// position: field order inside a Pigeon class is the encoding order.
  final String? origin;

  /// What KIND of find this is. "trash" | "status" | "cache".
  ///
  /// The distinction that makes Status work. A WhatsApp status was never
  /// deleted: it is a file with a 24 hour life sitting in a visible folder, and
  /// offering to "restore" it is nonsense because it is not lost. It is SAVED
  /// instead, into the recovery folder, before it expires on its own.
  ///
  /// Getting this wrong in either direction is the same failure. Calling a
  /// status a recovered file overclaims; hiding it entirely misses what is
  /// probably the single most searched for case in this whole category.
  final String? role;
}

/// Progress during a scan. Codec 132.
///
/// Results stream because the one genuinely good idea in this category is
/// DiskDigger's: items become restorable before the scan finishes. A user who
/// spots the photo they came for should not have to wait out the remaining
/// thirty thousand entries.
class ScanProgress {
  ScanProgress({
    required this.sourceId,
    required this.scanned,
    required this.total,
    required this.found,
    required this.foundBytes,
    required this.done,
  });

  final String sourceId;

  /// Entries examined so far.
  final int scanned;

  /// Entries to examine. A REAL COUNT, taken before the walk begins, not a
  /// timer dressed up as a progress bar.
  final int total;

  final int found;
  final int foundBytes;
  final bool done;
}

/// The result of one restore or purge attempt. Codec 133.
///
/// A RESULT OBJECT RATHER THAN A THROWN ERROR, because most outcomes are not
/// errors. `expired` means the OS already removed it and the list was stale;
/// `needsConsent` means the system wants the user to confirm and the UI must ask
/// rather than retry; `noSpace` is user-actionable. Collapsing these into an
/// exception produces the "Restore failed" dialog that tells nobody anything.
class RestoreOutcome {
  RestoreOutcome({
    required this.itemId,
    required this.status,
    required this.detail,
    this.restoredPath,
  });

  final String itemId;

  /// "restored" | "expired" | "needsConsent" | "noSpace" | "denied" |
  /// "notFound" | "failed"
  final String status;

  final String detail;

  /// Where it ended up. Null unless [status] is "restored".
  final String? restoredPath;
}

/// Everything the ledger needs to draw itself. Codec 134.
class RecoverySummary {
  RecoverySummary({
    required this.sources,
    required this.totalItems,
    required this.totalBytes,
    required this.expiringSoonItems,
    required this.partial,
    required this.imageCount,
    required this.videoCount,
    required this.audioCount,
    required this.documentCount,
    required this.otherCount,
  });

  final List<RecoverySource> sources;
  final int totalItems;
  final int totalBytes;

  /// Items with 48 hours or less left. The one number worth putting a deadline
  /// on, because after it passes nothing can bring them back.
  final int expiringSoonItems;

  /// Per kind, so home can label six category tiles without a second call.
  ///
  /// APPENDED IN PHASE 4, at the end of the class. Field order inside a Pigeon
  /// class is the encoding order: appending is safe, inserting is not. Same rule
  /// that governs IconStyle in the launcher schema.
  ///
  /// Computed in the same cursor pass as the totals, so the pre-scan stays a
  /// counting operation and never walks a directory tree.
  final int imageCount;
  final int videoCount;
  final int audioCount;
  final int documentCount;
  final int otherCount;

  /// True when this summary was produced WITHOUT full access, so the numbers are
  /// a floor rather than a total.
  ///
  /// This is what stops the pre-scan from lying. Before the grant the app can
  /// only count its own trashed items and the thumbnail cache, and a screen
  /// showing that as a total would be the fake count every competitor opens
  /// with.
  final bool partial;
}

@HostApi()
abstract class RecoveryHostApi {
  /// Push the trash path registry. Called once at startup from Dart.
  ///
  /// PUSHED FROM DART rather than read from assets natively, and that is the
  /// whole point: Dart decides where the JSON came from. Today it is a bundled
  /// asset. In Phase 7 it is a signed CDN pack, and not one line of Kotlin
  /// changes. Recovery coverage is data, not code.
  @async
  void setTrashMap(String json);

  @async
  RecoveryAccess access();

  /// Opens the All Files Access settings screen. Returns false when no activity
  /// on this device can handle the intent.
  @async
  bool requestAllFilesAccess();

  /// Fast counts for the home screen, from MediaStore aggregates and a shallow
  /// look at the thumbnail cache. Never walks a directory tree.
  ///
  /// Runs before the permission grant, which is why [RecoverySummary.partial]
  /// exists. This is what makes home open populated instead of on a spinner.
  @async
  RecoverySummary prescan();

  /// The full walk. Progress arrives on [RecoveryFlutterApi]; items become
  /// readable through [items] while it runs.
  @async
  RecoverySummary scan(List<String> sourceIds);

  /// Stop an in-flight scan. Whatever was found so far stays available.
  @async
  void cancelScan();

  /// A page of findings. Sorted newest deleted first, then largest first for
  /// items with no deletion date.
  @async
  List<RecoverableItem> items(String sourceId, int offset, int limit);

  /// Put items back. MediaStore items return to their original folder; loose
  /// files go to a recovery folder, because their original location was never
  /// recorded anywhere and inventing one puts files in the wrong place.
  @async
  List<RestoreOutcome> restore(List<String> itemIds);

  /// Delete permanently, right now. Used by the review session's bin.
  @async
  List<RestoreOutcome> purge(List<String> itemIds);

  /// JPEG bytes for one item, at most [maxPixels] on the long edge.
  ///
  /// APPENDED IN PHASE 5. A method, so no type ids move.
  ///
  /// BYTES RATHER THAN A URI, and this is the one place that decision is not
  /// obvious. Flutter cannot load a `content://` URI: Image.network wants http
  /// and Image.file wants a path, and a trashed MediaStore row has neither. The
  /// alternatives were a FileProvider that re-exports other apps' deleted files
  /// over a content provider of our own, which is a security surface for a
  /// thumbnail, or this.
  ///
  /// Downscaled NATIVELY, before the bytes cross the channel. A review session
  /// showing a hundred 12 megapixel photos would otherwise push about 600 MB
  /// through the platform channel and decode all of it in the Dart heap. At 512
  /// px the same session is a few megabytes.
  ///
  /// Null when the item has no renderable preview, which is the honest answer
  /// for an audio file or a document, not an error.
  @async
  Uint8List? thumbnail(String itemId, int maxPixels);

  /// Files that are still on the device, matched by name.
  ///
  /// APPENDED IN PHASE 4. A HostApi method is not codec-numbered, so adding one
  /// moves no type ids. That is why sensor streaming and this could both be left
  /// out of the first cut without painting the schema into a corner.
  ///
  /// RETURNS RecoverableItem, WHICH IS NOT A TYPE LIE, though it looks like one.
  /// These files were never deleted, and [RecoverableItem.sourceId] is
  /// "live_files" so the UI can tell them apart and refuse to offer Restore on
  /// something that was never lost. A parallel class carrying the same eleven
  /// fields would have been a second thing to keep in step with the first, and
  /// search results have to render in one homogeneous list either way.
  ///
  /// Backed by MediaStore's own index rather than a directory walk, so it stays
  /// fast enough to run on every keystroke.
  @async
  List<RecoverableItem> search(String query, int limit);
}

@FlutterApi()
abstract class RecoveryFlutterApi {
  /// Fires on the platform thread during a scan, throttled natively so a fast
  /// source cannot flood the channel.
  void onScanProgress(ScanProgress progress);
}
