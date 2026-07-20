import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/boot_spec.dart';
import '../../engine/splash_spec.dart';
import 'boot_controller.dart';
import 'splash_sequence.dart';

/// Resolved colours for the boot log. Kept as its own small value type so the
/// renderer never has to know the shape of EffectiveTheme. The call site (one
/// place, home_screen) maps from the active palette into this.
class BootColors {
  const BootColors({
    required this.background,
    required this.text,
    required this.dim,
    required this.accent,
    this.ok = const Color(0xFF3FBF3F),
    this.fail = const Color(0xFFE24B4A),
    this.grubBar,
    this.grubBarText = const Color(0xFFFFFFFF),
    this.grubSelectedBar,
    this.grubSelectedText,
  });

  final Color background;
  final Color text;
  final Color dim;

  /// Used for the `[  **  ]` hang tag.
  final Color accent;

  /// The `[  OK  ]` green. A real terminal green by default; override per theme
  /// if you want a warmer one.
  final Color ok;

  final Color fail;

  /// The GRUB title/selection block. Defaults to [accent] when null.
  final Color? grubBar;
  final Color grubBarText;

  /// GRUB's currently-selected menu entry — classically an inverted bar (light
  /// fill, dark text). Both default to the log's own colours so the selection
  /// tints per distro with NO literal: the bar takes the foreground [text], its
  /// text takes the [background]. A theme that skins GRUB can override either.
  final Color? grubSelectedBar;
  final Color? grubSelectedText;

  /// Convenience for the common case: a near-black background, the theme accent
  /// for hangs and GRUB, muted grey for dmesg. Pass a distro-tinted background
  /// (Ubuntu aubergine, tui #080D08) when you have one.
  factory BootColors.fromPalette({
    required Color accent,
    Color background = const Color(0xFF0B0B0B),
    Color text = const Color(0xFFC8C8C8),
    Color dim = const Color(0xFF7A8FA0),
  }) =>
      BootColors(
        background: background,
        text: text,
        dim: dim,
        accent: accent,
      );

  Color get resolvedGrubBar => grubBar ?? accent;
  Color get resolvedGrubSelectedBar => grubSelectedBar ?? text;
  Color get resolvedGrubSelectedText => grubSelectedText ?? background;
}

/// Walks a [BootSpec] line by line, terminal style, then fades out to reveal
/// whatever is mounted underneath it.
///
/// Tap anywhere to skip. Respects the platform "reduce motion" setting: when
/// animations are disabled it completes almost immediately instead of making
/// someone sit through six seconds of theatre they opted out of.
///
/// Purely visual and stateless with respect to the app: it does not decide
/// WHEN to play (that is [BootController]) and it does not touch prefs. It just
/// renders and calls [onComplete].
class BootSequence extends StatefulWidget {
  const BootSequence({
    super.key,
    required this.spec,
    required this.colors,
    required this.onComplete,
    this.monoFontFamily = 'UbuntuMono',
    this.skippable = true,
  });

  final BootSpec spec;
  final BootColors colors;
  final VoidCallback onComplete;
  final String monoFontFamily;
  final bool skippable;

  @override
  State<BootSequence> createState() => _BootSequenceState();
}

class _BootSequenceState extends State<BootSequence> {
  final _visible = <BootLine>[];
  final _scroll = ScrollController();

  Timer? _timer;
  int _index = 0;
  bool _cancelled = false;
  bool _fading = false;

  @override
  void initState() {
    super.initState();
    // Kick off after first frame so MediaQuery is available for the
    // reduce-motion check.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      // Honour the opt-out: show the whole log at once, hold briefly, done.
      setState(() => _visible
        ..clear()
        ..addAll(widget.spec.lines));
      _scheduleScroll();
      _timer = Timer(const Duration(milliseconds: 350), _finishOut);
      return;
    }
    _scheduleNext();
  }

  void _scheduleNext() {
    if (_cancelled || !mounted) return;
    if (_index >= widget.spec.lines.length) {
      _timer = Timer(Duration(milliseconds: widget.spec.tailMs), _finishOut);
      return;
    }
    final line = widget.spec.lines[_index];
    _timer = Timer(Duration(milliseconds: line.effectiveDelayMs), () {
      if (_cancelled || !mounted) return;
      setState(() => _visible.add(line));
      _index++;
      _scheduleScroll();
      _scheduleNext();
    });
  }

  void _scheduleScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _skip() {
    if (!widget.skippable || _fading) return;
    _cancelled = true;
    _timer?.cancel();
    setState(() => _visible
      ..clear()
      ..addAll(widget.spec.lines));
    _scheduleScroll();
    _finishOut();
  }

  /// Fade to transparent, then hand control back. The fade is what makes the
  /// shell look like it "comes up" underneath rather than hard-cutting in.
  void _finishOut() {
    if (_fading || !mounted) return;
    setState(() => _fading = true);
    _timer = Timer(const Duration(milliseconds: 240), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _cancelled = true;
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: AnimatedOpacity(
        opacity: _fading ? 0 : 1,
        duration: const Duration(milliseconds: 220),
        child: Container(
          color: c.background,
          padding: const EdgeInsets.fromLTRB(14, 44, 14, 20),
          child: SingleChildScrollView(
            controller: _scroll,
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in _visible) _line(line, c),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(BootLine line, BootColors c) {
    final mono = TextStyle(
      fontFamily: widget.monoFontFamily,
      fontSize: 12.5,
      height: 1.5,
    );

    switch (line.kind) {
      case BootLineKind.blank:
        return SizedBox(height: mono.fontSize! * mono.height!);

      case BootLineKind.grub:
        return Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          color: c.resolvedGrubBar,
          child: Text(line.text, style: mono.copyWith(color: c.grubBarText)),
        );

      case BootLineKind.grubSelected:
        return Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          width: 220,
          color: c.resolvedGrubSelectedBar,
          child: Text(
            line.text,
            style: mono.copyWith(color: c.resolvedGrubSelectedText),
          ),
        );

      case BootLineKind.dim:
        return Text(line.text, style: mono.copyWith(color: c.dim));

      case BootLineKind.plain:
        return Text(line.text, style: mono.copyWith(color: c.text));

      case BootLineKind.ok:
        return _tagged('  OK  ', c.ok, line.text, c, mono);

      case BootLineKind.warn:
        return _tagged('  **  ', c.accent, line.text, c, mono);

      case BootLineKind.fail:
        return _tagged('FAILED', c.fail, line.text, c, mono);
    }
  }

  /// A `[  OK  ]  message` row with the coloured tag and foreground message.
  Widget _tagged(
    String tag,
    Color tagColor,
    String message,
    BootColors c,
    TextStyle mono,
  ) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: '[', style: mono.copyWith(color: c.dim)),
        TextSpan(text: tag, style: mono.copyWith(color: tagColor)),
        TextSpan(text: '] ', style: mono.copyWith(color: c.dim)),
        TextSpan(text: message, style: mono.copyWith(color: c.text)),
      ]),
    );
  }
}

/// Drop this around the shell in home_screen. It renders nothing until someone
/// calls `bootControllerProvider.notifier.play(spec)`, at which point the boot
/// log covers the shell, then fades away on completion.
///
/// [colors] is resolved by the caller from the active palette (one wiring
/// point, where the EffectiveTheme field names are known). [background] is
/// optional per-theme tint for the boot canvas; pass the distro's dark base
/// (Ubuntu aubergine, tui #080D08) when the theme has one.
class BootGate extends ConsumerWidget {
  const BootGate({
    super.key,
    required this.child,
    required this.colors,
    this.splashChrome,
    this.monoFontFamily = 'UbuntuMono',
  });

  final Widget child;
  final BootColors colors;

  /// Needed only for the SPLASH path. Null means a splash cannot be rendered,
  /// so the gate falls through to the shell — a missing wiring point degrades
  /// to "no splash", never to a crash on the first thing the user sees.
  final SplashChrome? splashChrome;

  final String monoFontFamily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(bootControllerProvider);
    return Stack(
      children: [
        child,
        // Exactly one of these can be non-null at a time — BootState enforces
        // that the verbose log and the splash are alternatives.
        if (boot.playing && boot.spec != null)
          Positioned.fill(
            child: BootSequence(
              spec: boot.spec!,
              colors: colors,
              monoFontFamily: monoFontFamily,
              onComplete: () =>
                  ref.read(bootControllerProvider.notifier).finish(),
            ),
          )
        else if (boot.playing &&
            boot.splash != null &&
            boot.splash!.style != SplashStyle.none &&
            splashChrome != null)
          Positioned.fill(
            child: SplashSequence(
              spec: boot.splash!,
              background: splashChrome!.background,
              accent: splashChrome!.accent,
              onDark: splashChrome!.onDark,
              title: splashChrome!.title,
              logoAsset: splashChrome!.logoAsset,
              displayFontFamily: splashChrome!.displayFontFamily,
              monoFontFamily: splashChrome!.monoFontFamily,
              onComplete: () =>
                  ref.read(bootControllerProvider.notifier).finish(),
            ),
          ),
      ],
    );
  }
}
