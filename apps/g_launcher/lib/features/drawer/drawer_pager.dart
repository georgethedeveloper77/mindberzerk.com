import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The drawer as PAGES rather than one long scroll, optionally with the cube.
///
/// **Why this is cheap.** Each page is an ordinary non-scrolling grid, and the
/// cube is a `Matrix4` applied to a page that is already built and laid out. No
/// extra rasterisation, no shader, no rebuild per frame; the transform runs on
/// the compositor. The famous CyanogenMod effect costs about as much as a fade.
///
/// **Why pages need a fixed row count.** A vertical drawer can let content
/// decide its own length; a paged one cannot, because the page boundary has to
/// fall between rows or apps get sliced in half at the fold. So rows are derived
/// from the space actually available, and the last page simply has gaps.
///
/// **The pager WRAPS.** Swiping past the last page lands on the first and
/// swiping back off the first lands on the last, in both the slide and the
/// cube. Implemented as an unbounded PageView whose indices map onto the
/// logical pages by modulo, starting from a large anchor so the user can wrap
/// backwards from page one immediately. The alternative, jumping the
/// controller when a fling settles on an edge, animates the whole strip back
/// across every page in between, which reads as the drawer rewinding rather
/// than wrapping.
class DrawerPager extends StatefulWidget {
  const DrawerPager({
    super.key,
    required this.itemCount,
    required this.columns,
    required this.aspectRatio,
    required this.itemBuilder,
    this.cube = false,
    this.topPadding = 0,
    this.rowsOverride,
    this.onRows,
    this.dragPaging = false,
    this.initialPage = 0,
    this.onPage,
    this.onAddPage,
  });

  final int itemCount;
  final int columns;
  final double aspectRatio;
  final Widget Function(BuildContext, int) itemBuilder;

  /// Rotate pages around the vertical axis instead of sliding them.
  final bool cube;

  /// Render exactly this many rows instead of deriving them from the height.
  ///
  /// The CUSTOM drawer's slot grid is laid against a frozen row count, and a
  /// pager free to re-derive its own would reflow every stored position the
  /// first time the height differed. When the frozen count no longer fits
  /// (a rotation, a smaller phone after a restore), rows compress into the
  /// minimum spacing and the overflow clips at the page bottom rather than
  /// reflowing the arrangement; Clean up pages is the honest fix.
  final int? rowsOverride;

  /// Reports the DERIVED row count after layout, so whoever seeds a custom
  /// arrangement freezes the row count the drawer was actually rendering
  /// instead of re-deriving it from an estimate that can be off by one.
  /// Called post-frame, only when the value changes, never when
  /// [rowsOverride] is set.
  final ValueChanged<int>? onRows;

  /// Turn pages while a drag hovers the screen edge, the way every launcher's
  /// reorder mode does. Off outside Custom so an edge drop keeps today's
  /// exact cancel-or-menu behavior.
  final bool dragPaging;

  /// The LOGICAL page to open on, so a remount restores the user's place
  /// instead of snapping back to the anchor. Safe to pass a page that no longer
  /// exists: the modulo below folds it back into range.
  final int initialPage;

  /// Reports the logical page as it settles, for whoever is persisting it.
  /// Fired from the controller listener, never during build.
  final ValueChanged<int>? onPage;

  /// Grow the drawer by one page. When non-null a "+" sits after the page dots,
  /// which is the only way an empty page comes into existence now that there is
  /// no permanent trailing one. Null outside Custom, where page count is purely
  /// a function of how many apps there are and growing it would mean nothing.
  final VoidCallback? onAddPage;

  /// The row-derivation formula, exposed so a caller estimating rows before
  /// the pager has laid out (seeding Custom on a drawer that was rendering
  /// the vertical list) uses the SAME arithmetic instead of a drifting copy.
  static int rowsFor({
    required double maxHeight,
    required double tileHeight,
    required double topPadding,
  }) {
    const vPad = 12.0;
    const mainGap = 16.0;
    return math.max(
      1,
      ((maxHeight - vPad * 2 - topPadding + mainGap) / (tileHeight + mainGap))
          .floor(),
    );
  }

  /// The empty first row, in logical pixels. See the note at its call site in
  /// app_drawer.
  ///
  /// Subtracted from the height BEFORE the row count is derived, which is what
  /// makes it cost exactly one row per page rather than pushing the last row
  /// off the bottom of every page. Passing it as padding alone would leave the
  /// pager still believing it had room for the old row count.
  final double topPadding;

  @override
  State<DrawerPager> createState() => _DrawerPagerState();
}

class _DrawerPagerState extends State<DrawerPager> {
  /// The controller's page indices are UNBOUNDED and this is where they start.
  ///
  /// Logical page = (index - _wrapBase) % pageCount, so the drawer opens on
  /// logical page zero and can be dragged thousands of pages in either
  /// direction before hitting the PageView's own floor at index zero, which no
  /// human will reach by swiping. Deliberately NOT derived from pageCount:
  /// pageCount is only known at layout time, the controller is built once, and
  /// the modulo makes the anchor's divisibility irrelevant.
  static const _wrapBase = 100000;

  late final PageController _controller =
      PageController(initialPage: _wrapBase + widget.initialPage);

  /// Live page offset, driven by the controller so the transform tracks the
  /// FINGER rather than an animation. A cube that only animates on release
  /// feels broken, because the whole appeal is dragging it round.
  late double _page = (_wrapBase + widget.initialPage).toDouble();

  /// The page count from the last build, so the listener can turn a raw
  /// controller index into a logical page. Layout owns the real number; this is
  /// the only way the listener can see it.
  int _pageCount = 1;

  /// The last logical page handed to [DrawerPager.onPage], so the report fires
  /// on change rather than on every scroll frame.
  int? _reportedPage;

  /// The last derived row count handed to [DrawerPager.onRows], so the
  /// post-frame report fires on change rather than on every build.
  int? _reportedRows;

  /// Runs while a drag hovers an edge strip; each tick turns one page.
  Timer? _turnTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (!_controller.hasClients) return;
      final p = _controller.page ?? _page;
      if (p != _page) setState(() => _page = p);

      // Dart's % is non-negative for a positive divisor, so wrapping backwards
      // past the anchor still reports a real page.
      final logical = (p.round() - _wrapBase) % _pageCount;
      if (logical != _reportedPage) {
        _reportedPage = logical;
        widget.onPage?.call(logical);
      }
    });
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleTurn({required bool previous}) {
    if (_turnTimer?.isActive ?? false) return;
    // Periodic, so holding at the edge keeps turning; the first turn lands
    // after one period, which doubles as the hover-intent delay.
    _turnTimer = Timer.periodic(const Duration(milliseconds: 550), (_) {
      if (!mounted || !_controller.hasClients) return;
      final current = (_controller.page ?? _page).round();
      _controller.animateToPage(
        previous ? current - 1 : current + 1,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _cancelTurn() {
    _turnTimer?.cancel();
    _turnTimer = null;
  }

  /// An invisible edge strip that turns pages while a drawer drag hovers it.
  ///
  /// It ACCEPTS the drop rather than rejecting it, deliberately: a rejected
  /// candidate never gets onMove, and an unaccepted release at the screen
  /// edge would fall through to the tile's cancel path and read intent
  /// wrongly. Accepting and doing nothing makes an edge release a harmless
  /// no-op, and the item stays where it was.
  Widget _turnStrip({required bool leftSide}) {
    return Positioned(
      left: leftSide ? 0 : null,
      right: leftSide ? null : 0,
      top: 0,
      bottom: 0,
      width: 32,
      child: DragTarget<Object>(
        onWillAcceptWithDetails: (_) => true,
        onMove: (_) => _scheduleTurn(previous: leftSide),
        onLeave: (_) => _cancelTurn(),
        onAcceptWithDetails: (_) => _cancelTurn(),
        builder: (_, __, ___) => const SizedBox.expand(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const hPad = 16.0;
        const vPad = 12.0;
        const crossGap = 8.0;
        const mainGap = 16.0;

        final tileW = (constraints.maxWidth -
                hPad * 2 -
                crossGap * (widget.columns - 1)) /
            widget.columns;
        final tileH = tileW / widget.aspectRatio;

        // At least one row, however cramped: a pager with zero rows per page
        // would divide by zero and show nothing at all. The override wins;
        // see its doc for why the custom drawer must not re-derive.
        final derived = DrawerPager.rowsFor(
          maxHeight: constraints.maxHeight,
          tileHeight: tileH,
          topPadding: widget.topPadding,
        );
        final rows = widget.rowsOverride ?? derived;

        if (widget.rowsOverride == null &&
            widget.onRows != null &&
            derived != _reportedRows) {
          _reportedRows = derived;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onRows?.call(derived);
          });
        }

        // ── SPEND THE LEFTOVER, DO NOT DUMP IT ──────────────────────────
        //
        // The row count is FLOORED, and it has to be: rounding up would slice
        // the last row at the page boundary, which is the one thing a paged
        // grid must never do. But flooring leaves up to one full row of height
        // unused, and all of it collected at the bottom as a hole between the
        // last row and the page dots. On a 4-column phone that gap was over a
        // whole row tall and read as the page having failed to fill.
        //
        // So the slack is spread back into the row spacing instead. Capped,
        // because a page of four rows floating a long way apart looks as wrong
        // as one crowded at the top; past the cap the remainder is centred,
        // which splits it top and bottom rather than leaving it all below.
        // ── A FROZEN ROW COUNT MUST SQUEEZE, NOT SPILL ──────────────────
        //
        // `rowsOverride` is the Custom drawer's frozen grid, and it can ask for
        // more rows than this screen derives: a different phone, a rotation, or
        // simply a count frozen when the search bar was hidden and now shown.
        //
        // The old arithmetic clamped the leftover at zero and carried on
        // laying out `rows * tileH`, which overflows the page and CLIPS at the
        // bottom. The tile is icon-then-label, so what gets cut is the label,
        // and the reported symptom is exactly that: names cut off on the last
        // row.
        //
        // So an override that does not fit shrinks the tile instead. The icons
        // get slightly smaller and every label survives, which is the right
        // trade: a grid one notch tighter still reads, a row of headless
        // captions does not.
        final available =
            constraints.maxHeight - vPad * 2 - widget.topPadding;
        final wanted = rows * tileH + (rows - 1) * mainGap;

        final tileHFit = wanted > available && rows > 0
            ? ((available - (rows - 1) * mainGap) / rows)
                .clamp(1.0, double.infinity)
            : tileH;

        // The delegate takes an aspect, not a height, so the squeeze has to be
        // expressed back as one. Unchanged when nothing was squeezed.
        final aspect = tileHFit <= 0 ? widget.aspectRatio : tileW / tileHFit;

        final usedH = rows * tileHFit + (rows - 1) * mainGap;
        final slack = (available - usedH).clamp(0.0, double.infinity);

        const maxGap = 30.0;
        final spread = rows > 1
            ? (mainGap + slack / (rows - 1)).clamp(mainGap, maxGap)
            : mainGap;
        final absorbed = rows > 1 ? (spread - mainGap) * (rows - 1) : 0.0;
        final centre = (slack - absorbed) / 2;

        final perPage = rows * widget.columns;
        final pageCount = math.max(1, (widget.itemCount / perPage).ceil());

        // One page has nothing to wrap to. The unbounded builder would happily
        // repeat it side by side, which reads as the drawer having duplicated
        // itself, so a lone page simply does not scroll. The dots are already
        // hidden below for the same count.
        final canPage = pageCount > 1;

        // Recorded for the controller listener, which has no other way to know
        // how many logical pages the modulo should wrap against.
        _pageCount = pageCount;

        final pageView = PageView.builder(
                controller: _controller,
                physics:
                    canPage ? null : const NeverScrollableScrollPhysics(),
                // No itemCount: unbounded, so the wrap works in both
                // directions. Every index maps onto a logical page below.
                itemBuilder: (context, index) {
                  final page = (index - _wrapBase) % pageCount;
                  final grid = Padding(
                    padding: EdgeInsets.fromLTRB(
                      hPad,
                      vPad + widget.topPadding + centre,
                      hPad,
                      vPad + centre,
                    ),
                    child: GridView.builder(
                      // The PAGE scrolls, not the grid inside it.
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: widget.columns,
                        childAspectRatio: aspect,
                        crossAxisSpacing: crossGap,
                        mainAxisSpacing: spread,
                      ),
                      itemCount: math.min(
                        perPage,
                        widget.itemCount - page * perPage,
                      ),
                      itemBuilder: (context, i) =>
                          widget.itemBuilder(context, page * perPage + i),
                    ),
                  );

                  // The cube hinges on the RAW index, not the logical page:
                  // the transform needs each face's distance from the live
                  // scroll position, and two faces showing the same logical
                  // page (wrapping a two-page drawer) still sit at different
                  // raw indices.
                  return widget.cube ? _cube(index, grid) : grid;
                },
              );

        return Column(
          children: [
            Expanded(
              child: widget.dragPaging
                  ? Stack(
                      children: [
                        Positioned.fill(child: pageView),
                        _turnStrip(leftSide: true),
                        _turnStrip(leftSide: false),
                      ],
                    )
                  : pageView,
            ),
            // The "+" has to be reachable even on a one-page drawer, which
            // is the one case the old `> 1` test hid.
            if (pageCount > 1 || widget.onAddPage != null)
              _Dots(
                count: pageCount,
                page: (_page.round() - _wrapBase) % pageCount,
                onAdd: widget.onAddPage,
              ),
          ],
        );
      },
    );
  }

  /// The cube face.
  ///
  /// Each page rotates around its own LEADING or TRAILING edge, the edge that
  /// stays touching its neighbour, which is what makes the pages read as faces
  /// of a solid rather than two cards passing each other. The page being
  /// dragged away hinges on its right edge, the one arriving hinges on its left.
  Widget _cube(int index, Widget child) {
    final delta = (index - _page).clamp(-1.0, 1.0);
    if (delta == 0) return child;

    // 90 degrees at a full page apart: any more and the faces detach, any less
    // and it reads as a lazy skew.
    final angle = delta * math.pi / 2;

    return LayoutBuilder(
      builder: (context, c) {
        final transform = Matrix4.identity()
          // Perspective. Without this the rotation is an orthographic squash
          // and the whole illusion collapses.
          ..setEntry(3, 2, 0.0015)
          ..rotateY(angle);

        return Transform(
          alignment: delta > 0 ? Alignment.centerLeft : Alignment.centerRight,
          transform: transform,
          child: child,
        );
      },
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.page, this.onAdd});

  final int count;
  final int page;

  /// Non-null in Custom: renders the "+" that grows the drawer.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color ?? Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: i == page ? 0.85 : 0.30),
              ),
            ),
          if (onAdd != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onAdd?.call();
              },
              // The dot is 6dp and a 6dp tap target is a miss waiting to
              // happen, so the padding is the hit box rather than decoration.
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Icon(
                  Icons.add,
                  size: 12,
                  color: color.withValues(alpha: 0.45),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
