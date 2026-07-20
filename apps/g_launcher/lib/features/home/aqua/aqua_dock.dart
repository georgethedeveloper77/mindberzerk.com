import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../engine/theme_spec.dart' show ThemePalette;
import '../../dock/aqua_dock_metrics.dart';
import '../gnome/gnome_dock.dart' show DockEntry;

/// The magnifying dock.
///
/// Geometry comes entirely from [AquaDockMetrics], which is pure functions with
/// no Flutter imports and its own unit tests. This widget is paint plus one
/// piece of state: where the finger is. Keeping the math out of here is what
/// lets the clipping behaviour be tested across every app count and every touch
/// position without a device, which is the only practical way to be sure a
/// magnifying dock never overflows its own bounds.
///
/// [DockEntry] is reused from the GNOME dock rather than redeclared. It is
/// already presentation-free — it holds a Widget, not a component key — so both
/// docks can render the same entries. It arguably belongs in `features/dock/`
/// now that two shells use it; moving it would touch the GNOME dock's golden
/// tests, so it stays put and is imported.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// WHY Listener AND NOT GestureDetector.
///
/// Magnification is not a gesture. It is a continuous visual response to where
/// a pointer happens to be, and it must not compete in the gesture arena — a
/// horizontal drag across the dock would otherwise be contested by the shell's
/// swipe handlers, and whichever won, the other would feel broken.
///
/// [Listener] sits below the arena entirely: it sees every pointer event
/// regardless of who eventually claims the gesture. With `behavior: opaque` the
/// dock also absorbs those pointers so they never reach the desktop underneath.
/// Taps stay on the individual slots, where a normal GestureDetector is exactly
/// right, because a tap IS a gesture.
///
/// The shell additionally places this dock OUTSIDE its GestureLayer, so a scrub
/// along the dock cannot register as a desktop swipe at all.
/// ─────────────────────────────────────────────────────────────────────────────
class AquaDock extends StatefulWidget {
  const AquaDock({
    super.key,
    required this.entries,
    required this.palette,
    required this.onLaunchpad,
  });

  final List<DockEntry> entries;
  final ThemePalette palette;

  /// Launchpad's own slot, pinned at the right end past a separator — the
  /// position a Mac keeps Trash in, and the one place in the dock that is not
  /// an app.
  final VoidCallback onLaunchpad;

  @override
  State<AquaDock> createState() => _AquaDockState();
}

class _AquaDockState extends State<AquaDock> {
  /// Where the finger is along the dock, or null for at-rest.
  ///
  /// Local state on purpose. This changes on every pointer move, and lifting it
  /// into Riverpod would rebuild the whole shell at touch frequency to animate
  /// six icons. Nothing outside this widget needs to know.
  double? _focus;

  /// The panel's own left edge in global coordinates, so pointer positions can
  /// be converted into the dock-local space the metrics expect.
  final _panelKey = GlobalKey();

  void _setFocusFrom(Offset globalPosition) {
    final box = _panelKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);
    setState(() => _focus = local.dx - _padding);
  }

  void _clearFocus() {
    if (_focus == null) return;
    setState(() => _focus = null);
  }

  /// Panel padding, subtracted so the metrics see a run starting at zero.
  static const _padding = 8.0;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final onDark = palette.onDark;

    // The Launchpad slot rides along in the same run, so magnification treats it
    // exactly like an app. A slot that refuses to swell with its neighbours is
    // the kind of small wrongness people feel without being able to name.
    final slotCount = widget.entries.length + 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The dock never spans the full width. A Mac's floats, with desktop
        // visible either side, and a phone dock that touches both edges reads as
        // a navigation bar rather than as a dock.
        final available =
            (constraints.maxWidth * 0.92) - _padding * 2;

        final slots = AquaDockMetrics.layout(
          count: slotCount,
          available: available,
          focus: _focus,
        );
        if (slots.isEmpty) return const SizedBox.shrink();

        // Tallest slot decides the panel height, so the panel grows with the
        // swell instead of clipping the magnified icon's top.
        final tallest = slots
            .map((s) => s.size)
            .reduce((a, b) => a > b ? a : b);

        return Center(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _setFocusFrom(e.position),
            onPointerMove: (e) => _setFocusFrom(e.position),
            onPointerUp: (_) => _clearFocus(),
            onPointerCancel: (_) => _clearFocus(),
            child: ClipRRect(
              // A Mac's dock is a tall rounded rectangle, not a pill. The radius
              // scales with the panel so it stays proportional as icons swell.
              borderRadius: BorderRadius.circular(tallest * 0.28),
              child: BackdropFilter(
                // The single most expensive thing on this desktop, and the one
                // that makes it read as Aqua. Same warning as the GNOME dock: if
                // it janks on a budget phone, measure here first.
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  key: _panelKey,
                  width: available + _padding * 2,
                  padding: const EdgeInsets.all(_padding),
                  decoration: BoxDecoration(
                    color: palette.dock,
                    border: Border.all(color: onDark.withValues(alpha: 0.14)),
                    borderRadius: BorderRadius.circular(tallest * 0.28),
                  ),
                  child: SizedBox(
                    height: tallest,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var i = 0; i < slots.length; i++)
                          _positioned(
                            slot: slots[i],
                            tallest: tallest,
                            child: i < widget.entries.length
                                ? _AquaSlotView(
                                    entry: widget.entries[i],
                                    size: slots[i].size,
                                    accent: palette.accent,
                                  )
                                : _LaunchpadSlot(
                                    size: slots[i].size,
                                    onDark: onDark,
                                    onTap: widget.onLaunchpad,
                                  ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Slots are BOTTOM-ALIGNED, not centred. A magnified icon on a Mac grows
  /// upward out of the dock while its feet stay on the same line; centring it
  /// would make the whole row appear to breathe in and out, which looks like a
  /// rendering bug rather than like magnification.
  Widget _positioned({
    required AquaSlot slot,
    required double tallest,
    required Widget child,
  }) {
    return Positioned(
      left: slot.center - slot.size / 2,
      top: tallest - slot.size,
      width: slot.size,
      height: slot.size,
      child: child,
    );
  }
}

class _AquaSlotView extends StatelessWidget {
  const _AquaSlotView({
    required this.entry,
    required this.size,
    required this.accent,
  });

  final DockEntry entry;
  final double size;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: entry.label,
      child: GestureDetector(
        onTap: entry.onTap,
        onLongPress: entry.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: FittedBox(
                // The icon widget was built at the dock's resting glyph size;
                // FittedBox scales it to whatever the magnification asked for
                // this frame. Rebuilding an AppIcon at a new pixel size on every
                // pointer move would re-cross the platform channel sixty times a
                // second, which is the whole reason the icon cache exists.
                fit: BoxFit.contain,
                child: entry.icon,
              ),
            ),
            // A Mac marks a running app with a dot beneath it. Same honesty rule
            // as the GNOME running bar: Android has no public "is this running"
            // API, so this lights only for what we actually know, and a dot on
            // an app that is not running is a small lie.
            SizedBox(
              height: 5,
              child: entry.isRunning
                  ? Center(
                      child: Container(
                        width: 3.5,
                        height: 3.5,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Launchpad's slot: the grid glyph on a translucent plate, past the separator.
class _LaunchpadSlot extends StatelessWidget {
  const _LaunchpadSlot({
    required this.size,
    required this.onDark,
    required this.onTap,
  });

  final double size;
  final Color onDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Launchpad',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: onDark.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(size * 0.24),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.grid_view_rounded,
                  // Tracks the slot, so the glyph swells with everything else.
                  size: size * 0.5,
                  color: onDark,
                ),
              ),
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}
