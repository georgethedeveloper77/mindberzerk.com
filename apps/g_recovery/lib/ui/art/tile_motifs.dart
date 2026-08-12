import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The thing behind the number, drawn per category.
///
/// In ui/art rather than inside home, because the storage reclaim cards use the
/// same set. Two features drawing the same shapes from two files is how they
/// drift apart.
///
/// It was an oversized copy of the tile's own glyph at seven percent, which is a
/// watermark: correct, cheap, and identical on all six tiles once you squint.
/// Six cards that differ only in hue read as one card recoloured, and that is
/// the whole complaint.
///
/// These are drawn instead. A waveform behind Audio, stacked sheets behind Docs,
/// overlapping frames behind Photos. Same job as the ghost, but each category
/// now looks like the thing it holds rather than like its own icon enlarged.
///
/// ─── ALL DETERMINISTIC ───────────────────────────────────────────────────────
///
/// Every painter seeds from a fixed number, never from the clock or from
/// Random(). A motif that reshuffled on rebuild would flicker on every scan,
/// every theme toggle and every count change, and a background that moves when
/// nothing happened is worse than no background.
///
/// ─── ALL CHEAP ───────────────────────────────────────────────────────────────
///
/// No shaders, no paths beyond a few dozen segments, no image decodes. Six of
/// these paint on the home screen of an app whose cold start has never been
/// measured, so each one has to cost about what an Icon cost.
abstract class TileMotif extends CustomPainter {
  const TileMotif(this.colour);

  final Color colour;

  Paint get fill => Paint()
    ..color = colour
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  Paint stroke(double width) => Paint()
    ..color = colour
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  @override
  bool shouldRepaint(TileMotif old) => old.colour != colour;

  /// A stable pseudo random sequence. Not Random(seed), because the algorithm
  /// behind that is not guaranteed stable across Dart versions and this needs to
  /// look the same next year as it does today.
  static double noise(int index, int seed) {
    final double value =
        math.sin((index + 1) * 12.9898 + seed * 78.233) * 43758.5453;
    return value - value.floorToDouble();
  }
}

/// Audio. A waveform, bars from the baseline, taller toward the middle.
class WaveformMotif extends TileMotif {
  const WaveformMotif(super.colour);

  @override
  void paint(Canvas canvas, Size size) {
    const int bars = 13;
    final double gap = size.width / bars;
    final double barWidth = gap * 0.42;
    final Paint paint = fill;

    for (int i = 0; i < bars; i++) {
      // Weighted toward the centre so it reads as a clip with a loud middle
      // rather than as a bar chart, which is a different thing entirely and
      // would imply data this tile does not have.
      final double centre = 1 - (i / (bars - 1) - 0.5).abs() * 2;
      final double jitter = TileMotif.noise(i, 7);
      final double height =
          size.height * (0.18 + centre * 0.62 * (0.55 + jitter * 0.45));

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            i * gap + (gap - barWidth) / 2,
            size.height - height,
            barWidth,
            height,
          ),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }
}

/// Documents. Three sheets, fanned, the front one with a folded corner.
class SheetsMotif extends TileMotif {
  const SheetsMotif(super.colour);

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width * 0.52;
    final double h = size.height * 0.72;
    final Paint line = stroke(size.width * 0.022);

    for (int i = 2; i >= 0; i--) {
      final double dx = size.width * 0.10 * i;
      final double dy = size.height * 0.07 * i;
      final Rect sheet = Rect.fromLTWH(dx, dy, w, h);
      final RRect rounded = RRect.fromRectAndRadius(
        sheet,
        Radius.circular(size.width * 0.05),
      );

      if (i == 0) {
        canvas.drawRRect(rounded, line);
        // The fold, only on the front sheet. On all three it turns into
        // hatching and stops reading as paper.
        final double fold = w * 0.28;
        canvas.drawLine(
          Offset(sheet.right - fold, sheet.top),
          Offset(sheet.right, sheet.top + fold),
          line,
        );
      } else {
        canvas.drawRRect(rounded, line);
      }
    }
  }
}

/// Photos. Overlapping frames, the fallback when a tile has no thumbnails yet.
class FramesMotif extends TileMotif {
  const FramesMotif(super.colour);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = stroke(size.width * 0.024);
    final double w = size.width * 0.56;
    final double h = size.height * 0.5;

    for (int i = 1; i >= 0; i--) {
      final Rect frame = Rect.fromLTWH(
        size.width * 0.16 * i,
        size.height * 0.2 + size.height * 0.16 * i,
        w,
        h,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(frame, Radius.circular(size.width * 0.06)),
        line,
      );
      if (i == 0) {
        // A horizon and a sun, the two marks that make a rectangle read as a
        // photograph rather than as a box.
        canvas.drawCircle(
          Offset(frame.left + w * 0.26, frame.top + h * 0.3),
          size.width * 0.05,
          line,
        );
        final Path hill = Path()
          ..moveTo(frame.left + w * 0.08, frame.bottom - h * 0.12)
          ..lineTo(frame.left + w * 0.42, frame.top + h * 0.45)
          ..lineTo(frame.left + w * 0.72, frame.bottom - h * 0.12);
        canvas.drawPath(hill, line);
      }
    }
  }
}

/// Video. A play mark with a scrub line under it.
class PlayMotif extends TileMotif {
  const PlayMotif(super.colour);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = stroke(size.width * 0.026);
    final Offset centre = Offset(size.width * 0.44, size.height * 0.42);
    final double r = size.width * 0.26;

    canvas.drawCircle(centre, r, line);

    final Path triangle = Path()
      ..moveTo(centre.dx - r * 0.3, centre.dy - r * 0.42)
      ..lineTo(centre.dx + r * 0.48, centre.dy)
      ..lineTo(centre.dx - r * 0.3, centre.dy + r * 0.42)
      ..close();
    canvas.drawPath(triangle, fill);

    final double y = size.height * 0.82;
    canvas.drawLine(
      Offset(size.width * 0.1, y),
      Offset(size.width * 0.9, y),
      stroke(size.width * 0.018),
    );
    canvas.drawCircle(Offset(size.width * 0.36, y), size.width * 0.045, fill);
  }
}

/// Previews. A field of dots, denser toward one corner.
class GrainMotif extends TileMotif {
  const GrainMotif(super.colour);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = fill;
    const int count = 34;

    for (int i = 0; i < count; i++) {
      final double x = TileMotif.noise(i, 3) * size.width;
      final double y = TileMotif.noise(i, 11) * size.height;
      // Radius falls off with distance from the bottom right, so the field has
      // a direction instead of being an even scatter.
      final double pull =
          1 -
          ((size.width - x) + (size.height - y)) / (size.width + size.height);
      canvas.drawCircle(
        Offset(x, y),
        size.width * (0.012 + pull * 0.03),
        paint,
      );
    }
  }
}

/// Messages. Two bubbles, one each way.
class BubblesMotif extends TileMotif {
  const BubblesMotif(super.colour);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = stroke(size.width * 0.024);

    RRect bubble(double l, double t, double w, double h) =>
        RRect.fromRectAndRadius(
          Rect.fromLTWH(l, t, w, h),
          Radius.circular(h * 0.42),
        );

    canvas.drawRRect(
      bubble(
        size.width * 0.06,
        size.height * 0.16,
        size.width * 0.56,
        size.height * 0.28,
      ),
      line,
    );
    canvas.drawRRect(
      bubble(
        size.width * 0.3,
        size.height * 0.54,
        size.width * 0.62,
        size.height * 0.28,
      ),
      line,
    );
  }
}

/// Duplicates. Two identical squares, offset.
class StackMotif extends TileMotif {
  const StackMotif(super.colour);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = stroke(size.width * 0.024);
    final double s = size.width * 0.46;
    for (int i = 1; i >= 0; i--) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * 0.14 * i,
            size.height * 0.16 + size.height * 0.14 * i,
            s,
            s,
          ),
          Radius.circular(size.width * 0.06),
        ),
        line,
      );
    }
  }
}

/// Large files. One block dwarfing three others.
class BlocksMotif extends TileMotif {
  const BlocksMotif(super.colour);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = fill;
    RRect box(double l, double t, double w, double h) =>
        RRect.fromRectAndRadius(
          Rect.fromLTWH(l, t, w, h),
          Radius.circular(size.width * 0.04),
        );

    canvas.drawRRect(
      box(
        size.width * 0.08,
        size.height * 0.2,
        size.width * 0.44,
        size.height * 0.62,
      ),
      paint,
    );
    for (int i = 0; i < 3; i++) {
      canvas.drawRRect(
        box(
          size.width * 0.6,
          size.height * (0.24 + i * 0.2),
          size.width * 0.18,
          size.height * 0.13,
        ),
        paint,
      );
    }
  }
}

/// Age. A clock face with one hand well past the hour.
class ClockMotif extends TileMotif {
  const ClockMotif(super.colour);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = stroke(size.width * 0.026);
    final Offset centre = Offset(size.width * 0.44, size.height * 0.46);
    final double r = size.width * 0.3;

    canvas.drawCircle(centre, r, line);
    canvas.drawLine(centre, centre.translate(0, -r * 0.62), line);
    canvas.drawLine(centre, centre.translate(r * 0.44, r * 0.2), line);
  }
}

/// The motif for a category, or null where there is nothing worth drawing.
TileMotif? motifFor(String key, Color colour) {
  switch (key) {
    case 'image':
      return FramesMotif(colour);
    case 'video':
      return PlayMotif(colour);
    case 'audio':
      return WaveformMotif(colour);
    case 'document':
      return SheetsMotif(colour);
    case 'thumbnails':
      return GrainMotif(colour);
    case 'messages':
      return BubblesMotif(colour);
    case 'duplicates':
      return StackMotif(colour);
    case 'similar':
      return FramesMotif(colour);
    case 'large':
      return BlocksMotif(colour);
    case 'stale':
      return ClockMotif(colour);
    // Overlapping frames, softened by being drawn twice at a slight offset.
    // The nearest thing in the set to "out of focus" without a blur filter,
    // which a CustomPainter cannot do cheaply.
    case 'blurred':
      return FramesMotif(colour);
    default:
      return null;
  }
}
