import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../core/logging.dart';
import 'compress_api.g.dart';

/// The Dart face of compression.
class CompressBridge {
  CompressBridge({CompressHostApi? api}) : _api = api ?? CompressHostApi();

  final CompressHostApi _api;

  /// Counts and bytes only. Cheap enough to call on a screen nobody asked to
  /// scan, which is the whole reason it exists separately.
  Future<CompressSummary?> summary({int minBytes = 1024 * 1024}) =>
      _guard(() => _api.summary(minBytes));

  Future<List<CompressCandidate>> candidates({
    String kind = 'all',
    int minBytes = 1024 * 1024,
    int limit = 300,
  }) async =>
      await _guard(() => _api.candidates(kind, minBytes, limit)) ??
      const <CompressCandidate>[];

  Future<List<CompressPreview>> preview(
    List<String> fileIds, {
    required int quality,
  }) async =>
      await _guard(() => _api.preview(fileIds, quality)) ??
      const <CompressPreview>[];

  Future<List<CompressOutcome>> compress(
    List<String> fileIds, {
    required int quality,
  }) async =>
      await _guard(() => _api.compress(fileIds, quality)) ??
      const <CompressOutcome>[];

  /// Both versions of one file. Megabytes, so one file at a time only.
  Future<CompressComparison?> comparison(String fileId, {required int quality}) =>
      // Explicit type argument, because the method is itself nullable.
      //
      // _guard returns Future<T?>, so inference against Future<CompressComparison?>
      // picks T = CompressComparison and then demands a non-null argument.
      // Naming T = CompressComparison? makes the two nulls collapse, which is
      // what was meant. Same trap server_bridge documents on nextRunMillis.
      _guard<CompressComparison?>(() => _api.comparison(fileId, quality));

  /// Every clip over the floor, with the ineligible ones included and marked.
  Future<List<VideoCandidate>> videoCandidates({
    int minBytes = 8 * 1024 * 1024,
    int limit = 300,
  }) async =>
      await _guard(() => _api.videoCandidates(minBytes, limit)) ??
      const <VideoCandidate>[];

  /// Encodes a slice of one clip and extrapolates. Seconds, not milliseconds.
  Future<VideoEstimate?> estimateVideo(
    String fileId, {
    String preset = 'same',
  }) => _guard<VideoEstimate?>(
    () => _api.estimateVideo(fileId, preset),
  );

  /// Re-encodes clips and replaces them. Minutes, behind a notification.
  Future<List<CompressOutcome>> compressVideo(
    List<String> fileIds, {
    String preset = 'same',
  }) async =>
      await _guard(() => _api.compressVideo(fileIds, preset)) ??
      const <CompressOutcome>[];

  /// Remembers files that measured no gain, so they stop coming back.
  Future<void> markNoGain(List<String> fileIds) async =>
      _guard(() => _api.markNoGain(fileIds));

  /// Forgets those verdicts, because they were reached at one quality.
  Future<void> clearNoGain() async => _guard(_api.clearNoGain);

  /// What has already been made smaller, newest first.
  Future<List<CompressedEntry>> history({int limit = 400}) async =>
      await _guard(() => _api.history(limit)) ?? const <CompressedEntry>[];

  Future<void> cancel() async => _guard(_api.cancel);

  Future<CompressProgress?> progress() => _guard(_api.progress);

  Future<T?> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (error, stackTrace) {
      GLog.e(
        'compress call failed',
        scope: 'compress',
        cause: '${error.code}: ${error.message}',
        stackTrace: stackTrace,
      );
      return null;
    } on MissingPluginException {
      GLog.w('compress bridge not registered', scope: 'compress');
      return null;
    }
  }
}

final Provider<CompressBridge> compressBridgeProvider =
    Provider<CompressBridge>((Ref ref) => CompressBridge());

/// Counts and bytes per category, with nothing encoded.
///
/// ─── SAFE TO WATCH FROM THE STORAGE TAB ──────────────────────────────────────
///
/// Every other provider here measures by re-encoding, which is why none of them
/// may run unasked. This one is a single MediaStore query, so the tab can say
/// how many screenshots there are before anyone has agreed to a scan, and it
/// still promises no saving it has not measured.
final FutureProvider<CompressSummary?> compressSummaryProvider =
    FutureProvider<CompressSummary?>(
      (Ref ref) => ref.watch(compressBridgeProvider).summary(),
    );

/// Images over a megabyte, largest first.
///
/// A megabyte is the floor because below it the saving is measured in tens of
/// kilobytes and the quality loss is permanent either way. Offering a 400 KB
/// photo would be asking someone to trade something real for nothing.
final FutureProvider<List<CompressCandidate>> compressCandidatesProvider =
    FutureProvider<List<CompressCandidate>>(
      (Ref ref) => ref.watch(compressBridgeProvider).candidates(),
    );

/// Candidates for one scope, which is how every list screen asks.
///
/// Family rather than one list filtered in Dart: the query does the work, and
/// fetching three thousand rows to display twelve is the shape of thing that
/// makes a list feel slow for no reason a user could name.
final FutureProviderFamily<List<CompressCandidate>, String>
compressScopeProvider =
    FutureProvider.family<List<CompressCandidate>, String>(
      (Ref ref, String kind) =>
          ref.watch(compressBridgeProvider).candidates(kind: kind),
    );

/// Both versions of one picture, for the viewer.
///
/// Autodisposed by the family, which matters more here than anywhere else in
/// this file: each entry holds two full size image buffers, and a paged viewer
/// that kept every page it had visited would run a phone out of memory in a
/// couple of dozen swipes.
final FutureProviderFamily<CompressComparison?, ({String fileId, int quality})>
compressComparisonProvider =
    FutureProvider.family<CompressComparison?, ({String fileId, int quality})>(
      (Ref ref, ({String fileId, int quality}) request) => ref
          .watch(compressBridgeProvider)
          .comparison(request.fileId, quality: request.quality),
    );

/// How a run is going, polled while one is happening.
///
/// ─── THE RUN SCREEN HAD NONE OF THIS, AND THE API ALWAYS DID ─────────────────
///
/// CompressProgress has carried done, total, bytes saved and the file being
/// worked on since the first version of this bridge, and nothing read it. The
/// screen showed a spinner and a paragraph for what can be a minute of work on
/// fifty photos, which is the shape of a progress bar that was never wired up.
///
/// Polled rather than pushed, the same choice the transfer screen makes: one
/// update per file is far too little traffic to justify a FlutterApi, and the
/// poll stops by itself once nothing is running.
final StreamProvider<CompressProgress?> compressProgressProvider =
    StreamProvider<CompressProgress?>((Ref ref) async* {
      final CompressBridge bridge = ref.watch(compressBridgeProvider);

      CompressProgress? state = await bridge.progress();
      yield state;

      int idle = 0;
      while (idle < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        state = await bridge.progress();
        yield state;

        // Two quiet ticks after it stops, then the poll ends. Long enough to
        // catch the final count, short enough that an idle screen is not asking
        // a question forever.
        idle = (state?.running ?? false) ? 0 : idle + 1;
      }
    });

/// Clips, with a verdict on each.
///
/// A far higher floor than the image path: eight megabytes rather than one.
/// Below that a video is a few seconds long, gains almost nothing, and would
/// still cost a full encode to find out.
final FutureProvider<List<VideoCandidate>> videoCandidatesProvider =
    FutureProvider<List<VideoCandidate>>(
      (Ref ref) => ref.watch(compressBridgeProvider).videoCandidates(),
    );

/// One clip's forecast.
///
/// A family so each row asks for its own, and only when it is on screen. A
/// provider that estimated the whole list on open would run the encoder sixty
/// times before drawing anything.
final FutureProviderFamily<VideoEstimate?, ({String fileId, String preset})>
videoEstimateProvider =
    FutureProvider.family<VideoEstimate?, ({String fileId, String preset})>(
      (Ref ref, ({String fileId, String preset}) request) => ref
          .watch(compressBridgeProvider)
          .estimateVideo(request.fileId, preset: request.preset),
    );

/// The record of what this app has already compressed.
///
/// Invalidated after every run rather than polled, because it only changes when
/// this app changes it and nothing else on the phone can write to it.
final FutureProvider<List<CompressedEntry>> compressHistoryProvider =
    FutureProvider<List<CompressedEntry>>(
      (Ref ref) => ref.watch(compressBridgeProvider).history(),
    );

/// The chosen quality, 60 to 95.
///
/// 85 by default. Below 80 artefacts start showing in skies and skin on a phone
/// screen, which is where a person would actually notice; above 90 the file
/// barely shrinks and the whole exercise stops being worth the loss.
class CompressQuality extends Notifier<int> {
  @override
  int build() => 85;

  void select(int value) => state = value.clamp(60, 95);
}

final NotifierProvider<CompressQuality, int> compressQualityProvider =
    NotifierProvider<CompressQuality, int>(CompressQuality.new);

/// What a re-encode would really produce, for the files asked about.
///
/// Keyed on the quality as well as the ids, so moving the slider recomputes
/// rather than showing a saving measured at a different setting.
final FutureProviderFamily<
  List<CompressPreview>,
  ({List<String> ids, int quality})
>
compressPreviewProvider =
    FutureProvider.family<
      List<CompressPreview>,
      ({List<String> ids, int quality})
    >(
      (Ref ref, ({List<String> ids, int quality}) request) => ref
          .watch(compressBridgeProvider)
          .preview(request.ids, quality: request.quality),
    );
