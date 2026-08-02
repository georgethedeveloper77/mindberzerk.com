import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/components.dart';
import '../../../engine/effective_theme.dart';
import '../../desklets/desklet_edit.dart';
import '../../desklets/desklet_picker.dart';
import '../../settings/settings_screen.dart';
import '../../settings/wallpaper_screen.dart';
import '../../themes/themes_screen.dart';
import '../workspaces/workspace_controller.dart';

/// The desktop long-press menu — GNOME's "right-click the desktop", mobile
/// shaped.
///
/// **A bottom BAR of icon-and-label actions, not a list sheet.** This is the
/// idiom every Android launcher's home-edit mode uses, and it is the right one
/// here: there are four destinations, they are peers, and a vertical list of
/// four rows makes you read four lines to find the one you wanted. A row of
/// glyphs you can hit by muscle memory is faster and takes a third of the
/// screen — which matters, because the whole point of this gesture is to change
/// how the desktop LOOKS, and you need to see it while you choose.
///
/// The wallpaper stays visible behind a light scrim for the same reason: you are
/// picking a wallpaper, so hiding it behind an opaque sheet is exactly backwards.
///
/// [context] must be the shell's context, not a sheet's: we capture its
/// Navigator up front and push screens AFTER the bar closes. Pushing onto the
/// bar's own context would tear the new route down with it. That shell context
/// also sits under the shell's ChromeScope (installed in home_screen), so the
/// bar is captured and re-provided across the route boundary below.
///
/// Takes a [WidgetRef] because Widgets opens the picker (a provider read for the
/// active workspace, and the picker itself writes placements). The shells that
/// call this are ConsumerStatefulWidgets and already hold a ref.
Future<void> showDesktopMenu(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
) async {
  // ─── THE GATE LIVES AT THE DOOR, NOT IN EACH SHELL ────────────────────────
  //
  // Every shell wires its own desktop long-press, so gating them one by one
  // means the next shell added inherits the bug by default. This menu is about
  // the DESKTOP, and while a widget is being edited the subject is that widget,
  // so the correct answer is the same for every caller and belongs here.
  //
  // The GNOME shell also checks before firing its haptic, because a buzz
  // followed by nothing reads as a dropped input rather than as a refusal. This
  // is the floor beneath that, for the shells that do not.
  if (ref.read(deskletEditProvider).active) return;

  final navigator = Navigator.of(context);
  // ChromeScope does not cross a route boundary on its own — capture it here
  // and re-provide it inside the route, the same trick ThemedSheet uses.
  final chrome = ChromeScope.of(context);

  await showGeneralDialog<void>(
    context: context,
    // Light, not the usual heavy modal black: the desktop behind this is the
    // subject, not a distraction.
    // Matched to the sheets and dialogs, which sit at 0.38. A menu and a sheet
    // appearing over the same desktop with different scrims is the
    // inconsistency nobody can name and everybody feels.
    barrierColor: Colors.black.withValues(alpha: 0.38),
    barrierDismissible: true,
    barrierLabel: 'Close',
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (routeContext, _, __) {
      void open(Widget screen) {
        Navigator.pop(routeContext);
        navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
      }

      return ChromeScope(
        data: chrome,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: _Bar(
            theme: theme,
            actions: [
              _Action(
                icon: Icons.image_outlined,
                label: 'Wallpaper',
                onTap: () => open(WallpaperScreen(theme: theme)),
              ),
              _Action(
                icon: Icons.format_paint_outlined,
                label: 'Themes',
                onTap: () => open(const ThemesScreen()),
              ),
              _Action(
                icon: Icons.widgets_outlined,
                label: 'Widgets',
                // ── STRAIGHT TO THE PICKER ──────────────────────────────
                //
                // This used to enter desklet edit mode and surface an "Editing
                // workspace" bar with an Add button on it — two steps and a bar
                // to reach a screen. Adding a widget is a single intent, so it
                // now opens the widget picker directly. Resizing an existing
                // desklet is the OTHER gesture (long-press the tile), and it no
                // longer needs a bar either.
                //
                // Pop the menu FIRST, then push on the shell's Navigator via
                // the captured shell context — the picker captures ChromeScope
                // from it, and the menu's own route is dead by the time the
                // push lands.
                onTap: () {
                  Navigator.pop(routeContext);
                  showDeskletPicker(
                    context,
                    ref,
                    theme,
                    page: ref.read(activeWorkspaceProvider),
                  );
                },
              ),
              _Action(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () => open(SettingsScreen(theme: theme)),
              ),
            ],
          ),
        ),
      );
    },
    transitionBuilder: (_, animation, __, child) {
      // Rises from the bottom edge. Short, because this is a menu, not a scene
      // change — anything slower makes a long-press feel laggy.
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// The bar itself: one row, evenly divided, sitting above the gesture inset.
class _Bar extends StatelessWidget {
  const _Bar({required this.theme, required this.actions});

  final EffectiveTheme theme;
  final List<_Action> actions;

  @override
  Widget build(BuildContext context) {
    // The chrome the route re-provided above. Read for the shared panel
    // radius; the colours still come from the glass itself.
    final d = ChromeScope.of(context);

    return SafeArea(
      top: false,
      // MATERIAL, not a plain Container. showGeneralDialog builds this outside
      // the app's Scaffold, so there is no Material ancestor in the tree — and
      // the InkWell in each action needs one or it throws on first paint. Using
      // Material for the bar itself gives the ancestor AND the surface, and
      // clipping it means the ink ripple stops at the rounded corner instead of
      // spilling past it.
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        // ─── GLASS, WHICH IS WHAT THIS FILE ALREADY ARGUED FOR ──────────
        //
        // The doc at the top says the wallpaper stays visible behind a light
        // scrim, "because you are picking a wallpaper, so hiding it behind an
        // opaque sheet is exactly backwards". It then drew the bar in
        // `c.surface`, which is opaque, and in light mode resolves to something
        // very close to white. So the bar was the one thing on screen doing the
        // opposite of what the file says it is for.
        //
        // GlassPanel is the same primitive every sheet, dialog and anchored
        // menu now uses: blurred, translucent, tinted with the distro's own
        // colour. The wallpaper reads through it, which is the entire point of
        // this gesture.
        child: GlassPanel(
          // No literal: the shared panel radius, like every other floating
          // surface. This bar carried its own 20 while the sheet carried 16,
          // which is the drift a single setting exists to end.
          borderRadius: BorderRadius.circular(d.panelRadius),
          child: Material(
            // Transparent: the glass paints the surface. Material stays because
            // showGeneralDialog builds this outside the app's Scaffold, so the
            // InkWell in each action has no Material ancestor and throws on
            // first paint without one.
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(d.panelRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [for (final a in actions) Expanded(child: a)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One glyph-over-label target. Deliberately tall enough to hit without looking.
class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: d.colors.text),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: d.text.caption.copyWith(color: d.colors.text),
            ),
          ],
        ),
      ),
    );
  }
}
