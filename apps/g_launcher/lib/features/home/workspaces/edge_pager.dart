import 'package:flutter/foundation.dart';

/// Cross-page drag: hold a dragged icon near the left or right edge and the
/// desktop flips to the next workspace.
///
/// This is where the bugs live, so it is a pure state machine with tests and no
/// Flutter in sight. Every one of these rules exists because the naive version
/// —"if x > width - 48, flip page"— produces a specific, infuriating bug:
///
///  1. **Dwell, don't flip on touch.** Without a dwell delay, dragging an icon
///     to the rightmost column of page 1 flips you to page 2 before you can drop
///     it. The user cannot reach the edge column at all. 400ms is the number
///     that felt right on an S22; it is a constant, tune it.
///
///  2. **Cooldown after a flip.** Without one, holding at the edge machine-guns
///     through every workspace in about a second and you land on page 7.
///
///  3. **Re-arm requires leaving the zone.** After a flip, the pointer is still
///     in the edge zone (it didn't move — the page did). If dwell restarts
///     immediately you get bug 2 with extra steps. The zone must be exited and
///     re-entered, OR the cooldown must fully elapse.
///
///  4. **No flip past the ends.** Dwelling on the right edge of the last page
///     must do nothing, not create a page. Page creation is an explicit
///     gesture, not something you trip over while dragging.
///
/// Feed it pointer positions during a drag; it tells you when to page.

@immutable
class EdgePagerConfig {
  const EdgePagerConfig({
    this.edgeWidth = 56.0,
    this.dwell = const Duration(milliseconds: 400),
    this.cooldown = const Duration(milliseconds: 650),
  });

  /// How wide the hot zone is, in logical pixels, at each edge.
  final double edgeWidth;

  /// How long the pointer must sit in the zone before the page flips.
  final Duration dwell;

  /// How long after a flip before another can fire.
  final Duration cooldown;
}

enum EdgeZone { none, left, right }

/// What the caller should do, if anything.
enum EdgePagerAction { none, pageLeft, pageRight }

class EdgePager {
  EdgePager({
    this.config = const EdgePagerConfig(),
  });

  final EdgePagerConfig config;

  EdgeZone _zone = EdgeZone.none;
  Duration? _enteredAt;
  Duration? _lastFlipAt;

  /// True once a flip has fired and the pointer has not yet left the zone.
  bool _spent = false;

  @visibleForTesting
  EdgeZone get zone => _zone;

  /// Call on every drag update.
  ///
  /// [x] is the pointer's x in the desktop's local coordinates, [width] the
  /// desktop width, [now] a monotonic clock (a Stopwatch's elapsed, or the
  /// ticker's). Injected rather than read from DateTime so the state machine is
  /// testable without sleeping.
  ///
  /// [canPageLeft] / [canPageRight] come from the layout: false at the ends.
  EdgePagerAction update({
    required double x,
    required double width,
    required Duration now,
    required bool canPageLeft,
    required bool canPageRight,
  }) {
    final zone = _zoneFor(x, width);

    // Left the zone (or crossed to the other one) — re-arm.
    if (zone != _zone) {
      _zone = zone;
      _enteredAt = zone == EdgeZone.none ? null : now;
      _spent = false;
      return EdgePagerAction.none;
    }

    if (zone == EdgeZone.none) return EdgePagerAction.none;

    // Rule 3: this dwell already fired. Wait for the pointer to leave, or for
    // the cooldown to fully elapse — whichever comes first.
    if (_spent) {
      final since = now - (_lastFlipAt ?? Duration.zero);
      if (since < config.cooldown) return EdgePagerAction.none;
      // Cooldown elapsed and still dwelling: treat it as a fresh dwell.
      _spent = false;
      _enteredAt = now;
      return EdgePagerAction.none;
    }

    final enteredAt = _enteredAt;
    if (enteredAt == null) {
      _enteredAt = now;
      return EdgePagerAction.none;
    }

    // Rule 1: dwell.
    if (now - enteredAt < config.dwell) return EdgePagerAction.none;

    // Rule 2: cooldown.
    final lastFlip = _lastFlipAt;
    if (lastFlip != null && now - lastFlip < config.cooldown) {
      return EdgePagerAction.none;
    }

    // Rule 4: never past the ends.
    final wantsLeft = zone == EdgeZone.left;
    if (wantsLeft && !canPageLeft) return EdgePagerAction.none;
    if (!wantsLeft && !canPageRight) return EdgePagerAction.none;

    _lastFlipAt = now;
    _spent = true;
    return wantsLeft ? EdgePagerAction.pageLeft : EdgePagerAction.pageRight;
  }

  /// Drag ended or was cancelled. Always call this — a stale `_spent` leaks into
  /// the next drag and swallows its first flip.
  void reset() {
    _zone = EdgeZone.none;
    _enteredAt = null;
    _lastFlipAt = null;
    _spent = false;
  }

  EdgeZone _zoneFor(double x, double width) {
    if (x <= config.edgeWidth) return EdgeZone.left;
    if (x >= width - config.edgeWidth) return EdgeZone.right;
    return EdgeZone.none;
  }
}
