import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/prefs/launcher_prefs.dart';
import '../../../engine/desklet_skin.dart';
import '../../../engine/effective_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _rects; // force the late init here, not at teardown
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

  /// Measure where this tile actually landed, and tell the stage.
  ///
  /// Post-frame because `localToGlobal` needs a laid-out render box, and during
  /// build there is not one yet. The notifier's own equality guard makes a
  /// repeat at the same position a no-op, so this costs one comparison per
  /// layout pass rather than a platform call.
  void _report(int widgetId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final origin = box.localToGlobal(Offset.zero);
      _rects.report(widget.desklet.id, this, widgetId, origin & box.size);
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.desklet.config['widgetId'];
    if (id is! int) return _Fallback(theme: widget.theme);

    _report(id);

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
