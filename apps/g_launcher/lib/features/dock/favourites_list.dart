/// PHASE L5: the dock, as a list of names.
///
/// ─── IT IS THE DOCK, NOT A NEW HOME SURFACE ─────────────────────────────────
///
/// The tempting design is a favourites HOME: a content type of its own, pinned
/// apps as its own thing, sitting beside the desklet grid. It is the wrong
/// shape, and the reason is that `favourites` already exists and already means
/// this. `HomeLayout` has `pinToDock`, `unpinFromDock`, `reorderDockKeys` and
/// `dockKeys` with capacity and dead-pin handling; `drawer_actions` already
/// offers Pin on every app; `EditMode.apps` already reorders. A second surface
/// reading the same list would be a second writer for all of it.
///
/// So this is a PRESENTATION. Both shells that mount a dock already build a
/// `List<DockEntry>`, and that list is the whole input here. Nothing about
/// pinning, ordering, capacity or exclusion knows this file exists.
///
/// ─── AND IT SITS WHERE THE DOCK SITS ────────────────────────────────────────
///
/// Vertically, down an edge, reserving its width through the same
/// [DockExtentProbe] the bar uses. That is not a compromise, it is the correct
/// reading of the reference: a phone launcher whose home screen is a column of
/// app names is, on a desktop, a wide left dock with labels. Ubuntu already
/// puts its dock there.
///
/// Placing it as desktop CONTENT instead would put it on top of the desklet
/// grid and the workspace pager, and the desktop would have to learn to reflow
/// around something that is not a dock. Down the edge, `dockInsets` reflows the
/// grid already, for free, because the width is measured rather than declared.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../design/components/press_pop.dart';
import '../../engine/theme_spec.dart' show ThemePalette;
import '../home/gnome/gnome_dock.dart' show DockEntry;
import 'dock_extent.dart';

/// How wide the list runs.
///
/// ─── A FRACTION OF THE SCREEN, CLAMPED, NOT A CONSTANT ──────────────────────
///
/// A fixed width is either a stripe on a tablet or most of a small phone. The
/// floor is what fits an icon plus a readable name; the ceiling stops the
/// desktop behind it from becoming a margin.
const double _kMinWidth = 168;
const double _kMaxWidth = 232;
const double _kWidthFraction = 0.52;

/// One row. Tall enough for a 48dp touch target with the label centred on the
/// icon rather than crowded against it.
const double _kRowHeight = 60;

/// Gap between the icon and its name.
const double _kIconGap = 14;

/// How many rows fit in [available] height.
///
/// Public because the shell has to pass a capacity into `HomeLayout.dockKeys`
/// BEFORE this widget exists to measure anything, and two derivations of the
/// same number is how the list ends up sized for a different set of apps than
/// it draws. `DockMetrics.capacityFor` is the bar's answer to the identical
/// problem; this is the list's.
int favouritesCapacityFor({required double available, required int max}) {
  final fits = (available / _kRowHeight).floor();
  return fits.clamp(0, max);
}

/// The width this list will take, for a shell that needs it before layout.
double favouritesWidthFor(double screenWidth) =>
    (screenWidth * _kWidthFraction).clamp(_kMinWidth, _kMaxWidth);

/// Pinned apps as a column of names.
class FavouritesList extends StatelessWidget {
  const FavouritesList({
    super.key,
    required this.entries,
    required this.palette,
    required this.opacity,
    this.onDropApp,
  });

  /// Exactly what the bar is given. See the library doc: the shell builds this
  /// once and the presentation is the only thing that differs.
  final List<DockEntry> entries;

  final ThemePalette palette;

  /// The dock's own opacity pref, applied to the plate behind the rows rather
  /// than to the rows: fading the labels would make the setting read as a
  /// legibility control instead of a surface one.
  final double opacity;

  /// Drop an app here to pin it. Always armed, matching the bar: on a list with
  /// no pins this is the gesture that creates an arrangement, so refusing it
  /// would refuse the only thing that makes reordering possible.
  final void Function(String componentKey)? onDropApp;

  @override
  Widget build(BuildContext context) {
    final width = favouritesWidthFor(MediaQuery.sizeOf(context).width);

    // ─── vertical: true, AND IT IS NOT OBVIOUS ────────────────────────────
    //
    // The probe measures the cross axis, and for a list running down an edge
    // that is the WIDTH. Reporting the height would reserve the length of the
    // run and leave the desktop with nothing.
    return DockExtentProbe(
      vertical: true,
      child: SizedBox(
        width: width,
        child: DragTarget<String>(
          onAcceptWithDetails: (d) => onDropApp?.call(d.data),
          builder: (context, candidate, rejected) {
            final hovering = candidate.isNotEmpty;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: palette.dock.withValues(
                  alpha: hovering ? opacity.clamp(0.0, 1.0) : opacity * 0.85,
                ),
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(18),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final e in entries) _FavouriteRow(entry: e, palette: palette),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FavouriteRow extends StatefulWidget {
  const _FavouriteRow({required this.entry, required this.palette});

  final DockEntry entry;
  final ThemePalette palette;

  @override
  State<_FavouriteRow> createState() => _FavouriteRowState();
}

class _FavouriteRowState extends State<_FavouriteRow> {
  bool _held = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _held = true),
      onTapCancel: () => setState(() => _held = false),
      onTap: () {
        setState(() => _held = false);
        e.onTap?.call();
      },
      onLongPress: e.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              // ─── THE ROW'S OWN BOX, NOT THE POINTER ───────────────────
              //
              // `onLongPress` takes an anchor the menu opens against, and the
              // bar hands it the slot's rect. Handing it a touch point instead
              // would open the menu under the thumb that summoned it, which is
              // the one place it cannot be read.
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              e.onLongPress!(
                box.localToGlobal(Offset.zero) & box.size,
              );
            },
      child: SizedBox(
        height: _kRowHeight,
        child: Row(
          children: [
            const SizedBox(width: 12),
            PressPop(
              held: _held,
              radius: 12,
              ringColor: widget.palette.onDark,
              child: e.icon,
            ),
            const SizedBox(width: _kIconGap),
            Expanded(
              child: Text(
                e.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: widget.palette.onDark,
                ),
              ),
            ),
            // The running bar the dock draws, as a dot at the trailing edge.
            // Same honesty rule `DockEntry.isRunning` states: lit only for what
            // is actually known, never guessed.
            if (e.isRunning)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: widget.palette.accent,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
