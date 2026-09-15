import 'package:flutter/material.dart';

import 'chrome_theme.dart';

/// Loading indicators in the distro accent. Circular for spot loads, linear for
/// pack downloads.
///
/// Named constructors instead of a bool flag so call sites read as
/// `ThemedProgress.circular()` rather than `ThemedProgress(linear: false)`.
///
/// ─── THE LINEAR ARM IS NOT A LinearProgressIndicator ────────────────────────
///
/// It was, in two places: here, unused, and inlined again inside `_ThemeCard`
/// with a different track colour. Material's widget was dropped rather than
/// wrapped for two reasons.
///
/// Its indeterminate animation is a two-segment scale-and-translate that every
/// Android app ships, which reads as a system control sitting on top of the
/// distro's artwork rather than as part of this store. And its minimum height
/// is hardcoded past what this needs.
///
/// ─── THE BAR WEARS THE PACK'S COLOUR, NOT THE CHROME'S ──────────────────────
///
/// [accent] is the distro's own published `previewAccent`, straight off the
/// signed index, which is the same value the miniature above the bar already
/// tints its icon tiles with. So a Plasma download fills in Breeze blue over a
/// Breeze preview, rather than in the house orange every card would otherwise
/// share.
///
/// Null falls back to the chrome accent, which is what packs published before
/// `previewAccent` existed have. Deliberately no luminance correction: an
/// accent too dark to read here would already be invisible as an icon tile in
/// the picture directly above it, and a colour this layer invents would be
/// wrong in a way that looks deliberate.
class ThemedProgress extends StatelessWidget {
  const ThemedProgress.circular(
      {super.key, this.size = 24, this.strokeWidth = 2.5})
      : _linear = false,
        value = null,
        accent = null;

  /// [value] null = indeterminate; 0..1 = determinate (download progress).
  const ThemedProgress.linear({super.key, this.value, this.accent})
      : _linear = true,
        size = 0,
        strokeWidth = 0;

  final bool _linear;
  final double size;
  final double strokeWidth;
  final double? value;

  /// The pack's own accent, or null for the chrome's.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    if (_linear) {
      return _LinearBar(
        value: value,
        accent: accent ?? c.accent,
        // `lineStrong`, not `line`. The bar sits on the preview artwork rather
        // than on a chrome surface, so its track is the only thing guaranteeing
        // the fill reads against whatever that distro's wallpaper happens to
        // be. A chrome token that varies per theme cannot make that promise.
        track: c.lineStrong,
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: c.accent,
        // A faint track ring so the spinner reads on any surface.
        backgroundColor: c.line,
      ),
    );
  }
}

/// Flush to the edge it is pinned to, so no radius and no margin.
const double _barHeight = 3;

/// One pass of the indeterminate block, left edge to right edge.
const Duration _sweepPeriod = Duration(milliseconds: 1150);

/// How long a determinate bar takes to catch up to a new byte count.
///
/// Real chunk arrivals are lumpy, so a bar bound straight to them steps rather
/// than moves. This is short enough to stay honest about where the download is
/// and long enough to absorb the gaps between chunks.
const Duration _settleDuration = Duration(milliseconds: 240);

class _LinearBar extends StatefulWidget {
  const _LinearBar({
    required this.value,
    required this.accent,
    required this.track,
  });

  final double? value;
  final Color accent;
  final Color track;

  @override
  State<_LinearBar> createState() => _LinearBarState();
}

class _LinearBarState extends State<_LinearBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep =
      AnimationController(vsync: this, duration: _sweepPeriod);

  @override
  void initState() {
    super.initState();
    _syncSweep();
  }

  @override
  void didUpdateWidget(_LinearBar old) {
    super.didUpdateWidget(old);
    // The first real chunk turns an indeterminate bar determinate, which is the
    // ordinary transition here rather than an edge case: the caller passes null
    // until bytes arrive so a DNS lookup does not render as a stalled 0%.
    _syncSweep();
  }

  /// The controller runs only while there is nothing to measure.
  ///
  /// Guarded on `isAnimating` rather than restarted unconditionally, because
  /// this runs on every rebuild and a `repeat()` per frame would reset the
  /// block to the left edge every frame, which is a bar that never moves.
  void _syncSweep() {
    if (widget.value == null) {
      if (!_sweep.isAnimating) _sweep.repeat();
    } else if (_sweep.isAnimating) {
      _sweep.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;

    // ─── A BOUNDARY, BECAUSE THE SIBLING IS EXPENSIVE ──────────────────────
    //
    // This bar is a Stack child over `StorePreview`, which renders a device
    // frame, a wallpaper and an icon strip. Stack children share a layer, so
    // without this every sweep frame would repaint that preview too.
    return RepaintBoundary(
      child: SizedBox(
        height: _barHeight,
        child: value == null
            ? AnimatedBuilder(
                animation: _sweep,
                builder: (context, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _SweepPainter(
                    t: _sweep.value,
                    accent: widget.accent,
                    track: widget.track,
                  ),
                ),
              )
            : TweenAnimationBuilder<double>(
                // `begin` only applies on the first build; every later value
                // animates from wherever the bar currently is.
                tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
                duration: _settleDuration,
                // easeOut, so the bar leads the byte count early and settles
                // late. The alternative reads as a stall at the exact moment
                // the signature check runs.
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _FillPainter(
                    value: v,
                    accent: widget.accent,
                    track: widget.track,
                  ),
                ),
              ),
      ),
    );
  }
}

/// One block crossing the track, with two dimmer copies lagging behind it.
///
/// Three solid rectangles rather than a shader gradient: the tail is the only
/// thing that says which way the block is travelling, and at 3dp tall a
/// gradient would band on the mid-range panels this ships to.
class _SweepPainter extends CustomPainter {
  const _SweepPainter({
    required this.t,
    required this.accent,
    required this.track,
  });

  /// 0..1 through one period.
  final double t;
  final Color accent;
  final Color track;

  /// Head first, then the two shadows. Fractions of the track width.
  static const _widths = <double>[0.38, 0.22, 0.12];

  /// Phase offsets, as fractions of one period: 70ms and 130ms behind the head.
  static const _lags = <double>[0, 0.061, 0.113];

  static const _alphas = <double>[1, 0.45, 0.20];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = track);

    // Dimmest first. The three overlap, and the head has to sit on top of its
    // own tail rather than under it.
    for (var i = _widths.length - 1; i >= 0; i--) {
      // Dart's `%` is non-negative for a positive divisor, so a lag that pushes
      // the phase below zero wraps into the end of the previous pass.
      final phase = (t - _lags[i]) % 1.0;
      final w = size.width * _widths[i];
      // -w to size.width: the block is fully off the track at both ends of the
      // period, so the wrap from one pass to the next is never visible.
      final left = -w + (size.width + w) * Curves.easeInOut.transform(phase);
      canvas.drawRect(
        Rect.fromLTWH(left, 0, w, size.height),
        Paint()..color = accent.withValues(alpha: _alphas[i]),
      );
    }
  }

  @override
  bool shouldRepaint(_SweepPainter old) =>
      old.t != t || old.accent != accent || old.track != track;
}

/// A left-anchored fill, for a download whose total is known.
class _FillPainter extends CustomPainter {
  const _FillPainter({
    required this.value,
    required this.accent,
    required this.track,
  });

  final double value;
  final Color accent;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = track);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * value, size.height),
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(_FillPainter old) =>
      old.value != value || old.accent != accent || old.track != track;
}
