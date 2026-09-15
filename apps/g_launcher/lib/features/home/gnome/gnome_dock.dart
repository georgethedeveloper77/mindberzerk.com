import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../design/components/anchored_menu.dart';
import '../../../engine/theme_spec.dart' show ThemePalette;
import '../../dock/dock_extent.dart';
import '../../dock/dock_metrics.dart';
import '../../dock/dock_motion.dart';
import '../../drawer/drawer_drag.dart';

/// One dock slot.
///
/// Holds a widget rather than a component name so the dock has no dependency on
/// the icon engine — it renders whatever `IconCache` hands it, and the dock's
/// golden tests don't need a live LauncherApps.
@immutable
class DockEntry {
  const DockEntry({
    required this.id,
    required this.label,
    required this.icon,
    this.isRunning = false,
    this.isPinned = false,
    this.onTap,
    this.onLongPress,
  });

  final String id;
  final String label;
  final Widget icon;

  /// Draws the orange running bar. Android has no public "is this running"
  /// API — light this only for what you actually KNOW (recents via the
  /// accessibility service). Default false; a running bar on an app that isn't
  /// running is a small lie, and small lies are how people stop trusting a
  /// shell.
  final bool isRunning;

  /// Pinned by the user (vs shown because it's frequent). The long-press sheet
  /// uses it to offer "Unpin" vs "Pin".
  final bool isPinned;

  final VoidCallback? onTap;

  /// Receives the SLOT's rectangle in global coordinates, so the menu it opens
  /// can sit beside the icon rather than at the bottom of the screen.
  ///
  /// ─── WHY THIS IS NOT A VoidCallback ANY MORE ─────────────────────────────
  ///
  /// `onLongPress` carries no position, and neither does the slot's own
  /// `GestureDetector`. The dock menu used to be a bottom sheet, which needed
  /// nothing; a popover has to know what it is pointing at. Measuring here
  /// rather than passing `LongPressStartDetails` gives the panel the ICON's
  /// box instead of the point the thumb happened to land on, which is what
  /// keeps the menu aligned to the dock rather than to the finger.
  ///
  /// Null when the slot is not laid out, which `AnchoredMenu` treats the same
  /// way it treats any missing anchor: centred.
  final void Function(Rect? anchor)? onLongPress;
}

/// The dock. Mockup geometry throughout, scaled by [slotSize]:
/// translucent `rgba(32,27,33,.74)` with a 12px backdrop blur, 1px white-10%
/// border, 18px radius, 9/7 padding, 9px gaps. Running apps get an orange bar on
/// their outer edge, centred from the slot size (not a literal).
///
/// **Axis-aware.** A left dock is a Column with the running bar to the icon's
/// left; a bottom dock is a Row with the bar underneath. The grid button sits
/// at [gridButton] — start, end, or absent — separated by a hairline.
///
/// Capacity is the CALLER's problem (`DockMetrics.capacityFor` from the real
/// inset-adjusted length); this widget renders exactly what it's given and
/// never scrolls. A dock you have to scroll has lost the argument.
/// How this dock sits. The gnome-family answer to [AquaDockStyle].
///
/// ─── THE SAME THREE, AND DELIBERATELY NOT THE SAME ENUM ─────────────────────
///
/// `aqua_dock` has its own because it also owns the parabolic swell, and that
/// swell is a Mac thing this dock has never had. Sharing one enum would give
/// `GnomeDock` a `magnified` arm it cannot honour, which is a value a distro
/// could author and never see: the failure this whole run keeps removing.
///
/// So `magnified` is absent here and `dockStyle: "magnified"` on a gnome distro
/// resolves to [floating], which is what this dock has always drawn. That is a
/// real limitation and it is better than a lie.
enum GnomeDockStyle {
  /// On the edge, square across the meeting side. Xfce's bottom panel-as-dock.
  flat,

  /// Off the edge, rounded on all four corners. Ubuntu's, and the default.
  floating;

  static GnomeDockStyle parse(String raw) =>
      raw == 'flat' ? GnomeDockStyle.flat : GnomeDockStyle.floating;
}

class GnomeDock extends StatelessWidget {
  const GnomeDock({
    super.key,
    required this.entries,
    required this.side,
    required this.gridButton,
    required this.slotSize,
    required this.palette,
    required this.onActivities,
    this.style = GnomeDockStyle.floating,
    this.opacity = 1.0,
    this.activitiesIconBuilder,
    this.onReorder,
    this.onDropApp,
    this.hover = 'none',
    this.press = 'sink',
  });

  final List<DockEntry> entries;
  final DockSide side;
  final GridButtonPosition gridButton;

  /// The per-render slot size (see [DockMetrics.slotFor]): large when the dock
  /// is near-empty, shrinking as it fills. The glyph and the running-bar
  /// centring are both derived from it, so nothing here is a hardcoded literal.
  final double slotSize;

  /// The active theme's palette. The dock fill ([ThemePalette.dock]), the grid
  /// glyph colour ([ThemePalette.onDark]) and the running-bar accent
  /// ([ThemePalette.accent]) all come from here, so a non-Ubuntu dock isn't
  /// Ubuntu-coloured.
  final ThemePalette palette;

  /// How solid this dock is, from `EffectiveTheme.dockOpacity`.
  ///
  /// ─── A PARAMETER NOW, NOT A ChromeScope READ ────────────────────────────
  ///
  /// This used to read `ChromeScope.of(context).opacity`, on the grounds that
  /// threading a number down through the shell would mean a new argument for
  /// something already in scope. That was right while there was ONE opacity.
  /// The dock now has its own, the scope carries the general one, and reading
  /// the scope here would silently ignore the dock's setting. So it is passed,
  /// and the shell is the thing that knows which number this is.
  final double opacity;

  final VoidCallback onActivities;

  /// How this dock sits. Defaults to [GnomeDockStyle.floating], which is what
  /// this widget has always drawn, so a distro that authors nothing does not
  /// move. See [GnomeDockStyle].
  final GnomeDockStyle style;

  /// Drag-reorder, or null to leave the dock exactly as it was.
  ///
  /// ─── A CALLBACK, FOR THE REASON THE CLASS NOTE ALREADY GIVES ────────────
  ///
  /// This widget holds no `ref` and knows nothing about prefs, which is what
  /// lets its golden tests render without a live LauncherApps. Reading
  /// `prefsProvider` here to write the new order would throw that away for one
  /// gesture. So the dock reports what the user did and the shell, which
  /// already owns the entry list, decides what it means.
  ///
  /// Arguments are the moved slot's id, the id it was dropped on, and whether
  /// it landed on the far half of that slot. IDS, not indices: what the dock
  /// renders is a filtered, capacity-truncated view of `favourites`, so a slot
  /// position is not a position in the stored list. See
  /// [HomeLayout.reorderDockKeys].
  ///
  /// NULL DISABLES IT ENTIRELY, and that is the default. A dock in
  /// frequent-apps mode has no arrangement to change, and the golden tests pass
  /// nothing, so both keep the plain non-draggable slots.
  final void Function(String movedId, String targetId, bool after)? onReorder;

  /// How this dock responds to a finger, from `EffectiveTheme.dockHover`.
  ///
  /// ─── THIS DOCK HAS NEVER RESPONDED TO ONE ──────────────────────────────
  ///
  /// It tracked no pointer and drew no motion, which was fine while
  /// magnification was a `dockStyle` value only the Aqua dock honoured. It is
  /// not fine now that seven modes are offered in Settings: four of them would
  /// have done nothing on Ubuntu, Fedora, Pop and Zorin, which is a setting
  /// that silently does nothing.
  ///
  /// The motion itself is `DockSlotMotion`, shared with every other surface
  /// that holds slots, so this dock implements none of the seven. It reports
  /// where the finger is and wraps each slot.
  final String hover;

  /// What a slot does when it is tapped, from `EffectiveTheme.dockPress`.
  ///
  /// Shares the hover tracker: a pointer stream that already reports where the
  /// finger is knows when it went down, and a second tracker would be a second
  /// claim on the same gesture.
  final String press;

  /// An app arriving from another surface, by component key.
  ///
  /// ─── SEPARATE FROM [onReorder], BECAUSE THEY ARE DIFFERENT EVENTS ──────
  ///
  /// A reorder moves something already in the dock and is expressed as two ids
  /// and a side. An arrival has no position to move from and no neighbour to
  /// land beside; it is a pin. Folding them together would mean inventing a
  /// target id for something that has none.
  ///
  /// Null on a shell that does not accept drops, which is also how the dock
  /// refuses them: with no handler the whole-dock target never accepts, so
  /// nothing highlights and the drag returns home.
  final void Function(String componentKey)? onDropApp;

  /// Builds the Activities (app-drawer) button's icon at the dock-owned glyph
  /// size. When null, the button falls back to the 9-dot grid glyph.
  ///
  /// This is the seam for the per-theme distro logo: the CALLER passes a builder
  /// (typically `LauncherBrandIcon`) only when the active theme ships a logo, so
  /// the dock stays free of the icon engine / flutter_svg and its golden tests
  /// keep rendering the plain glyph. Passing it only for logo-bearing themes is
  /// deliberate: it keeps `LauncherBrandIcon`'s Mindhunter fallback out of the
  /// dock, where a bare square reads worse than the universally-understood grid.
  final Widget Function(double glyphSize)? activitiesIconBuilder;

  @override
  Widget build(BuildContext context) {
    final vertical = side.isVertical;

    // ── WHICH WAY THE RUNNING BAR FACES ──────────────────────────────────
    //
    // GNOME draws it on the dock's OUTER edge, against the screen. For a left
    // dock that is the icon's left; for a right dock it is the icon's right,
    // and for a bottom dock it is underneath. The old code asked `vertical` and
    // then hardcoded `left: -7`, which was the same answer twice because left
    // was the only vertical side there was. A right dock rendered with that
    // would put its bars on the INNER edge, pointing at the desktop, which is
    // the one detail that would make it read as a mirrored left dock rather
    // than as a right dock.
    final outerEdgeIsStart = side != DockSide.right;

    final glyph = DockMetrics.gridGlyphFor(slotSize);

    // Was Ubuntu.separator. Same reasoning as the border: a hairline that is
    // hardcoded to Ubuntu's chrome is invisible on some palettes and glaring on
    // others.
    final separatorColor = palette.onDark.withValues(alpha: 0.14);

    // The Activities button's icon: the theme's logo when the caller supplies a
    // builder, otherwise the 9-dot grid glyph. Both draw at the dock-owned glyph
    // size, so a logo lands the same size as the grid it replaces.
    Widget activitiesIcon() =>
        activitiesIconBuilder?.call(glyph) ??
        Icon(Icons.apps_rounded, size: glyph, color: palette.onDark);

    final children = <Widget>[];

    void addGridButton() {
      children.add(_Separator(vertical: vertical, color: separatorColor));
      children.add(_gapBox(vertical));
      children.add(_DockSlot(
        vertical: vertical,
        outerEdgeIsStart: outerEdgeIsStart,
        slotSize: slotSize,
        entry: DockEntry(
          id: '__activities__',
          label: context.t('home.activities'),
          icon: activitiesIcon(),
          onTap: onActivities,
        ),
        accent: palette.accent,
        plate: palette.onDark.withValues(alpha: 0.10),
      ));
    }

    void addGridButtonStart() {
      children.add(_DockSlot(
        vertical: vertical,
        outerEdgeIsStart: outerEdgeIsStart,
        slotSize: slotSize,
        entry: DockEntry(
          id: '__activities__',
          label: context.t('home.activities'),
          icon: activitiesIcon(),
          onTap: onActivities,
        ),
        accent: palette.accent,
        plate: palette.onDark.withValues(alpha: 0.10),
      ));
      children.add(_gapBox(vertical));
      children.add(_Separator(vertical: vertical, color: separatorColor));
    }

    if (gridButton == GridButtonPosition.start) addGridButtonStart();

    for (var i = 0; i < entries.length; i++) {
      if (children.isNotEmpty) children.add(_gapBox(vertical));
      children.add(_DockSlot(
        // Only a real app. The Activities slots above pass nothing, so they
        // stay a plain button: it is drawn by the dock rather than held by it
        // and has no component key to carry.
        draggable: true,
        vertical: vertical,
        outerEdgeIsStart: outerEdgeIsStart,
        slotSize: slotSize,
        entry: entries[i],
        accent: palette.accent,
        // ONLY the app slots. The Activities button is not in `favourites`, so
        // it has no position to move to and nothing to move around it; making
        // it draggable would let a user try to reorder a thing the dock draws
        // rather than a thing the dock holds.
        onReorder: onReorder,
        caretColor: palette.accent,
      ));
    }

    if (gridButton == GridButtonPosition.end && entries.isNotEmpty) {
      children.add(_gapBox(vertical));
      addGridButton();
    } else if (gridButton == GridButtonPosition.end && entries.isEmpty) {
      // A dock with nothing but the grid button still shows it — it's the only
      // way into Activities if gestures are off.
      addGridButtonStart();
      children.removeLast(); // no trailing separator when it's alone
      children.removeLast();
    }

    // ─── THE MOTION WRAPS THE ROW, NOT EACH SLOT'S BOX ──────────────────
    //
    // `children` is already built and is a mixed list: app slots, the grid
    // button, separators and gap boxes. Wrapping it here rather than at each
    // `_DockSlot` means the separators and gaps do not move, which is correct:
    // a hairline that lifted with its neighbour would read as part of the icon.
    //
    // Centres are computed from the slot size and the index rather than
    // measured, because every child in this Flex is either a slot or a known
    // constant. Measuring would need a key per child and a post-frame pass to
    // learn what the layout already knows.
    // The tracker runs for EITHER axis. Gating it on hover alone left press
    // dead on every dock whose distro chose Flat, which is the pairing a
    // minimal shell is most likely to want: no motion following the finger, a
    // clear acknowledgement on the tap.
    final flow = hover == 'none' && press == 'none'
        ? _flow(vertical: vertical, children: children)
        : DockFocusTracker(
            enabled: true,
            vertical: vertical,
            // Two slots either side. Wider and the whole row moves as one
            // piece, which reads as the dock sliding rather than reacting.
            spread: (slotSize + DockMetrics.gap) * 2,
            builder: (context, focus) => _flow(
              vertical: vertical,
              children: _withMotion(
                children,
                focus: focus,
                vertical: vertical,
              ),
            ),
          );

    // ONE radius, used by the clip AND the decoration below. They were two
    // literals that had to agree, and a second style is exactly the point at
    // which two literals stop agreeing.
    //
    // A flat dock is square only on the side it MEETS. Rounding the edge it is
    // sitting on would draw a gap that is not there; rounding the other three
    // is what still makes it a dock rather than a bar.
    final radius = switch (style) {
      GnomeDockStyle.floating => BorderRadius.circular(18),
      GnomeDockStyle.flat => switch (side) {
          DockSide.bottom ||
          DockSide.off =>
            const BorderRadius.vertical(top: Radius.circular(14)),
          DockSide.left => const BorderRadius.horizontal(
              right: Radius.circular(14),
            ),
          DockSide.right => const BorderRadius.horizontal(
              left: Radius.circular(14),
            ),
        },
    };

    // ─── MEASURED HERE, NOT AT THE SHELL'S Positioned ────────────────────
    //
    // Four shells mount this widget and each positions it themselves. Wrapping
    // inside the dock means all four report their extent without knowing the
    // provider exists, and a fifth cannot forget to.
    // ─── ONE TARGET FOR THE WHOLE DOCK ──────────────────────────────────
    //
    // The per-slot target below handles reordering and refuses everything
    // else, which is what lets this one take it: Flutter offers a drag to every
    // target under the pointer and the innermost that ACCEPTS wins, so a slot
    // declining an arrival hands it outward rather than swallowing it.
    //
    // Whole-dock rather than per-slot, because an app arriving from the desktop
    // has no opinion about WHERE in the dock it goes. Asking the user to hit a
    // 9dp gap between two icons to express something they were not thinking
    // about is how a drop becomes a game.
    return DragTarget<DrawerDrag>(
      onWillAcceptWithDetails: (d) =>
          onDropApp != null &&
          d.data is AppDrag &&
          d.data.from != DragOrigin.dock,
      onAcceptWithDetails: (d) {
        HapticFeedback.mediumImpact();
        onDropApp!((d.data as AppDrag).componentKey);
      },
      builder: (context, candidate, __) => DockExtentProbe(
      vertical: vertical,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          // The only thing saying a drop will land. Drawn OUTSIDE the dock's
          // own clip so it reads as a halo around the dock rather than as a
          // change to the dock's own surface.
          borderRadius: radius,
          boxShadow: candidate.isEmpty
              ? null
              : [BoxShadow(color: palette.accent.withValues(alpha: 0.55),
                  blurRadius: 14, spreadRadius: 1)],
        ),
        child: ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        // The blur earns its keep — the dock sits on an arbitrary photograph —
        // but it is also the single most expensive thing on the desktop. If the
        // launcher ever janks on a Tecno, measure this first.
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: vertical
              ? const EdgeInsets.symmetric(horizontal: 7, vertical: 9)
              : const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            // ─── THE USER'S DOCK SETTING, PASSED IN ─────────────────────
            //
            // See [opacity]: this was a ChromeScope read while there was only
            // one opacity to read. The dock has its own now, so the scope
            // would give the wrong number.
            //
            // MULTIPLIED, not replaced. `palette.dock` already carries the
            // distro's own alpha, and Ubuntu's is 0xBD on purpose; overwriting
            // it would make every distro's dock equally solid and throw away an
            // authored value to honour a preference.
            color: palette.dock.withValues(alpha: palette.dock.a * opacity),
            // Was Ubuntu.dockBorder, a fixed white-10% hairline. Derived from
            // the palette now, so a light-chrome distro gets a hairline that is
            // actually visible against it instead of Ubuntu's.
            border: Border.all(color: palette.onDark.withValues(alpha: 0.10)),
            borderRadius: radius,
          ),
          child: flow,
        ),
      ),
      ),
      ),
      ),
    );
  }

  /// The Flex the dock's children sit in, built in one place so the motion
  /// branch and the plain branch cannot drift on `mainAxisSize`.
  static Widget _flow({
    required bool vertical,
    required List<Widget> children,
  }) =>
      vertical
          ? Column(mainAxisSize: MainAxisSize.min, children: children)
          : Row(mainAxisSize: MainAxisSize.min, children: children);

  /// Wrap each real slot in the hover motion, leaving the furniture alone.
  ///
  /// ─── COUNTED BY SLOT, NOT BY CHILD INDEX ───────────────────────────────
  ///
  /// `children` is a mixed list: slots, gap boxes and a hairline separator
  /// before the grid button. Positioning by child index would put every slot
  /// after the separator roughly half a slot out, and the error would grow
  /// along the row, so the focus would drift from the finger on exactly the
  /// docks with the most apps.
  ///
  /// Separators and gaps are returned untouched. A hairline that lifted with
  /// its neighbour would read as part of the icon.
  List<Widget> _withMotion(
    List<Widget> children, {
    required DockFocus? focus,
    required bool vertical,
  }) {
    var slot = 0;
    return [
      for (final child in children)
        if (child is! _DockSlot)
          child
        else
          _wrapSlot(
            child: child,
            focus: focus,
            vertical: vertical,
            // Computed rather than measured: every slot is `slotSize` with a
            // `gap` between, which is what this dock's own Flex lays out.
            // Measuring would need a key per child and a post-frame pass to
            // learn what the layout already knows.
            centre: DockMetrics.padding +
                slotSize / 2 +
                (slot++) * (slotSize + DockMetrics.gap),
          ),
    ];
  }

  /// Hover outside, press inside.
  ///
  /// ─── THE ORDER MATTERS ─────────────────────────────────────────────────
  ///
  /// Hover moves a slot to where the finger says it should be; press moves it
  /// relative to wherever that is. Nested the other way, a magnified icon's
  /// squash would be scaled by the magnification and a lifted icon's bounce
  /// would start from the lift and overshoot the panel above it.
  ///
  /// Two widgets rather than one answering both axes, so the seven and the ten
  /// compose instead of enumerating seventy combinations.
  Widget _wrapSlot({
    required Widget child,
    required DockFocus? focus,
    required bool vertical,
    required double centre,
  }) =>
      DockSlotMotion(
        mode: hover,
        focus: focus,
        centre: centre,
        slotSize: slotSize,
        vertical: vertical,
        child: DockPressMotion(
          mode: press,
          focus: focus,
          centre: centre,
          vertical: vertical,
          child: child,
        ),
      );

  static Widget _gapBox(bool vertical) => vertical
      ? const SizedBox(height: DockMetrics.gap)
      : const SizedBox(width: DockMetrics.gap);
}

class _DockSlot extends ConsumerStatefulWidget {
  const _DockSlot({
    required this.entry,
    required this.vertical,
    required this.outerEdgeIsStart,
    required this.slotSize,
    required this.accent,
    this.plate,
    this.onReorder,
    this.caretColor,
    this.draggable = false,
  });

  /// True for a slot holding a real app.
  ///
  /// ─── DRAGGING OUT IS NOT REORDERING ────────────────────────────────────
  ///
  /// Both used to be gated on [onReorder] being non-null, which the shell
  /// passes only when something is pinned. That is right for REORDERING: a dock
  /// auto-filling from frequent apps has no arrangement to change. It is wrong
  /// for dragging an app OUT, which is how somebody takes an app off a dock
  /// they never arranged, and pinning is not a thing they should have to do
  /// first in order to unpin.
  ///
  /// Conflating the two also made the Activities button and a frequent-apps
  /// slot the same case. They are not: Activities is drawn by the dock rather
  /// than held by it, has no component key, and must never be draggable.
  final bool draggable;

  final DockEntry entry;
  final bool vertical;

  /// Whether the dock's outer edge is the leading one: true for left and
  /// bottom, false for right. See the note at [GnomeDock.build].
  final bool outerEdgeIsStart;
  final double slotSize;

  /// Running-bar colour, from the theme palette's accent.
  final Color accent;
  final Color? plate;

  /// See [GnomeDock.onReorder]. Null leaves this slot a plain tap-and-hold
  /// target, byte for byte what it was before drag existed.
  final void Function(String movedId, String targetId, bool after)? onReorder;

  final Color? caretColor;

  @override
  ConsumerState<_DockSlot> createState() => _DockSlotState();
}

class _DockSlotState extends ConsumerState<_DockSlot> {
  /// Where the POINTER went down, for the hold-versus-drag test on release.
  /// Compared against the draggable's release offset, which under
  /// `pointerDragAnchorStrategy` is the finger.
  Offset? _downAt;

  /// Which half of this slot a hovering drag is over, along the DOCK's axis.
  /// Null when nothing is hovering.
  bool? _dropAfter;

  /// The same 24dp the drawer and folder tiles use. Named here rather than
  /// shared for the reason those two give: it is the same number, not the same
  /// decision.
  static const _slop = 24.0;

  void _openMenu() {
    final open = widget.entry.onLongPress;
    if (open == null) return;
    // `context` is this slot's own, so the rect is the icon's box.
    open(AnchoredMenu.anchorOf(context));
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final vertical = widget.vertical;
    final slotSize = widget.slotSize;

    // Centre the running bar along the slot's long axis, COMPUTED from the live
    // slot size — a hardcoded offset de-centres it the moment the dock resizes.
    final barCentre = (slotSize - DockMetrics.runningBar) / 2;

    final core = SizedBox(
      width: slotSize,
      height: slotSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: widget.plate,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: entry.icon,
            ),
          ),
          if (entry.isRunning)
            // Left dock: bar to the icon's left (outer edge, per GNOME).
            // Bottom dock: bar underneath — same meaning, rotated world.
            vertical
                ? Positioned(
                    left: widget.outerEdgeIsStart ? -7 : null,
                    right: widget.outerEdgeIsStart ? null : -7,
                    top: barCentre,
                    child: _RunningBar(vertical: true, color: widget.accent),
                  )
                : Positioned(
                    bottom: -7,
                    left: barCentre,
                    child: _RunningBar(vertical: false, color: widget.accent),
                  ),
        ],
      ),
    );

    final tappable = GestureDetector(
      onTap: entry.onTap,
      behavior: HitTestBehavior.opaque,
      child: core,
    );

    // ─── NOT AN APP MEANS NOTHING CHANGES ──────────────────────────────────
    //
    // The Activities button and every golden test take this branch, and it is
    // the original widget unchanged: a plain GestureDetector whose long press
    // opens the menu. A button the dock DRAWS has nothing to drag.
    //
    // This used to test `onReorder == null`, which also caught every slot on a
    // dock with no pins. See [draggable]: that made pinning a prerequisite for
    // unpinning by drag, which is backwards.
    if (!widget.draggable) {
      return Semantics(
        button: true,
        label: entry.label,
        child: GestureDetector(
          onTap: entry.onTap,
          onLongPress: entry.onLongPress == null ? null : _openMenu,
          behavior: HitTestBehavior.opaque,
          child: core,
        ),
      );
    }

    final marker = _dropAfter;
    final caret = widget.caretColor ?? widget.accent;

    // ─── STILL GATED, BECAUSE THIS ONE REALLY IS ABOUT ARRANGEMENT ────────
    //
    // `reorderDockKeys` matches against `favourites` and returns the prefs
    // unchanged when either key is not pinned, so on a frequent-apps dock every
    // reorder is a silent no-op. Arming the caret there would draw an insertion
    // marker for a move that cannot happen.
    final canReorder = widget.onReorder != null;

    return Semantics(
      button: true,
      label: entry.label,
      child: DragTarget<DrawerDrag>(
        // ─── REORDERS ONLY, AND EVERYTHING ELSE FALLS THROUGH ───────────
        //
        // This target is INSIDE the whole-dock one that accepts arrivals. A
        // refusal here is not a dead end: Flutter offers a drag to every target
        // under the pointer and the innermost that accepts wins, so a desktop
        // icon dropped on a dock slot is declined by this and taken by the dock
        // as a pin, which is what the user meant by aiming at the dock.
        //
        // Only a dock-origin app is a reorder. A folder has no dock position to
        // move to, and an arrival has no position to move from.
        onWillAcceptWithDetails: (d) =>
            canReorder &&
            d.data is AppDrag &&
            d.data.from == DragOrigin.dock &&
            (d.data as AppDrag).componentKey != entry.id,
        onLeave: (_) {
          if (_dropAfter != null) setState(() => _dropAfter = null);
        },
        onMove: (d) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null || !box.hasSize) return;
          final local = box.globalToLocal(d.offset);

          // ─── THE SPLIT FOLLOWS THE DOCK'S AXIS ──────────────────────────
          //
          // A left dock is a Column, so "after" is further DOWN; a bottom dock
          // is a Row, so "after" is further RIGHT. Testing dx on a vertical
          // dock would ask which side of a 48dp-wide column the finger was on,
          // which is noise, and every drop would land on whichever answer the
          // noise gave.
          final after = vertical
              ? local.dy > box.size.height / 2
              : local.dx > box.size.width / 2;
          if (after != _dropAfter) setState(() => _dropAfter = after);
        },
        onAcceptWithDetails: (d) {
          final after = _dropAfter ?? false;
          setState(() => _dropAfter = null);
          HapticFeedback.selectionClick();
          widget.onReorder!((d.data as AppDrag).componentKey, entry.id, after);
        },
        builder: (context, candidate, __) => Stack(
          clipBehavior: Clip.none,
          children: [
            Listener(
              onPointerDown: (e) => _downAt = e.position,
              child: LongPressDraggable<DrawerDrag>(
                // ─── THE MOTION STANDS DOWN FOR THE DRAG ─────────────────
                //
                // A transformed icon carries its drop target with it, so a dock
                // that keeps animating while something is being dragged across
                // it is a dock whose targets slide away from the finger. See
                // `dockDragActiveProvider`.
                //
                // Cleared on BOTH ends. `onDragEnd` covers a drop and
                // `onDraggableCanceled` covers a release over nothing; missing
                // either would leave the dock frozen until the next drag.
                onDragStarted: () {
                  HapticFeedback.mediumImpact();
                  ref.read(dockDragActiveProvider.notifier).set(true);
                },
                onDragEnd: (_) =>
                    ref.read(dockDragActiveProvider.notifier).set(false),
                // ─── THE DOCK IS A SOURCE NOW ─────────────────────────────
                //
                // This sent a bare `String`, the entry id, which only this
                // dock's own targets could read. That is why a dock icon could
                // be reordered and could not be dragged anywhere: the desktop
                // was not refusing it, the desktop could not see it.
                //
                // `entry.id` IS the component key. `_dockReorder` already hands
                // it to `HomeLayout.reorderDockKeys`, which matches against
                // `favourites`, so the two were always the same string.
                data: AppDrag(entry.id, from: DragOrigin.dock),
                dragAnchorStrategy: pointerDragAnchorStrategy,

                // Split on release, the same trade the drawer and the folder
                // grid document: the draggable consumes the long press, so the
                // menu is opened by a release that nothing accepted and that
                // never really travelled. Doing it differently here would make
                // one gesture mean different things on three surfaces.
                onDraggableCanceled: (_, offset) {
                  ref.read(dockDragActiveProvider.notifier).set(false);
                  final from = _downAt;
                  if (from == null || (offset - from).distance < _slop) {
                    _openMenu();
                  }
                },
                feedback: FractionalTranslation(
                  translation: const Offset(-0.5, -0.5),
                  child: Opacity(
                    opacity: 0.9,
                    child: SizedBox(
                      width: slotSize * 1.1,
                      height: slotSize * 1.1,
                      child: FittedBox(child: entry.icon),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.25, child: core),
                child: tappable,
              ),
            ),

            // The insertion caret, drawn ACROSS the dock's axis so it reads as
            // a gap opening rather than as a border on one icon. A highlight
            // over the slot would say "into this one", and a dock has nothing
            // to drop into.
            if (marker != null)
              Positioned(
                top: vertical ? (marker ? null : -4) : 0,
                bottom: vertical ? (marker ? -4 : null) : 0,
                left: vertical ? 0 : (marker ? null : -4),
                right: vertical ? 0 : (marker ? -4 : null),
                child: Center(
                  child: Container(
                    width: vertical ? slotSize * 0.7 : 3,
                    height: vertical ? 3 : slotSize * 0.7,
                    decoration: BoxDecoration(
                      color: caret,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RunningBar extends StatelessWidget {
  const _RunningBar({required this.vertical, required this.color});

  final bool vertical;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: vertical ? 3 : DockMetrics.runningBar,
      height: vertical ? DockMetrics.runningBar : 3,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.vertical, required this.color});

  final bool vertical;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return vertical
        ? Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            color: color,
          )
        : Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 5),
            color: color,
          );
  }
}
