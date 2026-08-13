import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/compress_api.g.dart';
import '../../../bridge/compress_bridge.dart';
import '../../../bridge/server_api.g.dart';
import '../../../bridge/server_bridge.dart';
import '../../../bridge/storage_api.g.dart';
import '../../../core/format.dart';
import '../../../ui/g_stat.dart';
import '../../storage/compress/compress_page.dart';
import '../../storage/state/storage_providers.dart';
import '../../../core/i18n/g_strings.dart';

/// MAKING ROOM, WHICH IS NOT THE SAME QUESTION AS GETTING FILES BACK.
///
/// ─── BELOW THE MOSAIC AND OUTSIDE IT ─────────────────────────────────────────
///
/// The grid answers one thing: what has been deleted and can come back. This
/// answers another: what is still here and could take less room. A seventh tile
/// would make the grid mean two things, and it would be the only tile whose tap
/// does not open a list of deleted files.
///
/// With a heading between them it reads as the second offer rather than as an
/// exception to the first.
///
/// ─── IT NEVER SCANS, AND STILL CARRIES A REAL FIGURE ─────────────────────────
///
/// Counting screenshots and adding up their bytes is one MediaStore query.
/// Measuring what would come back means re-encoding, which is work, and work is
/// not something a launch screen may start. So before a scan this says what
/// those files WEIGH, and only afterwards what they would SAVE.
///
/// ─── AND IT LEAVES WHEN THERE IS NOTHING TO SHRINK ───────────────────────────
///
/// A category tile at zero still says something: this app covers that kind of
/// file. A compress row at zero says nothing at all.
class CompressRow extends ConsumerWidget {
  const CompressRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final CompressSummary? summary = ref.watch(compressSummaryProvider).value;
    if (summary == null) return const SizedBox.shrink();

    final int shots = summary.screenshotCount;
    final int photos = summary.photoCount;
    final int clips = summary.videoCount ?? 0;
    if (shots == 0 && photos == 0 && clips == 0) {
      return const SizedBox.shrink();
    }

    final int held =
        summary.screenshotBytes +
        summary.photoBytes +
        (summary.videoBytes ?? 0);

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.md - 1),
      child: Material(
        color: const Color(0x00000000),
        child: InkWell(
          borderRadius: GRadius.all(GRadius.card),
          onTap: () => Navigator.of(context).push(CompressPage.route()),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: GRadius.all(GRadius.card),
              border: Border.all(color: t.warning.withValues(alpha: 0.30)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  t.warning.withValues(alpha: 0.11),
                  t.warning.withValues(alpha: 0.01),
                ],
              ),
            ),
            child: ClipRRect(
              borderRadius: GRadius.all(GRadius.card),
              child: Stack(
                children: <Widget>[
                  // Bars settling, held still. The same idea as the encoding
                  // animation, drawn the same way in a third place. Not a
                  // thumbnail: a photograph here would suggest these files are
                  // deleted, which is the confusion the section break exists to
                  // prevent.
                  // ─── BEHIND THE ICON, NOT BEHIND THE NUMBER ─────────────
                  //
                  // At 46 percent they ran straight under the byte figure and
                  // read as scratches through it. A backdrop that damages the
                  // one number on the row is worse than no backdrop.
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FractionallySizedBox(
                        widthFactor: 0.30,
                        child: Padding(
                          padding: const EdgeInsets.only(right: GSpace.md),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              for (final double w in const <double>[
                                0.82,
                                0.62,
                                0.74,
                                0.48,
                                0.66,
                              ])
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2.5,
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerRight,
                                    widthFactor: w,
                                    child: Container(
                                      height: w > 0.7 ? 7 : 5,
                                      decoration: BoxDecoration(
                                        color: t.warning.withValues(
                                          alpha: 0.10,
                                        ),
                                        borderRadius: GRadius.all(4),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(GSpace.md),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.warning.withValues(alpha: 0.18),
                            borderRadius: GRadius.all(11),
                          ),
                          child: Icon(
                            Icons.compress_rounded,
                            size: 17,
                            color: t.warning,
                          ),
                        ),
                        const SizedBox(width: GSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                context.s('Make files smaller'),
                                style: GType.heading.copyWith(color: t.text),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_parts(shots, photos, clips)}, same pixels',
                                maxLines: 2,
                                style: GType.micro.copyWith(color: t.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: GSpace.sm),
                        GStat(
                          label: 'now',
                          value: GFormat.bytes(held),
                          tone: t.warning,
                          align: CrossAxisAlignment.end,
                        ),
                        const SizedBox(width: GSpace.sm),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 19,
                          color: t.dim,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Only the categories that exist, named in plain words.
  ///
  /// A phone with no screenshots should never read "0 screenshots and 33
  /// photos", which is the same rule nullable stats follow everywhere else.
  static String _parts(int shots, int photos, int clips) {
    final List<String> parts = <String>[
      if (shots > 0)
        '${GFormat.count(shots)} ${shots == 1 ? 'screenshot' : 'screenshots'}',
      if (photos > 0)
        '${GFormat.count(photos)} ${photos == 1 ? 'photo' : 'photos'}',
      if (clips > 0) '${GFormat.count(clips)} ${clips == 1 ? 'clip' : 'clips'}',
    ];
    if (parts.length <= 1) return parts.join();
    return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  }
}

/// THREE NUMBERS, DELIBERATELY NOT THREE CARDS.
///
/// ─── SIGNPOSTS, NOT SUMMARIES ────────────────────────────────────────────────
///
/// Storage, device and server each have a tab that explains them properly. Cards
/// here would make Home compete with the thing it is pointing at, and the reader
/// would end up with two half explanations instead of one good one.
///
/// ─── THIS REPLACES THE DEVICE CARD ───────────────────────────────────────────
///
/// Battery, free memory, temperature and swap sat at the bottom of a screen
/// about deleted files. Four numbers nobody came for, on a sampler that is
/// paused unless the Device tab is showing, so they were usually stale as well.
/// One of them survives here.
class PillarStats extends ConsumerWidget {
  const PillarStats({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;

    final StorageOverview? storage = ref.watch(storageOverviewProvider).value;
    final ServerConfig? server = ref.watch(serverConfigProvider).value;
    final TransferState? transfer = ref.watch(transferProvider).value;

    return Container(
      decoration: BoxDecoration(
        color: t.panel,
        border: Border.all(color: t.line),
        borderRadius: GRadius.all(GRadius.card),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: GSpace.md,
        horizontal: GSpace.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _Pillar(
              value: GFormat.bytesOrNull(storage?.volume.usedBytes),
              label: 'USED',
            ),
          ),
          _Rule(t: t),
          Expanded(
            child: _Pillar(
              value: GFormat.bytesOrNull(storage?.volume.freeBytes),
              label: 'FREE',
            ),
          ),
          _Rule(t: t),
          Expanded(
            child: _Pillar(
              // Absent rather than invented. A phone with no server has no
              // figure here, and "0 GB" would read as a failed backup.
              value: server == null
                  ? 'Not set'
                  : transfer?.lastRunMillis == null
                  ? 'Never'
                  : GFormat.relativeDay(
                      DateTime.fromMillisecondsSinceEpoch(
                        transfer!.lastRunMillis!,
                      ),
                      DateTime.now(),
                    ),
              label: context.s('BACKUP'),
              muted: server == null,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── NOT TAPPABLE, AND THAT IS THE POINT ────────────────────────────────────
///
/// They are signposts to three tabs that are already one thumb away at the
/// bottom of the screen. Making them navigate would add a second, less
/// discoverable route to the same place and turn a row of facts into a row of
/// buttons, which is exactly the weight this row exists to avoid carrying.
class _Pillar extends StatelessWidget {
  const _Pillar({required this.value, required this.label, this.muted = false});

  final String? value;
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GType.monoSmall.copyWith(
            color: muted ? t.dim : t.text,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: GType.badge.copyWith(color: t.dim)),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.t});

  final GTokens t;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 26, color: t.line);
}
