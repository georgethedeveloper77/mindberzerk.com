import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/effective_theme.dart';
import '../desklets/desklet_edit.dart';
import 'workspaces/workspace_overview.dart';

/// Hold the empty desktop to zoom out to the workspaces.
///
/// ─── IT USED TO OPEN A MENU, AND THE MENU IS STILL IN THERE ─────────────────
///
/// The hold opened `showDesktopMenu`: a bottom bar of six actions over the
/// desktop. Pinch, separately, opened the overview. So the launcher had two
/// zoomed-out ideas of the desktop reachable by two gestures, one of which
/// could change how it looks and the other of which could change how many there
/// were, and neither could do the other's job.
///
/// The overview now carries that same bar along its foot, so the hold arrives
/// somewhere strictly larger than where it used to. `showDesktopMenu` is
/// untouched and still exported for any caller that wants the bar on its own.
///
/// ─── WHY THIS IS A SHARED FILE AND NOT FOUR COPIES ────────────────────────
///
/// It was private to gnome_shell, which meant every other shell had to either
/// re-derive it or go without. Three of the four did one or the other, and all
/// three were wrong in a different way:
///
///   * Plasma and tiling had NOTHING. Holding the desktop did nothing at all,
///     so the only route to wallpaper or themes was the drawer, and a user who
///     expected a launcher's desktop to be long-pressable concluded the shell
///     could not be customised. That is a shipped review, in those words.
///   * Aqua re-derived it as a bare GestureDetector with no edit-mode gate, so
///     the recognizer stayed registered while a desklet was being edited and
///     took the hold that the tile underneath was waiting for.
///
/// The gate is what is easy to forget, so this widget owns it rather than
/// accepting it. There is no `enabled` flag to pass, and no way to mount this
/// and get the ungated version.
///
/// ─── PLACE IT DIRECTLY AROUND THE WORKSPACE ───────────────────────────────
///
/// The wrapper claims NO axis: translucent, long press only. A held press with
/// no movement resolves to the desktop menu; any drag falls through to the
/// pager. There is no arena fight, because the thing that causes one is
/// claiming an axis a scrollable owns, which this does not do. A hold that
/// lands on a desklet is claimed by the desklet instead, because the tile is
/// deeper in the tree and wins on its own.
class DesktopHold extends ConsumerWidget {
  const DesktopHold({
    super.key,
    required this.theme,
    required this.child,
  });

  final EffectiveTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ─── A NULL CALLBACK, NOT AN EARLY RETURN OF THE CHILD ─────────────────
    //
    // Two things are being avoided here, and they pull in opposite directions.
    //
    // Returning `child` unwrapped while editing would change the SHAPE of the
    // tree. This wraps the workspace PageView: a shape change unmounts it, a
    // remounted PageView carries a brand new PageController, and the desktop
    // silently jumps back to workspace one every time edit mode toggles.
    //
    // Gating inside the handler is not a gate at all. A long-press recognizer
    // that returns early has still WON the arena, which is to say it has still
    // taken the pointer from the tile underneath, and that tile then never
    // receives the hold it was waiting for. Holding a widget in edit mode does
    // nothing, and holding one at rest opens this menu instead of picking the
    // widget up.
    //
    // GestureDetector builds a recognizer only for a non-null callback, so a
    // null registers nothing and competes for nothing while the tree keeps
    // exactly the shape it had.
    final editing = ref.watch(deskletEditProvider).active;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: editing
          ? null
          : () {
              // The haptic fires here rather than in each shell, and only after
              // the gate. A buzz followed by nothing reads as a dropped input
              // rather than as a refusal.
              HapticFeedback.mediumImpact();
              // `open()` refuses during edit mode on its own, which is the same
              // refusal the null callback above already makes. Both stay: the
              // gate here is what stops the recognizer competing for the
              // pointer at all, and the one in `open` is the floor under every
              // other caller.
              ref.read(workspaceOverviewProvider.notifier).open();
            },
      child: child,
    );
  }
}
