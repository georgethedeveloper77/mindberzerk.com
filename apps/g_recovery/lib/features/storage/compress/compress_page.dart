import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/compress_api.g.dart';
import '../../../bridge/compress_bridge.dart';
import '../../../core/format.dart';
import '../../../ui/g_app_bar.dart';
import '../../../ui/g_card.dart';
import '../../../ui/g_sheet.dart';
import '../../../ui/g_stat.dart';
import 'compress_list_page.dart';
import 'compressed_page.dart';
import 'video_list_page.dart';

/// CHOOSING WHAT TO LOOK AT.
///
/// ─── THIS SCREEN USED TO BE THE WHOLE FEATURE, AND THAT WAS THE PROBLEM ──────
///
/// It was one flat list of every image over a megabyte with a quality slider on
/// top, which meant screenshots and photographs were the same operation at the
/// same setting. They are not. A screenshot is re-encoded losslessly and cannot
/// come out worse; a photograph is re-encoded lossily and permanently, and the
/// two deserve different lists, different copy, and in one case a slider that
/// does not exist.
///
/// So this is now a chooser and nothing else. Every number on it is real before
/// anything is scanned, because counting files is a query and only measuring a
/// saving is work.
class CompressPage extends ConsumerWidget {
  const CompressPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const CompressPage(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final CompressSummary? summary = ref.watch(compressSummaryProvider).value;

    final int shots = summary?.screenshotCount ?? 0;
    final int photos = summary?.photoCount ?? 0;
    // Video counts toward the headline too.
    //
    // It was left out while the video card was a placeholder, which made the
    // total quietly disagree with the cards under it: three eligible clips are
    // usually larger than every photo on the phone put together, and "stored in
    // formats that take more room than they need" is more true of them than of
    // anything else here.
    final int held = (summary?.screenshotBytes ?? 0) +
        (summary?.photoBytes ?? 0) +
        (summary?.videoBytes ?? 0);

    final List<CompressedEntry> history =
        ref.watch(compressHistoryProvider).value ?? const <CompressedEntry>[];
    final int compressed = history.length;
    final int freed = history.fold<int>(
      0,
      (int sum, CompressedEntry e) => sum + (e.originalBytes - e.newBytes),
    );

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
              child: GAppBar(
                title: 'Make files smaller',
                subtitle: 'Same pixels, fewer bytes',
                leading: GIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                actions: <Widget>[
                  GIconButton(
                    icon: Icons.info_outline_rounded,
                    onTap: () => _explain(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  GSpace.gutter,
                  0,
                  GSpace.gutter,
                  GSpace.xl,
                ),
                children: <Widget>[
                  if (summary != null && shots == 0 && photos == 0)
                    GCard(
                      child: Text(
                        'Nothing here is stored in a format that could be '
                        'made smaller.',
                        style: GType.bodySmall.copyWith(color: t.muted),
                      ),
                    )
                  else ...<Widget>[
                    // ─── WHAT IS HELD, NOT WHAT IS SAVED ─────────────────────
                    //
                    // The saving is a measurement and it does not exist until a
                    // list is opened. What these files currently weigh is a
                    // single query, so it can lead the screen honestly, and it
                    // is also the only number that makes the two cards below
                    // add up to something.
                    if (held > 0)
                      _Held(bytes: held),
                    const SizedBox(height: GSpace.lg),

                    GOverline('Choose what to look at'),
                    const SizedBox(height: GSpace.sm + 1),

                    // Screenshots first, and not alphabetically. It is the one
                    // category where nothing can be lost, which makes it the
                    // right place for someone to find out what this feature
                    // does to their phone.
                    if (shots > 0) ...<Widget>[
                      _Scope(
                        hue: t.accent,
                        icon: Icons.crop_square_rounded,
                        title: 'Screenshots',
                        // Short on purpose. The stamp underneath already says
                        // nothing is lost, so the sentence does not have to.
                        detail: '${GFormat.count(shots)} PNG files',
                        stamp: 'Nothing lost',
                        stampTone: t.accent,
                        holds: summary?.screenshotBytes,
                        onTap: () => Navigator.of(context).push(
                          CompressListPage.route('screenshot'),
                        ),
                      ),
                      const SizedBox(height: GSpace.sm + 1),
                    ],

                    if (photos > 0)
                      _Scope(
                        hue: t.photo,
                        icon: Icons.photo_outlined,
                        title: 'Photos',
                        detail: '${GFormat.count(photos)} worth re-saving',
                        stamp: 'Measured',
                        stampTone: t.photo,
                        holds: summary?.photoBytes,
                        onTap: () => Navigator.of(
                          context,
                        ).push(CompressListPage.route('photo')),
                      ),

                    // ─── VIDEO, NAMED AND NOT PROMISED ───────────────────────
                    //
                    // Drawn, dimmed, and it does not open. Carrying a figure
                    // would mean estimating from an encoder that has not been
                    // written, and this app has spent weeks removing numbers
                    // exactly like that from everywhere else.
                    const SizedBox(height: GSpace.sm + 1),
                    _Soon(
                      clips: summary?.videoCount ?? 0,
                      bytes: summary?.videoBytes ?? 0,
                    ),

                    if (compressed > 0) ...<Widget>[
                      const SizedBox(height: GSpace.lg),
                      GOverline('Already done'),
                      const SizedBox(height: GSpace.sm + 1),
                      _Done(
                        files: compressed,
                        freed: freed,
                        onTap: () => Navigator.of(
                          context,
                        ).push(CompressedPage.route()),
                      ),
                    ],

                    // ─── NO "NOT OFFERED" SECTION ────────────────────────────
                    //
                    // There was a card here explaining that documents, PDFs and
                    // music are already compressed. It was five lines of prose
                    // answering a question nobody had asked yet, on a screen
                    // whose whole job is to route someone into a list.
                    //
                    // A category that is not offered does not need a headstone.
                    // If somebody wonders where their PDFs are, the info sheet
                    // in the app bar says so in one line, which is the right
                    // place for an answer to a question that has actually
                    // occurred to them.
                    //
                    // Video is absent for the different reason that it does not
                    // work yet, and a card offering twenty one gigabytes that
                    // opens nothing is the promise this app spent weeks
                    // removing everywhere else.
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _explain(BuildContext context) {
    final GTokens t = context.g;
    showGSheet(
      context: context,
      title: 'What this does',
      children: <Widget>[
        GSheetPoint(
          icon: Icons.straighten_rounded,
          tone: t.docs,
          text:
              'The saving shown is measured, not guessed. Each file is really '
              're-encoded before you decide.',
        ),
        GSheetPoint(
          icon: Icons.photo_size_select_actual_rounded,
          tone: t.docs,
          text:
              'Pictures keep their size in pixels. Nothing is cropped or '
              'scaled down, so they print and crop as before.',
        ),
        GSheetPoint(
          icon: Icons.event_rounded,
          tone: t.docs,
          text:
              'Date, place and camera settings are copied across, so your '
              'gallery keeps its order.',
        ),
        GSheetPoint(
          icon: Icons.picture_as_pdf_outlined,
          text:
              'Documents, PDFs and music are not listed. They are already '
              'compressed inside, so squeezing them again gains almost '
              'nothing.',
        ),
        const GSheetHeading('Screenshots are the safe ones'),
        GSheetPoint(
          icon: Icons.verified_outlined,
          tone: t.accent,
          text:
              'A screenshot becomes a WebP with identical pixels. It is '
              'smaller and there is no version of it that looks worse.',
        ),
        const GSheetHeading('Photos cannot be undone'),
        GSheetPoint(
          icon: Icons.restore_from_trash_outlined,
          text:
              'A photo is re-encoded and loses a little detail. The original '
              'goes to the trash for thirty days, and after that the smaller '
              'version is the only one left.',
        ),
      ],
    );
  }
}


/// The headline: what these files weigh now.
class _Held extends StatelessWidget {
  const _Held({required this.bytes});

  final int bytes;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.07),
        border: Border.all(color: t.accent.withValues(alpha: 0.24)),
        borderRadius: GRadius.all(GRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(GSpace.md + 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              GFormat.bytes(bytes),
              style: GType.monoDisplay.copyWith(color: t.text),
            ),
            const SizedBox(height: GSpace.xs + 1),
            Text(
              'is stored in formats that take more room than they need. How '
              'much comes back is measured when you open a list.',
              style: GType.micro.copyWith(color: t.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Video: drawn, dimmed, and it does not open.
/// VIDEO.
///
/// ─── THE PROBE THAT USED TO LIVE HERE IS GONE ────────────────────────────────
///
/// This card was briefly a one tap encoder test, because the whole video
/// pipeline had been written and never run. It did its job: it proved
/// Transformer works on this hardware, and it caught a real bug, a clip
/// forecasting three times its own size because no target bitrate was being
/// requested.
///
/// It now opens the real screen, which is what it was always standing in for.
class _Soon extends StatelessWidget {
  const _Soon({required this.clips, required this.bytes});

  /// Clips whose codec AND bitrate leave something to gain. Real, from the
  /// header test, so the card names a quantity without naming a saving: what
  /// these files weigh is known, and what they would weigh is not until the
  /// encoder has actually run on them.
  final int clips;
  final int bytes;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final bool any = clips > 0;

    return GCard(
      onTap: () => Navigator.of(context).push(VideoListPage.route()),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.video.withValues(alpha: 0.18),
              borderRadius: GRadius.all(11),
            ),
            child: Icon(Icons.play_arrow_rounded, size: 18, color: t.video),
          ),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Video', style: GType.heading.copyWith(color: t.text)),
                const SizedBox(height: 2),
                Text(
                  any
                      // Singular when there is one. A count that reads "1
                      // clips" is the sort of thing a person notices before
                      // they notice anything the app got right.
                      ? '${GFormat.count(clips)} '
                            '${clips == 1 ? "clip" : "clips"} in an older format'
                      : 'Nothing here would gain from re-encoding',
                  style: GType.micro.copyWith(color: t.muted),
                ),
                const SizedBox(height: GSpace.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: t.warning.withValues(alpha: 0.11),
                    borderRadius: GRadius.all(7),
                    border: Border.all(
                      color: t.warning.withValues(alpha: 0.34),
                    ),
                  ),
                  child: Text(
                    'ESTIMATED  ·  PRO',
                    style: GType.badge.copyWith(color: t.warning),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: GSpace.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              GStat(
                label: 'now',
                value: bytes > 0 ? GFormat.bytes(bytes) : null,
                align: CrossAxisAlignment.end,
              ),
              const SizedBox(height: GSpace.sm),
              Icon(Icons.chevron_right_rounded, size: 19, color: t.dim),
            ],
          ),
        ],
      ),
    );
  }
}

/// The ledger entry point.
class _Done extends StatelessWidget {
  const _Done({
    required this.files,
    required this.freed,
    required this.onTap,
  });

  final int files;
  final int freed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return GCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.success.withValues(alpha: 0.16),
              borderRadius: GRadius.all(11),
            ),
            child: Icon(Icons.check_rounded, size: 17, color: t.success),
          ),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Compressed files',
                  style: GType.heading.copyWith(color: t.text),
                ),
                const SizedBox(height: 2),
                Text(
                  '${GFormat.count(files)} files, originals still in the trash',
                  style: GType.micro.copyWith(color: t.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: GSpace.sm),
          GStat(
            label: 'freed',
            value: GFormat.bytes(freed),
            tone: t.success,
            align: CrossAxisAlignment.end,
          ),
          const SizedBox(width: GSpace.sm),
          Icon(Icons.chevron_right_rounded, size: 19, color: t.dim),
        ],
      ),
    );
  }
}

class _Scope extends StatelessWidget {
  const _Scope({
    required this.hue,
    required this.icon,
    required this.title,
    required this.detail,
    required this.stamp,
    required this.stampTone,
    required this.holds,
    required this.onTap,
  });

  final Color hue;
  final IconData icon;
  final String title;
  final String detail;
  final String stamp;
  final Color stampTone;

  /// Bytes the category currently occupies, NOT what it would save.
  ///
  /// The distinction is the whole reason this screen can show a number before
  /// scanning. What is on the phone is a fact; what comes back is a
  /// measurement, and it does not exist yet.
  final int? holds;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return GCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hue.withValues(alpha: 0.18),
              borderRadius: GRadius.all(11),
            ),
            child: Icon(icon, size: 17, color: hue),
          ),
          const SizedBox(width: GSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: GType.heading.copyWith(color: t.text)),
                const SizedBox(height: 2),
                Text(detail, style: GType.micro.copyWith(color: t.muted)),
                const SizedBox(height: GSpace.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: stampTone.withValues(alpha: 0.11),
                    borderRadius: GRadius.all(7),
                    border: Border.all(
                      color: stampTone.withValues(alpha: 0.34),
                    ),
                  ),
                  child: Text(
                    stamp.toUpperCase(),
                    style: GType.badge.copyWith(color: stampTone),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: GSpace.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              GStat(
                label: 'now',
                value: GFormat.bytesOrNull(holds),
                align: CrossAxisAlignment.end,
              ),
              const SizedBox(height: GSpace.sm),
              Icon(Icons.chevron_right_rounded, size: 19, color: t.dim),
            ],
          ),
        ],
      ),
    );
  }
}
