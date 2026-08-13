/// What a tile does while its menu is open.
///
/// ─── THE PROBLEM THIS SOLVES ────────────────────────────────────────────────
///
/// A long press opened a menu and nothing on the grid changed. On a full drawer
/// the panel is anchored near the tile but not attached to it, so "which app is
/// this about?" was answered only by the name in the header, and only if you
/// read it. Holding the wrong icon and not noticing until after tapping
/// Uninstall is a real outcome of that.
///
/// ─── WHY SQUASH AND POP RATHER THAN A PLAIN SCALE ───────────────────────────
///
/// The dip to 0.90 lands where the long-press timer completes, so the tile
/// appears to compress under the finger and then release. That makes the motion
/// a CONSEQUENCE of the press rather than a highlight painted on afterwards,
/// and it gives the timer a visible landing point, which until now only the
/// haptic marked.
///
/// The dip is also the part that survives a busy wallpaper. A scale alone
/// disappears against a light photo and a ring alone reads as a selection
/// checkbox; the two together, arriving in that order, read as one gesture.
///
/// ─── WHY THE RING IS NOT A SHADOW ───────────────────────────────────────────
///
/// `AnchoredMenu` draws a deliberately light scrim (`0x33000000`, and its
/// comment says why: the thing the menu is about has to stay visible). At 20%
/// black a drop shadow under an icon is invisible, while a hairline ring at the
/// icon's own corner radius survives it. The scrim does the dimming of the
/// neighbours for free, which is why nothing here touches them.
library;

import 'package:flutter/widgets.dart';

class PressPop extends StatefulWidget {
  const PressPop({
    super.key,
    required this.held,
    required this.child,
    this.radius = 16,
    this.ringColor = const Color(0xFFFFFFFF),
  });

  /// True from the moment the menu is asked for until it closes. The caller
  /// owns this, because the caller is the only thing that knows the difference
  /// between a hold and the start of a drag: see the split-on-release note on
  /// `_AppTile`.
  final bool held;

  final Widget child;

  /// The ring's corner radius. Should match the ICON's, not the cell's, or the
  /// ring reads as a box drawn around the tile instead of an outline of it.
  final double radius;

  final Color ringColor;

  @override
  State<PressPop> createState() => _PressPopState();
}

class _PressPopState extends State<PressPop>
    with SingleTickerProviderStateMixin {
  /// Constructed in initState, never `late final`. A `late final` controller
  /// initialised from a field initialiser runs before `initState`, so `vsync:
  /// this` binds to a State that is not yet attached to a ticker provider.
  late final AnimationController _c;

  /// Total. The dip owns the first 22% and the rise owns the rest.
  static const _duration = Duration(milliseconds: 340);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _duration);

    // ─── ANIMATED, NOT SNAPPED, AND THAT IS THE LOCATE CASE ────────────────
    //
    // This was `_c.value = 1`, which puts the tile straight into the end state
    // with no motion. For a press that is unreachable: `held` is false when the
    // tile builds and turns true later, so `didUpdateWidget` runs the curve.
    //
    // For LOCATE it is the only path. The target is aimed before the drawer
    // pages or the folder opens, so the tile is BUILT already held and this is
    // the branch it takes. Snapping meant the app was ringed and never moved,
    // which is the "it does not bounce" report: the answer was on screen, and
    // nothing drew the eye to it, which is the entire job.
    if (widget.held) _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(PressPop old) {
    super.didUpdateWidget(old);
    if (widget.held == old.held) return;

    if (widget.held) {
      _c.forward(from: 0);
    } else {
      // ─── THE RELEASE IS NOT THE PRESS PLAYED BACKWARDS ──────────────────
      //
      // Reversing would replay the dip on the way out, so the tile would
      // squash again as the menu closes, which reads as a second press nobody
      // made. The tile just settles back over the shorter half.
      _c.animateTo(0, duration: const Duration(milliseconds: 160));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Honoured here rather than at the call sites, so a tile cannot opt out of
    // the accessibility setting by forgetting to ask. Same rule verbose boot
    // follows: the end state still happens, only the travel is removed.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value;
        if (t == 0) return child!;

        final double scale;
        final double lift;

        if (reduceMotion) {
          scale = 1;
          lift = 0;
        } else if (t < 0.22) {
          // The dip. Down to 0.90 across the first fifth, and no lift yet: a
          // tile that rose while it compressed would read as two things
          // happening rather than one.
          scale = 1 - (t / 0.22) * 0.10;
          lift = 0;
        } else {
          final u = (t - 0.22) / 0.78;
          scale = 0.90 + u * 0.20; // 0.90 up through 1.0 to 1.10
          lift = -5 * u;
        }

        return Transform.translate(
          offset: Offset(0, lift),
          child: Transform.scale(
            scale: scale,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                child!,
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      // Trails the motion. Fading the ring in from zero would
                      // have it at full strength during the dip, which is the
                      // one moment the tile is SMALLER than its neighbours and
                      // an outline makes it look broken rather than picked.
                      opacity: ((t - 0.3) / 0.4).clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(widget.radius + 4),
                          border: Border.all(color: widget.ringColor, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
