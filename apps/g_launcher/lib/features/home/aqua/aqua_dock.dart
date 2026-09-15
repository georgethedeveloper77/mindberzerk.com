import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../design/components/anchored_menu.dart';
import '../../../engine/theme_spec.dart' show ThemePalette;
import '../../dock/aqua_dock_metrics.dart';
import '../../dock/dock_extent.dart';
import '../../dock/dock_motion.dart';
import '../../drawer/drawer_drag.dart';
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
/// How this dock sits. See [ThemeLayout.dockStyle].
enum AquaDockStyle {
  /// Plank: on the bottom edge, square-topped, no swell. elementary.
  flat,

  /// Deepin's fashion dock: off the edge, fully rounded, translucent, no swell.
  floating,

  /// The Mac: off the edge AND swelling under the finger. What this dock has
  /// always drawn, and therefore the engine default.
  magnified;

  /// Unknown values answer [magnified], the same drop-not-fatal contract every
  /// other parse in the engine keeps. `LayoutResolver` has already narrowed
  /// this to the three, so a stranger here means a build older than the theme.
  static AquaDockStyle parse(String raw) => switch (raw) {
        'flat' => AquaDockStyle.flat,
        'floating' => AquaDockStyle.floating,
        _ => AquaDockStyle.magnified,
      };

  /// Does the pointer change the LAYOUT, not just the paint?
  ///
  /// The two quiet styles do not merely look different, they stop listening.
  /// Without this the handlers would still run and the slots would still
  /// resize, so a flat plank would shuffle its icons under a finger that was
  /// trying to drag one, and nothing on screen would explain why.
  /// ─── MOVED TO `AquaDock._swells` ───────────────────────────────────────
  ///
  /// Kept as a getter rather than deleted because the answer is still true of
  /// the VALUE: a pack authoring `magnified` does magnify, since the resolver
  /// seeds `dockHover` from it. What changed is who asks. The dock reads the
  /// hover field, so a user who turns magnification off on a Deepin pack gets a
  /// dock that still sits the way Deepin's does.
  @Deprecated('Read EffectiveTheme.dockHover; see AquaDock.hover.')
  bool get swells => this == AquaDockStyle.magnified;
}

class AquaDock extends StatefulWidget {
  const AquaDock({
    super.key,
    required this.entries,
    required this.palette,
    required this.style,
    required this.hover,
    required this.press,
    required this.onLaunchpad,
    this.opacity = 1.0,
    this.onDropApp,
  });

  final List<DockEntry> entries;
  final ThemePalette palette;

  /// How this dock sits. See [AquaDockStyle].
  final AquaDockStyle style;

  /// How it responds to a finger, from `EffectiveTheme.dockHover`.
  ///
  /// ─── THE SWELL LEFT [style] ────────────────────────────────────────────
  ///
  /// `AquaDockStyle.magnified` meant two things at once: a corner radius and a
  /// swell. The radius is a way of SITTING and stays on the style; the swell is
  /// a RESPONSE and is one of seven now, so it moved to its own field.
  ///
  /// A pack that authored `dockStyle: "magnified"` still magnifies, because the
  /// resolver seeds this from that value. Nothing republishes.
  final String hover;

  /// What a slot does when it is tapped, from `EffectiveTheme.dockPress`.
  final String press;

  /// How solid the dock is, from `EffectiveTheme.dockOpacity`.
  ///
  /// This dock painted `palette.dock` raw and therefore ignored the surface
  /// slider entirely, while the GNOME dock beside it honoured it. Same
  /// multiply-into-the-authored-alpha rule as that one, so an Aqua palette
  /// that authors its own translucency keeps it.
  final double opacity;

  /// Launchpad's own slot, pinned at the right end past a separator — the
  /// position a Mac keeps Trash in, and the one place in the dock that is not
  /// an app.
  final VoidCallback onLaunchpad;

  /// An app arriving from another surface, by component key.
  ///
  /// ─── THE SAME CONTRACT THE GNOME DOCK USES ─────────────────────────────
  ///
  /// Null on a shell that does not accept drops, and that is also how the dock
  /// refuses one: with no handler the target never accepts, so nothing
  /// highlights and the drag returns to where it started.
  ///
  /// Reorder is deliberately NOT here yet. This dock lays its slots out with
  /// `AquaDockMetrics.layout`, which positions by index inside a Stack rather
  /// than by order in a Row, so an insertion caret has nowhere obvious to draw
  /// and the drop-side test the GNOME slot does on `dx` has no equivalent while
  /// the row is swelling. Dragging in and out works without it; ordering is its
  /// own problem.
  final void Function(String componentKey)? onDropApp;

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

  /// Does this dock's row swell under the finger?
  ///
  /// One reading, used by the layout call and by all four pointer handlers.
  /// They were five separate `style.swells` tests and a sixth would have been
  /// easy to forget, which is how a dock ends up tracking a pointer it does not
  /// animate for.
  bool get _swells => widget.hover == 'magnify';

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final onDark = palette.onDark;
    final style = widget.style;

    // The Launchpad slot rides along in the same run, so magnification treats it
    // exactly like an app. A slot that refuses to swell with its neighbours is
    // the kind of small wrongness people feel without being able to name.
    final slotCount = widget.entries.length + 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The dock never spans the full width. A Mac's floats, with desktop
        // visible either side, and a phone dock that touches both edges reads as
        // a navigation bar rather than as a dock.
        final available = (constraints.maxWidth * 0.92) - _padding * 2;

        final slots = AquaDockMetrics.layout(
          count: slotCount,
          available: available,
          // NULL for the two styles that do not swell, so every slot comes
          // back at its resting size. `layout` already takes a nullable focus
          // for the at-rest case, so this is one word rather than a second
          // layout path that would have to stay in step with this one.
          focus: _swells ? _focus : null,
        );
        if (slots.isEmpty) return const SizedBox.shrink();

        // Tallest slot decides the panel height, so the panel grows with the
        // swell instead of clipping the magnified icon's top.
        final tallest =
            slots.map((s) => s.size).reduce((a, b) => a > b ? a : b);

        // ONE radius, used by the clip AND the decoration below. They were two
        // literals and had to agree; three styles is exactly the number at
        // which two literals stop agreeing.
        final radius = switch (style) {
          // Plank meets the bottom edge, so its lower corners are not corners
          // at all. Rounding them would draw a gap that is not there.
          AquaDockStyle.flat => BorderRadius.vertical(
              top: Radius.circular(tallest * 0.22),
            ),
          // Deepin's is rounder than a Mac's: fashion mode is a pill on the
          // wallpaper, and that extra radius is most of what tells the two
          // apart at a glance.
          AquaDockStyle.floating => BorderRadius.circular(tallest * 0.42),
          AquaDockStyle.magnified => BorderRadius.circular(tallest * 0.28),
        };

        // ─── THE SWELL IS WHY THIS ONE HAS TO BE MEASURED ────────────────
        //
        // `AquaDockMetrics.reserve` is computed at the BASE slot, and a
        // magnified dock is taller than that while a finger is on it. The
        // constant is the only one of the two that can under-reserve, which
        // puts the desktop's bottom row behind a lifted icon.
        return DragTarget<DrawerDrag>(
          // An app from the desktop or the drawer. Not one of this dock's own:
          // there is no reorder here to accept it into.
          onWillAcceptWithDetails: (d) =>
              widget.onDropApp != null &&
              d.data is AppDrag &&
              d.data.from != DragOrigin.dock,
          onAcceptWithDetails: (d) {
            HapticFeedback.mediumImpact();
            widget.onDropApp!((d.data as AppDrag).componentKey);
          },
          builder: (context, candidate, __) => DockExtentProbe(
          vertical: false,
          child: Center(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            // Silent unless this dock swells. A flat plank that still tracked
            // the pointer would resize its slots invisibly and fight every
            // drag that started on it.
            onPointerDown:
                _swells ? (e) => _setFocusFrom(e.position) : null,
            onPointerMove:
                _swells ? (e) => _setFocusFrom(e.position) : null,
            onPointerUp: _swells ? (_) => _clearFocus() : null,
            onPointerCancel: _swells ? (_) => _clearFocus() : null,
            child: ClipRRect(
              borderRadius: radius,
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
                    color: palette.dock.withValues(
                      alpha: palette.dock.a * widget.opacity,
                    ),
                    border: Border.all(color: onDark.withValues(alpha: 0.14)),
                    borderRadius: radius,
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
                                ? DockSlotMotion(
                                    // ─── MAGNIFY IS ALREADY DONE HERE ────
                                    //
                                    // `AquaDockMetrics.layout` resizes the SLOT
                                    // and conserves the run's total width,
                                    // which is a better magnify than a scale
                                    // transform and is covered by its own
                                    // tests. Passing `none` for that mode
                                    // leaves it alone; the other six have no
                                    // layout equivalent and come from here.
                                    mode: _swells ? 'none' : widget.hover,
                                    focus: _focus == null
                                        ? null
                                        : DockFocus(
                                            position: _focus!,
                                            spread: AquaDockMetrics.spreadSlots *
                                                slots[i].size,
                                          ),
                                    centre: slots[i].center,
                                    slotSize: slots[i].size,
                                    vertical: false,
                                    child: DockPressMotion(
                                      mode: widget.press,
                                      focus: _focus == null
                                          ? null
                                          : DockFocus(
                                              position: _focus!,
                                              spread:
                                                  AquaDockMetrics.spreadSlots *
                                                      slots[i].size,
                                              // This dock tracks its own
                                              // pointer, and it only sets
                                              // `_focus` while one is down.
                                              pressed: true,
                                            ),
                                      centre: slots[i].center,
                                      vertical: false,
                                      child: _AquaSlotView(
                                        entry: widget.entries[i],
                                        size: slots[i].size,
                                        accent: palette.accent,
                                      ),
                                    ),
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

class _AquaSlotView extends ConsumerWidget {
  const _AquaSlotView({
    required this.entry,
    required this.size,
    required this.accent,
  });

  final DockEntry entry;
  final double size;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final core = Column(
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
        );

    // ─── A SOURCE, LIKE EVERY OTHER DOCK ────────────────────────────────
    //
    // `entry.id` is the component key, the same string `HomeLayout` matches
    // against `favourites`, so the payload needs nothing this widget does not
    // already hold.
    //
    // The feedback is the icon at its RESTING size rather than whatever the
    // magnification made it this frame. A slot lifted mid-swell would leave the
    // finger holding an icon that is a different size each time, which reads as
    // the drag being unstable rather than as the dock being alive.
    return Semantics(
      button: true,
      label: entry.label,
      child: LongPressDraggable<DrawerDrag>(
        data: AppDrag(entry.id, from: DragOrigin.dock),
        // The swell carries each icon's drop target with it, so it stands down
        // for the drag. See `dockDragActiveProvider`.
        onDragStarted: () {
          HapticFeedback.mediumImpact();
          ref.read(dockDragActiveProvider.notifier).set(true);
        },
        onDragEnd: (_) =>
            ref.read(dockDragActiveProvider.notifier).set(false),
        onDraggableCanceled: (_, __) =>
            ref.read(dockDragActiveProvider.notifier).set(false),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.9,
            child: SizedBox(width: size, height: size, child: entry.icon),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: core),
        child: GestureDetector(
          onTap: entry.onTap,
          // Same measured rect as the GNOME slot. A magnified slot is a
          // different size every frame, and the menu opens beside whatever it
          // is at the moment of the press, which is the honest answer.
          //
          // The draggable above consumes the long press, so this fires only on
          // a hold that never travelled. Same split the GNOME slot and the
          // drawer tile both document.
          onLongPress: entry.onLongPress == null
              ? null
              : () => entry.onLongPress!(AnchoredMenu.anchorOf(context)),
          behavior: HitTestBehavior.opaque,
          child: core,
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
      label: context.t('home.launchpad'),
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
