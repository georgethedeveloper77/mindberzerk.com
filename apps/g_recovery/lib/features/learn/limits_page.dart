import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_card.dart';
import '../../ui/g_enter.dart';
import '../../ui/g_sheet.dart';
import '../../core/i18n/g_strings.dart';

/// WHY SOME FILES CANNOT BE RECOVERED.
///
/// The page carrying the argument the whole product rests on. Every competitor
/// in this category implies a deep scan that finds anything; this is the screen
/// that says out loud why that is not true, and it has to be good enough that a
/// person believes the app rather than feeling fobbed off.
///
/// Structured as three tiers rather than as prose, because the honest answer is
/// not "no" but "it depends where it went", and a paragraph cannot show that
/// shape. The technical detail sits behind the info icon: someone who wants to
/// know about TRIM can find it, and someone who wanted a straight answer already
/// got one.
class LimitsPage extends StatelessWidget {
  const LimitsPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const LimitsPage(),
  );

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            GSpace.gutter,
            0,
            GSpace.gutter,
            GSpace.xl,
          ),
          children: <Widget>[
            GAppBar(
              title: context.s('What can come back'),
              leading: GIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
              actions: <Widget>[
                GIconButton(
                  icon: Icons.info_outline_rounded,
                  onTap: () => _showDetail(context),
                ),
              ],
            ),

            const SizedBox(height: GSpace.sm),
            const DustArt(height: 190),
            const SizedBox(height: GSpace.lg),

            Text(
              context.s('Deleting is not\none thing'),
              style: GType.display.copyWith(color: t.text),
            ),
            const SizedBox(height: GSpace.md),
            Text(
              context.s(
                'What happens to a file depends entirely on how it left. Some are '
                'waiting to be picked up. Some left a shadow. Some are simply not '
                'there any more, and no app can change that.',
              ),
              style: GType.bodySmall.copyWith(color: t.muted),
            ),

            const SizedBox(height: GSpace.lg),

            GEnter(
              index: 0,
              child: _Tier(
                tone: t.success,
                icon: Icons.check_circle_outline_rounded,
                verdict: 'Comes back whole',
                title: context.s('It went to a trash folder'),
                body:
                    'Android keeps deleted photos and videos for thirty days, '
                    'and many apps keep their own bin as well. The original file '
                    'is still on the phone with a flag on it. Restoring puts it '
                    'back exactly as it was.',
              ),
            ),
            const SizedBox(height: GSpace.sm + 1),

            GEnter(
              index: 1,
              child: _Tier(
                tone: t.warning,
                icon: Icons.filter_drama_outlined,
                verdict: 'Comes back smaller',
                title: context.s('Only the preview survived'),
                body:
                    'To show you a gallery quickly, Android saves a small copy '
                    'of every picture. That copy often outlives the original. It '
                    'is real and it is yours, but it is a few hundred pixels '
                    'wide and enlarging it will not bring back the detail.',
              ),
            ),
            const SizedBox(height: GSpace.sm + 1),

            GEnter(
              index: 2,
              child: _Tier(
                tone: t.danger,
                icon: Icons.remove_circle_outline_rounded,
                verdict: 'Does not come back',
                title: context.s('It was erased outside a bin'),
                body:
                    'A file removed by a cleaner app, a file manager, or the '
                    'app that owned it does not go anywhere. The space is handed '
                    'straight back to the phone, which wipes it almost '
                    'immediately. There is nothing left to read.',
              ),
            ),

            const SizedBox(height: GSpace.lg),

            GEnter(
              index: 3,
              child: GCard(
                onTap: () => _showDetail(context),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.shield_outlined, size: 20, color: t.accentText),
                    const SizedBox(width: GSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            context.s('Why no app can do more'),
                            style: GType.heading.copyWith(color: t.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.s('The technical reason, if you want it.'),
                            style: GType.micro.copyWith(color: t.muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 20, color: t.dim),
                  ],
                ),
              ),
            ),

            const SizedBox(height: GSpace.md),
            Text(
              // The commercial point, stated once and without naming anyone.
              context.s(
                'Any app promising to recover anything from an ordinary phone is '
                'looking in exactly the same places this one does.',
              ),
              textAlign: TextAlign.center,
              style: GType.micro.copyWith(color: t.dim),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final GTokens t = context.g;
    showGSheet(
      context: context,
      title: context.s('Why no app can do more'),
      children: <Widget>[
        Text(
          context.s(
            'Recovery tools on a computer work by reading the disk directly, past '
            'the filing system, and reassembling whatever is still lying there. '
            'Three things stop that working on a phone.',
          ),
          style: GType.bodySmall.copyWith(color: t.muted),
        ),
        const GSheetHeading('The storage erases itself'),
        GSheetPoint(
          icon: Icons.bolt_outlined,
          text: context.s(
            'Phone storage is flash, which cannot overwrite in place. When '
            'a file is deleted the phone immediately tells the chip that '
            'those blocks are free, and the chip clears them in the '
            'background, usually within seconds. On a spinning hard disk the '
            'data sat there until something else needed the room. Here it '
            'does not.',
          ),
        ),
        const GSheetHeading('No app may read the disk'),
        GSheetPoint(
          icon: Icons.lock_outline_rounded,
          text: context.s(
            'Reading raw storage needs root. Android gives an app a view of '
            'files, never of the disk underneath them, so the scan that '
            'desktop tools perform cannot even be attempted.',
          ),
        ),
        const GSheetHeading('It is all encrypted anyway'),
        GSheetPoint(
          icon: Icons.enhanced_encryption_outlined,
          text: context.s(
            'Every modern Android phone encrypts each file with its own '
            'key, and that key is destroyed with the file. Even reaching the '
            'raw blocks would return noise.',
          ),
        ),
        const GSheetHeading('So what is left'),
        GSheetPoint(
          icon: Icons.check_rounded,
          tone: null,
          text: context.s(
            'Everything that has not actually been deleted yet: the system '
            'trash, the bins individual apps keep, media sitting in a folder '
            'after the app forgot about it, and the thumbnail cache. That is '
            'what this app looks through, and it says which of them each find '
            'came from.',
          ),
        ),
      ],
    );
  }
}

/// One tier of the answer.
class _Tier extends StatelessWidget {
  const _Tier({
    required this.tone,
    required this.icon,
    required this.verdict,
    required this.title,
    required this.body,
  });

  final Color tone;
  final IconData icon;
  final String verdict;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final bool dark = t.brightness == Brightness.dark;
    final BorderRadius radius = GRadius.all(GRadius.card);

    return DecoratedBox(
      decoration: BoxDecoration(
        // Tinted by verdict, so the three are separable before a word is read.
        // This is the one screen where colour carrying a judgement is correct:
        // the judgement IS the content.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            tone.withValues(alpha: dark ? 0.17 : 0.1),
            tone.withValues(alpha: dark ? 0.06 : 0.035),
          ],
        ),
        border: Border.all(color: tone.withValues(alpha: dark ? 0.36 : 0.26)),
        borderRadius: radius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(GSpace.lg - 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 19, color: tone),
                const SizedBox(width: GSpace.sm + 1),
                Text(
                  verdict.toUpperCase(),
                  style: GType.overline.copyWith(color: tone),
                ),
              ],
            ),
            const SizedBox(height: GSpace.md),
            Text(title, style: GType.title.copyWith(color: t.text)),
            const SizedBox(height: GSpace.sm),
            Text(body, style: GType.bodySmall.copyWith(color: t.muted)),
          ],
        ),
      ),
    );
  }
}

/// Files falling and coming apart.
///
/// The subject of the page, drawn. A card descends, breaks into particles part
/// way down, and the particles fade before they land. Nothing reaches the
/// bottom, which is the entire point: there is no pile of recoverable debris
/// down there for an app to sift through.
class DustArt extends StatefulWidget {
  const DustArt({super.key, this.height = 190});

  final double height;

  @override
  State<DustArt> createState() => _DustArtState();
}

class _DustArtState extends State<DustArt> with SingleTickerProviderStateMixin {
  // Constructed here, never as a late final with an initialiser. The lazy form
  // can run its initialiser from inside dispose, where createTicker reads
  // TickerMode off a deactivated element.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6400),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    if (MediaQuery.disableAnimationsOf(context)) {
      return SizedBox(
        height: widget.height,
        child: CustomPaint(
          painter: _DustPainter(tokens: t, phase: 0.5),
          size: Size.infinite,
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) => CustomPaint(
          painter: _DustPainter(tokens: t, phase: _controller.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _DustPainter extends CustomPainter {
  const _DustPainter({required this.tokens, required this.phase});

  final GTokens tokens;
  final double phase;

  static const int _files = 4;
  static const int _motes = 9;

  /// Where the card stops being a card. Before this it falls whole; after, it
  /// is particles that spread and fade.
  static const double _breakAt = 0.46;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _files; i++) {
      final double local = (phase + i / _files) % 1;
      _fall(canvas, size, local, i);
    }
  }

  void _fall(Canvas canvas, Size size, double local, int index) {
    final double x =
        size.width * (0.2 + 0.2 * index) +
        math.sin(local * math.pi * 2 + index) * size.width * 0.03;
    final double y = size.height * (0.08 + local * 0.78);

    final Color colour = <Color>[
      tokens.photo,
      tokens.video,
      tokens.docs,
      tokens.audio,
    ][index % 4];

    if (local < _breakAt) {
      // Whole, and fading slightly as it goes. A card at full strength right up
      // to the moment it shatters looks like a cut rather than a decay.
      final double fade = 1 - (local / _breakAt) * 0.25;
      final double w = size.width * 0.13;
      final double h = w * 0.8;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.sin(local * 4 + index) * 0.3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          Radius.circular(w * 0.16),
        ),
        Paint()..color = colour.withValues(alpha: 0.85 * fade),
      );
      canvas.restore();
      return;
    }

    // Coming apart. Spread grows with distance past the break, opacity falls to
    // nothing before the particles reach the bottom edge.
    final double since = (local - _breakAt) / (1 - _breakAt);
    final double spread = size.width * 0.14 * since;
    final double alpha = (1 - since) * 0.7;
    if (alpha <= 0.01) return;

    final Paint paint = Paint()..color = colour.withValues(alpha: alpha);
    for (int m = 0; m < _motes; m++) {
      final double angle = (m / _motes) * math.pi * 2 + index;
      final double drift = 0.5 + ((m * 37 + index * 11) % 50) / 100;
      canvas.drawCircle(
        Offset(
          x + math.cos(angle) * spread * drift,
          y + math.sin(angle) * spread * drift * 0.6,
        ),
        size.width * (0.013 - 0.006 * since),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DustPainter old) =>
      old.phase != phase || old.tokens.ink != tokens.ink;
}
