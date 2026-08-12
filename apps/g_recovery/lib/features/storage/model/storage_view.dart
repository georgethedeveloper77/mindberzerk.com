import 'package:flutter/foundation.dart' show immutable;

/// What the Storage screen draws, described independently of where it came from.
///
/// A view model rather than the bridge types on purpose. The ledger has to add
/// up to a whole disk, and the pieces come from different places: MediaStore
/// answers for media, PackageManager for apps, StatFs for the total and the
/// free space, and the trash total is already known from the recovery prescan.
/// Binding the widgets to any one of those would mean rebuilding them when the
/// next piece arrives.
@immutable
class StorageBreakdown {
  const StorageBreakdown({
    required this.totalBytes,
    required this.freeBytes,
    required this.buckets,
  });

  final int totalBytes;
  final int freeBytes;

  /// Largest first. The widget does not sort, so a caller can pin a bucket if
  /// it ever needs to.
  final List<StorageBucket> buckets;

  int get usedBytes => totalBytes - freeBytes;

  /// Whatever the buckets do not account for.
  ///
  /// Never negative and never hidden. Android's own storage screens quietly
  /// fold this into "System" or "Other files", which is how a user ends up
  /// staring at 16 GB they cannot explain. If the sum falls short of what the
  /// filesystem reports, the gap is real and is drawn as its own segment.
  int get unaccountedBytes {
    final int counted = buckets.fold<int>(
      0,
      (int total, StorageBucket bucket) => total + bucket.bytes,
    );
    final int gap = usedBytes - counted;
    return gap > 0 ? gap : 0;
  }
}

/// One slice of the disk.
@immutable
class StorageBucket {
  const StorageBucket({
    required this.id,
    required this.label,
    required this.bytes,
    this.drillable = true,
  });

  /// Stable key. The colour and the glyph are chosen from this, so a bucket
  /// keeps its identity across the bar, the legend and any screen it opens.
  final String id;

  final String label;
  final int bytes;

  /// False for anything the app can measure but not enumerate. System is the
  /// obvious case: showing a chevron that opens an empty page is worse than
  /// showing no chevron.
  final bool drillable;
}

/// One of the four things worth doing about it.
@immutable
class ReclaimAction {
  const ReclaimAction({
    required this.id,
    required this.label,
    required this.value,
    required this.detail,
    this.ready = true,
  });

  final String id;
  final String label;

  /// Already formatted. Some of these are sizes and some are counts, and
  /// forcing them into one type would mean the widget deciding which, which is
  /// the caller's business.
  final String value;

  final String detail;

  /// False while the figure is still being worked out, or when the feature it
  /// leads to has not been set up. Drawn flat, and does not claim a number it
  /// cannot stand behind.
  final bool ready;
}
