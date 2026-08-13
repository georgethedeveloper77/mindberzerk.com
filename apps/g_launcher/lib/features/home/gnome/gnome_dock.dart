import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/components/anchored_menu.dart';
import '../../../engine/theme_spec.dart' show ThemePalette;
import '../../dock/dock_metrics.dart';

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
class GnomeDock extends StatelessWidget {
  const GnomeDock({
    super.key,
    required this.entries,
    required this.side,
    required this.gridButton,
    required this.slotSize,
    required this.palette,
    required this.onActivities,
    this.opacity = 1.0,
    this.activitiesIconBuilder,
    this.onReorder,
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
          label: 'Activities',
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
          label: 'Activities',
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

    final flow = vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: children)
        : Row(mainAxisSize: MainAxisSize.min, children: children);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
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
            borderRadius: BorderRadius.circular(18),
          ),
          child: flow,
        ),
      ),
    );
  }

  static Widget _gapBox(bool vertical) => vertical
      ? const SizedBox(height: DockMetrics.gap)
      : const SizedBox(width: DockMetrics.gap);
}

class _DockSlot extends StatefulWidget {
  const _DockSlot({
    required this.entry,
    required this.vertical,
    required this.outerEdgeIsStart,
    required this.slotSize,
    required this.accent,
    this.plate,
    this.onReorder,
    this.caretColor,
  });

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
  State<_DockSlot> createState() => _DockSlotState();
}

class _DockSlotState extends State<_DockSlot> {
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

    // ─── NO onReorder MEANS NOTHING CHANGES ────────────────────────────────
    //
    // The Activities button, a dock in frequent-apps mode, and every golden
    // test take this branch, and it is the original widget unchanged: a plain
    // GestureDetector whose long press opens the menu. Introducing a draggable
    // on paths that cannot reorder would cost them the simple long-press for no
    // gain, and the goldens would start rendering a different tree.
    if (widget.onReorder == null) {
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

    return Semantics(
      button: true,
      label: entry.label,
      child: DragTarget<String>(
        onWillAcceptWithDetails: (d) => d.data != entry.id,
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
          widget.onReorder!(d.data, entry.id, after);
        },
        builder: (context, candidate, __) => Stack(
          clipBehavior: Clip.none,
          children: [
            Listener(
              onPointerDown: (e) => _downAt = e.position,
              child: LongPressDraggable<String>(
                data: entry.id,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                onDragStarted: HapticFeedback.mediumImpact,

                // Split on release, the same trade the drawer and the folder
                // grid document: the draggable consumes the long press, so the
                // menu is opened by a release that nothing accepted and that
                // never really travelled. Doing it differently here would make
                // one gesture mean different things on three surfaces.
                onDraggableCanceled: (_, offset) {
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
