/// KDE's virtual-desktop pager applet, in the panel: numbered squares, the
/// active one filled with the accent.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/effective_theme.dart';
import '../../home/workspaces/workspace_controller.dart';

class PanelPager extends ConsumerWidget {
  const PanelPager({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(workspaceCountProvider);
    final active = ref.watch(activeWorkspaceProvider);
    final onDark = theme.palette.onDark;
    final vertical = theme.panelSide.isVertical;

    // The squares run ALONG the panel, so they stack on a vertical one. A Row
    // here would have laid four 16dp squares across a 40dp strip and shown the
    // first two.
    return Flex(
      direction: vertical ? Axis.vertical : Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          GestureDetector(
            onTap: () => ref.read(activeWorkspaceProvider.notifier).goTo(i),
            child: Container(
              width: 16,
              height: 16,
              margin: vertical
                  ? const EdgeInsets.symmetric(vertical: 2)
                  : const EdgeInsets.symmetric(horizontal: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == active
                    ? theme.palette.accent.withValues(alpha: 0.9)
                    : Colors.transparent,
                border: Border.all(color: onDark.withValues(alpha: 0.35)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontFamily: theme.typography.mono,
                  fontSize: 9,
                  color: i == active ? onDark : onDark.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
