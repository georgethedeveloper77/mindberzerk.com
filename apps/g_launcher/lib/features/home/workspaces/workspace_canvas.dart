import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/effective_theme.dart';
import '../../desklets/desklet_edit.dart';
import '../../desklets/desklet_surface.dart';
import 'workspace_controller.dart';

/// The vertical-workspace surface shared by the non-GNOME shells.
///
/// The wallpaper is drawn by WindowManager beneath Flutter, so the pages are
/// empty; a light parallax tint gives the swipe something to move against
/// (sliding between identical empty pages otherwise reads as a dead gesture).
/// The owning shell holds the [PageController] so a pager tap or a HOME press
/// can drive it too, not only a swipe. GnomeShell keeps its own inline copy of
/// this; the Plasma and tiling shells share this one.
class WorkspaceCanvas extends ConsumerWidget {
  const WorkspaceCanvas({
    super.key,
    required this.controller,
    required this.count,
    this.theme,
  });

  final PageController controller;
  final int count;

  /// PHASE D3. NULLABLE, and that is a migration convenience rather than an
  /// oversight: a shell that has not been passed a theme yet keeps the old
  /// empty pages instead of failing to compile. Pass it and the workspace draws
  /// its desklets.
  final EffectiveTheme? theme;

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
          itemBuilder: (_, page) => theme == null
              ? const SizedBox.expand()
              : DeskletSurfaceView(theme: theme!, page: page),
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
