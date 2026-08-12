import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/storage_api.g.dart';
import '../../../core/format.dart';

/// Bytes by year.
///
/// The most useful single chart in a storage tool, because the answer to "what
/// can I delete" is almost always "the year you stopped looking at".
class AgeHistogram extends StatelessWidget {
  const AgeHistogram({
    required this.buckets,
    super.key,
    this.height = 56,
    this.onTap,
  });

  final List<AgeBucket> buckets;
  final double height;
  final void Function(AgeBucket bucket)? onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    if (buckets.isEmpty) return const SizedBox.shrink();

    final int peak = buckets.fold(
      0,
      (int max, AgeBucket b) => b.totalBytes > max ? b.totalBytes : max,
    );
    if (peak <= 0) return const SizedBox.shrink();

    // Only the last ten years. Older than that is usually one stray file with a
    // broken timestamp, and it flattens every real bar to nothing.
    final List<AgeBucket> shown = buckets.length > 10
        ? buckets.sublist(buckets.length - 10)
        : buckets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (final AgeBucket bucket in shown)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTap == null ? null : () => onTap!(bucket),
                      child: Tooltip(
                        message:
                            '${bucket.year}  ${GFormat.bytes(bucket.totalBytes)}',
                        child: FractionallySizedBox(
                          heightFactor: (bucket.totalBytes / peak).clamp(
                            0.03,
                            1.0,
                          ),
                          alignment: Alignment.bottomCenter,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: bucket.totalBytes == peak
                                  ? t.accent
                                  : t.accent.withValues(alpha: 0.42),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: GSpace.sm - 1),
        Row(
          children: <Widget>[
            for (final AgeBucket bucket in shown)
              Expanded(
                child: Text(
                  // Two digit years. Four digits at ten columns wide overlap on
                  // a 360 dp screen.
                  "'${bucket.year.toString().substring(2)}",
                  textAlign: TextAlign.center,
                  style: GType.monoSmall.copyWith(color: t.dim, fontSize: 9),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
