import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/recovery_api.g.dart';
import '../../../core/format.dart';
import '../../../app/shell.dart';
import '../../../ui/art/escape_art.dart';
import '../../../ui/g_badge.dart';
import '../../../ui/g_button.dart';
import '../../../ui/g_card.dart';
import '../../recovery/category_page.dart';
import '../../recovery/state/recovery_providers.dart';
import '../../../core/i18n/g_strings.dart';

/// The one number the whole app is built around, with a deadline under it.
///
/// Laid out as a Row, not a Stack with a Positioned overlay. The overlay
/// version looked right until the subtitle wrapped to two lines and ran
/// straight through the illustration, which is the failure mode of every
/// hard coded inset: it is invisible until the content is real.
class HeroCard extends ConsumerWidget {
  const HeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final RecoverySummary? summary = ref.watch(prescanProvider).value;

    // ─── THREE STATES, NOT TWO ─────────────────────────────────────────────
    //
    // A prescan runs on its own and returns counts, so a summary arriving is
    // not the same as the phone having been looked through properly. Without
    // file access it reports what it could reach, which on a fresh install is
    // usually nothing, and the card then said the trash was clear.
    //
    // It was the one place in this app that stated something it did not know.
    final bool blind =
        summary != null && summary.totalItems == 0 && summary.partial;
    final bool scanned = ref.watch(scanControllerProvider).value != null;

    // ─── THE BACKGROUND STATE, NOT THE PUSH STREAM ─────────────────────────
    //
    // scanProgressProvider is a push channel from the bridge and only lives
    // while a Flutter engine does. The scan deliberately outlives the engine,
    // so a user who leaves during one and comes back would find a screen that
    // had missed every event and believed nothing was running.
    //
    // backgroundScanProvider asks instead, quickly while a scan is going and
    // then twice more before it stops. It is the only one of the two that can
    // answer after a resume.
    final BackgroundScanState? scan = ref.watch(backgroundScanProvider).value;
    final bool running = scan?.running ?? false;

    // Counts come from the prescan, which does not update itself while the
    // service walks. Refreshed once when the scan settles rather than polled,
    // because re-running it every second would be a second scan chasing the
    // first.
    ref.listen<AsyncValue<BackgroundScanState?>>(backgroundScanProvider, (
      AsyncValue<BackgroundScanState?>? was,
      AsyncValue<BackgroundScanState?> now,
    ) {
      final bool wasRunning = was?.value?.running ?? false;
      final bool isRunning = now.value?.running ?? false;
      if (wasRunning && !isRunning) ref.invalidate(prescanProvider);
    });

    return GCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(GSpace.lg - 1, GSpace.lg, 0, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        running ? 'CHECKING THIS PHONE' : 'RECOVERABLE NOW',
                        style: GType.overline.copyWith(
                          color: running ? t.accent : t.dim,
                        ),
                      ),
                      const SizedBox(height: GSpace.sm),
                      Text(
                        // A dash, not a nought. Nothing was counted, so there
                        // is no number to print, and a zero here is an answer
                        // to a question nobody asked.
                        running
                            // What the walk has turned up so far, climbing.
                            // The prescan total is stale the moment a scan
                            // starts, and showing it beside a running progress
                            // bar would be two numbers disagreeing.
                            ? GFormat.count(scan?.found ?? 0)
                            : summary == null
                            ? '  '
                            : blind
                            ? '\u2014'
                            : GFormat.count(summary.totalItems),
                        style: GType.monoDisplay.copyWith(
                          color: running
                              ? t.accent
                              : blind
                              ? t.dim
                              : t.text,
                        ),
                      ),
                      const SizedBox(height: GSpace.xs),
                      Text(
                        running
                            ? _progressLine(scan!)
                            : _subtitle(
                                summary,
                                blind: blind,
                                scanned: scanned,
                              ),
                        style: GType.monoSmall.copyWith(
                          color: running || summary == null || blind
                              ? t.dim
                              : t.success,
                        ),
                      ),
                    ],
                  ),
                ),
                // Fixed width, so the art can never encroach on the text no
                // matter how the numbers wrap.
                //
                // ─── EscapeArt REPLACES GArtSlot AND BinRisePainter ──────────
                //
                // Those two were deleted when the art was unified: one widget
                // now draws every empty state in the app with the same bin and
                // the same motion, changing only what comes out of it. Five
                // shapes rather than five painters, and no Lottie.
                SizedBox(
                  width: 124,
                  child: EscapeArt(
                    height: 124,
                    // ─── OFF WHEN HOME IS NOT SHOWING ────────────────────────
                    //
                    // Home sits in an IndexedStack, so this card stays mounted
                    // for the life of the app. Without the flag its ticker
                    // repaints behind Storage, Device and More forever, which
                    // is exactly the drain a device utility has least excuse
                    // for.
                    active: ref.watch(gShellTabProvider) == GTabs.home,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              GSpace.lg - 1,
              GSpace.md,
              GSpace.lg - 1,
              GSpace.lg - 1,
            ),
            child: Column(
              children: <Widget>[
                // Not over a dash. A floor under a real count is a useful
                // warning; a floor under nothing is a warning about a number
                // that does not exist.
                if (summary != null && summary.partial && !blind) ...<Widget>[
                  Row(
                    children: <Widget>[
                      GBadge.partial('Floor, not a total'),
                      const SizedBox(width: GSpace.sm),
                      Expanded(
                        child: Text(
                          context.s('Counted without file access'),
                          style: GType.micro.copyWith(color: t.dim),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: GSpace.md),
                ],
                // ─── A REAL BAR, BECAUSE THERE IS A REAL TOTAL ────────────
                //
                // ScanProgress documents its total as a count taken before the
                // walk begins rather than a timer dressed up as progress, so
                // this can be honest where most apps cannot.
                //
                // Absent while the total is still zero, which happens for the
                // moment between starting and the first count landing. A bar
                // that jumps from full to empty looks broken.
                if (running && (scan?.total ?? 0) > 0) ...<Widget>[
                  ClipRRect(
                    borderRadius: GRadius.all(4),
                    child: SizedBox(
                      height: 5,
                      child: Stack(
                        children: <Widget>[
                          Positioned.fill(child: ColoredBox(color: t.panelAlt)),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0,
                              end: (scan!.scanned / scan.total).clamp(0.0, 1.0),
                            ),
                            duration: GMotion.slow,
                            curve: Curves.easeOut,
                            builder:
                                (
                                  BuildContext context,
                                  double value,
                                  Widget? _,
                                ) => FractionallySizedBox(
                                  widthFactor: value,
                                  child: ColoredBox(color: t.accent),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: GSpace.md),
                ],

                // ─── THE BUTTON FOLLOWS THE STATE ─────────────────────────
                //
                // On a phone that has not been looked through, the only useful
                // action is to look. A disabled Review button on a fresh
                // install is a dead control on the one screen a new user reads,
                // and it was the only thing offered.
                if (running)
                  GButton(
                    label: context.s('Stop'),
                    kind: GButtonKind.ghost,
                    onPressed: () async {
                      await ref.read(recoveryBridgeProvider).cancelScan();
                      ref.invalidate(backgroundScanProvider);
                    },
                  )
                else if (blind)
                  GButton(
                    label: context.s('Turn on file access'),
                    icon: Icons.folder_open_rounded,
                    onPressed: () async {
                      await ref
                          .read(recoveryBridgeProvider)
                          .requestAllFilesAccess();
                      ref.invalidate(recoveryAccessProvider);
                      ref.invalidate(prescanProvider);
                    },
                  )
                else if (summary != null && summary.totalItems == 0 && !scanned)
                  GButton(
                    label: context.s('Scan this phone'),
                    icon: Icons.search_rounded,
                    // ─── THE SERVICE, NOT A FOREGROUND RUN ────────────────
                    //
                    // ScanController.run awaits a single call, so leaving the
                    // app mid scan would abandon it with nothing to come back
                    // to. The background scan has a foreground service holding
                    // it up and a state that can be asked for on resume, which
                    // is the whole reason both exist.
                    onPressed: () async {
                      await ref
                          .read(recoveryBridgeProvider)
                          .startBackgroundScan();
                      ref.invalidate(backgroundScanProvider);
                    },
                  )
                else
                  GButton(
                    label: context.s('Review and restore'),
                    onPressed: summary == null || summary.totalItems == 0
                        ? null
                        : () => Navigator.of(context).push(
                            CategoryPage.route(title: context.s('Everything')),
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// What the walk is doing, in words.
  ///
  /// The place being searched rather than a percentage. A percentage of a scan
  /// tells somebody nothing they can act on, and naming the source is what
  /// makes a minute of waiting feel like work rather than a spinner.
  String _progressLine(BackgroundScanState scan) {
    final String where = _sourceName(scan.sourceId);
    if (scan.total <= 0) return 'found so far\n$where';
    return 'found so far\n$where  ${GFormat.count(scan.scanned)} '
        'of ${GFormat.count(scan.total)}';
  }

  /// Source ids are ours; these are the words for them.
  ///
  /// An unknown id falls through to a neutral phrase rather than printing
  /// media_trash at somebody, because a new source added natively should read
  /// oddly rather than read like a leak.
  static String _sourceName(String? sourceId) {
    switch (sourceId) {
      case 'media_trash':
        return 'Trash folders';
      case 'app_trash':
        return 'App leftovers';
      case 'thumbnails':
        return 'Thumbnail cache';
      default:
        return 'Looking';
    }
  }

  String _subtitle(
    RecoverySummary? summary, {
    required bool blind,
    required bool scanned,
  }) {
    if (summary == null) return 'Checking your device';

    // Looked, and was not allowed to see. Not an answer at all.
    if (blind) {
      return 'Not checked yet.\nFile access is off.';
    }

    if (summary.totalItems == 0) {
      // Looked at the trash and found nothing, but the deeper places have not
      // been walked. True, incomplete, and it says which.
      if (!scanned) {
        return 'Nothing in the trash.\nA full scan looks further.';
      }
      // Looked everywhere it can and found nothing. Not a failure and not an
      // empty state to apologise for: on a tidy phone this is the correct,
      // good answer.
      return 'Nothing waiting.\nYour trash is clear.';
    }
    final String size = GFormat.bytes(summary.totalBytes);
    if (summary.expiringSoonItems > 0) {
      return '$size\n${summary.expiringSoonItems} expire within 48 hours';
    }
    // Two lines on purpose. One long line wraps unpredictably next to the art
    // and the break lands mid phrase.
    return '$size\nup to 30 days to act';
  }
}
