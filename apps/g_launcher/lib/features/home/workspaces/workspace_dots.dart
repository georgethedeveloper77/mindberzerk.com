import 'package:flutter/material.dart';

/// The right-edge workspace indicator. Mockup, exactly:
///
///   .wsdots   right: 9px, vertically centred, 7px gap
///   .wsdots i 6×6, border-radius 50%, rgba(255,255,255,.32)
///   .wsdots i.a  background: orange, height: 18px, border-radius: 3px
///
/// So: idle dots are CIRCLES, the active one is a 6×18 rounded bar. Not a
/// bigger circle, not a lozenge — a bar. It reads as "you are here on a vertical
/// strip", which is exactly what GNOME's workspace switcher does.
///
/// Dumb by design: no Riverpod, no theme import. Count, active index and colours
/// are passed in, so Plasma and the tiling shell can reuse it wherever their
/// ThemeSpec puts the indicator, and it is golden-testable with no providers.
class WorkspaceDots extends StatelessWidget {
  const WorkspaceDots({
    super.key,
    required this.count,
    required this.active,
    required this.accent,
    required this.idle,
    this.onSelect,
    this.dotSize = 6.0,
    this.activeLength = 18.0,
    this.gap = 7.0,
  });

  final int count;
  final int active;

  /// Active dot. Ubuntu orange.
  final Color accent;

  /// Inactive dots. White at 32% — not grey. On a photograph, a solid grey dot
  /// looks like a dead pixel.
  final Color idle;

  /// Tap a dot to jump. Null makes the strip decorative.
  final ValueChanged<int>? onSelect;

  final double dotSize;
  final double activeLength;
  final double gap;

  @override
  Widget build(BuildContext context) {
    // One workspace is not a choice, and a lone dot is noise on a desktop whose
    // entire point is that it's empty.
    if (count <= 1) return const SizedBox.shrink();

    return Semantics(
      container: true,
      label: 'Workspaces',
      value: 'Workspace ${active + 1} of $count',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: EdgeInsets.symmetric(vertical: gap / 2),
              child: _Dot(
                index: i,
                isActive: i == active,
                accent: accent,
                idle: idle,
                dotSize: dotSize,
                activeLength: activeLength,
                onTap: onSelect == null ? null : () => onSelect!(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.index,
    required this.isActive,
    required this.accent,
    required this.idle,
    required this.dotSize,
    required this.activeLength,
    required this.onTap,
  });

  final int index;
  final bool isActive;
  final Color accent;
  final Color idle;
  final double dotSize;
  final double activeLength;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dot = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: dotSize,
      height: isActive ? activeLength : dotSize,
      decoration: BoxDecoration(
        color: isActive ? accent : idle,
        // Circle when idle (radius = half of 6), 3px bar when active. Animating
        // between the two radii is what gives the dot its little stretch.
        borderRadius:
            BorderRadius.circular(isActive ? 3 : dotSize / 2),
        boxShadow: const [
          BoxShadow(
              color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
    );

    if (onTap == null) return dot;

    return Semantics(
      button: true,
      selected: isActive,
      label: 'Workspace ${index + 1}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // 6px is an unhittable target. Pad the touch area to 44 without changing
        // a single drawn pixel.
        child: SizedBox(
          width: 44,
          height: isActive ? activeLength + 12 : 24,
          child: Center(child: dot),
        ),
      ),
    );
  }
}
