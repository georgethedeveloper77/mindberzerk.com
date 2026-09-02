/// Reading a `PageController`'s page without being able to crash.
///
/// ─── WHAT ACTUALLY THREW ────────────────────────────────────────────────────
///
///     Bad state: Too many elements
///       _WallpaperParallax.build.<fn> (gnome_shell.dart:804)
///
/// `PageController.page` reads `ScrollController.position`, and that getter is
/// `positions.single`. Both of its guards are `assert`s, and asserts are
/// compiled out of a release build, so what a user hits is not Flutter's
/// friendly "attached to multiple scroll views" message but the raw `StateError`
/// that `single` throws when the iterable has more than one element.
///
/// TWO POSITIONS, NOT ZERO. `Too many elements` is the more-than-one message;
/// none at all is `No element`. So at the moment it fired, two `PageView`s were
/// attached to one controller.
///
/// ─── AND WHY `hasClients` DID NOT SAVE IT ───────────────────────────────────
///
/// Every call site guarded with `hasClients`, which is `positions.isNotEmpty`.
/// That is true with two positions attached, so the guard passed and the read
/// went straight into the throw. It only ever protected against the zero case,
/// which is not the case that happened.
///
/// ─── THE ROOT CAUSE IS NOT FIXED HERE, AND THAT IS DELIBERATE ───────────────
///
/// Each shell state owns exactly one controller and mounts exactly one pager, so
/// two attachments means two of those trees were alive at once: a shell swap
/// where the outgoing subtree had not been unmounted before the incoming one
/// mounted, most likely during a theme change. I could not identify which
/// transition does it from the shells alone, and guessing at a fix for a
/// transition I cannot see is worse than the crash.
///
/// So this makes the READ safe, which is correct whatever causes the overlap,
/// and leaves [_reportOverlap] behind to say when it happens. A breadcrumb plus
/// a non-fatal is what turns "two positions, somehow" into a named transition.
library;

import 'package:flutter/widgets.dart';

import '../core/crash.dart';

extension SafePageRead on PageController {
  /// The current page, or null when it cannot be read.
  ///
  /// Null covers BOTH failure modes: no pager attached yet, and more than one
  /// attached. Callers treat them the same because the correct response is the
  /// same, which is to do nothing this frame. A pager mid-swap settles within a
  /// frame or two, and every caller of this is drawing a tint or comparing an
  /// index.
  double? get pageOrNull {
    final count = positions.length;
    if (count == 1) return page;
    if (count > 1) _reportOverlap(count);
    return null;
  }
}

/// Reported ONCE per process, not per frame.
///
/// The parallax reads this from an `AnimatedBuilder`, so an unguarded report
/// would fire at sixty hertz for as long as the overlap lasted and would arrive
/// as thousands of events from one device.
///
/// A BREADCRUMB ONLY, WHICH IS HALF A DIAGNOSTIC. `Crash.log` is the one call I
/// have seen used and can be sure of the shape of; a non-fatal would be the
/// better instrument, and it is what should go here once `core/crash.dart` has
/// been read. As it stands this line is visible only on a device that reports
/// something else afterwards, which, now that the crash is fixed, may be never.
/// That gap is deliberate and should be closed rather than forgotten.
bool _reported = false;

void _reportOverlap(int count) {
  if (_reported) return;
  _reported = true;
  Crash.log('page controller overlap: $count positions attached');
}
