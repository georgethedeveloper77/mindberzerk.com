import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/prefs/launcher_prefs.dart';
import '../../../engine/desklet_skin.dart';
import '../../../engine/effective_theme.dart';
import '../../../platform/launcher_api.g.dart' as api;
import '../desklet_edit.dart';

/// A hosted third-party AppWidget on the desktop. PHASE D-widgets (host).
///
/// ─── HYBRID COMPOSITION, NOT THE VIRTUAL-DISPLAY AndroidView ────────────────
///
/// The first cut embedded the hosted view with the plain `AndroidView`, which
/// renders through a VIRTUAL DISPLAY. That path mis-composites complex widgets:
/// a Spotify or media widget came up washed-out and grey, with no album art and
/// no playlist grid, because virtual-display rendering drops the widget's
/// backgrounds, async-loaded images, and collection (grid/list) children. The
/// data was live — the song title showed — but the DISPLAY was wrong.
///
/// This uses HYBRID COMPOSITION via [PlatformViewLink] +
/// `initExpensiveAndroidView` (texture-layer hybrid composition). It renders the
/// REAL `AppWidgetHostView` into the tree, so backgrounds, images, and the
/// scrollable playlist grid all draw exactly as they do on any other launcher.
/// It costs a little more than a virtual display, which is the right trade for a
/// handful of desktop widgets that must look correct.
///
/// If a specific widget still misbehaves under TLHC (rare, usually SurfaceView
/// children), the one-line switch is `initSurfaceAndroidView`, full hybrid
/// composition, at a bit more cost.
///
/// ─── LONG-PRESS TO EDIT ─────────────────────────────────────────────────────
///
/// A PlatformView captures pointer events so the widget can be interactive, so
/// the desktop's hold-to-edit gesture is declared here as a
/// [LongPressGestureRecognizer] on the surface: a hold enters edit mode and
/// selects this tile, while taps still reach the widget.
///
/// ─── BOUNDED BOX + RELAYOUT ─────────────────────────────────────────────────
///
/// A PlatformView has no intrinsic size, so the surface's `_Tile` hands it the
/// cell rectangle directly (never a FittedBox); this guards the unbounded case
/// defensively. On every real size change it pushes the new footprint to the
/// provider via `updateWidgetSize`, so a responsive widget picks the layout that
/// fits — a media bar when short, the full grid when tall.
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
  int? _lastW;
  int? _lastH;

  void _enterEdit() {
    HapticFeedback.mediumImpact();
    final edit = ref.read(deskletEditProvider.notifier);
    edit.enter();
    edit.select(widget.desklet.id);
  }

  Set<Factory<OneSequenceGestureRecognizer>> get _recognizers =>
      <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(
          () => LongPressGestureRecognizer()..onLongPress = _enterEdit,
        ),
      };

  Widget _hostView(int id) {
    return PlatformViewLink(
      viewType: 'g_launcher/widget',
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: _recognizers,
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        return PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: 'g_launcher/widget',
          layoutDirection: TextDirection.ltr,
          creationParams: <String, Object?>{'widgetId': id},
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.desklet.config['widgetId'];
    if (id is! int) return _Fallback(theme: widget.theme);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A PlatformView cannot lay out unbounded. The surface gives us a
          // bounded cell, but guard defensively rather than assert.
          if (!constraints.maxWidth.isFinite ||
              !constraints.maxHeight.isFinite) {
            return _Fallback(theme: widget.theme);
          }

          _maybeRelayout(id, constraints);

          return SizedBox.expand(child: _hostView(id));
        },
      ),
    );
  }

  void _maybeRelayout(int id, BoxConstraints c) {
    final w = c.maxWidth.round();
    final h = c.maxHeight.round();
    if (w <= 0 || h <= 0) return;
    if (w == _lastW && h == _lastH) return;
    _lastW = w;
    _lastH = h;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      api.LauncherHostApi().updateWidgetSize(id, w, h, w, h);
    });
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
