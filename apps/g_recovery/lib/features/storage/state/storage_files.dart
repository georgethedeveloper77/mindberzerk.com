import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bridge/storage_api.g.dart';
import '../../../ui/g_sort.dart';
import 'storage_providers.dart';

/// What a drill in page is looking at.
///
/// Its own type rather than reusing StorageFilter, because the tab's filter is a
/// user setting shared by the whole screen and this is a page's own question. A
/// page that hijacked the shared filter would change the tab underneath itself
/// and leave the chips lit when the user came back.
///
/// Value equality is written out by hand. This is a provider family key, and
/// Pigeon's generated classes have no equals at all, so a spec used directly
/// would rebuild and refetch on every single build.
@immutable
class StorageScope {
  const StorageScope({
    required this.title,
    this.kind,
    this.minBytes,
    this.olderThanDays,
    this.folderPrefix,
    this.sort = GSortMode.largest,
  });

  /// A copy in a different order. The scope is a family key, so a new order has
  /// to produce a new key or the provider would serve the cached list.
  StorageScope sorted(GSortMode next) => StorageScope(
    title: title,
    kind: kind,
    minBytes: minBytes,
    olderThanDays: olderThanDays,
    folderPrefix: folderPrefix,
    sort: next,
  );

  final String title;

  /// "image" | "video" | "audio" | "document" | "other". Null means every kind.
  final String? kind;

  final int? minBytes;
  final int? olderThanDays;

  /// One folder, from the treemap. Native matches on RELATIVE_PATH.
  final String? folderPrefix;

  /// Sent to native, which orders every matching row before the limit applies.
  final GSortMode sort;

  StorageQuerySpec toSpec() => StorageQuerySpec(
    kinds: kind == null ? const <String>[] : <String>[kind!],
    // 400 rather than the 300 the tab uses. A grid shows three per row, so
    // the same number of rows costs more items, and this is the page a
    // person scrolls rather than glances at.
    limit: 400,
    minBytes: minBytes,
    olderThanDays: olderThanDays,
    folderPrefix: folderPrefix,
    sort: sort.name,
  );

  @override
  bool operator ==(Object other) =>
      other is StorageScope &&
      other.title == title &&
      other.kind == kind &&
      other.minBytes == minBytes &&
      other.olderThanDays == olderThanDays &&
      other.folderPrefix == folderPrefix &&
      other.sort == sort;

  @override
  int get hashCode =>
      Object.hash(title, kind, minBytes, olderThanDays, folderPrefix, sort);
}

/// Everything, biggest first.
///
/// NO SIZE FLOOR, and removing the one I had put there is the point.
///
/// MediaIndex already sorts every query by size descending, so a floor was not
/// making the list large, it was hiding the rest of it behind an arbitrary
/// cliff. A phone whose biggest file is 60 MB would have been told it has no
/// large files, which is both useless and untrue.
///
/// Without a floor the page is simply the phone's files ranked by size, which is
/// what the name promises and what a person opening it expects to find.
const StorageScope kLargeFilesScope = StorageScope(title: 'Biggest files');

/// Two years or older.
///
/// 730 days rather than a calendar count, because the query counts days and the
/// age buckets count years. The two can disagree by a few files either side of
/// the boundary, which is worth knowing before someone reports it as a bug.
const StorageScope kStaleScope = StorageScope(
  title: 'Untouched',
  olderThanDays: 730,
);

/// The files a scope matches.
final storageFilesProvider =
    FutureProvider.family<StorageQueryResult?, StorageScope>(
      (Ref ref, StorageScope scope) =>
          ref.watch(storageBridgeProvider).query(scope.toSpec()),
    );

/// Everything native needs to draw a preview, as one family key.
///
/// The id alone is not enough any more: audio artwork and PDF first pages are
/// reached by kind, and native has no type for a bare file id. Carrying them in
/// the key means the provider caches per file rather than per file per call
/// site, and equality is written out because this is a family key.
@immutable
class ThumbRequest {
  const ThumbRequest({
    required this.fileId,
    required this.kind,
    this.name,
    this.mimeType,
    this.maxPixels = 256,
  });

  /// From the file being drawn, so a caller cannot get it wrong.
  factory ThumbRequest.of(StorageFile file, {int maxPixels = 256}) =>
      ThumbRequest(
        fileId: file.fileId,
        kind: file.kind,
        name: file.name,
        mimeType: file.mimeType,
        maxPixels: maxPixels,
      );

  final String fileId;
  final String kind;
  final String? name;
  final String? mimeType;
  final int maxPixels;

  @override
  bool operator ==(Object other) =>
      other is ThumbRequest &&
      other.fileId == fileId &&
      other.maxPixels == maxPixels;

  /// Deliberately keyed on the id and the size only.
  ///
  /// The other three are derived from the same file, so two requests with the
  /// same id and size cannot legitimately differ in them, and including them
  /// would only risk a cache miss on a null that arrived late.
  @override
  int get hashCode => Object.hash(fileId, maxPixels);
}

/// Preview bytes for one file.
///
/// 256 pixels by default, matching the recovery grid. A cell is about 110
/// logical pixels, so this is already generous at 3x, and a screen of ninety
/// full resolution decodes is how a gallery runs out of memory.
final storageThumbProvider = FutureProvider.family<Uint8List?, ThumbRequest>(
  (Ref ref, ThumbRequest request) => ref
      .watch(storageBridgeProvider)
      .thumbnail(
        request.fileId,
        request.maxPixels,
        kind: request.kind,
        name: request.name,
        mimeType: request.mimeType,
      ),
);
