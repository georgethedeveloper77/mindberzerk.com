import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'workspace_controller.dart';

/// The empty vertical-workspace surface shared by the non-GNOME shells.
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
  });

  final PageController controller;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        PageView.builder(
          controller: controller,
          scrollDirection: Axis.vertical,
          itemCount: count,
          onPageChanged: (page) =>
              ref.read(activeWorkspaceProvider.notifier).goTo(page),
          itemBuilder: (_, __) => const SizedBox.expand(),
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
