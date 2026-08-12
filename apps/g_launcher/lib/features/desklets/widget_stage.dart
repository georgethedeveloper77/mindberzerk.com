/// Where every hosted widget is on screen, and whether the stage should show it.
///
/// ─── THE SHAPE OF THIS, AND WHY IT IS BACKWARDS FROM THE OBVIOUS ────────────
///
/// The obvious design computes each widget's rectangle from the grid: page,
/// column, row, cell size, done. It is wrong here, and expensively so. A tile's
/// real position on screen also depends on the shell's panel, its dock, the
/// system insets, the workspace surface's own margin, and which page the
/// PageView has scrolled to. Reproducing all of that would be a second layout
/// engine that has to agree with the first, and the day it stops agreeing every
/// widget sits a few dp off with nothing to point at.
///
/// So each tile MEASURES ITSELF. `AppWidgetDesklet` is a transparent hole in the
/// Flutter tree that reserves exactly the right space and reports its own global
/// rectangle through [stageRectsProvider]. Whatever the layout did, that is
/// where the widget goes.
///
/// ─── VISIBILITY IS A PRODUCT DECISION, NOT AN OPTIMISATION ──────────────────
///
/// The stage is behind Flutter, so Flutter chrome draws over it, which is right
/// for a dock and a top bar. It is wrong for anything full-screen: the drawer
/// paints a 0.92 wash, so a widget under it would bleed through at 8% and read
/// as dirt rather than as translucency. The GNOME shell already documents that
/// exact problem for its own chrome.
///
/// Native also cannot follow Flutter's scroll without a message per frame, and
/// one frame of lag is tens of pixels of shear against the desklets beside it.
///
/// So the stage hides during a workspace swipe, during edit mode, and whenever
/// the drawer is open. Hiding for motion is not a compromise: it is what lets
/// hosted widgets be hidden and OUR desklets keep parallaxing, which is the
/// contrast worth having.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../drawer/drawer_state.dart';
import 'desklet_edit.dart';

const _channel = MethodChannel('g_launcher/widget_stage');

/// One placed widget's global rectangle, in dp, and who reported it.
///
/// [owner] is the reporting State object's identity. It exists because a forget
/// is DEFERRED (see [StageRects.forget]) and a desklet can be torn down and
/// rebuilt in a different page element within the same frame. Without it, the
/// old State's deferred forget would delete the rect the new State had just
/// reported, and the widget would vanish until something moved.
typedef StageRect = ({int widgetId, Rect rect, Object owner});

/// Every hosted widget currently laid out, by desklet id.
///
/// Keyed by DESKLET id rather than widget id so a tile that is rebuilt with a
/// new widget id (a re-bind after the provider was reinstalled) replaces its own
/// entry instead of leaving the old one stranded and visible forever.
class StageRects extends Notifier<Map<String, StageRect>> {
  @override
  Map<String, StageRect> build() => const {};

  void report(String deskletId, Object owner, int widgetId, Rect rect) {
    final existing = state[deskletId];
    if (existing != null &&
        existing.owner == owner &&
        existing.widgetId == widgetId &&
        _close(existing.rect, rect)) {
      return;
    }
    state = {
      ...state,
      deskletId: (widgetId: widgetId, rect: rect, owner: owner),
    };
  }

  /// Drop a rect, but only if [owner] is still the one that reported it.
  ///
  /// ─── WHY THIS IS DEFERRED AND WHY IT IS GUARDED ───────────────────────
  ///
  /// The caller is a State being torn down, and a State inside a
  /// `PageView.builder` is torn down DURING LAYOUT: the sliver collects garbage
  /// from inside `performLayout`, which is a build-tree lifecycle, and writing
  /// provider state there throws "Tried to modify a provider while the widget
  /// tree was building". So the write waits for the frame to end.
  ///
  /// Waiting introduces the race the owner check closes. Between the teardown
  /// and the callback, the same desklet can be rebuilt in another element and
  /// report a fresh rect. An unguarded forget would then delete a live entry.
  void forget(String deskletId, Object owner) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state[deskletId]?.owner != owner) return;
      state = {...state}..remove(deskletId);
    });
  }

  /// Sub-pixel equality, because `localToGlobal` returns doubles and a rect that
  /// differs in the eighth decimal is the same rect. Without this the map is a
  /// new object on every frame and the sync below never stops firing.
  static bool _close(Rect a, Rect b) =>
      (a.left - b.left).abs() < 0.5 &&
      (a.top - b.top).abs() < 0.5 &&
      (a.width - b.width).abs() < 0.5 &&
      (a.height - b.height).abs() < 0.5;
}

final stageRectsProvider =
    NotifierProvider<StageRects, Map<String, StageRect>>(StageRects.new);

/// Is the desktop still enough to show live widgets?
class StageMotion extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool moving) {
    if (state == moving) return;
    state = moving;
  }
}

final stageMovingProvider = NotifierProvider<StageMotion, bool>(StageMotion.new);

/// Should the stage be visible right now?
final stageVisibleProvider = Provider<bool>((ref) {
  if (ref.watch(stageMovingProvider)) return false;
  if (ref.watch(deskletEditProvider).active) return false;
  if (ref.watch(activitiesOpenProvider)) return false;
  return true;
});

/// Tell the stage the widget is gone for good.
///
/// Distinct from simply stopping reporting a rect, and the distinction is the
/// whole reason the churn is fixed: an unreported widget is HIDDEN and keeps its
/// host view, a released one is destroyed. A page scrolling out of a PageView
/// must do the first and only removal does the second.
Future<void> releaseStageWidget(int widgetId) async {
  try {
    await _channel.invokeMethod<void>('release', {'widgetId': widgetId});
  } on PlatformException {
    // The stage not existing is not an error worth surfacing: the widget is
    // being removed either way, and its host id is freed by removeWidget.
  }
}

/// Mounts once, near the root of a shell, and pushes every change to native.
///
/// A widget rather than a listener set up in an initState because it has to live
/// exactly as long as the desktop does, and because putting it in the tree is
/// what makes it obvious that removing the desktop removes the sync.
class WidgetStageSync extends ConsumerStatefulWidget {
  const WidgetStageSync({super.key});

  @override
  ConsumerState<WidgetStageSync> createState() => _WidgetStageSyncState();
}

class _WidgetStageSyncState extends ConsumerState<WidgetStageSync> {
  List<double> _lastFlat = const [];
  bool? _lastVisible;

  @override
  Widget build(BuildContext context) {
    final rects = ref.watch(stageRectsProvider);
    final visible = ref.watch(stageVisibleProvider);

    // ─── WHILE HIDDEN, POSITIONS ARE NOT NEWS ─────────────────────────────
    //
    // Rects change on every frame of a workspace swipe, because the tiles
    // genuinely move. The stage is hidden throughout, so sending them would be
    // a platform call per frame telling native where to put views nobody can
    // see. Send the hide once and go quiet until the desktop settles.
    final flat = visible ? _flatten(rects) : const <double>[];

    if (visible == _lastVisible && _same(flat, _lastFlat)) {
      return const SizedBox.shrink();
    }
    _lastVisible = visible;
    _lastFlat = flat;

    // POST-FRAME, because this runs during build and a platform call from
    // inside build can reenter.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _channel.invokeMethod<void>('sync', {
        'rects': flat,
        'visible': visible,
      }).catchError((_) {
        // Nothing to do and nothing to say. A failed sync leaves the stage
        // where it was, which is the last correct position, and the next
        // layout pass sends it again.
      });
    });

    return const SizedBox.shrink();
  }

  static List<double> _flatten(Map<String, StageRect> rects) {
    final flat = <double>[];
    for (final r in rects.values) {
      flat
        ..add(r.widgetId.toDouble())
        ..add(r.rect.left)
        ..add(r.rect.top)
        ..add(r.rect.width)
        ..add(r.rect.height);
    }
    return flat;
  }

  static bool _same(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() >= 0.5) return false;
    }
    return true;
  }
}
