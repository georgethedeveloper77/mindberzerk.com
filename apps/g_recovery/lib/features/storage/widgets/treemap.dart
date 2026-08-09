import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/storage_api.g.dart';
import '../../../core/format.dart';

/// Folder sizes as proportional rectangles.
///
/// A squarified treemap, not a pie: a pie with twelve slices is unreadable and
/// cannot carry labels, while a treemap gives the largest folders enough area
/// to name themselves. The layout walks a row at a time and switches direction
/// whenever the remaining space is taller than it is wide, which keeps the
/// rectangles closer to square than a naive slice-and-dice and therefore
/// readable.
class FolderTreemap extends StatelessWidget {
  const FolderTreemap({
    required this.folders,
    super.key,
    this.height = 190,
    this.onTap,
  });

  final List<FolderUsage> folders;
  final double height;
  final void Function(FolderUsage folder)? onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    if (folders.isEmpty) return const SizedBox.shrink();

    final List<Color> palette = <Color>[
      t.video,
      t.photo,
      t.audio,
      t.docs,
      t.chat,
      t.apps,
    ];

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final List<_Cell> cells = _layout(
            folders,
            Rect.fromLTWH(0, 0, constraints.maxWidth, height),
          );
          return Stack(
            children: <Widget>[
              for (int i = 0; i < cells.length; i++)
                Positioned.fromRect(
                  rect: cells[i].rect.deflate(2),
                  child: _Tile(
                    folder: cells[i].folder,
                    tint: palette[i % palette.length],
                    onTap: onTap == null
                        ? null
                        : () => onTap!(cells[i].folder),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<_Cell> _layout(List<FolderUsage> input, Rect area) {
    final List<FolderUsage> sorted = List<FolderUsage>.of(input)
      ..sort((FolderUsage a, FolderUsage b) =>
          b.totalBytes.compareTo(a.totalBytes));
    final int total =
        sorted.fold(0, (int sum, FolderUsage f) => sum + f.totalBytes);
    if (total <= 0) return const <_Cell>[];

    final List<_Cell> cells = <_Cell>[];
    Rect remaining = area;
    int left = total;

    for (int i = 0; i < sorted.length; i++) {
      final FolderUsage folder = sorted[i];
      final bool isLast = i == sorted.length - 1;
      if (isLast) {
        cells.add(_Cell(folder, remaining));
        break;
      }
      final double share = folder.totalBytes / left;
      // Split across the LONGER axis every time. Splitting always the same way
      // produces slivers by the fourth or fifth folder, and a sliver cannot
      // hold a label.
      if (remaining.width >= remaining.height) {
        final double w = remaining.width * share;
        cells.add(
          _Cell(folder, Rect.fromLTWH(remaining.left, remaining.top, w, remaining.height)),
        );
        remaining = Rect.fromLTWH(
          remaining.left + w,
          remaining.top,
          remaining.width - w,
          remaining.height,
        );
      } else {
        final double h = remaining.height * share;
        cells.add(
          _Cell(folder, Rect.fromLTWH(remaining.left, remaining.top, remaining.width, h)),
        );
        remaining = Rect.fromLTWH(
          remaining.left,
          remaining.top + h,
          remaining.width,
          remaining.height - h,
        );
      }
      left -= folder.totalBytes;
      if (remaining.width < 8 || remaining.height < 8) break;
    }
    return cells;
  }
}

class _Cell {
  const _Cell(this.folder, this.rect);

  final FolderUsage folder;
  final Rect rect;
}

class _Tile extends StatelessWidget {
  const _Tile({required this.folder, required this.tint, this.onTap});

  final FolderUsage folder;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Material(
      color: tint.withValues(alpha: 0.18),
      borderRadius: GRadius.all(GRadius.tile),
      child: InkWell(
        onTap: onTap,
        borderRadius: GRadius.all(GRadius.tile),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: GRadius.all(GRadius.tile),
            border: Border.all(color: tint.withValues(alpha: 0.34)),
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              // Labels are dropped rather than clipped when the cell is too
              // small. A half word is noise; an unlabelled block still reads
              // correctly as "something small".
              if (c.maxHeight < 30 || c.maxWidth < 54) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    folder.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GType.micro.copyWith(
                      color: t.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    GFormat.bytes(folder.totalBytes),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GType.monoSmall.copyWith(color: t.muted, fontSize: 9.5),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
