/// One panel, drawn from its spec.
///
/// ─── THE SHELL USED TO BE THE PANEL ────────────────────────────────────────
///
/// This was `_PlasmaPanel`, private to the KDE shell, and it was the only panel
/// in the app that could be edited, reordered, moved to another edge or resized.
/// Mint, MATE and Xfce all resolve through that shell, so they got it by
/// accident; GNOME and Aqua draw the same module vocabulary and got none of it.
///
/// A panel is not a shell's idea. It is a side, a thickness and a list of
/// modules, and all three arrive on `EffectiveTheme` already merged from the
/// pack and the user's own edits. So the widget takes a theme and draws what it
/// says, and a shell's job shrinks to deciding whether it has a panel at all
/// and what sits behind it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/effective_theme.dart';
import '../../engine/theme_spec.dart' show PanelModule, TopBarSide;
import '../desklets/desklet_edit.dart';
import 'panel_edit.dart';
import 'panel_editor_sheet.dart';
import 'panel_modules.dart';
import 'panel_skin.dart';

class PanelBar extends ConsumerWidget {
  const PanelBar({super.key, required this.theme, required this.insets});

  final EffectiveTheme theme;

  /// The WHOLE window inset, not just the bottom one. A panel on the left has
  /// to clear a gesture bar at the foot of its own strip and a notch at the
  /// head of it, and a panel that only knew about the bottom would put its
  /// kickoff button under the camera.
  final EdgeInsets insets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = currentPanelItems(theme);

    // ─── HEIGHT AND SIDE COME FROM THE RESOLVER ──────────────────────────
    //
    // Both can be set by the pack or by the user, so they arrive already
    // merged. Reading the PanelSpec here as well would put the same question in
    // two places, and the two would eventually disagree.
    final height = theme.panelHeight ?? defaultPanelHeight;
    final side = theme.panelSide;
    final vertical = side.isVertical;

    final editing = ref.watch(deskletEditProvider).editingPanel;
    final host = PanelHost(theme: theme, vertical: vertical, items: items);

    return GestureDetector(
      // ─── HOLD THE PANEL TO EDIT IT ──────────────────────────────────────
      //
      // Long press only, claiming no axis, which is the same arrangement
      // `DesktopHold` uses on the workspace and for the same reason: the task
      // strip scrolls along the panel, and claiming that axis here would fight
      // it for every flick.
      //
      // The callback is NULL rather than the branch returning an unwrapped
      // child, so the tree keeps its shape and no recognizer is registered when
      // there is nothing to enter. Null on a distro without `panelEdit`, and
      // null again once editing, where a second long press has nothing to do.
      behavior: HitTestBehavior.translucent,
      onLongPress: (!theme.panelEdit || editing)
          ? null
          : () async {
              HapticFeedback.mediumImpact();
              // ─── THE NOTIFIER IS CAPTURED BEFORE THE AWAIT ─────────────
              //
              // `ref.read` after an await threw: Riverpod refuses a `ref` whose
              // widget has been unmounted, and this widget IS unmounted while
              // the editor is open if the user changes the edge, because that
              // rebuilds the panel into a different slot. The exception left
              // edit mode switched ON for good, which is why the dock never
              // came back after Done: the dock is hidden while editing.
              //
              // The notifier itself outlives the widget, so reading it first
              // and calling it after is safe.
              final edit = ref.read(deskletEditProvider.notifier);
              edit.enterPanel();
              await showPanelEditor(context, theme);
              edit.exit();
            },
      child: Material(
        color: theme.palette.bar
            .withValues(alpha: panelBaseOpacity * theme.barOpacity),
        // The ONLY thing edit mode does to the panel: a rule on its inner edge
        // saying which panel the sheet is about. A phone has one, but the
        // MATE layout has two and the sheet has to be attributable to one.
        shape: editing
            ? Border(
                bottom: side == TopBarSide.top
                    ? BorderSide(color: theme.palette.accent, width: 2)
                    : BorderSide.none,
                top: side == TopBarSide.top
                    ? BorderSide.none
                    : BorderSide(color: theme.palette.accent, width: 2),
              )
            : null,
        child: Padding(
          // ─── ONLY THE EDGES THIS PANEL DOES NOT OCCUPY ─────────────────
          //
          // A bottom panel clears the gesture bar beneath it and nothing else.
          // A LEFT panel has to clear the notch above it and the gesture bar
          // below it, along the whole length of its strip.
          padding: EdgeInsets.only(
            bottom: side == TopBarSide.top ? 0 : insets.bottom,
            top: side == TopBarSide.bottom ? 0 : insets.top,
            left: side == TopBarSide.right ? insets.left : 0,
            right: side == TopBarSide.left ? insets.right : 0,
          ),
          child: SizedBox(
            // The stepper writes ONE number and it means thickness either way:
            // a vertical panel's height is its width. Two prefs would reset the
            // panel every time it changed orientation, which is the opposite of
            // what someone who just set it expects.
            height: vertical ? null : height,
            width: vertical ? height : null,
            child: Flex(
              direction: vertical ? Axis.vertical : Axis.horizontal,
              children: [
                // ─── NO EDIT AFFORDANCE ON THE PANEL ITSELF ────────────
                //
                // `PanelSlot` used to dim each module, wash it in accent, hang
                // a minus on it and carry a drag. All four are gone, and with
                // them the file: at 44dp the badges landed 30dp apart and
                // overlapped their neighbours, and the sideways drag past
                // targets that also accepted the drop was the hardest gesture
                // in the app. The sheet does all of it on 56dp rows.
                //
                // What is left is the flex, which is one line and belongs to
                // the bar anyway: the task strip is an Expanded and an Expanded
                // must be a direct child of this Flex.
                for (final item in items)
                  if (item.kind == PanelModule.tasks)
                    Expanded(child: panelModuleWidget(ref, item, host))
                  else
                    panelModuleWidget(ref, item, host),
                // The trailing gutter turns with the panel: on a vertical strip
                // a WIDTH would do nothing at all and the clock would sit
                // against the bottom edge.
                SizedBox(
                  width: vertical ? 0 : panelTrailingGutter,
                  height: vertical ? panelTrailingGutter : 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
