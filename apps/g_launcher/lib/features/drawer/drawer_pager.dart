import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The drawer as PAGES rather than one long scroll — optionally with the cube.
///
/// **Why this is cheap.** Each page is an ordinary non-scrolling grid, and the
/// cube is a `Matrix4` applied to a page that is already built and laid out. No
/// extra rasterisation, no shader, no rebuild per frame — the transform runs on
/// the compositor. The famous CyanogenMod effect costs about as much as a fade.
///
/// **Why pages need a fixed row count.** A vertical drawer can let content
/// decide its own length; a paged one cannot, because the page boundary has to
/// fall between rows or apps get sliced in half at the fold. So rows are derived
/// from the space actually available, and the last page simply has gaps.
class DrawerPager extends StatefulWidget {
  const DrawerPager({
    super.key,
    required this.itemCount,
    required this.columns,
    required this.aspectRatio,
    required this.itemBuilder,
    this.cube = false,
  });

  final int itemCount;
  final int columns;
  final double aspectRatio;
  final Widget Function(BuildContext, int) itemBuilder;

  /// Rotate pages around the vertical axis instead of sliding them.
  final bool cube;

  @override
  State<DrawerPager> createState() => _DrawerPagerState();
}

class _DrawerPagerState extends State<DrawerPager> {
  final _controller = PageController();

  /// Live page offset, driven by the controller so the transform tracks the
  /// FINGER rather than an animation — a cube that only animates on release
  /// feels broken, because the whole appeal is dragging it round.
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (!_controller.hasClients) return;
      final p = _controller.page ?? 0;
      if (p != _page) setState(() => _page = p);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        // would divide by zero and show nothing at all.
        final rows = math.max(
          1,
          ((constraints.maxHeight - vPad * 2 + mainGap) / (tileH + mainGap))
              .floor(),
        );

        final perPage = rows * widget.columns;
        final pageCount = (widget.itemCount / perPage).ceil();

        return Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pageCount,
                itemBuilder: (context, page) {
                  final grid = Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: hPad,
                      vertical: vPad,
                    ),
                    child: GridView.builder(
                      // The PAGE scrolls, not the grid inside it.
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: widget.columns,
                        childAspectRatio: widget.aspectRatio,
                        crossAxisSpacing: crossGap,
                        mainAxisSpacing: mainGap,
                      ),
                      itemCount: math.min(
                        perPage,
                        widget.itemCount - page * perPage,
                      ),
                      itemBuilder: (context, i) =>
                          widget.itemBuilder(context, page * perPage + i),
                    ),
                  );

                  return widget.cube ? _cube(page, grid) : grid;
                },
              ),
            ),
            if (pageCount > 1)
              _Dots(count: pageCount, page: _page.round()),
          ],
        );
      },
    );
  }

  /// The cube face.
  ///
  /// Each page rotates around its own LEADING or TRAILING edge — the edge that
  /// stays touching its neighbour — which is what makes the pages read as faces
  /// of a solid rather than two cards passing each other. The page being
  /// dragged away hinges on its right edge, the one arriving hinges on its left.
  Widget _cube(int page, Widget child) {
    final delta = (page - _page).clamp(-1.0, 1.0);
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
  const _Dots({required this.count, required this.page});

  final int count;
  final int page;

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
        ],
      ),
    );
  }
}
