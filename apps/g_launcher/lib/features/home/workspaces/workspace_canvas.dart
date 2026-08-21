import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/effective_theme.dart';
import '../../desklets/desklet_edit.dart';
import '../../desklets/desklet_surface.dart';
import '../home_grid.dart';
import 'workspace_controller.dart';

/// The vertical-workspace surface shared by the non-GNOME shells.
///
/// The wallpaper is drawn by WindowManager beneath Flutter, so the pages carry
/// no background of their own; a light parallax tint gives the swipe something
/// to move against (sliding between identical empty pages otherwise reads as a
/// dead gesture). The owning shell holds the [PageController] so a pager tap or
/// a HOME press can drive it too, not only a swipe. GnomeShell keeps its own
/// inline copy of this; the Plasma and tiling shells share this one.
class WorkspaceCanvas extends ConsumerWidget {
  const WorkspaceCanvas({
    super.key,
    required this.theme,
    required this.controller,
    required this.count,
  });

  final PageController controller;
  final int count;

  /// ─── REQUIRED, AND IT USED TO BE NULLABLE ──────────────────────────────
  ///
  /// PHASE D3 made this optional so a shell that had not been updated yet kept
  /// the old empty pages instead of failing to compile. Both callers were then
  /// left un-updated, so BOTH of them built `SizedBox.expand()` on every page
  /// forever: the Plasma and tiling desktops could not show a desklet at all,
  /// on any workspace, and nothing anywhere said so. A user who added a clock
  /// watched it vanish, which is indistinguishable from the picker being
  /// broken.
  ///
  /// A migration convenience that outlives its migration is just a silent
  /// failure mode. Required means the next shell to mount this cannot repeat
  /// it: it will not compile until it decides.
  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        PageView.builder(
          controller: controller,
          scrollDirection: Axis.vertical,
          // PHASE D4 — workspace swiping is OFF while the desktop is edited.
          //
          // A move drag inside a vertical PageView is contested by the
          // PageView's own vertical drag, and the arena resolves that in the
          // scrollable's favour often enough to make dragging a desklet feel
          // broken. The Aqua dock dodged the same problem by living outside the
          // gesture layer; a desklet cannot, because it is a child of the pager
          // by construction. Taking the physics away removes the contest
          // entirely rather than fighting it, and the edit bar tells the user
          // why the swipe stopped working.
          physics: ref.watch(deskletEditProvider).active
              ? const NeverScrollableScrollPhysics()
              : null,
          itemCount: count,
          onPageChanged: (page) =>
              ref.read(activeWorkspaceProvider.notifier).goTo(page),
          // THE ONE INSERTION POINT FOR THE WHOLE PHASE. These pages were
          // `SizedBox.expand()` because the desktop was empty by design; the
          // authentic reading has not changed (no app icons here), but a real
          // desktop does carry desklets, and this is where they live. Nothing
          // else in any shell had to move.
          //
          // DeskletSurfaceView returns an empty page as `SizedBox.expand()` on
          // its own when there is nothing to draw and edit mode is off, so the
          // authentic bare desktop is still what an un-arranged workspace
          // looks like. The difference is that it is now a decision that
          // surface makes, rather than a null check up here that no desklet
          // could ever get past.
          itemBuilder: (_, page) => Stack(
            children: [
              // ─── ICONS UNDER, DESKLETS OVER ─────────────────────────────
              //
              // Which is what a real desktop does: a Plasma widget floats above
              // the Folder View, never beneath it. It also matters for touch,
              // because a desklet is draggable in edit mode and an icon grid
              // laid on top would take the press before the tile saw it.
              //
              // An empty DeskletSurfaceView returns `SizedBox.expand()` with no
              // child, which does not absorb a hit test, so the grid underneath
              // stays reachable through the gaps between tiles.
              //
              // Gated on the DISTRO, not on the shell. Plasma and Cinnamon carry
              // an icon grid; the tiling shells and Aqua mount this same canvas
              // and will not, because their themes say false. GNOME never
              // reaches here at all, since it inlines its own pager, which is
              // correct today and is the thing to revisit when Mint arrives.
              if (theme.desktopIcons)
                Positioned.fill(child: HomeGrid(theme: theme, page: page)),
              Positioned.fill(
                child: DeskletSurfaceView(theme: theme, page: page),
              ),
            ],
          ),
        ),
        Positioned.fill(
          child: _Parallax(controller: controller, pageCount: count),
        ),
      ],
    );
  }
}

class _Parallax extends StatelessWidget {
  const _Parallax({required this.controller, required this.pageCount});

  final PageController controller;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final page = controller.hasClients && controller.page != null
              ? controller.page!
              : controller.initialPage.toDouble();
          final t = page / (pageCount - 1);

          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1, -1 + t * 0.6),
                end: Alignment(1, 1 + t * 0.6),
                colors: const [Color(0x00000000), Color(0x1A000000)],
              ),
            ),
          );
        },
      ),
    );
  }
}
