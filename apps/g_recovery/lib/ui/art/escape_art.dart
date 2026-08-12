import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Files climbing out of a bin.
///
/// Shared by the onboarding opener and the home hero, which is why it sits in
/// ui/art rather than inside either feature.
///
/// Drawn and animated in code rather than shipped as a Lottie file. The
/// dependency is the smaller reason; the real one is that a Lottie has its
/// colours baked in, and this screen sits immediately before the one where the
/// user picks an accent. Art that cannot follow that choice would be wrong for
/// five of the six accents on offer.
///
/// LOOPS, and this is the one place in the app where a loop is right. Every
/// other animation here plays once because it decorates a screen someone is
/// working on. This screen has no work on it: it is looked at for a few seconds
/// and then left, so motion is the content.
/// What comes out of the bin.
///
/// Same bin, same motion, different cargo. One widget covers every empty state
/// in the app, which is why there is no Lottie per category and no new
/// dependency: five shapes are five short paint calls.
enum EscapeShape {
  /// Rounded cards with two rules on them.
  files,

  /// Chat bubbles with a tail.
  messages,

  /// Picture frames, with a horizon and a sun.
  photos,

  /// Pages with a folded corner.
  documents,

  /// A quaver: two note heads and a beam.
  audio,
}

class EscapeArt extends StatefulWidget {
  const EscapeArt({
    super.key,
    this.height = 220,
    this.active = true,
    this.shape = EscapeShape.files,
  });

  final double height;

  /// Same bin, same motion, different cargo. The message archive is the same
  /// promise as file recovery told about a different object, and drawing it with
  /// the same hand is what makes them feel like one app.
  final EscapeShape shape;

  /// Off switch for the caller.
  ///
  /// Home lives in an IndexedStack, so the hero stays mounted for the life of
  /// the app. Without this, a ticker would keep repainting behind Storage,
  /// Device and More forever, which is exactly the battery cost a device
  /// utility has the least excuse for.
  final bool active;

  @override
  State<EscapeArt> createState() => _EscapeArtState();
}

class _EscapeArtState extends State<EscapeArt>
    with SingleTickerProviderStateMixin {
  // Constructed here, never as a late final with an initialiser. The lazy form
  // can run its initialiser from inside dispose, where createTicker reads
  // TickerMode off a deactivated element.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(EscapeArt old) {
    super.didUpdateWidget(old);
    if (widget.active == old.active) return;
    if (widget.active) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    if (!widget.active || MediaQuery.disableAnimationsOf(context)) {
      return SizedBox(
        height: widget.height,
        child: CustomPaint(
          painter: _EscapePainter(tokens: t, phase: 0.42, shape: widget.shape),
          size: Size.infinite,
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) => CustomPaint(
          painter: _EscapePainter(
            tokens: t,
            phase: _controller.value,
            shape: widget.shape,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _EscapePainter extends CustomPainter {
  const _EscapePainter({
    required this.tokens,
    required this.phase,
    required this.shape,
  });

  final GTokens tokens;
  final EscapeShape shape;

  /// 0 to 1, wrapping. Each card runs its own offset copy of this, so one loop
  /// of the controller produces a continuous stream rather than four cards
  /// leaving together and a gap behind them.
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    // Three cards in a hero slot, five on an onboarding screen. Five at 124 dp
    // is a scribble: the shapes overlap before either has been read.
    final int cards = size.width < 170 ? 3 : 5;
    final double binWidth = size.width * 0.34;
    final double binHeight = size.height * 0.36;
    final double binLeft = (size.width - binWidth) / 2;
    final double binTop = size.height - binHeight - size.height * 0.06;
    final Offset mouth = Offset(size.width / 2, binTop);

    // Cards first, so the bin overlaps the one still emerging and the rest
    // appear to come from inside rather than from behind.
    for (int i = 0; i < cards; i++) {
      final double local = (phase + i / cards) % 1;
      _card(canvas, size, mouth, local, i);
    }

    _bin(canvas, Rect.fromLTWH(binLeft, binTop, binWidth, binHeight));
  }

  void _card(Canvas canvas, Size size, Offset mouth, double local, int index) {
    // Fade in fast, hold, fade out near the top. A card that appears at full
    // opacity at the mouth looks pasted on.
    final double opacity = local < 0.12
        ? local / 0.12
        : local > 0.78
        ? (1 - local) / 0.22
        : 1;

    // Eased so cards leave briskly and drift at the top, which is how paper
    // behaves and is also where the eye has time to read the shape.
    final double rise = Curves.easeOutCubic.transform(local);
    final double drift =
        math.sin((local * 2 + index) * math.pi) * size.width * 0.16;

    final double w = size.width * 0.15;
    final double h = w * 0.78;
    final Offset centre = Offset(
      mouth.dx + drift,
      mouth.dy - rise * size.height * 0.72,
    );

    final Color colour = <Color>[
      tokens.photo,
      tokens.video,
      tokens.docs,
      tokens.audio,
      tokens.chat,
    ][index % 5];

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate((math.sin((local + index) * math.pi * 2)) * 0.42);

    // saveLayer, because photos and documents cut their detail out with
    // BlendMode.dstOut. Without a layer that punches a hole through everything
    // painted before it, including the bin, rather than through this one card.
    final bool cuts =
        shape == EscapeShape.photos || shape == EscapeShape.documents;
    if (cuts) {
      canvas.saveLayer(
        Rect.fromCenter(center: Offset.zero, width: w * 2, height: h * 2),
        Paint(),
      );
    }

    final Paint fill = Paint()
      ..color = colour.withValues(alpha: 0.9 * opacity.clamp(0, 1))
      ..isAntiAlias = true;

    final Rect body = Rect.fromCenter(
      center: Offset.zero,
      width: w,
      height: shape == EscapeShape.messages ? h * 0.86 : h,
    );

    switch (shape) {
      case EscapeShape.messages:
        canvas.drawRRect(
          RRect.fromRectAndRadius(body, Radius.circular(h * 0.4)),
          fill,
        );
        // The tail. Without it a rounded rectangle is a pill, and a pill is not
        // a message.
        canvas.drawPath(
          Path()
            ..moveTo(body.left + w * 0.16, body.bottom - 1)
            ..lineTo(body.left + w * 0.06, body.bottom + h * 0.2)
            ..lineTo(body.left + w * 0.36, body.bottom - 1)
            ..close(),
          fill,
        );

      case EscapeShape.photos:
        canvas.drawRRect(
          RRect.fromRectAndRadius(body, Radius.circular(w * 0.1)),
          fill,
        );
        // A horizon and a sun, cut out of the frame rather than drawn over it,
        // so the shape reads as a picture at 18 px.
        final Paint cut = Paint()..blendMode = BlendMode.dstOut;
        canvas.drawCircle(
          Offset(body.left + w * 0.26, body.top + h * 0.28),
          h * 0.11,
          cut,
        );
        canvas.drawPath(
          Path()
            ..moveTo(body.left, body.bottom)
            ..lineTo(body.left + w * 0.34, body.center.dy)
            ..lineTo(body.left + w * 0.58, body.bottom - h * 0.16)
            ..lineTo(body.right, body.top + h * 0.42)
            ..lineTo(body.right, body.bottom)
            ..close(),
          cut,
        );

      case EscapeShape.documents:
        // A folded corner, which is the only thing that separates a page from a
        // rectangle at this size.
        final double fold = w * 0.3;
        canvas.drawPath(
          Path()
            ..moveTo(body.left, body.top)
            ..lineTo(body.right - fold, body.top)
            ..lineTo(body.right, body.top + fold)
            ..lineTo(body.right, body.bottom)
            ..lineTo(body.left, body.bottom)
            ..close(),
          fill,
        );
        canvas.drawPath(
          Path()
            ..moveTo(body.right - fold, body.top)
            ..lineTo(body.right - fold, body.top + fold)
            ..lineTo(body.right, body.top + fold)
            ..close(),
          Paint()..blendMode = BlendMode.dstOut,
        );

      case EscapeShape.audio:
        // A quaver. Two heads and a beam, no stroke joins to go wrong when the
        // whole thing is 20 px across.
        final Paint beam = Paint()
          ..color = fill.color
          ..strokeWidth = h * 0.13
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;
        canvas.drawLine(
          Offset(body.left + w * 0.28, body.bottom - h * 0.18),
          Offset(body.right - w * 0.06, body.top + h * 0.06),
          beam,
        );
        canvas.drawCircle(
          Offset(body.left + w * 0.2, body.bottom - h * 0.14),
          h * 0.17,
          fill,
        );
        canvas.drawCircle(
          Offset(body.right - w * 0.14, body.top + h * 0.34),
          h * 0.17,
          fill,
        );

      case EscapeShape.files:
        canvas.drawRRect(
          RRect.fromRectAndRadius(body, Radius.circular(w * 0.16)),
          fill,
        );
    }

    // Two rules on the card, so it reads as a document and not as a swatch.
    // Rules only on a file card. On a note or a bubble they read as damage.
    if (shape != EscapeShape.files && shape != EscapeShape.documents) {
      if (cuts) canvas.restore();
      canvas.restore();
      return;
    }

    final Paint rule = Paint()
      ..color = tokens.ink.withValues(alpha: 0.3 * opacity.clamp(0, 1))
      ..strokeWidth = h * 0.07
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-w * 0.26, -h * 0.1),
      Offset(w * 0.26, -h * 0.1),
      rule,
    );
    canvas.drawLine(
      Offset(-w * 0.26, h * 0.1),
      Offset(w * 0.06, h * 0.1),
      rule,
    );
    if (cuts) canvas.restore();
    canvas.restore();
  }

  /// The bin is red.
  ///
  /// The one object on this screen that is not a file, and the only one whose
  /// meaning is fixed. Drawing it in the accent would make it change colour with
  /// a user preference, which is wrong for a thing everyone already recognises,
  /// and drawing it in panel grey made it disappear behind the very cards it is
  /// supposed to be losing.
  void _bin(Canvas canvas, Rect body) {
    final Paint shell = Paint()
      ..color = tokens.danger
      ..isAntiAlias = true;
    final Paint edge = Paint()
      ..color = tokens.danger
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..isAntiAlias = true;

    // Tapered, so it reads as a bin rather than a box.
    final Path shape = Path()
      ..moveTo(body.left, body.top)
      ..lineTo(body.right, body.top)
      ..lineTo(body.right - body.width * 0.1, body.bottom)
      ..lineTo(body.left + body.width * 0.1, body.bottom)
      ..close();
    canvas.drawPath(shape, shell);
    canvas.drawPath(shape, edge);

    final double lipHeight = body.height * 0.16;
    final RRect lip = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        body.left - body.width * 0.08,
        body.top - lipHeight / 2,
        body.width * 1.16,
        lipHeight,
      ),
      Radius.circular(lipHeight / 2),
    );
    // The lip a shade off the body, so the bin has a rim rather than reading as
    // one flat red shape.
    canvas.drawRRect(
      lip,
      Paint()..color = Color.lerp(tokens.danger, tokens.ink, 0.28)!,
    );
    canvas.drawRRect(lip, edge);

    for (int i = 1; i <= 3; i++) {
      final double x = body.left + body.width * (i / 4);
      canvas.drawLine(
        Offset(x, body.top + body.height * 0.22),
        Offset(x, body.bottom - body.height * 0.14),
        Paint()
          ..color = tokens.ink.withValues(alpha: 0.28)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_EscapePainter old) =>
      old.phase != phase || old.shape != shape || old.tokens.ink != tokens.ink;
}
