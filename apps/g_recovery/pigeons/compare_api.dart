import 'package:pigeon/pigeon.dart';

/// THE SOURCE OF TRUTH for the comparison bridge.
///
/// Regenerate after ANY edit here:
///
///   cd apps/g_recovery
///   dart run pigeon --input pigeons/compare_api.dart
///
/// Outputs (both generated, never hand-edit):
///   lib/bridge/compare_api.g.dart
///   android/app/src/main/kotlin/com/mindhunter/g_recovery/compare/CompareApi.g.kt
///
/// ─── ITS OWN SCHEMA AND PACKAGE ──────────────────────────────────────────────
///
/// Pigeon emits a FlutterError class into every generated Kotlin file, so two
/// schemas in one package is a redeclaration error. A separate file also starts
/// these codec ids fresh at 129 and touches nothing in storage or recovery.
///
/// ─── WHY THIS IS NOT PART OF StorageHostApi ──────────────────────────────────
///
/// Everything there answers immediately from a MediaStore cursor. This decodes
/// every image on the phone, which on a full device is minutes rather than
/// milliseconds, and it returns GROUPS rather than files. Bolting a long running
/// job with progress onto an API built for instant queries would make every
/// caller of the fast half handle a state it can never be in.
///
/// ─── ONE PASS, THREE ANSWERS ─────────────────────────────────────────────────
///
/// Exact duplicates, near duplicates and blur all need the same thing: each
/// image decoded once at a small size. Doing them separately would decode every
/// photo three times, so the scan computes all three and the UI picks what to
/// show.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/bridge/compare_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/mindhunter/g_recovery/compare/CompareApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.mindhunter.g_recovery.compare'),
    dartPackageName: 'g_recovery',
  ),
)

/// A set of files that belong together. Codec 129.
class CompareGroup {
  CompareGroup({
    required this.groupId,
    required this.kind,
    required this.fileIds,
    required this.totalBytes,
    required this.wastedBytes,
    required this.keepFileId,
    required this.sizes,
  });

  final String groupId;

  /// "exact" for byte identical copies, "similar" for near duplicates.
  ///
  /// A String rather than an enum, matching every other schema in this app: an
  /// enum numbers before classes and adding a third kind would renumber
  /// everything after it.
  final String kind;

  /// Every member, largest first, so the head of the list is the one worth
  /// keeping on size alone.
  final List<String> fileIds;

  final int totalBytes;

  /// What removing everything except the keeper would free.
  ///
  /// Reported separately from [totalBytes] because they are wildly different
  /// numbers and confusing them is how a cleaner app claims to free forty
  /// gigabytes and frees four.
  final int wastedBytes;

  /// The suggestion, never the decision.
  ///
  /// Largest file in the group, since for two encodings of one photo the bigger
  /// one carries more detail. The UI preselects the others and lets the user
  /// change it; nothing is ever removed on this recommendation alone.
  final String keepFileId;

  /// Size per file, in the same order as [fileIds].
  ///
  /// APPENDED LAST, so nothing before it renumbers.
  ///
  /// Without it the UI divided the group total evenly, which is exact for byte
  /// identical copies and wrong for near duplicates, where a shared copy can be
  /// a fifth the size of the original. Once a user can keep more than one file
  /// in a set, that approximation stops being cosmetic: the figure on the button
  /// is what they are deciding on.
  final List<int> sizes;
}

/// One image judged soft. Codec 130.
class BlurredImage {
  BlurredImage({
    required this.fileId,
    required this.sharpness,
    required this.sizeBytes,
  });

  final String fileId;

  /// Variance of the Laplacian. Higher is sharper.
  ///
  /// Reported raw rather than as a verdict so the UI can sort by it and a
  /// threshold can move without a native change. It is scale dependent, which
  /// is why every image is measured at the same working size.
  final double sharpness;

  final int sizeBytes;
}

/// What a scan found. Codec 131.
class CompareResult {
  CompareResult({
    required this.groups,
    required this.blurred,
    required this.scanned,
    required this.cancelled,
  });

  final List<CompareGroup> groups;
  final List<BlurredImage> blurred;

  final int scanned;

  /// True when the user stopped it. The findings so far are real and are kept;
  /// what is not true is that they are complete, and the UI says so.
  final bool cancelled;
}

/// How far along. Codec 132.
class CompareProgress {
  CompareProgress({
    required this.scanned,
    required this.total,
    required this.found,
    required this.done,
  });

  final int scanned;
  final int total;
  final int found;
  final bool done;
}

@HostApi()
abstract class CompareHostApi {
  /// Decodes every image and computes all three answers in one pass.
  ///
  /// [blurThreshold] is passed in so the line between soft and sharp can move
  /// without a native change. Around 100 is a reasonable start on a 256 pixel
  /// working size; below 50 catches only the truly ruined.
  @async
  CompareResult scan(int maxImages, double blurThreshold);

  /// Stops the scan. Whatever has been compared so far is returned by the call
  /// still in flight, with cancelled true.
  @async
  void cancel();
}

/// Progress, pushed while a scan runs.
@FlutterApi()
abstract class CompareFlutterApi {
  void onCompareProgress(CompareProgress progress);
}
