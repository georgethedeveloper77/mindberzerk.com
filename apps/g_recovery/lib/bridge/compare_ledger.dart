import '../core/prefs/prefs_keys.dart';
import '../core/prefs/prefs_store.dart';
import 'compare_api.g.dart';
import 'storage_api.g.dart';

/// WHAT A SCAN FOUND, KEPT BETWEEN LAUNCHES.
///
/// ─── WHY THIS HAD TO EXIST ───────────────────────────────────────────────────
///
/// A comparison decodes every photo on the phone. On a full device that is
/// minutes of work and real battery, and until now the result lived only in a
/// notifier: the process dying threw it away, and so did trashing a single
/// group, because both review pages called forget() on the way out.
///
/// So a person paid for the scan, used it once, and was asked to pay again. A
/// card reading "Scan" three days running is not a feature that has not been
/// used, it is a feature that cannot be finished.
///
/// ─── IT REMEMBERS THE MEASUREMENT, NEVER A PREDICTION ────────────────────────
///
/// Every figure here was measured on real files at [at]. What can go out of date
/// is whether it still describes the phone, and [fingerprint] answers that
/// without a second scan. A remembered measurement shown next to its date is
/// honest. The same number with no date would not be.
///
/// ─── PLAIN JSON IN PREFERENCES ───────────────────────────────────────────────
///
/// Read whole, written whole, a few hundred rows. The same call CompressLedger
/// made on the native side, for the same reason: a table would be the right
/// shape at ten thousand rows and pure ceremony here.
class ScanRecord {
  const ScanRecord({
    required this.at,
    required this.fingerprint,
    required this.scanned,
    required this.cancelled,
    required this.groups,
    required this.blurred,
  });

  /// From a fresh result.
  ///
  /// [fingerprint] is passed in rather than read here, so this file stays free
  /// of feature providers and a caller that cannot supply one gets an empty
  /// string, which means "cannot verify" rather than "verified fresh".
  factory ScanRecord.of(CompareResult result, {required String fingerprint}) =>
      ScanRecord(
        at: DateTime.now(),
        fingerprint: fingerprint,
        scanned: result.scanned,
        cancelled: result.cancelled,
        groups: result.groups,
        blurred: result.blurred,
      );

  final DateTime at;

  /// The state of storage when this was measured. Empty when it could not be
  /// read, which the UI treats as unverifiable rather than as a match.
  final String fingerprint;

  final int scanned;

  /// True when the user stopped it. The findings are real, they are just not
  /// the whole library, and the strip on the storage tab says so.
  final bool cancelled;

  final List<CompareGroup> groups;
  final List<BlurredImage> blurred;

  List<CompareGroup> ofKind(String kind) =>
      groups.where((CompareGroup group) => group.kind == kind).toList();

  /// Drops groups that have been acted on, and keeps everything else.
  ///
  /// THIS IS THE WHOLE POINT OF THE FILE. The old behaviour discarded the
  /// entire result the moment one group was trashed, on the correct reasoning
  /// that a group naming files now in the bin would offer to free space that is
  /// already free. That reasoning applies to the group that was trashed. It has
  /// never applied to the other thirty nine.
  ScanRecord withoutGroups(Set<String> groupIds) {
    if (groupIds.isEmpty) return this;
    return _copyWith(
      groups: <CompareGroup>[
        for (final CompareGroup group in groups)
          if (!groupIds.contains(group.groupId)) group,
      ],
    );
  }

  /// The same, for photos removed from the blur grid.
  ScanRecord withoutBlurred(Set<String> fileIds) {
    if (fileIds.isEmpty) return this;
    return _copyWith(
      blurred: <BlurredImage>[
        for (final BlurredImage image in blurred)
          if (!fileIds.contains(image.fileId)) image,
      ],
    );
  }

  ScanRecord _copyWith({
    List<CompareGroup>? groups,
    List<BlurredImage>? blurred,
  }) => ScanRecord(
    at: at,
    fingerprint: fingerprint,
    scanned: scanned,
    cancelled: cancelled,
    groups: groups ?? this.groups,
    blurred: blurred ?? this.blurred,
  );

  // ───────────────────────────────────────────────────────────────────────────
  // Persistence
  // ───────────────────────────────────────────────────────────────────────────

  /// Null when nothing has been scanned, or when the blob cannot be read.
  ///
  /// A corrupt record is treated as absent rather than thrown. Losing a scan
  /// costs the user a few minutes; crashing on launch costs them the app.
  static ScanRecord? read(PrefsStore prefs) {
    final Map<String, Object?> json = prefs.readJson(GPrefsKeys.compareScan);
    if (json.isEmpty) return null;

    final int millis = (json['at'] as num?)?.toInt() ?? 0;
    if (millis <= 0) return null;

    final Object? rawGroups = json['groups'];
    final Object? rawBlurred = json['blurred'];

    final List<CompareGroup> groups = <CompareGroup>[];
    if (rawGroups is List) {
      for (final Object? entry in rawGroups) {
        final CompareGroup? group = _group(entry);
        if (group != null) groups.add(group);
      }
    }

    final List<BlurredImage> blurred = <BlurredImage>[];
    if (rawBlurred is List) {
      for (final Object? entry in rawBlurred) {
        final BlurredImage? image = _blurredImage(entry);
        if (image != null) blurred.add(image);
      }
    }

    return ScanRecord(
      at: DateTime.fromMillisecondsSinceEpoch(millis),
      fingerprint: json['fingerprint'] as String? ?? '',
      scanned: (json['scanned'] as num?)?.toInt() ?? 0,
      cancelled: json['cancelled'] as bool? ?? false,
      groups: groups,
      blurred: blurred,
    );
  }

  /// Bounded, and the order of the trim is the point.
  ///
  /// Groups go out by smallest saving and blurred photos by sharpest, so what
  /// survives a trim is what a person would have acted on anyway. The caps are
  /// far above any real phone; they exist so that one pathological library
  /// cannot turn a synchronous read at launch into a stall.
  Future<void> write(PrefsStore prefs) {
    final List<CompareGroup> keptGroups = List<CompareGroup>.of(groups)
      ..sort(
        (CompareGroup a, CompareGroup b) =>
            b.wastedBytes.compareTo(a.wastedBytes),
      );
    final List<BlurredImage> keptBlurred = List<BlurredImage>.of(blurred)
      ..sort(
        (BlurredImage a, BlurredImage b) => a.sharpness.compareTo(b.sharpness),
      );

    return prefs.writeJson(GPrefsKeys.compareScan, <String, Object?>{
      'at': at.millisecondsSinceEpoch,
      'fingerprint': fingerprint,
      'scanned': scanned,
      'cancelled': cancelled,
      'groups': <Object?>[
        for (final CompareGroup group in keptGroups.take(_maxGroups))
          _groupJson(group),
      ],
      'blurred': <Object?>[
        for (final BlurredImage image in keptBlurred.take(_maxBlurred))
          _blurredJson(image),
      ],
    });
  }

  static Future<void> clear(PrefsStore prefs) =>
      prefs.remove(GPrefsKeys.compareScan);

  static const int _maxGroups = 400;
  static const int _maxBlurred = 400;

  // ───────────────────────────────────────────────────────────────────────────
  // Pigeon types, by hand
  // ───────────────────────────────────────────────────────────────────────────
  //
  // The generated classes have encode and decode, and both speak the codec's
  // positional list rather than JSON. Using them here would tie a file on disk
  // to a field order that is allowed to change whenever the schema grows, and a
  // record written by one version would be misread by the next rather than
  // rejected. Named keys cost a few lines and cannot silently shift.

  static Map<String, Object?> _groupJson(CompareGroup group) =>
      <String, Object?>{
        'groupId': group.groupId,
        'kind': group.kind,
        'fileIds': group.fileIds,
        'totalBytes': group.totalBytes,
        'wastedBytes': group.wastedBytes,
        'keepFileId': group.keepFileId,
        'sizes': group.sizes,
      };

  static CompareGroup? _group(Object? entry) {
    if (entry is! Map<String, Object?>) return null;
    final Object? fileIds = entry['fileIds'];
    final Object? sizes = entry['sizes'];
    if (fileIds is! List || sizes is! List) return null;

    final String groupId = entry['groupId'] as String? ?? '';
    final String keepFileId = entry['keepFileId'] as String? ?? '';
    if (groupId.isEmpty || keepFileId.isEmpty) return null;

    return CompareGroup(
      groupId: groupId,
      kind: entry['kind'] as String? ?? 'exact',
      fileIds: <String>[for (final Object? id in fileIds) id.toString()],
      totalBytes: (entry['totalBytes'] as num?)?.toInt() ?? 0,
      wastedBytes: (entry['wastedBytes'] as num?)?.toInt() ?? 0,
      keepFileId: keepFileId,
      sizes: <int>[
        for (final Object? size in sizes) (size as num?)?.toInt() ?? 0,
      ],
    );
  }

  static Map<String, Object?> _blurredJson(BlurredImage image) =>
      <String, Object?>{
        'fileId': image.fileId,
        'sharpness': image.sharpness,
        'sizeBytes': image.sizeBytes,
      };

  static BlurredImage? _blurredImage(Object? entry) {
    if (entry is! Map<String, Object?>) return null;
    final String fileId = entry['fileId'] as String? ?? '';
    if (fileId.isEmpty) return null;

    return BlurredImage(
      fileId: fileId,
      sharpness: (entry['sharpness'] as num?)?.toDouble() ?? 0,
      sizeBytes: (entry['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// WHETHER THE PHONE STILL LOOKS THE WAY IT DID WHEN THE SCAN RAN.
///
/// ─── THE OVERVIEW IS ALREADY LOADED, SO THIS IS FREE ─────────────────────────
///
/// MediaStore.getGeneration would be the textbook answer and it would cost a
/// fifth HostApi method, a Kotlin implementation, a Dart wrapper and an API 30
/// branch, to learn something these two numbers already imply. Adding or
/// removing a photo moves both of them.
///
/// It can be fooled, in theory: delete one file and add another of exactly the
/// same size in the same session. The cost of being wrong is a card that says
/// "checked yesterday" when it should say "photos have changed", which is not
/// worth a bridge method.
///
/// Empty when the overview has not resolved, and empty never matches anything,
/// which is why the comparison is written to treat empty as unverifiable rather
/// than as stale.
String storageFingerprint(StorageOverview? overview) => overview == null
    ? ''
    : '${overview.indexedBytes}:${overview.volume.usedBytes}';
