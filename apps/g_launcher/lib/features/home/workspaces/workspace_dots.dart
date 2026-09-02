import 'package:flutter/material.dart';

/// The workspace indicator. Mockup, exactly:
///
///   .wsdots   right: 9px, vertically centred, 7px gap
///   .wsdots i 6×6, border-radius 50%, rgba(255,255,255,.32)
///   .wsdots i.a  background: orange, height: 18px, border-radius: 3px
///
/// So: idle dots are CIRCLES, the active one is a 6×18 rounded bar. Not a
/// bigger circle, not a lozenge — a bar. It reads as "you are here on a strip",
/// which is exactly what GNOME's workspace switcher does.
///
/// Dumb by design: no Riverpod, no theme import. Count, active index and colours
/// are passed in, so Plasma and the tiling shell can reuse it wherever their
/// ThemeSpec puts the indicator, and it is golden-testable with no providers.
///
/// ─── THE STRIP RUNS ALONG [axis], AND USED TO BE A COLUMN ───────────────────
///
/// The right-edge indicator is vertical and that is still the default, so the
/// one shipping caller does not move. The overview needs the same strip lying
/// on its side, under the card it belongs to, and a second copy of this file
/// would be two places to keep the mockup's 6/18/7 numbers correct.
///
/// The active dot's LONG dimension follows the axis. That is the whole reason
/// this is a parameter rather than a `RotatedBox` at the call site: rotating
/// would turn the bar the wrong way, so the thing that says "you are here"
/// would point across the strip instead of along it.
class WorkspaceDots extends StatelessWidget {
  const WorkspaceDots({
    super.key,
    required this.count,
    required this.active,
    required this.accent,
    required this.idle,
    this.onSelect,
    this.stripLabel,
    this.stripValue,
    this.dotLabel,
    this.axis = Axis.vertical,
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

  /// The screen reader's name for the strip, its reading of where you are, and
  /// a name for each dot.
  ///
  /// ─── NULLABLE, AND OMITTED RATHER THAN DEFAULTED ────────────────────────
  ///
  /// These were the literals 'Workspaces', 'Workspace 2 of 4' and 'Workspace 3'
  /// baked into this file, which made the one widget in this area that is
  /// deliberately provider-free also the one that could not be translated. It
  /// cannot look a key up: it has no Riverpod, no theme and no BuildContext
  /// extension by design, and giving it one to fix three strings would trade
  /// away the reason it is golden-testable without providers.
  ///
  /// So the caller resolves them. Null omits that Semantics node rather than
  /// falling back to English, because a default here would be an untranslated
  /// string that looks deliberate. A caller that passes nothing gets a strip
  /// that is silent to a screen reader, which is a visible gap rather than a
  /// hidden wrong answer.
  final String? stripLabel;
  final String? stripValue;

  /// Given a zero-based index, the name of that dot. Called per dot, so the
  /// caller decides whether that is "Workspace 3" or something else.
  final String Function(int index)? dotLabel;

  /// Which way the strip runs.
  ///
  /// DEFAULTED, not required, and deliberately so. Every other new parameter in
  /// this area is required on the grounds that a default is a silent wrong
  /// answer, but that argument does not apply here: vertical IS the answer the
  /// existing caller wants, the mockup this file quotes is a vertical strip, and
  /// a caller that forgets to pass one gets the behaviour it had before this
  /// parameter existed rather than a plausible-looking mistake.
  final Axis axis;

  final double dotSize;
  final double activeLength;
  final double gap;

  @override
  Widget build(BuildContext context) {
    // One workspace is not a choice, and a lone dot is noise on a desktop whose
    // entire point is that it's empty.
    if (count <= 1) return const SizedBox.shrink();

    final vertical = axis == Axis.vertical;

    return Semantics(
      container: true,
      label: stripLabel,
      value: stripValue,
      // Flex rather than a Column/Row branch: the two differ by one field and
      // writing both would be the same children list twice.
      child: Flex(
        direction: axis,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              // The gap runs ALONG the strip, so which axis it pads on follows
              // the direction. Padding the wrong one leaves the dots touching
              // and widens the strip across instead.
              padding: vertical
                  ? EdgeInsets.symmetric(vertical: gap / 2)
                  : EdgeInsets.symmetric(horizontal: gap / 2),
              child: _Dot(
                isActive: i == active,
                accent: accent,
                idle: idle,
                axis: axis,
                dotSize: dotSize,
                activeLength: activeLength,
                label: dotLabel?.call(i),
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
    required this.isActive,
    required this.accent,
    required this.idle,
    required this.axis,
    required this.label,
    required this.dotSize,
    required this.activeLength,
    required this.onTap,
  });

  final bool isActive;
  final Color accent;
  final Color idle;
  final Axis axis;

  /// This dot's own name, or null to leave it unnamed. See
  /// [WorkspaceDots.dotLabel].
  final String? label;

  final double dotSize;
  final double activeLength;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final vertical = axis == Axis.vertical;

    // The long side is the one the strip runs along; the short side stays
    // [dotSize] on both. An idle dot is square either way, which is what makes
    // it a circle once the radius lands.
    final long = isActive ? activeLength : dotSize;

    final dot = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: vertical ? dotSize : long,
      height: vertical ? long : dotSize,
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

    // 6px is an unhittable target. Pad the touch area without changing a single
    // drawn pixel: 44 across the strip, and enough along it to clear the dot.
    final along = isActive ? activeLength + 12 : 24.0;

    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: vertical ? 44 : along,
          height: vertical ? along : 44,
          child: Center(child: dot),
        ),
      ),
    );
  }
}
