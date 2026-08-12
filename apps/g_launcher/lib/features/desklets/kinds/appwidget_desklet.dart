import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/prefs/launcher_prefs.dart';
import '../../../engine/desklet_skin.dart';
import '../../../engine/effective_theme.dart';
import '../../../engine/widget_span.dart';
import '../desklet_menu.dart';
import '../widget_stage.dart';

/// A hosted third-party AppWidget on the desktop.
///
/// ─── THIS DRAWS NOTHING. THE WIDGET IS NOT IN FLUTTER AT ALL ────────────────
///
/// It used to be, through `PlatformViewLink` and `initExpensiveAndroidView`,
/// which is hybrid composition. That path is not slow here, it is BROKEN. On
/// this device's Adreno driver under Impeller, hybrid composition cannot
/// allocate its overlay buffers:
///
///     E/Gralloc4: isSupported(1, 1, 56, 1, ...) failed with 1
///     E/AHardwareBuffer: GraphicBuffer(w=4, h=4, lc=1) failed
///
/// and Flutter's layering collapses. That single failure was the black quad
/// where the widget should have been, the clock desklet drawing twice, desklets
/// bleeding through the drawer and through pushed routes, and 302MB of EGL and
/// GL mtrack. Four bugs, one cause, none of them ours.
///
/// A second problem lived in the same place: a PlatformView inside
/// `PageView.builder` is destroyed when its page scrolls out, so every swipe
/// re-inflated the provider's RemoteViews from a CACHED tree whose image URIs
/// had expired. Spotify's provider answered FileNotFoundException for every
/// cover, dozens of synchronous binder calls on the main thread. That was both
/// the missing album art and the 1662ms freeze.
///
/// So the real `AppWidgetHostView` now lives in `WidgetStage`, a plain Android
/// ViewGroup behind FlutterView, exactly where One UI keeps its widgets. This
/// widget is the HOLE it shows through: it reserves the right space in the
/// Flutter layout, reports where that space ended up, and paints nothing.
///
/// ─── WHY IT MEASURES ITSELF RATHER THAN BEING TOLD ──────────────────────────
///
/// The stage could have been handed grid coordinates and left to compute the
/// rectangle. It would then need the shell's panel height, its dock, the system
/// insets, the surface margin and the page offset, which is a second layout
/// engine that has to agree with the first one forever. `localToGlobal` on the
/// tile's own render box is the answer the layout already produced.
///
/// ─── AND WHY LEAVING THE PAGE ONLY HIDES IT ─────────────────────────────────
///
/// `deactivate` forgets the rect; it does NOT release the widget. An unreported
/// widget is set GONE by the stage and keeps its host view, so scrolling a page
/// away costs nothing and scrolling back costs nothing. Release happens once,
/// from `removeDesklet`, when the widget actually leaves the desktop. That
/// distinction is the entire fix for the re-inflation churn.
class AppWidgetDesklet extends ConsumerStatefulWidget {
  const AppWidgetDesklet({
    super.key,
    required this.theme,
    required this.desklet,
    required this.skin,
  });

  final EffectiveTheme theme;
  final Desklet desklet;
  final DeskletSkin skin;

  @override
  ConsumerState<AppWidgetDesklet> createState() => _AppWidgetDeskletState();
}

class _AppWidgetDeskletState extends ConsumerState<AppWidgetDesklet> {
  /// Captured in `initState` and used in `deactivate`.
  ///
  /// Reading `ref` during dispose throws in Riverpod 3, and `deactivate` is
  /// close enough to that boundary to be worth not testing. The notifier object
  /// itself is safe to hold.
  late final StageRects _rects = ref.read(stageRectsProvider.notifier);

  /// Is the measure loop running? Guards against a second chain being started
  /// by anything that calls [_arm] twice.
  bool _measuring = false;

  @override
  void initState() {
    super.initState();
    _rects; // force the late init here, not at teardown
    _arm();
  }

  @override
  void deactivate() {
    // FORGET, not release. See the class note: this fires when a workspace page
    // scrolls out, and destroying the host view there is the churn we removed.
    //
    // `this` is the owner token. A `PageView.builder` tears its pages down from
    // inside `performLayout`, so the forget cannot write provider state now and
    // is deferred to the end of the frame. In that gap the same desklet can be
    // rebuilt in a different element and report a fresh rect, so the token is
    // what stops this teardown deleting the new State's entry. See
    // `StageRects.forget`.
    _rects.forget(widget.desklet.id, this);
    super.deactivate();
  }

  void _openMenu() {
    final box = context.findRenderObject() as RenderBox?;
    final anchor = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    showDeskletMenu(context, ref, widget.theme, widget.desklet, anchor: anchor);
  }

  /// Start measuring, once, and keep measuring for as long as this tile lives.
  ///
  /// ─── THIS USED TO BE DRIVEN BY build(), AND THAT WAS THE BUG ────────────
  ///
  /// The old code called `_report` from `build` and its comment claimed the
  /// cost was "one comparison per layout pass". It was not. A post-frame
  /// callback registered from `build` runs once, after the frame that build
  /// belonged to, and `build` runs when this widget is REBUILT. Nothing here
  /// watches a provider and nothing above it rebuilds during ordinary desktop
  /// use, so in practice the rect was measured once and then believed forever.
  ///
  /// A tile's position on screen changes constantly WITHOUT a rebuild: the
  /// workspace pager translates its viewport, the edge pager applies a parallax,
  /// an entry animation slides the canvas in. Every one of those moves the tile
  /// by moving a paint offset above it, and none of them rebuilds this element.
  /// So the launcher reported a rect from whatever transient position the tile
  /// held on its first frame and never corrected it. Measured on device:
  ///
  ///     HostedWidgetView{... -211,257-818,1052}
  ///
  /// A 1029px widget pinned at x = -211px, hanging 80dp off the left edge,
  /// exactly where a mid-animation canvas had it at first build. Native was
  /// obeying perfectly; the number it was given was a fossil.
  ///
  /// ─── WHY A CHAINED POST-FRAME AND NOT A PERSISTENT CALLBACK ─────────────
  ///
  /// `addPersistentFrameCallback` cannot be removed, so one per desklet would
  /// accumulate for the life of the process. Re-arming a post-frame callback
  /// from inside itself gives the same per-frame cadence and stops on its own
  /// the moment this State is unmounted.
  ///
  /// It also cannot spin. `addPostFrameCallback` does not REQUEST a frame, it
  /// only runs at the end of one that was going to happen anyway. An idle
  /// desktop produces no frames, so the chain simply waits, and a tile cannot
  /// move without a frame. The loop is therefore exactly as busy as the screen
  /// is.
  ///
  /// ─── AND WHY IT IS STILL CHEAP ──────────────────────────────────────────
  ///
  /// One `localToGlobal` and one Rect comparison per hosted widget per frame.
  /// `StageRects.report` returns without writing when the rect is within half a
  /// pixel of the last one, so a settled desktop does no provider work and
  /// sends no platform message. During motion the stage is hidden and
  /// `WidgetStageSync` flattens to an empty list, so the reports go nowhere
  /// until the desktop settles, which is the behaviour that file already
  /// documents.
  void _arm() {
    if (_measuring) return;
    _measuring = true;
    _tick();
  }

  void _tick() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _measuring = false;
        return;
      }
      _measure();
      _tick();
    });
  }

  /// One measurement. Silent when there is nothing honest to report.
  void _measure() {
    final id = widget.desklet.config[WidgetConfigKeys.widgetId];
    if (id is! int) return;

    final box = context.findRenderObject() as RenderBox?;

    // `attached` as well as `hasSize`. A deactivated element still answers
    // `mounted` and still has a render object, but that object is off the tree
    // and `localToGlobal` on it walks a broken ancestor chain. The rect it
    // returns is meaningless rather than merely stale.
    if (box == null || !box.attached || !box.hasSize) return;

    _rects.report(
      widget.desklet.id,
      this,
      id,
      box.localToGlobal(Offset.zero) & box.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.desklet.config[WidgetConfigKeys.widgetId];
    if (id is! int) return _Fallback(theme: widget.theme);

    // NO _report HERE ANY MORE. The measure loop started in initState runs on
    // every frame and does not need a build to prompt it; calling it here as
    // well would only arm a second chain. See [_arm].

    // ─── THE HOLE, AND WHY IT IS NOT TRULY EMPTY ──────────────────────────
    //
    // A press that lands here at rest never reaches Flutter at all: the
    // Activity's dispatchTouchEvent hands it to the stage first, so the
    // widget's own buttons work. This detector therefore only sees presses the
    // stage declined, which is precisely edit mode, a swipe, and any moment the
    // stage is hidden. That is exactly when a hold should open the tile's menu,
    // so the two halves partition the gesture space rather than competing for
    // it.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _openMenu();
      },
      // Transparent, deliberately. Anything painted here would sit ON TOP of
      // the widget showing through from behind, and a background at even a few
      // percent reads as a haze over someone else's app.
      child: const SizedBox.expand(),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.onDark.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.onDark.withValues(alpha: 0.12)),
      ),
      child: Center(
        child: Icon(
          Icons.widgets_outlined,
          color: p.onDark.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
