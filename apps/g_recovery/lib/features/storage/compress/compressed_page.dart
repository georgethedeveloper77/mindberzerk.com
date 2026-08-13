import '../../../app/theme/tokens.dart';
import '../../../bridge/compress_api.g.dart';
import '../../../bridge/compress_bridge.dart';
import '../../../core/format.dart';
import '../../../ui/g_card.dart';
import '../../../ui/g_detail_page.dart';
import '../../../ui/g_enter.dart';
import '../../../ui/g_stat.dart';
import '../state/storage_files.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// WHAT HAS ALREADY BEEN MADE SMALLER.
///
/// ─── A RECORD, NOT A FOLDER ──────────────────────────────────────────────────
///
/// Nothing here moved. Every file is still where it was, in the gallery, next
/// to everything else, findable by every other app on the phone. Sweeping
/// people's photographs into an app directory is what cleaner apps do and it is
/// how photographs get lost.
///
/// ─── ITS REAL JOB IS THE THIRTY DAYS ─────────────────────────────────────────
///
/// A run ends in a message that disappears. This is where someone checks a week
/// later that their pictures still look right, and it is the only place that
/// tells them how long they have left to pull an original back out of the
/// trash. That window is the whole reason the screen is worth building: after
/// it closes, a bad result is permanent.
class CompressedPage extends ConsumerWidget {
  const CompressedPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const CompressedPage(),
  );

  /// Android keeps a trashed item for thirty days. Not configurable, not
  /// reported anywhere, and the same on every device this app runs on.
  static const int _trashDays = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final List<CompressedEntry> entries =
        ref.watch(compressHistoryProvider).value ?? const <CompressedEntry>[];

    final int freed = entries.fold<int>(
      0,
      (int sum, CompressedEntry e) => sum + (e.originalBytes - e.newBytes),
    );

    return GDetailSliverPage(
      hue: t.photo,
      icon: Icons.compress_rounded,
      title: 'Compressed files',
      subtitle: entries.isEmpty
          ? null
          : '${GFormat.count(entries.length)} files  ·  '
                '${GFormat.bytes(freed)} freed',
      slivers: <Widget>[
        if (entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(GSpace.xl),
                child: Text(
                  'Nothing yet. Anything you compress is listed here with '
                  'what it was before, so you can check it later.',
                  textAlign: TextAlign.center,
                  style: GType.bodySmall.copyWith(color: t.muted),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((
                BuildContext context,
                int index,
              ) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: GSpace.md),
                        child: GCard(
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: GStat(
                                  label: 'freed in total',
                                  value: GFormat.bytes(freed),
                                ),
                              ),
                              Expanded(
                                child: GStat(
                                  label: 'files',
                                  value: GFormat.count(entries.length),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final CompressedEntry entry = entries[index - 1];
                    return GEnter(
                      index: index,
                      child: _Entry(entry: entry, trashDays: _trashDays),
                    );
              }, childCount: entries.length + 1),
            ),
          ),
      ],
    );
  }
}

class _Entry extends ConsumerWidget {
  const _Entry({required this.entry, required this.trashDays});

  final CompressedEntry entry;
  final int trashDays;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;

    final Uint8List? bytes = ref
        .watch(
          storageThumbProvider(
            ThumbRequest(fileId: entry.fileId, kind: 'image', maxPixels: 256),
          ),
        )
        .value;

    // Days remaining on the original, not the date it was compressed.
    //
    // The date is trivia; the window is the only actionable fact on the row,
    // because it is how long a result that turned out badly can still be undone.
    final DateTime gone = DateTime.fromMillisecondsSinceEpoch(
      entry.whenMillis,
    ).add(Duration(days: trashDays));
    final int left = gone.difference(DateTime.now()).inDays;
    final bool recoverable = left > 0;

    final int saved = entry.originalBytes - entry.newBytes;

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.sm),
      child: GCard(
        padding: const EdgeInsets.all(GSpace.sm + 2),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: GRadius.all(GRadius.tile),
              child: SizedBox(
                width: 46,
                height: 46,
                child: bytes == null
                    ? ColoredBox(
                        color: t.panelAlt,
                        child: Center(
                          child: Icon(
                            Icons.photo_outlined,
                            size: 17,
                            color: t.dim,
                          ),
                        ),
                      )
                    : Image.memory(bytes, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: GSpace.md - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GType.bodySmall.copyWith(color: t.text),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    // Before, after, and how. Lossless and quality 85 are
                    // different promises, and a week later nobody remembers
                    // which a given file got.
                    '${GFormat.bytes(entry.originalBytes)} to '
                    '${GFormat.bytes(entry.newBytes)}  ·  '
                    '${entry.lossless ? 'lossless' : 'quality ${entry.quality}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GType.monoSmall.copyWith(color: t.dim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: GSpace.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '-${GFormat.bytes(saved)}',
                  style: GType.monoSmall.copyWith(
                    color: t.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  recoverable ? '$left DAYS' : 'GONE',
                  style: GType.badge.copyWith(
                    color: recoverable ? t.dim : t.dim.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
