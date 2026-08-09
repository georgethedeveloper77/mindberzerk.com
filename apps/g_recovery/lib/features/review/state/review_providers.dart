import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bridge/recovery_api.g.dart';
import '../../recovery/state/recovery_providers.dart';

/// What the user decided about one item. Nothing has happened yet.
enum ReviewVerdict { keep, bin }

@immutable
class ReviewSession {
  const ReviewSession({
    required this.queue,
    required this.index,
    required this.verdicts,
  });

  final List<RecoverableItem> queue;

  /// Position in [queue]. Equal to queue.length when the session is finished.
  final int index;

  /// Decisions so far, keyed by item id.
  ///
  /// A MAP RATHER THAN TWO SETS, so undo is a removal and a re-decision is an
  /// overwrite. Two sets would let an item end up in both after an undo, which
  /// is the bug that makes a review tool delete something the user kept.
  final Map<String, ReviewVerdict> verdicts;

  bool get isDone => index >= queue.length;

  RecoverableItem? get current => isDone ? null : queue[index];

  RecoverableItem? get next =>
      index + 1 < queue.length ? queue[index + 1] : null;

  Iterable<RecoverableItem> get binned => queue.where(
        (RecoverableItem item) => verdicts[item.itemId] == ReviewVerdict.bin,
      );

  Iterable<RecoverableItem> get kept => queue.where(
        (RecoverableItem item) => verdicts[item.itemId] == ReviewVerdict.keep,
      );

  int get reviewed => verdicts.length;

  int get binnedBytes =>
      binned.fold(0, (int sum, RecoverableItem item) => sum + item.sizeBytes);

  ReviewSession copyWith({
    int? index,
    Map<String, ReviewVerdict>? verdicts,
  }) =>
      ReviewSession(
        queue: queue,
        index: index ?? this.index,
        verdicts: verdicts ?? this.verdicts,
      );
}

/// Owns the session.
///
/// NOTHING IS DELETED OR RESTORED UNTIL [commit]. That is the whole contract of
/// this screen: swiping is fast and mistakes are certain, so every decision has
/// to be reversible right up to a single explicit confirmation. A review tool
/// that acts on each swipe is a review tool that loses a photo.
class ReviewController extends Notifier<ReviewSession?> {
  @override
  ReviewSession? build() => null;

  void start(List<RecoverableItem> items) {
    state = ReviewSession(
      queue: List<RecoverableItem>.unmodifiable(items),
      index: 0,
      verdicts: const <String, ReviewVerdict>{},
    );
  }

  void decide(ReviewVerdict verdict) {
    final ReviewSession? session = state;
    final RecoverableItem? item = session?.current;
    if (session == null || item == null) return;
    state = session.copyWith(
      index: session.index + 1,
      verdicts: <String, ReviewVerdict>{
        ...session.verdicts,
        item.itemId: verdict,
      },
    );
  }

  /// Steps back one and forgets that decision.
  void undo() {
    final ReviewSession? session = state;
    if (session == null || session.index == 0) return;
    final RecoverableItem previous = session.queue[session.index - 1];
    final Map<String, ReviewVerdict> verdicts =
        Map<String, ReviewVerdict>.of(session.verdicts)..remove(previous.itemId);
    state = session.copyWith(index: session.index - 1, verdicts: verdicts);
  }

  /// Skips without recording anything, so the item stays untouched.
  void skip() {
    final ReviewSession? session = state;
    if (session == null || session.isDone) return;
    state = session.copyWith(index: session.index + 1);
  }

  void end() => state = null;

  /// Applies every decision, in one pass, and only when called.
  ///
  /// Restores first. If storage is tight, a purge that runs first frees room the
  /// restore then needs, but the reverse ordering means a failed restore has not
  /// already had its source deleted.
  Future<ReviewOutcome> commit() async {
    final ReviewSession? session = state;
    if (session == null) return const ReviewOutcome(restored: 0, deleted: 0);

    final List<String> keep =
        session.kept.map((RecoverableItem item) => item.itemId).toList();
    final List<String> bin =
        session.binned.map((RecoverableItem item) => item.itemId).toList();

    final RecoveryBridgeRef bridge = RecoveryBridgeRef(ref);
    final List<RestoreOutcome> restored =
        keep.isEmpty ? const <RestoreOutcome>[] : await bridge.restore(keep);
    final List<RestoreOutcome> deleted =
        bin.isEmpty ? const <RestoreOutcome>[] : await bridge.purge(bin);

    state = null;
    ref.invalidate(recoveryItemsProvider);
    ref.invalidate(prescanProvider);

    return ReviewOutcome(
      restored: restored.where(_ok).length,
      deleted: deleted.where(_ok).length,
      firstProblem: <RestoreOutcome>[...restored, ...deleted]
          .where((RestoreOutcome outcome) => !_ok(outcome))
          .firstOrNull,
    );
  }

  static bool _ok(RestoreOutcome outcome) => outcome.status == 'restored';
}

@immutable
class ReviewOutcome {
  const ReviewOutcome({
    required this.restored,
    required this.deleted,
    this.firstProblem,
  });

  final int restored;
  final int deleted;
  final RestoreOutcome? firstProblem;
}

/// Small indirection so the controller reads as intent instead of as chained
/// provider reads.
class RecoveryBridgeRef {
  const RecoveryBridgeRef(this.ref);

  final Ref ref;

  Future<List<RestoreOutcome>> restore(List<String> ids) =>
      ref.read(recoveryBridgeProvider).restore(ids);

  Future<List<RestoreOutcome>> purge(List<String> ids) =>
      ref.read(recoveryBridgeProvider).purge(ids);
}

final NotifierProvider<ReviewController, ReviewSession?> reviewProvider =
    NotifierProvider<ReviewController, ReviewSession?>(ReviewController.new);
