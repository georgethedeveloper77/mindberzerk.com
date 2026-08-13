import 'package:flutter/material.dart';

import '../../../app/theme/category_colors.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/format.dart';
import '../model/storage_view.dart';
import '../../../core/i18n/g_strings.dart';

/// The disk, as one bar and a legend.
///
/// The bar is the honest part and it is worth knowing what it will look like on
/// a real phone: on a 256 GB Samsung with 84 GB of apps, Apps takes a third of
/// the bar and every media category is a sliver. That is correct, and it is also
/// why the reclaim cards underneath do the actual work. A breakdown tells a
/// person where their space went; it does not tell them what to do.
///
/// Segments below one percent still draw, at one percent. A category that is
/// genuinely tiny should read as tiny, but a zero width segment reads as a bug
/// and loses the legend colour it is meant to key.
class StorageLedger extends StatelessWidget {
  const StorageLedger({required this.breakdown, this.onOpen, super.key});

  final StorageBreakdown breakdown;
  final void Function(StorageBucket)? onOpen;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final int total = breakdown.totalBytes;
    if (total <= 0) return const SizedBox.shrink();

    final List<StorageBucket> buckets = <StorageBucket>[
      ...breakdown.buckets,
      if (breakdown.unaccountedBytes > 0)
        StorageBucket(
          id: 'unaccounted',
          // Named for what it IS, not for the fact that we cannot list it.
          // App code and private app data are the whole of this gap on every
          // phone, and calling it "Other" the way the OS does is how a person
          // ends up staring at sixteen gigabytes with no explanation.
          label: context.s('Apps and system'),
          bytes: breakdown.unaccountedBytes,
          drillable: false,
        ),
    ];

    // The largest bucket with somewhere to go. Apps and system, and the
    // unaccounted gap, are measurable and not removable, so they set no scale.
    final int actionablePeak = buckets
        .where((StorageBucket bucket) => bucket.drillable)
        .fold<int>(
          0,
          (int most, StorageBucket b) => b.bytes > most ? b.bytes : most,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // NO HEADLINE AND NO BAR HERE ANY MORE.
        //
        // The storage page draws both above this card now, so keeping them
        // meant the same total, the same free figure and the same segmented bar
        // appeared twice on one screen, a few hundred pixels apart.
        //
        // This widget is the legend and nothing else.
        for (int i = 0; i < buckets.length; i++)
          _LegendRow(
            bucket: buckets[i],
            tint: categoryTint(t, buckets[i].id),
            // Scaled against the largest bucket a person can ACT on, and apps
            // and system are excluded from that scale entirely.
            //
            // On a real phone apps are 103 GB against 474 MB of images, so
            // measuring against them makes every row that matters a hairline and
            // turns the column into one full bar and five empty ones. The gap is
            // still shown as a number and a segment in the bar above; what it
            // does not get is a say in the scale of the comparison underneath.
            share: actionablePeak == 0 || !buckets[i].drillable
                ? 0
                : buckets[i].bytes / actionablePeak,
            delay: Duration(milliseconds: 55 * i),
            last: i == buckets.length - 1,
            onTap: buckets[i].drillable && onOpen != null
                ? () => onOpen!(buckets[i])
                : null,
          ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.bucket,
    required this.tint,
    required this.share,
    required this.delay,
    required this.last,
    this.onTap,
  });

  final StorageBucket bucket;
  final Color tint;
  final double share;

  /// Staggered down the column, so the rows arrive in order rather than as one
  /// block. Forty milliseconds apart: enough to read as a sequence, not enough
  /// to make anyone wait.
  final Duration delay;

  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: GSpace.sm + 2),
          decoration: BoxDecoration(
            border: last ? null : Border(bottom: BorderSide(color: t.line)),
          ),
          child: Row(
            // Top aligned now that the body is a label above a bar. Centring
            // would float the dot and the size against the middle of a two line
            // block and leave neither lined up with the word it belongs to.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tint,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: GSpace.md - 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      bucket.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GType.body.copyWith(color: t.text),
                    ),
                    // No bar at all where there is nothing to compare. Apps and
                    // system is the biggest number on the screen and the one
                    // thing on it nobody can act on; drawing it a bar invites a
                    // tap that leads nowhere.
                    if (share > 0) ...<Widget>[
                      const SizedBox(height: GSpace.sm - 2),
                      ClipRRect(
                        borderRadius: GRadius.all(4),
                        child: SizedBox(
                          // Eight, not three. At three it was a hairline under a
                          // label and read as an underline rather than as a
                          // measurement.
                          height: 8,
                          child: Stack(
                            children: <Widget>[
                              Positioned.fill(
                                child: ColoredBox(color: t.panelAlt),
                              ),
                              // Positioned.fill AND heightFactor, and both are
                              // load bearing.
                              //
                              // A Stack gives a non positioned child LOOSE
                              // constraints, and DecoratedBox has no size of its
                              // own, so without these the coloured fill was laid
                              // out at zero height and only the grey track ever
                              // appeared. The bars were not the wrong colour;
                              // they were not being drawn at all.
                              Positioned.fill(
                                child: _Grow(
                                  delay: delay,
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: share.clamp(0.03, 1),
                                    heightFactor: 1,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        // Each row its own colour, and a
                                        // gradient across it so a long bar is
                                        // not a flat slab.
                                        gradient: LinearGradient(
                                          colors: <Color>[
                                            tint,
                                            tint.withValues(alpha: 0.55),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  GFormat.bytes(bucket.bytes),
                  style: GType.monoSmall.copyWith(color: t.muted),
                ),
              ),
              // No chevron where there is nothing to open. A disclosure arrow
              // that leads to an empty page is a worse answer than none.
              if (onTap != null) ...<Widget>[
                const SizedBox(width: GSpace.sm - 2),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: t.dim,
                  ),
                ),
              ] else
                const SizedBox(width: GSpace.lg - 2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grows its child from nothing to full width, once.
///
/// A clip rather than a size animation, so the thing inside is laid out at its
/// final width from the first frame and simply becomes visible left to right.
/// Animating the width instead would reflow every segment on every frame and
/// make the legend text jump.
class _Grow extends StatelessWidget {
  const _Grow({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    // Reduce motion gets the finished state. The bar carries information, so it
    // must never be the animation that decides whether it is readable.
    if (MediaQuery.disableAnimationsOf(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Interval(
        (delay.inMilliseconds / 1300).clamp(0.0, 0.85),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (BuildContext context, double value, Widget? built) => ClipRect(
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0001, 1),
          child: built,
        ),
      ),
      child: child,
    );
  }
}
