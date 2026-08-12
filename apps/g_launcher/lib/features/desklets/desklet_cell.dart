/// The desktop cell, as MEASURED, published for the surfaces that cannot see it.
///
/// ─── WHY THIS IS NOT AN ESTIMATE ────────────────────────────────────────────
///
/// `DeskletSurfaceView.estimateCell` used to answer this from
/// `MediaQuery.sizeOf` minus the view padding, and its own doc comment admitted
/// it was approximate. That was acceptable while the error was small. It is not
/// acceptable now, because the workspace is NOT the screen: panels are siblings
/// of it and take their own space out of it, and the dock sits inside it. On a
/// GNOME-style distro that is roughly 100dp the estimate never knew about, so
/// `cell.h` read about 55dp where the real cell measured about 47. Every widget
/// sized through the dp path was seeded close to a fifth short, and the error
/// moved when you switched distros.
///
/// The surface already measures the truth inside its own `LayoutBuilder`. It
/// publishes it here, once per real change, and the picker reads it back. The
/// value is the surface's, not a second opinion about it.
///
/// ─── WHY cols AND rows RIDE ALONG ───────────────────────────────────────────
///
/// A reader that holds a cell width from one distro and a column count from
/// another produces spans that are wrong in a way nothing downstream can
/// detect. Carrying all of it as one record makes that combination
/// unrepresentable rather than merely discouraged.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/widget_span.dart';

/// The last measured desktop cell, or null before any surface has laid out.
///
/// Null is a real state and callers must handle it. It happens on a cold start
/// where the first thing built is not a graphical shell, and on the pane
/// surface, which has no grid at all.
class DeskletCellNotifier extends Notifier<DeskletCell?> {
  @override
  DeskletCell? build() => null;

  /// `.set`, never `.update`, per the standing rule. Records compare
  /// structurally, so the equality guard here is exact rather than approximate
  /// and a re-layout at the same size does not churn every reader.
  void set(DeskletCell next) {
    if (state == next) return;
    state = next;
  }
}

final deskletCellProvider =
    NotifierProvider<DeskletCellNotifier, DeskletCell?>(
  DeskletCellNotifier.new,
);
