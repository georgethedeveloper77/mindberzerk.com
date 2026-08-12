import 'package:pigeon/pigeon.dart';

/// THE SOURCE OF TRUTH for the storage bridge.
///
/// Regenerate after ANY edit here:
///
///   cd apps/g_recovery
///   dart run pigeon --input pigeons/storage_api.dart
///
/// Outputs (both generated, never hand-edit):
///   lib/bridge/storage_api.g.dart
///   android/app/src/main/kotlin/com/mindhunter/g_recovery/storage/StorageApi.g.kt
///
/// ─── A THIRD SCHEMA, NOT ADDITIONS TO recovery_api.dart ─────────────────────
///
/// Own subpackage `com.mindhunter.g_recovery.storage`, because Pigeon emits a
/// `FlutterError` class into every generated Kotlin file and two schemas in one
/// package is a compile-time redeclaration.
///
/// Separate for a design reason too. Recovery is about things that are GONE;
/// storage is about things that are HERE. They have different lifetimes, a
/// different failure vocabulary, and different threading. Folding storage into
/// the recovery codec would also mean every storage change risks renumbering a
/// schema that is already shipping.
///
/// ─── NEVER WRITE A SHELL GLOB IN A DOC COMMENT HERE ─────────────────────────
///
/// A star immediately before a slash closes the generated KDoc block early and
/// the rest of the sentence lands inside a Kotlin constructor. Write `policyN`,
/// or name the path in prose.
///
/// ─── DECLARATION ORDER IS THE WIRE FORMAT ───────────────────────────────────
///
///   129 VolumeInfo    130 KindUsage      131 FolderUsage
///   132 AgeBucket     133 StorageFile    134 StorageOverview
///   135 StorageQuerySpec                 136 StorageQueryResult
///   137 StorageOutcome  138 DirEntry     139 VolumeEntry
///
/// ADD NEW TYPES AT THE END. NO ENUMS, ever: they number before classes, so one
/// would push all nine up by one.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/bridge/storage_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/mindhunter/g_recovery/storage/StorageApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.mindhunter.g_recovery.storage'),
    dartPackageName: 'g_recovery',
  ),
)

/// The primary shared volume. Codec 129.
class VolumeInfo {
  VolumeInfo({
    required this.totalBytes,
    required this.freeBytes,
    required this.usedBytes,
  });

  /// From StatFs on the data partition.
  ///
  /// NOT the number on the box. A 256 GB phone reports around 234 GB usable
  /// after the filesystem, the system image and the vendor partition take their
  /// share, and a user comparing against Settings must see the same figure we
  /// do, which is this one.
  final int totalBytes;

  final int freeBytes;

  /// total minus free. Includes the OS and every app's private data, so it is
  /// always larger than the sum of what the categories below can see.
  final int usedBytes;
}

/// One media kind. Codec 130.
class KindUsage {
  KindUsage({
    required this.kind,
    required this.itemCount,
    required this.totalBytes,
  });

  /// "image" | "video" | "audio" | "document" | "other". A String, because an
  /// enum here would renumber the whole schema.
  final String kind;

  final int itemCount;
  final int totalBytes;
}

/// One folder, as MediaStore reports it. Codec 131.
class FolderUsage {
  FolderUsage({
    required this.path,
    required this.label,
    required this.itemCount,
    required this.totalBytes,
  });

  /// The RELATIVE_PATH value, for example "DCIM/Camera/".
  final String path;

  /// The last meaningful segment, for display.
  final String label;

  final int itemCount;
  final int totalBytes;
}

/// One year, for the age histogram. Codec 132.
class AgeBucket {
  AgeBucket({
    required this.year,
    required this.itemCount,
    required this.totalBytes,
  });

  final int year;
  final int itemCount;
  final int totalBytes;
}

/// A file that is still on the device. Codec 133.
class StorageFile {
  StorageFile({
    required this.fileId,
    required this.name,
    required this.kind,
    required this.sizeBytes,
    this.relativePath,
    this.mimeType,
    this.dateModifiedMillis,
    this.durationMillis,
  });

  /// Opaque handle. Dart must never parse it.
  final String fileId;

  final String name;
  final String kind;
  final int sizeBytes;
  final String? relativePath;
  final String? mimeType;
  final int? dateModifiedMillis;
  final int? durationMillis;
}

/// Everything the Storage tab draws on open. Codec 134.
class StorageOverview {
  StorageOverview({
    required this.volume,
    required this.kinds,
    required this.folders,
    required this.ages,
    required this.indexedBytes,
    required this.indexedCount,
    required this.complete,
  });

  final VolumeInfo volume;
  final List<KindUsage> kinds;

  /// Largest first, capped natively. A phone can have hundreds of folders and a
  /// treemap of hundreds of rectangles is a texture, not information.
  final List<FolderUsage> folders;

  final List<AgeBucket> ages;

  /// The total this overview can actually account for.
  ///
  /// ALWAYS LESS THAN [VolumeInfo.usedBytes], and the gap is not an error. It is
  /// the OS, app code, and every app's private directory, none of which
  /// MediaStore indexes and none of which any app can enumerate. The UI shows
  /// the gap as its own segment rather than quietly inflating a category, which
  /// is what a cleaner app does to make its numbers look bigger.
  final int indexedBytes;

  final int indexedCount;

  /// False when the index was truncated for time. The figures are then a floor.
  final bool complete;
}

/// A filter. Codec 135.
class StorageQuerySpec {
  StorageQuerySpec({
    required this.kinds,
    required this.limit,
    required this.sort,
    this.minBytes,
    this.olderThanDays,
    this.folderPrefix,
    this.nameContains,
  });

  /// Empty means every kind.
  final List<String> kinds;

  final int limit;
  final int? minBytes;
  final int? olderThanDays;
  final String? folderPrefix;
  final String? nameContains;

  /// "newest" | "oldest" | "largest" | "smallest" | "name"
  ///
  /// SORTED NATIVELY, and it has to be. The query returns at most [limit] rows,
  /// so ordering in Dart afterwards would sort the page rather than the library:
  /// asking for smallest first would hand back the smallest of the 400 largest,
  /// which is wrong in a way nobody notices until they trust it.
  ///
  /// A String rather than an enum, matching every other field here: an enum
  /// numbers before classes and adding a sixth order would renumber every class
  /// in the schema.
  final String sort;
}

/// Codec 136.
class StorageQueryResult {
  StorageQueryResult({
    required this.files,
    required this.matchCount,
    required this.matchBytes,
    required this.folders,
    required this.ages,
  });

  /// Capped by [StorageQuerySpec.limit]. [matchCount] is the real total, so the
  /// headline figure never lies just because the list was truncated.
  final List<StorageFile> files;

  final int matchCount;
  final int matchBytes;

  /// Breakdown of the MATCH, not of the device. This is what makes a query an
  /// answer with a shape rather than a list.
  final List<FolderUsage> folders;
  final List<AgeBucket> ages;
}

/// Codec 137.
class StorageOutcome {
  StorageOutcome({
    required this.fileId,
    required this.status,
    required this.detail,
  });

  final String fileId;

  /// "deleted" | "trashed" | "needsConsent" | "notFound" | "denied" | "failed"
  ///
  /// `trashed` is distinct from `deleted` on purpose: the default action moves a
  /// file to the OS trash where it is recoverable for thirty days, and telling
  /// the user it was deleted when it was not would be the same overclaim this
  /// app refuses to make in the other direction.
  final String status;

  final String detail;
}

/// One thing inside a folder. Codec 138.
///
/// Appended last, so nothing before it renumbers.
///
/// ─── THIS IS NOT StorageFile ─────────────────────────────────────────────────
///
/// StorageFile is a MediaStore row: indexed, with a kind and a media id, and
/// reachable by every other method here. This is what is actually on disk, which
/// is a different and larger set. MediaStore never saw the zip a file manager
/// dropped into Download, and it has no idea that Android/data exists.
///
/// Keeping them apart is the point. A browser that could only show indexed files
/// would teach a false picture of the filesystem, which is the one thing this
/// screen exists not to do.
class DirEntry {
  DirEntry({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.sizeBytes,
    required this.modifiedMillis,
    required this.childCount,
    required this.readable,
    required this.hidden,
  });

  final String path;
  final String name;
  final bool isDirectory;

  /// Zero for a directory. Summing a tree means walking it, and a browser that
  /// stalled on every folder to total its contents would be unusable on a
  /// phone.
  final int sizeBytes;

  final int modifiedMillis;

  /// How many things are directly inside, or null when it could not be read.
  ///
  /// Null is meaningful here and is not the same as zero: an empty folder and a
  /// folder the system refuses to open look identical without it.
  final int? childCount;

  /// False for the folders Android will not open, chiefly Android/data and
  /// Android/obb from Android 11 onward.
  ///
  /// Shown rather than hidden. A person who cannot see the locked door does not
  /// learn that it is locked, and this is the same folder that makes deleted
  /// chat messages unrecoverable.
  final bool readable;

  /// Starts with a dot. Listed, but behind a toggle, because a browser that
  /// silently omits things teaches the wrong shape of the filesystem.
  final bool hidden;
}

/// A mounted volume. Codec 139.
///
/// ─── NOT VolumeInfo ──────────────────────────────────────────────────────────
///
/// VolumeInfo is three numbers about the volume an overview describes. This is
/// a volume the phone has, with a name and a path, so it can be listed and
/// opened. A phone with an SD card has two of these and one overview.
class VolumeEntry {
  VolumeEntry({
    required this.id,
    required this.label,
    required this.path,
    required this.totalBytes,
    required this.freeBytes,
    required this.removable,
    required this.primary,
  });

  final String id;

  /// What the system calls it. "SanDisk SD card" rather than a mount point,
  /// because the mount point is a different string on every device.
  final String label;

  /// Null when the volume is mounted somewhere this app cannot reach, which
  /// happens on some OEM builds for USB drives.
  final String? path;

  final int totalBytes;
  final int freeBytes;

  final bool removable;

  /// Internal storage. There is exactly one, and it is the one the overview
  /// already describes.
  final bool primary;
}

@HostApi()
abstract class StorageHostApi {
  /// Volume stats plus the MediaStore aggregate. One pass, no directory walk.
  @async
  StorageOverview overview();

  @async
  StorageQueryResult query(StorageQuerySpec spec);

  /// JPEG preview bytes, downscaled natively. Same reasoning as the recovery
  /// thumbnail: Flutter cannot load a content URI, and shipping full size
  /// bitmaps across the channel is how a grid runs a phone out of memory.
  ///
  /// [kind], [name] and [mimeType] are passed IN rather than looked up.
  ///
  /// Native has only the file id, which carries no type, so deciding how to
  /// draw a preview would mean a second MediaStore query per thumbnail: on a
  /// scrolling grid, one extra cursor per cell. Dart already holds all three on
  /// the StorageFile it is drawing, so handing them over costs nothing and the
  /// native side goes straight to the right renderer.
  ///
  /// Without this the call site hardcoded "image", which meant audio artwork
  /// and PDF first pages could never be reached however well they worked.
  @async
  Uint8List? thumbnail(
    String fileId,
    int maxPixels,
    String kind,
    String? name,
    String? mimeType,
  );

  /// Moves files to the OS trash by default, where the user has thirty days to
  /// change their mind. [permanent] skips that.
  @async
  List<StorageOutcome> remove(List<String> fileIds, bool permanent);

  /// A playable content URI for this file, or null if it is no longer listed.
  ///
  /// The one thing video playback cannot be done without. VideoPlayerController
  /// takes a content URI and nothing else will do: Dart cannot open a
  /// MediaStore row by id, and the file path behind it is unreadable under
  /// scoped storage even when the row is perfectly readable.
  ///
  /// A STRING, not a typed URI, because Pigeon has no URI and because the same
  /// value is handed straight back to the platform for the external chooser.
  @async
  String? contentUri(String fileId);

  /// Raw bytes, for the formats this app renders itself.
  ///
  /// Text and CSV, and nothing larger than [maxBytes]. Dart cannot read a
  /// content URI on its own, so the bytes have to cross the bridge, and a
  /// three hundred megabyte log decoded into a Dart string would take the app
  /// down on a phone that had every right to survive opening it.
  ///
  /// Returns null when the file is missing or larger than the cap. The caller
  /// distinguishes the two by checking the size it already has.
  @async
  Uint8List? readBytes(String fileId, int maxBytes);

  /// Every mounted volume: internal, and any SD card or USB drive.
  ///
  /// From StorageManager rather than a guessed path. On a phone with an SD card
  /// the second volume has a different id on every device, and hardcoding
  /// /storage/sdcard1 was already wrong a decade ago.
  @async
  List<VolumeEntry> volumes();

  /// What is directly inside a folder.
  ///
  /// [path] null means the roots: internal storage, plus any SD card or USB
  /// volume currently mounted.
  ///
  /// One level only. A recursive walk is what makes file managers hang on a
  /// folder with forty thousand files in it, and nothing on this screen needs
  /// more than the level being looked at.
  @async
  List<DirEntry> listDirectory(String? path);

  /// Hands the file to whatever app can open it.
  ///
  /// For the formats with no credible in-app renderer, which on Android means
  /// office documents and anything proprietary. Returns false when nothing on
  /// the phone can handle the type, so the UI can say that instead of appearing
  /// to do nothing.
  ///
  /// Grants read permission on the URI for the duration of the target activity.
  /// Without that flag the chooser opens onto a permission error, which looks
  /// like a bug in this app rather than in the one that was launched.
  @async
  bool openExternally(String fileId);
}
