import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../app/theme/tokens.dart';
import '../core/i18n/g_strings.dart';

/// THE FIRST TWO SECONDS.
///
/// ─── WHY LOTTIE HERE AND NOWHERE ELSE ────────────────────────────────────────
///
/// Every other animation in this app is drawn in code, because code recolours
/// with the accent for free and costs no dependency. The splash is the one place
/// that trade flips: it plays once, it is the first impression, and the hand
/// animated timing in this file is better than anything a CustomPainter would
/// produce for the same effort.
///
/// The file is 8 KB and pure vector, with no embedded bitmaps, which is why it
/// can be recoloured at all. The other Lottie in the folder had four image
/// assets and could not follow the theme.
///
/// ─── IT FOLLOWS THE ACCENT ───────────────────────────────────────────────────
///
/// The artwork ships red. Every fill is replaced through a value delegate, so a
/// user on the mint accent sees a mint animation rather than a red one that
/// matches nothing else on their phone.
///
/// ─── IT NEVER BLOCKS ─────────────────────────────────────────────────────────
///
/// [onDone] fires when the animation finishes OR when the timeout expires,
/// whichever comes first. A splash that waits on a decode is a splash that hangs
/// on the one phone where the decode is slow.
class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Constructed here, never as a late final with an initialiser. The lazy form
  // can run its initialiser from inside dispose, where createTicker reads
  // TickerMode off a deactivated element.
  late final AnimationController _controller;

  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);

    // The hard stop. Two and a half seconds is longer than the animation and
    // shorter than a person's patience, and it fires even if the asset fails to
    // load at all.
    Future<void>.delayed(const Duration(milliseconds: 2500), _finish);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Scaffold(
      backgroundColor: t.ink,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 250,
              height: 120,
              child: Lottie.asset(
                'assets/lottie/delete_bubble.json',
                controller: _controller,
                onLoaded: (LottieComposition composition) {
                  _controller
                    ..duration = composition.duration
                    ..forward().whenComplete(_finish);
                },
                // Failing to draw a splash must never fail to start the app.
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? s) {
                      _finish();
                      return const SizedBox.shrink();
                    },
                // ONE delegate, not two.
                //
                // The first version set both a colour and a colour filter over
                // '**'. The filter repaints the whole composition in one flat
                // tone, which erases the shading the animation depends on and
                // leaves a moving blob. The colour delegate alone replaces each
                // fill and keeps the artwork's own structure.
                delegates: LottieDelegates(
                  values: <ValueDelegate<dynamic>>[
                    // '**' matches every layer and shape, so this covers the
                    // shape fill and the solid layers without needing the
                    // artwork's internal names, which would break the moment
                    // the file is re-exported.
                    ValueDelegate.color(const <String>['**'], value: t.accent),
                  ],
                ),
              ),
            ),
            const SizedBox(height: GSpace.lg),
            Text(
              context.s('G Recovery'),
              style: GType.title.copyWith(color: t.text),
            ),
          ],
        ),
      ),
    );
  }
}
