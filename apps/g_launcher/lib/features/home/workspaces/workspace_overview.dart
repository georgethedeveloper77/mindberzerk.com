/// The Spatial Desktop: every workspace at once, tilted, on a pinch.
///
/// ─── WHY THIS IS AN OVERLAY AND NOT A PAGE ──────────────────────────────────
///
/// The obvious build is another entry in the pager, the way the apps page is
/// one. It is wrong for the same reason `appsPageProvider` documents in
/// reverse: the apps page is a DESTINATION you swipe to and stay on, and an
/// overview is a MODE you enter, act in, and leave. Making it a page would mean
/// the overview has an index, that index competes with the apps page for "last
/// page", and `ActiveWorkspace.goTo` would clamp against a number that changes
/// depending on whether you happen to be zoomed out.
///
/// So it sits above the shell in `home_screen`, owns back through the one
/// PopScope there, and the pager underneath never learns it exists.
///
/// ─── AND WHY THE CARDS ARE THE REAL PAGES, SCALED ───────────────────────────
///
/// The cheap version paints coloured rectangles with the palette. That is what
/// `DevicePreview` does for the settings tiles and it is right there, because a
/// settings tile is describing a distro you have not installed. This is
/// describing YOUR workspace, and the entire question the user is asking is
/// "which one has my clock on it". A rectangle cannot answer that.
///
/// So each card mounts the same `HomeGrid` and `DeskletSurfaceView` the page
/// itself does, inside a `Transform.scale`. `PageView.builder` only keeps the
/// visible cards and their immediate neighbours alive, so this is three pages
/// mounted rather than five, which is what the desktop already costs while you
/// swipe.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/effective_theme.dart';
import '../../desklets/desklet_edit.dart';
import '../../desklets/desklet_surface.dart';
import '../home_grid.dart';
import 'workspace_controller.dart';

/// Is the overview open?
///
/// A [Notifier] rather than a `StateProvider` so the two verbs are named. Six
/// places will eventually want to close this and `state = false` at each of
/// them is how `openApps` ended up existing.
final workspaceOverviewProvider =
    NotifierProvider<WorkspaceOverviewOpen, bool>(WorkspaceOverviewOpen.new);

class WorkspaceOverviewOpen extends Notifier<bool> {
  @override
  bool build() => false;

  /// ─── REFUSED DURING EDIT MODE ───────────────────────────────────────────
  ///
  /// Desklet editing is a per-page arrangement with a drag in progress and an
  /// edit bar explaining itself. Zooming out mid-drag would leave the pointer
  /// holding a desklet that is now a sixth of its size on a page that is no
  /// longer under it. `workspace_canvas` already takes the pager's physics away
  /// for exactly this reason; this is the same refusal one layer up.
  void open() {
    if (ref.read(deskletEditProvider).active) return;
    if (!state) state = true;
  }

  void close() {
    if (state) state = false;
  }

  void toggle() => state ? close() : open();
}

/// The overview itself. Mounted above the shell, drawn only when open.
class WorkspaceOverview extends ConsumerStatefulWidget {
  const WorkspaceOverview({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  ConsumerState<WorkspaceOverview> createState() => _WorkspaceOverviewState();
}

class _WorkspaceOverviewState extends ConsumerState<WorkspaceOverview> {
  PageController? _pages;

  /// How wide a card is as a fraction of the screen.
  ///
  /// Under a half would fit four cards on screen and make each one too small to
  /// read a clock on, which is the only reason to be here. This shows the
  /// current card whole with both neighbours peeking, so the set reads as a
  /// strip you can move along rather than as a grid of thumbnails.
  static const _viewport = 0.62;

  /// The flanking cards' tilt and shrink at full separation.
  static const _tilt = 0.42;
  static const _shrink = 0.18;

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = ref.watch(workspaceOverviewProvider);
    if (!open) {
      // Disposed on close rather than kept, so reopening always lands on the
      // live workspace instead of wherever the user last scrolled to and then
      // backed out of.
      _pages?.dispose();
      _pages = null;
      return const SizedBox.shrink();
    }

    final count = ref.watch(workspaceCountProvider);
    final active = ref.watch(activeWorkspaceProvider);
    final theme = widget.theme;
    final palette = theme.palette;

    _pages ??= PageController(
      initialPage: active.clamp(0, count - 1),
      viewportFraction: _viewport,
    );

    return Material(
      // theme-exempt: the wash below paints the distro's own colour; Material
      // must not put an opaque slab under it.
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(workspaceOverviewProvider.notifier).close(),
              child: ColoredBox(
                color: palette.bgBottom.withValues(alpha: 0.82),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),
                Text(
                  'Workspaces'.toUpperCase(),
                  style: TextStyle(
                    fontFamily: theme.typography.display,
                    fontSize: 12 * theme.textScale,
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w600,
                    color: palette.accent,
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: count,
                    itemBuilder: (context, page) => _Card(
                      theme: theme,
                      page: page,
                      controller: _pages!,
                      tilt: _tilt,
                      shrink: _shrink,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(activeWorkspaceProvider.notifier).goTo(page);
                        ref.read(workspaceOverviewProvider.notifier).close();
                      },
                    ),
                  ),
                ),
                _Footer(theme: theme, count: count),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One workspace, tilted by how far it sits from the middle.
class _Card extends StatelessWidget {
  const _Card({
    required this.theme,
    required this.page,
    required this.controller,
    required this.tilt,
    required this.shrink,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final int page;
  final PageController controller;
  final double tilt;
  final double shrink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // `hasClients` is false on the first frame, before the viewport has
        // been laid out. Falling back to the initial page rather than to zero
        // keeps the opening frame tilted correctly instead of flashing the
        // whole strip flat and then snapping.
        final current = controller.hasClients && controller.page != null
            ? controller.page!
            : controller.initialPage.toDouble();
        // Clamped to one page of separation. Without it the fifth card away
        // from centre is rotated most of the way past edge-on and renders as a
        // sliver, which reads as a glitch rather than as depth.
        final delta = (page - current).clamp(-1.0, 1.0);

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            // The perspective term has to come FIRST. Matrix4 multiplies on the
            // right, so setting it after the rotation applies it in the rotated
            // frame and the cards lean without ever appearing to recede.
            ..setEntry(3, 2, 0.0012)
            ..rotateY(-delta * tilt)
            // `scale` is deprecated; the four-argument form is the replacement.
            // The fourth is the W component and must stay 1: scaling it divides
            // the whole matrix through the perspective divide, which resizes
            // the card AND flattens the tilt set on the line above.
            ..scaleByDouble(
              1 - delta.abs() * shrink,
              1 - delta.abs() * shrink,
              1,
              1,
            ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 24, 8, 24),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.bgTop.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: palette.onDark.withValues(alpha: 0.16),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _Miniature(theme: theme, page: page),
            ),
          ),
        ),
      ),
    );
  }
}

/// The page's real contents, scaled to fit the card.
///
/// ─── LAID OUT AT SCREEN SIZE, THEN SHRUNK ───────────────────────────────────
///
/// Not laid out at card size. `HomeGrid` and `DeskletSurfaceView` compute cell
/// geometry from the constraints they are given, so building them inside a
/// 200dp box produces a genuinely different arrangement: a desklet spanning two
/// columns might wrap, and the card would then be an honest picture of a
/// desktop that does not exist.
///
/// `OverflowBox` hands them the full screen and `Transform.scale` shrinks the
/// result, so what you see is the page you will land on, smaller.
class _Miniature extends StatelessWidget {
  const _Miniature({required this.theme, required this.page});

  final EffectiveTheme theme;
  final int page;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / screen.width;

        return IgnorePointer(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minWidth: 0,
            maxWidth: screen.width,
            minHeight: 0,
            maxHeight: screen.height,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: screen.width,
                height: screen.height,
                child: Stack(
                  children: [
                    if (theme.desktopIcons)
                      Positioned.fill(
                        child: HomeGrid(theme: theme, page: page),
                      ),
                    Positioned.fill(
                      child: DeskletSurfaceView(theme: theme, page: page),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The label, and the two things you can do to the set.
class _Footer extends ConsumerWidget {
  const _Footer({required this.theme, required this.count});

  final EffectiveTheme theme;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = theme.palette;
    final notifier = ref.read(workspaceCountProvider.notifier);

    Widget chip(IconData icon, String? label, VoidCallback? onTap) {
      final on = onTap != null;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: on
            ? () {
                HapticFeedback.selectionClick();
                onTap();
              }
            : null,
        child: Container(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: label == null ? 12 : 16),
          decoration: BoxDecoration(
            color: palette.onDark.withValues(alpha: on ? 0.08 : 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: palette.onDark.withValues(alpha: on ? 0.16 : 0.06),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: on
                    ? palette.accent
                    : palette.onDark.withValues(alpha: 0.30),
              ),
              if (label != null) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: theme.typography.display,
                    fontSize: 13 * theme.textScale,
                    color: palette.onDark
                        .withValues(alpha: on ? 0.85 : 0.30),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Workspace ${ref.watch(activeWorkspaceProvider) + 1} of $count',
          style: TextStyle(
            fontFamily: theme.typography.display,
            fontSize: 14 * theme.textScale,
            color: palette.onDark,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // DISABLED, NOT HIDDEN, at the ends of the range.
            //
            // A control that disappears at the boundary makes the row jump
            // width and leaves the user wondering whether they imagined it.
            // Greyed says the limit exists and that they have reached it, which
            // is the same argument `appearance_section` makes for keeping the
            // light tiles visible on a dark-only distro.
            chip(
              Icons.add,
              'Add workspace',
              count < WorkspaceCount.max
                  ? () => notifier.set(count + 1)
                  : null,
            ),
            const SizedBox(width: 12),
            chip(
              Icons.remove,
              null,
              count > WorkspaceCount.min
                  ? () => notifier.set(count - 1)
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
