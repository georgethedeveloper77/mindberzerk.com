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
///   137 StorageOutcome
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
  @async
  Uint8List? thumbnail(String fileId, int maxPixels);

  /// Moves files to the OS trash by default, where the user has thirty days to
  /// change their mind. [permanent] skips that.
  @async
  List<StorageOutcome> remove(List<String> fileIds, bool permanent);
}
