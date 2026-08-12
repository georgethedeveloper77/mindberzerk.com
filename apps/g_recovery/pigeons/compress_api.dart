import 'package:pigeon/pigeon.dart';

/// THE SOURCE OF TRUTH for compression.
///
/// Regenerate after ANY edit here:
///
///   cd apps/g_recovery
///   dart run pigeon --input pigeons/compress_api.dart
///
/// Outputs (both generated, never hand-edit):
///   lib/bridge/compress_api.g.dart
///   android/app/src/main/kotlin/com/mindhunter/g_recovery/compress/CompressApi.g.kt
///
/// ─── NO ESTIMATES ANYWHERE IN THIS API ───────────────────────────────────────
///
/// Every cleaner on Play shows a predicted saving computed from a formula, and
/// the number is always wrong because compressibility depends on the picture,
/// not its size. A screenshot of flat colour shrinks by 90 percent; a photograph
/// of foliage shrinks by 5.
///
/// So [preview] actually re-encodes into memory and reports what it measured.
/// It is slower than a formula and it is the only version that can be trusted by
/// someone deciding whether to replace an original.
///
/// ─── DECLARATION ORDER IS THE WIRE FORMAT ────────────────────────────────────
///
///   129 CompressCandidate   130 CompressPreview   131 CompressOutcome
///   132 CompressProgress    133 CompressSummary   134 CompressComparison
///   135 CompressedEntry     136 VideoCandidate    137 VideoEstimate
///
/// ADD NEW TYPES AT THE END. NO ENUMS, ever.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/bridge/compress_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/mindhunter/g_recovery/compress/CompressApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.mindhunter.g_recovery.compress'),
    dartPackageName: 'g_recovery',
  ),
)

/// A file worth looking at. Codec 129.
class CompressCandidate {
  CompressCandidate({
    required this.fileId,
    required this.name,
    required this.sizeBytes,
    required this.widthPx,
    required this.heightPx,
    required this.mimeType,
    this.kind,
    this.dateMillis,
    this.folder,
  });

  final String fileId;
  final String name;
  final int sizeBytes;

  /// Zero when MediaStore does not know, which happens on files written by
  /// apps that never told it. The picture still compresses; only the row on
  /// screen is thinner.
  final int widthPx;
  final int heightPx;

  final String mimeType;

  // ─── APPENDED. NEW FIELDS GO BELOW THIS LINE, NEVER ABOVE IT ──────────────

  /// "screenshot" | "photo". Null from an older native layer.
  ///
  /// Separate categories because they are separate operations, not a filter on
  /// one. A photo is re-encoded as JPEG and loses a little quality for a lot of
  /// space. A screenshot is re-encoded as lossless WebP and loses nothing at
  /// all, because it is text and flat colour, which is exactly the content JPEG
  /// is worst at.
  final String? kind;

  /// When the picture was taken, for the sort and the details row.
  ///
  /// Without it the shared sort control offers newest and oldest against a
  /// field that does not exist, which is a list ordered by nothing wearing the
  /// label of a list ordered by date.
  final int? dateMillis;

  /// The folder it lives in, for details mode. "DCIM/Camera" and the like.
  final String? folder;
}

/// What a re-encode would actually produce. Codec 130.
class CompressPreview {
  CompressPreview({
    required this.fileId,
    required this.originalBytes,
    required this.newBytes,
    required this.quality,
    this.outputMime,
    this.lossless,
  });

  final String fileId;
  final int originalBytes;

  /// MEASURED, not predicted. The encode really happened, into memory.
  ///
  /// Can be LARGER than the original, and often is for a photo already saved at
  /// a lower quality than the one being applied. The UI drops those rather than
  /// offering to make a file bigger.
  final int newBytes;

  final int quality;

  // ─── APPENDED ─────────────────────────────────────────────────────────────

  /// What the re-encode produced, which is NOT always the source type.
  ///
  /// A PNG becomes WebP. The screen has to be able to say so, because "your
  /// screenshots will become .webp files" is a thing a person may object to and
  /// must not discover afterwards.
  final String? outputMime;

  /// Whether a single pixel changed.
  ///
  /// Load bearing on screen. A lossless saving can be offered without any
  /// warning at all, and it also justifies a far lower worth-it threshold: the
  /// 20 percent floor exists to stop trading permanent quality for a trivial
  /// gain, and with nothing being traded there is nothing to protect against.
  final bool? lossless;
}

/// What happened to one file. Codec 131.
class CompressOutcome {
  CompressOutcome({
    required this.fileId,
    required this.status,
    required this.savedBytes,
  });

  final String fileId;

  /// "replaced" | "skipped" | "failed"
  ///
  /// Skipped means the new file was not smaller enough to be worth it, which is
  /// a success for the user and a non event for the app.
  final String status;

  final int savedBytes;
}

/// How a run is going. Codec 132.
class CompressProgress {
  CompressProgress({
    required this.running,
    required this.done,
    required this.total,
    required this.savedBytes,
    required this.currentName,
  });

  final bool running;
  final int done;
  final int total;
  final int savedBytes;
  final String? currentName;
}

/// Counts and bytes, with nothing encoded. Codec 133.
///
/// ─── THE ONE READING IN THIS API THAT IS FREE ────────────────────────────────
///
/// Everything else here measures by re-encoding, which is the whole point and
/// is also why none of it can run unasked. But counting the screenshots and
/// adding up their sizes is a single MediaStore query, instant and cheap.
///
/// That is enough for the storage tab to say "1,204 screenshots, 8.7 GB" before
/// anything has been scanned, which is a real fact rather than an empty
/// invitation, and it still promises no saving it has not measured.
class CompressSummary {
  CompressSummary({
    required this.screenshotCount,
    required this.screenshotBytes,
    required this.photoCount,
    required this.photoBytes,
    this.videoCount,
    this.videoBytes,
  });

  final int screenshotCount;
  final int screenshotBytes;
  final int photoCount;
  final int photoBytes;

  // ─── APPENDED FOR VIDEO ───────────────────────────────────────────────────

  /// Clips whose codec makes them worth re-encoding. Null from older native.
  ///
  /// Counted the same way as the others and just as cheaply: MediaStore knows
  /// the size, and the codec test is a header read rather than a decode.
  final int? videoCount;
  final int? videoBytes;
}

/// Both versions of one picture, for looking at. Codec 134.
///
/// ─── WHY BOTH BUFFERS AND NOT JUST THE NEW ONE ───────────────────────────────
///
/// The screen has to show the original too, and the obvious shortcut is to pull
/// it from the thumbnailer. That would be dishonest: the thumbnailer returns a
/// scaled decode, so the original would arrive softer than the full resolution
/// re-encode sitting beside it, and the compressed version would look BETTER
/// than the file it came from.
///
/// A comparison that flatters the thing being sold is worse than no comparison.
/// Both sides come back at their true size, from one decode, and the difference
/// on screen is only ever the difference the encoder made.
class CompressComparison {
  CompressComparison({
    required this.fileId,
    required this.original,
    required this.encoded,
    required this.originalBytes,
    required this.newBytes,
    required this.lossless,
  });

  final String fileId;

  /// The file exactly as it is on disk.
  final Uint8List original;

  /// What the re-encode produced. Identical bytes are still returned when
  /// [lossless] is true, so the screen never has to special case a null.
  final Uint8List encoded;

  final int originalBytes;
  final int newBytes;

  /// True for a screenshot. The viewer shows no comparison at all in that case,
  /// because a control that swaps an image for the same image is a control that
  /// teaches the user their eyes are wrong.
  final bool lossless;
}

/// One file this app has already made smaller. Codec 135.
///
/// ─── A RECORD, NOT A FOLDER ──────────────────────────────────────────────────
///
/// Nothing moves on disk. The picture stays exactly where it was, in the
/// gallery, next to everything else. Moving people's photographs into an app
/// directory is what cleaner apps do and it is how photographs get lost, along
/// with every other app's ability to find them.
///
/// ─── AND IT IS WHAT STOPS THE LOOP ───────────────────────────────────────────
///
/// The output of a compression is itself a large JPEG, so without this it comes
/// straight back as a candidate and the app offers to compress the thing it
/// just made. That is why a freshly compressed library fills with rows reading
/// "no gain": they were all correct, and all pointless.
class CompressedEntry {
  CompressedEntry({
    required this.fileId,
    required this.name,
    required this.originalBytes,
    required this.newBytes,
    required this.whenMillis,
    required this.lossless,
    required this.quality,
  });

  /// The id of the file that was WRITTEN, not the one that was trashed.
  ///
  /// It is the one that still exists, so it is the one the candidate query has
  /// to exclude and the one a thumbnail can be drawn from.
  final String fileId;

  final String name;
  final int originalBytes;
  final int newBytes;
  final int whenMillis;

  /// Whether a pixel changed. "lossless" and "quality 85" are different
  /// promises, and a week later nobody remembers which a given file got.
  final bool lossless;

  /// Meaningless when [lossless]. Recorded anyway, because a file that turns
  /// out badly is evidence about a setting.
  final int quality;
}

/// A clip, and whether re-encoding it would achieve anything. Codec 136.
///
/// ─── THE CODEC DECIDES, NOT THE SIZE ─────────────────────────────────────────
///
/// H.264 to HEVC reliably clears 40 percent because H.264 is a twenty year old
/// codec every phone still records in for compatibility. HEVC to HEVC clears
/// almost nothing and costs ten minutes of full rate encoding and a noticeable
/// bite out of the battery.
///
/// A cleaner that offers every video by size will therefore spend the longest
/// it has ever made someone wait, on the file with the least to gain. So the
/// verdict is read from the track header before anything is offered, and the
/// ones that cannot be helped are shown saying so rather than hidden.
class VideoCandidate {
  VideoCandidate({
    required this.fileId,
    required this.name,
    required this.sizeBytes,
    required this.widthPx,
    required this.heightPx,
    required this.durationMillis,
    required this.codec,
    required this.bitrate,
    required this.eligible,
    this.reason,
    this.dateMillis,
    this.folder,
  });

  final String fileId;
  final String name;
  final int sizeBytes;
  final int widthPx;
  final int heightPx;
  final int durationMillis;

  /// "h264" | "hevc" | "vp9" | "av1" | "mpeg4" | "unknown"
  ///
  /// Normalised from the track mime type, so the screen can print something a
  /// person recognises rather than "video/x-vnd.on2.vp9".
  final String codec;

  /// Bits per second, from the container. Zero when it does not say.
  final int bitrate;

  final bool eligible;

  /// Why not, in words, and null when it is. "Already HEVC", "Too short".
  ///
  /// A sentence rather than a code, because unlike the server probe there is no
  /// button attached to any of these: they are all the same outcome, which is
  /// that nothing will be done to this file.
  final String? reason;

  final int? dateMillis;
  final String? folder;
}

/// What a real sample of one clip suggests. Codec 137.
///
/// ─── AN ESTIMATE, AND THE FIRST ONE IN THIS API ──────────────────────────────
///
/// Every figure elsewhere here is measured by encoding the whole file, which is
/// possible at four megabytes and absurd at two gigabytes, where measuring IS
/// the job. So a short slice is really encoded and the rest is extrapolated
/// from it.
///
/// That is a forecast, not a measurement, and it must never wear the same word
/// on screen as the photo figures. It is also honest in a way a bitrate formula
/// is not: it is this encoder, on this phone, on these pixels.
///
/// ─── AND IT CAN BE WRONG IN A KNOWN DIRECTION ────────────────────────────────
///
/// A clip that opens on a still shot and later pans across a market will
/// compress better in its first seconds than across its length, so the estimate
/// runs high. [sampledMillis] is reported so the screen can say what it was
/// based on rather than presenting a number from nowhere.
class VideoEstimate {
  VideoEstimate({
    required this.fileId,
    required this.originalBytes,
    required this.estimatedBytes,
    required this.sampledMillis,
    required this.preset,
  });

  final String fileId;
  final int originalBytes;

  /// Extrapolated. Can exceed [originalBytes] on a clip already well encoded,
  /// and the UI drops those rather than offering to make a file bigger.
  final int estimatedBytes;

  /// How much was actually encoded to reach it.
  final int sampledMillis;

  /// "same" or "smaller".
  final String preset;
}

@HostApi()
abstract class CompressHostApi {
  /// Counts and total bytes per category. No encoding, so it is safe to call
  /// on a screen the user did not ask to scan.
  @async
  CompressSummary summary(int minBytes);

  /// Images large enough to be worth re-encoding, largest first.
  ///
  /// [kind] is "screenshot", "photo", or "all". Filtered in the query rather
  /// than in Dart, because the alternative is fetching three thousand rows to
  /// display twelve.
  @async
  List<CompressCandidate> candidates(String kind, int minBytes, int limit);

  /// Re-encodes into memory and reports the real size.
  ///
  /// Slow: a full decode and encode per file. The caller previews only what is
  /// on screen, never the whole list.
  /// [quality] applies to photos only. A screenshot is encoded losslessly and
  /// ignores it, which is why the output format is reported back rather than
  /// assumed from what was asked for.
  @async
  List<CompressPreview> preview(List<String> fileIds, int quality);

  /// Replaces the originals, keeping them in the trash.
  ///
  /// ─── THE ORIGINAL IS TRASHED, NOT DELETED ────────────────────────────────
  ///
  /// A re-encode is lossy and irreversible. The user gets thirty days to notice
  /// that a picture they cared about now has artefacts in the sky, which is the
  /// only safe way to offer this at all.
  @async
  List<CompressOutcome> compress(List<String> fileIds, int quality);

  /// Remembers files that were measured and cannot be improved.
  ///
  /// ─── THE OTHER HALF OF THE LOOP ──────────────────────────────────────────
  ///
  /// Excluding this app's own output stopped it offering to re-compress what it
  /// wrote. It did nothing about the far larger group: photographs that were
  /// already saved efficiently and gain nothing at all. Those are measured,
  /// shown as "no gain", left alone by the run, and then measured again from
  /// scratch the next time the screen opens, forever.
  ///
  /// After one run the list is made up entirely of those files, which is
  /// indistinguishable from the run having done nothing.
  ///
  /// Not recorded during [preview], which is speculative and runs on every
  /// scroll. Only when the user has actually run a compression and the answer
  /// has been acted on.
  @async
  void markNoGain(List<String> fileIds);

  /// Forgets every no-gain verdict.
  ///
  /// Called when the quality changes, because the verdict was reached at one
  /// setting and does not hold at another: a file that gains nothing at 85 may
  /// well gain at 65. Simpler and more obviously correct than storing a quality
  /// per file and comparing.
  @async
  void clearNoGain();

  /// What this app has already compressed, newest first.
  ///
  /// Kept in native rather than in Dart prefs because the candidate query needs
  /// it to exclude its own output, and a filter that lived on the far side of
  /// the bridge would mean shipping every row across just to drop most of them.
  @async
  List<CompressedEntry> history(int limit);

  /// Every clip, with the ineligible ones included and marked.
  ///
  /// Included rather than filtered, because a user whose largest video is
  /// missing from a list about making files smaller will assume the app failed
  /// to see it. Saying "already HEVC" costs one row and answers the question.
  @async
  List<VideoCandidate> videoCandidates(int minBytes, int limit);

  /// Encodes a slice of one clip and extrapolates from what it produced.
  ///
  /// Slow: seconds rather than milliseconds, because it really runs the
  /// encoder. The caller estimates what is on screen, one at a time, never the
  /// whole list.
  ///
  /// [preset] is "same" for a codec swap at matched quality, or "smaller" for a
  /// reduced bitrate as well. Resolution is never touched by either.
  @async
  VideoEstimate? estimateVideo(String fileId, String preset);

  /// Re-encodes clips and replaces them, keeping the originals in the trash.
  ///
  /// ─── LONGER THAN ANYTHING ELSE IN THIS APP ───────────────────────────────
  ///
  /// Minutes per file rather than milliseconds, so it runs behind a foreground
  /// service with a notification and can be stopped between files or during
  /// one. Progress arrives through the same [progress] call the image path
  /// uses, and [cancel] stops both.
  @async
  List<CompressOutcome> compressVideo(List<String> fileIds, String preset);

  /// One file, decoded once, returned as both versions.
  ///
  /// Deliberately not part of [preview]. That measures a whole selection and
  /// must stay cheap per file; this carries megabytes across the bridge and is
  /// only ever called for the single picture on screen.
  @async
  CompressComparison? comparison(String fileId, int quality);

  @async
  void cancel();

  @async
  CompressProgress progress();
}
