import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../engine/splash_spec.dart';

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

  /// Distro name — the text style's content, and the fallback when a theme has
  /// no logo artwork.
  final String? title;

  /// Already resolved by the caller: the spec's own logo, else the theme's dark
  /// logo variant, else null.
  final String? logoAsset;

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
  /// than as a generic black screen — same rule the boot canvas follows.
  final Color background;
  final Color accent;
  final Color onDark;

  /// Distro name, for [SplashStyle.text] and as the fallback when there is no
  /// logo to draw.
  final String? title;

  /// Resolved by the caller: the spec's own `logo`, else the theme's dark logo
  /// variant, else null.
  final String? logoAsset;

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
    // Fade out, then hand control back — the shell "comes up" underneath rather
    // than hard-cutting in.
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

  Widget _logo() {
    final asset = widget.logoAsset;
    if (asset == null) {
      // No artwork: the distro's name in its own display font is a better
      // stand-in than a generic glyph nobody recognises.
      return Text(
        widget.title ?? '',
        style: TextStyle(
          fontFamily: widget.displayFontFamily,
          fontSize: 26,
          fontWeight: FontWeight.w300,
          letterSpacing: 1.5,
          color: widget.onDark,
        ),
      );
    }

    const size = 96.0;
    return SizedBox(
      width: size,
      height: size,
      child: asset.endsWith('.svg')
          ? SvgPicture.asset(
              asset,
              width: size,
              height: size,
              // TINTED, matching LauncherBrandIcon. A splash paints on the
              // distro's darkest colour, so the dark-surface logo variant has
              // to be knocked out to onDark or it renders as dark ink on dark
              // ground. LauncherBrandIcon already did this and this did not,
              // which is why the mark is legible in the drawer and invisible
              // on the splash: same asset, two readers, one rule.
              colorFilter: ColorFilter.mode(widget.onDark, BlendMode.srcIn),
            )
          : Image.asset(
              asset,
              width: size,
              height: size,
              color: widget.onDark,
              colorBlendMode: BlendMode.srcIn,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
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
/// has a known duration — a bar that spins forever while the thing behind it is
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
