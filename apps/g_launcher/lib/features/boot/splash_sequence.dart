import 'package:flutter/material.dart';

import '../../design/theme_mark.dart';
import '../../engine/splash_spec.dart';
import '../../engine/theme_source.dart';

/// Everything the splash renderer needs that is not in the [SplashSpec].
///
/// Its own small value type for the same reason [BootColors] is one: the
/// renderer never has to know the shape of EffectiveTheme, and the mapping
/// happens at ONE wiring point (home_screen) where the field names are known.
class SplashChrome {
  const SplashChrome({
    required this.background,
    required this.accent,
    required this.onDark,
    this.title,
    this.logoAsset,
    this.displayFontFamily,
    this.monoFontFamily = 'UbuntuMono',
  });

  /// The distro's dark base, so the splash reads as THIS distro starting.
  final Color background;
  final Color accent;
  final Color onDark;

  /// Distro name, the text style's content, and the fallback when a theme has
  /// no logo artwork.
  final String? title;

  /// Already resolved by the caller: the spec's own logo, else the theme's dark
  /// logo variant, else null.
  ///
  /// ─── THIS WAS A String AND THAT WAS THE BUG ─────────────────────────────
  ///
  /// A [ThemeAsset], because the same `theme.json` string means two different
  /// things and only [ThemeSource] knows which. A bundled Ubuntu says
  /// `assets/themes/ubuntu-24-04/logo_dark.webp`; the SAME distro republished
  /// over the CDN says `logo_dark.webp`, a bare filename sitting in the pack
  /// directory, because `PackPaths` refuses separators.
  ///
  /// Carrying a String across this boundary threw away the knowledge of which,
  /// so the renderer below had no choice but to guess, and it guessed
  /// `Image.asset` every time. On any installed pack that is
  /// `Unable to load asset: "logo_dark.webp"`, raised inside the image
  /// pipeline, swallowed by an errorBuilder, and visible only as a splash with
  /// no mark on it. Every other consumer of a theme path in the app already
  /// went through `source.asset(...)`; see `_Strip` in wallpaper_screen.dart,
  /// which carries the same scar. The splash was the last one holding a String.
  final ThemeAsset? logoAsset;

  final String? displayFontFamily;
  final String monoFontFamily;
}

/// Paints a [SplashSpec] for its duration, then fades out.
///
/// Purely visual and stateless with respect to the app, exactly like
/// [BootSequence]: it does not decide WHEN to play (that is [BootController])
/// and it does not touch prefs. It renders and calls [onComplete].
///
/// Not tap-to-skip, unlike the verbose boot. A six-second log you did not ask
/// for needs an escape hatch; a 900ms splash does not, and a tap target that
/// lives for under a second is one you will hit by accident on the shell
/// underneath.
class SplashSequence extends StatefulWidget {
  const SplashSequence({
    super.key,
    required this.spec,
    required this.background,
    required this.accent,
    required this.onDark,
    required this.onComplete,
    this.title,
    this.logoAsset,
    this.monoFontFamily = 'UbuntuMono',
    this.displayFontFamily,
  });

  final SplashSpec spec;

  /// The distro's dark base, so the splash reads as THIS distro starting rather
  /// than as a generic black screen, the same rule the boot canvas follows.
  final Color background;
  final Color accent;
  final Color onDark;

  /// Distro name, for [SplashStyle.text] and as the fallback when there is no
  /// logo to draw.
  final String? title;

  /// Resolved by the caller: the spec's own `logo`, else the theme's dark logo
  /// variant, else null. See [SplashChrome.logoAsset] for why this is a
  /// [ThemeAsset] and not a path.
  final ThemeAsset? logoAsset;

  final String monoFontFamily;
  final String? displayFontFamily;

  final VoidCallback onComplete;

  @override
  State<SplashSequence> createState() => _SplashSequenceState();
}

class _SplashSequenceState extends State<SplashSequence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.spec.durationMs),
  );

  bool _fading = false;

  @override
  void initState() {
    super.initState();

    // Reduce-motion: honour the opt-out by holding a still frame for a beat
    // instead of animating. The splash still happens (it is a transition, not
    // decoration), it just does not move.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduceMotion) {
        _controller.value = 1.0;
      } else {
        _controller.forward();
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });

    // The reduce-motion path never runs the controller to completion, so it
    // needs its own timer to land.
    Future<void>.delayed(
      Duration(milliseconds: widget.spec.durationMs + 60),
      _finish,
    );
  }

  void _finish() {
    if (_fading || !mounted) return;
    setState(() => _fading = true);
    // Fade out, then hand control back, so the shell "comes up" underneath
    // rather than hard-cutting in.
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _fading ? 0 : 1,
      duration: const Duration(milliseconds: 200),
      child: ColoredBox(
        color: widget.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.spec.style != SplashStyle.text) _logo(),
              if (widget.spec.style != SplashStyle.text)
                const SizedBox(height: 34),
              _indicator(),
            ],
          ),
        ),
      ),
    );
  }

  /// The distro's name in its own display font.
  ///
  /// Used for a theme that ships no artwork AND as the failure arm below, which
  /// is the part that changed. A missing file used to render
  /// `SizedBox.shrink`, so a broken logo path produced a splash with a hole in
  /// it and no way to tell that apart from a theme that simply has no mark.
  /// Landing on the wordmark means the worst case is a plainer splash rather
  /// than an empty one.
  Widget _wordmark() => Text(
        widget.title ?? '',
        style: TextStyle(
          fontFamily: widget.displayFontFamily,
          fontSize: 26,
          fontWeight: FontWeight.w300,
          letterSpacing: 1.5,
          color: widget.onDark,
        ),
      );

  Widget _logo() {
    // ── THE FOUR BRANCHES MOVED TO [ThemeMark] ─────────────────────────
    //
    // This file used to spell out svg-or-raster and file-or-asset itself, and
    // it was the FIRST place that got the file-or-asset half right. Two other
    // readers then made the original mistake independently, which is what
    // turned a fixed bug into a shared widget: the branches live in one place
    // now and this call site says only what is specific to a splash.
    return ThemeMark(
      asset: widget.logoAsset,
      size: 96,
      // ── AS AUTHORED, NOT KNOCKED OUT ───────────────────────────────
      //
      // This tinted to onDark, and on Ubuntu that turned the orange mark into
      // a solid white circle: srcIn keeps the alpha and replaces every opaque
      // pixel, so the disc and the friends inside it become one shape.
      //
      // The old argument was that a coloured mark can go muddy on dark chrome
      // and a silhouette guarantees contrast. True of some artwork, and it
      // contradicts the reason [ThemeLogo] is a PAIR: the dark variant is
      // already artwork authored for a dark surface, so tinting it discards
      // exactly what the second variant exists to preserve. A pack that ships a
      // mark which does not read on its own has shipped the wrong file, and
      // that is the pack author's problem rather than something to paper over
      // by making every distro's logo white.
      //
      // The FALLBACK keeps its tint, because the Mindhunter mark genuinely is
      // one monochrome silhouette that has to read on every distro.
      tint: null,
      fallback: _wordmark(),
    );
  }

  Widget _indicator() => switch (widget.spec.style) {
        SplashStyle.dots => _Dots(
            controller: _controller,
            color: widget.onDark,
          ),
        SplashStyle.bar => _Bar(
            controller: _controller,
            accent: widget.accent,
            track: widget.onDark.withValues(alpha: 0.18),
          ),
        SplashStyle.spinner => SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(widget.accent),
            ),
          ),
        SplashStyle.text => Text(
            widget.title ?? '',
            style: TextStyle(
              fontFamily: widget.monoFontFamily,
              fontSize: 13,
              color: widget.onDark.withValues(alpha: 0.7),
            ),
          ),
        // Handled by the gate, which never mounts this widget for `none`.
        SplashStyle.none => const SizedBox.shrink(),
      };
}

/// Plymouth's pulsing dots: each one brightens in turn, on a loop.
class _Dots extends StatelessWidget {
  const _Dots({required this.controller, required this.color});

  final AnimationController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // Three passes across the dots over the splash's life, so the rhythm
        // reads regardless of the authored duration.
        final t = (controller.value * 3) % 1.0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(
                      alpha: 0.25 + 0.75 * _pulse(t, i / 5),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// A short bright window travelling along the row, wrapping at the end.
  static double _pulse(double t, double offset) {
    final d = (t - offset) % 1.0;
    return d < 0.25 ? 1.0 - (d / 0.25) : 0.0;
  }
}

/// KDE's determinate bar. Determinate, not indeterminate, because the splash
/// has a known duration: a bar that spins forever while the thing behind it is
/// already ready is the animation everyone has learned to distrust.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.controller,
    required this.accent,
    required this.track,
  });

  final AnimationController controller;
  final Color accent;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => LinearProgressIndicator(
            value: controller.value,
            minHeight: 3,
            backgroundColor: track,
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
      ),
    );
  }
}
