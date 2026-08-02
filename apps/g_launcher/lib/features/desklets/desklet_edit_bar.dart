import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/effective_theme.dart';
import '../home/workspaces/workspace_controller.dart';
import 'desklet_edit.dart';
import 'desklet_picker.dart';
import 'package:g_launcher/i18n/i18n.dart';

/// The bar that says the desktop is being edited. PHASE D4.
///
/// ─── WHY THERE IS A VISIBLE EXIT AT ALL ─────────────────────────────────────
///
/// Edit mode disables workspace swiping (the PageView takes
/// NeverScrollableScrollPhysics so a move drag is uncontested). A mode that
/// silently breaks the desktop's main gesture and offers no way out is how a
/// launcher gets uninstalled — so it says what it is and how to leave, and back
/// leaves it too.
///
/// Deliberately a BAR and not a floating pill: it matches the desktop
/// long-press menu that opened it, which is already a bottom bar of glyph
/// actions over a scrim.
class DeskletEditBar extends ConsumerWidget {
  const DeskletEditBar({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edit = ref.watch(deskletEditProvider);
    if (!edit.active) return const SizedBox.shrink();

    // ─── EDITING ONE WIDGET IS NOT THE SAME MODE AS ARRANGING ─────────────
    //
    // The bar offered Add unconditionally, so the whole time you were sizing a
    // clock the only labelled action on screen invited you to place a second
    // widget. While a tile is selected the subject is THAT tile, and the bar
    // should carry nothing that changes the subject.
    //
    // Nothing selected is the other posture, entered from the desktop menu's
    // Widgets action or after a tile is dropped, and there Add is exactly the
    // right offer.
    final focused = edit.selected != null;

    final p = theme.palette;
    final insets = MediaQuery.viewPaddingOf(context);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + insets.bottom),
        color: p.bar.withValues(alpha: 0.94),
        child: Row(
          children: [
            Icon(
                focused
                    ? Icons.open_with
                    : Icons.dashboard_customize_outlined,
                size: 18,
                color: p.onDark.withValues(alpha: 0.7)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                focused ? 'Editing widget' : 'Editing workspace',
                style: TextStyle(
                  fontFamily: theme.typography.display,
                  fontSize: 14,
                  color: p.onDark.withValues(alpha: 0.85),
                ),
              ),
            ),
            if (!focused) ...[
              TextButton(
                onPressed: () => showDeskletPicker(
                  context,
                  ref,
                  theme,
                  // No col/row: the Add button means "somewhere", and the
                  // packer finds the first free rectangle. Tapping a specific
                  // empty cell is the way to say WHERE.
                  page: ref.read(activeWorkspaceProvider),
                ),
                child: Text(
                  'Add',
                  style: TextStyle(
                    fontFamily: theme.typography.display,
                    color: p.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                ref.read(deskletEditProvider.notifier).exit();
              },
              child: Text(
                context.t('common.done'),
                style: TextStyle(
                  fontFamily: theme.typography.display,
                  color: p.onDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
