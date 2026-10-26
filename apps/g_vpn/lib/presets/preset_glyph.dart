import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/meridian.dart';
import 'presets.dart';

/// The colour for [tone], from Meridian so both themes stay in step.
Color presetColor(PresetTone tone, Meridian m) => switch (tone) {
      PresetTone.blue => m.brand,
      PresetTone.amber => m.warn,
      PresetTone.green => m.good,
      PresetTone.violet => m.violet,
      PresetTone.teal => m.teal,
      PresetTone.pink => m.pink,
    };

/// A preset's icon in its colour, alive when it matters.
///
/// [working] (connecting through this preset): the icon does its own move
/// on a loop, a bolt flickering, a lock wiggling open, play pulsing, a
/// shield shining, a star turning. [active] (connected through it): a soft
/// glow breathes twice, then rests. Otherwise still. Nothing moves under
/// "remove animations", and nothing loops once the preset is idle.
class PresetGlyph extends StatefulWidget {
  const PresetGlyph({
    super.key,
    required this.icon,
    required this.tone,
    this.active = false,
    this.working = false,
    this.size = 44,
  });

  final PresetIcon icon;
  final PresetTone tone;
  final bool active;
  final bool working;
  final double size;

  @override
  State<PresetGlyph> createState() => _PresetGlyphState();
}

class _PresetGlyphState extends State<PresetGlyph> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  Timer? _rest;

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Once on arrival; later dependency changes (theme) leave it be.
    if (_started) return;
    _started = true;
    _sync(becameActive: widget.active);
  }

  @override
  void didUpdateWidget(PresetGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.working != widget.working || oldWidget.active != widget.active) {
      _sync(becameActive: widget.active && !oldWidget.active);
    }
  }

  void _sync({required bool becameActive}) {
    _rest?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 0;
      _c.stop();
      return;
    }
    if (widget.working) {
      _c.duration = const Duration(milliseconds: 900);
      _c.repeat();
    } else if (becameActive) {
      // Two breaths to say "this one", then still.
      _c.duration = const Duration(milliseconds: 1400);
      _c.repeat();
      _rest = Timer(const Duration(milliseconds: 2800), () {
        if (mounted) _c.animateTo(0, duration: const Duration(milliseconds: 300));
      });
    } else if (_c.isAnimating || _c.value != 0) {
      _c.animateTo(0, duration: const Duration(milliseconds: 250));
    }
  }

  @override
  void dispose() {
    _rest?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    final color = presetColor(widget.tone, m);
    final iconSize = widget.size * .52;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        final wave = math.sin(v * 2 * math.pi); // -1..1
        final lift = (1 - math.cos(v * 2 * math.pi)) / 2; // 0..1..0
        final working = widget.working;
        Widget glyph = Icon(presetIconData(widget.icon), size: iconSize, color: color);
        if (working) {
          glyph = switch (widget.icon) {
            PresetIcon.bolt => Opacity(opacity: .55 + .45 * lift, child: Transform.scale(scale: 1 + .18 * lift, child: glyph)),
            PresetIcon.unlock || PresetIcon.game => Transform.rotate(angle: .22 * wave, child: glyph),
            PresetIcon.star => Transform.rotate(angle: v * 2 * math.pi, child: glyph),
            PresetIcon.home => Transform.translate(offset: Offset(0, -4 * lift), child: glyph),
            _ => Transform.scale(scale: 1 + .16 * lift, child: glyph),
          };
        }
        return Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .16 + .10 * lift),
            borderRadius: BorderRadius.circular(widget.size * .32),
            boxShadow: [
              if (lift > 0) BoxShadow(color: color.withValues(alpha: .45 * lift), blurRadius: 16 * lift, spreadRadius: 1),
            ],
          ),
          child: glyph,
        );
      },
    );
  }
}
