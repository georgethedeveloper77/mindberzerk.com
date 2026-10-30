/// The workspace switcher on a panel: one box with the current number.
///
/// ─── ONE BOX, NOT FOUR ─────────────────────────────────────────────────────
///
/// It drew every workspace as its own numbered square, which is what Xfce and
/// Plasma draw on a 1920px panel. On a phone panel that is four targets of a
/// few dp each, taking the room the app icons need, to say something the page
/// dots under the desktop already say. One box shows where you are and is a
/// full-thickness target: tap for the next workspace, swipe along it to step
/// either way. It wraps, so four workspaces are never more than three taps
/// apart and usually one.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../engine/effective_theme.dart';
import '../../home/workspaces/workspace_controller.dart';

/// The numbered box, edge to edge.
const double _box = 26;

/// The tap target along the panel. Across it, the target is the panel itself.
const double _target = 44;

/// How far a swipe along the box has to travel before it steps.
const double _swipe = 12;

class PanelPager extends ConsumerWidget {
  const PanelPager({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(workspaceCountProvider);
    final active = ref.watch(activeWorkspaceProvider);
    final vertical = theme.panelSide.isVertical;
    final palette = theme.palette;

    // One workspace has nowhere to go, and a box that does nothing when tapped
    // reads as broken.
    if (count < 2) return const SizedBox.shrink();

    void step(int delta) {
      HapticFeedback.selectionClick();
      ref
          .read(activeWorkspaceProvider.notifier)
          .goTo((active + delta + count) % count);
    }

    var travel = 0.0;

    return Semantics(
      button: true,
      label: context.t('home.workspaceNOfTotal', {
        'n': '${active + 1}',
        'total': '$count',
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => step(1),
        // Along the panel only. Claiming the other axis would take the
        // desktop's own page swipe away from anyone starting it on the panel.
        onHorizontalDragStart: vertical ? null : (_) => travel = 0,
        onHorizontalDragUpdate: vertical
            ? null
            : (d) {
                travel += d.delta.dx;
                if (travel.abs() < _swipe) return;
                step(travel > 0 ? 1 : -1);
                travel = 0;
              },
        onVerticalDragStart: vertical ? (_) => travel = 0 : null,
        onVerticalDragUpdate: vertical
            ? (d) {
                travel += d.delta.dy;
                if (travel.abs() < _swipe) return;
                step(travel > 0 ? 1 : -1);
                travel = 0;
              }
            : null,
        child: SizedBox(
          width: vertical ? null : _target,
          height: vertical ? _target : null,
          child: Center(
            child: Container(
              width: _box,
              height: _box,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${active + 1}',
                style: TextStyle(
                  fontFamily: theme.typography.mono,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: palette.onDark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
