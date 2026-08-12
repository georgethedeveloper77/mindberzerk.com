import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bridge/compare_api.g.dart';
import '../../../bridge/compare_bridge.dart';
import '../../../bridge/storage_api.g.dart';
import '../../../core/format.dart';
import '../model/storage_view.dart';
import 'storage_files.dart';
import 'storage_providers.dart';

/// The bridge overview, reshaped for the ledger.
///
/// A separate step rather than the widget reading StorageOverview directly,
/// because the ledger has to add up to a whole disk and the overview only
/// accounts for what MediaStore indexes. Everything else, app code and every
/// app's private directory, is a gap that no app can enumerate, and the model
/// derives it rather than any widget having to know that.
final Provider<StorageBreakdown?>
storageBreakdownProvider = Provider<StorageBreakdown?>((Ref ref) {
  final StorageOverview? overview = ref.watch(storageOverviewProvider).value;
  if (overview == null) return null;

  // Largest first. The bar is drawn in this order, so the eye lands on the
  // segment worth acting on rather than on whichever kind happens to sort first
  // alphabetically.
  final List<KindUsage> kinds = List<KindUsage>.of(overview.kinds)
    ..sort((KindUsage a, KindUsage b) => b.totalBytes.compareTo(a.totalBytes));

  return StorageBreakdown(
    totalBytes: overview.volume.totalBytes,
    freeBytes: overview.volume.freeBytes,
    buckets: <StorageBucket>[
      for (final KindUsage kind in kinds)
        if (kind.totalBytes > 0)
          StorageBucket(
            id: kind.kind,
            label: _label(kind.kind),
            bytes: kind.totalBytes,
          ),
    ],
  );
});

/// What can be reclaimed, and what cannot be answered yet.
///
/// Every figure here is now real. The three comparison cards say "Not checked"
/// until a scan has run rather than claiming a number, and the two query backed
/// ones read the same query as the page they open, so a card and its page can
/// no longer disagree.
///
/// Below this, a saving is not worth a card. Ten megabytes: a row that lights up
/// for thirty six bytes teaches people to ignore the whole section, which costs
/// more than the row was ever worth.
const int _worthShowing = 10 * 1024 * 1024;

final Provider<List<ReclaimAction>>
reclaimActionsProvider = Provider<List<ReclaimAction>>((Ref ref) {
  // Needs no scan and no comparison. MediaIndex already returns every query
  // sorted by size descending, so the biggest files are simply the top of a list
  // MediaStore has already indexed.
  final StorageQueryResult? large = ref
      .watch(storageFilesProvider(kLargeFilesScope))
      .value;

  // Summed in Dart because the query returns them already ordered, so the ten
  // biggest are the first ten rows and no second pass is needed.
  final int? top = large?.files
      .take(10)
      .fold<int>(0, (int sum, StorageFile f) => sum + f.sizeBytes);

  // Null until the user runs a comparison. These three cards are the only ones
  // on the screen whose figure costs minutes of decoding to produce, so they
  // ask before they answer rather than quietly starting the work.
  final List<CompareGroup> exact = ref.watch(exactGroupsProvider);
  final List<CompareGroup> similar = ref.watch(similarGroupsProvider);
  final List<BlurredImage> blurred = ref.watch(blurredProvider);
  final bool compared = ref.watch(compareProvider).value != null;
  final bool comparing = ref.watch(compareProvider).isLoading;

  int wasted(List<CompareGroup> groups) => groups.fold<int>(
    0,
    (int sum, CompareGroup group) => sum + group.wastedBytes,
  );

  // FROM THE QUERY, NOT THE AGE BUCKETS.
  //
  // The buckets counted every indexed file over two years old, which on a real
  // phone is twelve .nomedia markers totalling thirty six bytes. Technically
  // true and completely useless: a card offering to reclaim 36 B is noise
  // sitting where a real saving should be.
  //
  // The query is the same one the card opens, so the number on the card and the
  // number on the page it leads to can no longer disagree.
  final StorageQueryResult? staleQuery = ref
      .watch(storageFilesProvider(kStaleScope))
      .value;

  return <ReclaimAction>[
    ReclaimAction(
      id: 'stale',
      label: 'Untouched',
      value: staleQuery == null
          ? 'Counting'
          : staleQuery.matchBytes < _worthShowing
          ? 'Nothing'
          : GFormat.bytes(staleQuery.matchBytes),
      detail: staleQuery == null || staleQuery.matchBytes < _worthShowing
          ? 'Files untouched for two years'
          : '${GFormat.count(staleQuery.matchCount)} files, two years or older',
      // A floor, not a zero check. Ten megabytes is the point below which
      // clearing something is not worth a person's attention, and a card that
      // lights up for 36 B teaches people to ignore the whole row.
      ready: staleQuery != null && staleQuery.matchBytes >= _worthShowing,
    ),
    ReclaimAction(
      id: 'duplicates',
      label: 'Duplicates',
      value: comparing
          ? 'Scanning'
          : !compared
          ? 'Scan'
          : exact.isEmpty
          ? 'None'
          : GFormat.bytes(wasted(exact)),
      detail: !compared
          ? 'Byte identical copies, safe to remove'
          : exact.isEmpty
          ? 'No identical copies on this phone'
          : '${GFormat.count(exact.length)} sets, identical',
      ready: exact.isNotEmpty,
    ),
    ReclaimAction(
      id: 'similar',
      label: 'Similar photos',
      value: comparing
          ? 'Scanning'
          : !compared
          ? 'Scan'
          : similar.isEmpty
          ? 'None'
          : GFormat.count(similar.length),
      detail: !compared
          ? 'Bursts and near copies, keep the best'
          : similar.isEmpty
          ? 'Nothing looks like anything else'
          : 'sets, ${GFormat.bytes(wasted(similar))} if you keep one each',
      ready: similar.isNotEmpty,
    ),
    ReclaimAction(
      id: 'blurred',
      label: 'Blurred',
      value: comparing
          ? 'Scanning'
          : !compared
          ? 'Scan'
          : blurred.isEmpty
          ? 'None'
          : GFormat.count(blurred.length),
      // Says "worth a look" rather than "delete these". A portrait with a soft
      // background and a photo of fog both score low and neither is a mistake,
      // and no measurement can tell blur from intent.
      detail: !compared
          ? 'Photos that came out soft'
          : blurred.isEmpty
          ? 'Everything looks sharp'
          : 'photos worth a second look',
      ready: blurred.isNotEmpty,
    ),
    ReclaimAction(
      id: 'large',
      label: 'Biggest files',
      // The top ten, not the whole disk. Every file added together is the
      // number already at the top of this screen, and repeating it here would
      // say nothing; what a person wants to know is how much sits in the few
      // files worth looking at first.
      value: top == null ? 'Counting' : GFormat.bytes(top),
      detail: large == null || large.files.isEmpty
          ? 'Everything you own, biggest first'
          : 'in the ten biggest, of '
                '${GFormat.count(large.matchCount)} files',
      ready: top != null && top > 0,
    ),
  ];
});

String _label(String kind) {
  switch (kind) {
    case 'image':
      return 'Images';
    case 'video':
      return 'Videos';
    case 'audio':
      return 'Audio';
    case 'document':
      return 'Documents';
    default:
      return 'Other files';
  }
}
