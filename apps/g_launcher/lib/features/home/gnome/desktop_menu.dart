import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/components.dart';
import '../../../engine/effective_theme.dart';
// ShellKind. `effective_theme.dart` imports theme_spec but does not re-export
// it, so the enum is not in scope through that alone.
import '../../../engine/theme_spec.dart';
import '../../desklets/desklet_edit.dart';
import '../../desklets/desklet_picker.dart';
import '../../icons/icon_theme_screen.dart';
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
              // ─── ICONS, A PEER OF THEMES ────────────────────────────
              //
              // It sat three taps inside Settings, which put "change how every
              // icon looks" below "change how the desktop looks" in a way
              // nothing about the product supports. Choosing an icon pack is
              // the same KIND of decision as choosing a theme, and there are
              // now fourteen packs behind it.
              //
              // Between Themes and Widgets: the two appearance actions sit
              // together and the two content actions sit together, so the bar
              // reads in pairs rather than as four unrelated glyphs.
              _Action(
                icon: Icons.apps_outlined,
                label: 'Icons',
                onTap: () => open(const IconThemeScreen()),
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
        // ─── GLASS FOR PANTHEON, SOLID FOR THE OTHER THIRTEEN ───────────
        //
        // This file argued for glass and it was half right. The reasoning was
        // sound: you are picking a wallpaper, so an opaque sheet hides the
        // thing you are choosing.
        //
        // It is only TRUE of elementary. Pantheon genuinely blurs what is
        // behind it. Xfce, Cinnamon, Yaru, COSMIC, KDE and DDE all draw solid
        // themed menus, so glass everywhere was the launcher's own look leaking
        // through the distro it claims to be, which is the one thing this
        // product cannot afford: a per-distro shell that wears the same chrome
        // for every distro is a skin.
        //
        // `aqua` is the shell elementary and Deepin share. Deepin is not
        // Pantheon, but DDE rounds hard and keeps its surfaces very dark, and
        // it is the closest of the thirteen to reading as translucent, so it is
        // the one place the shared shell answer is also the right one.
        //
        // The surface is the distro's own, at a low tint of its accent, so
        // Ubuntu's bar warms toward aubergine and Mint's cools toward green
        // without either becoming a coloured rectangle. Contrast was measured
        // across all fourteen palettes before the ratio was chosen: Ubuntu's
        // orange on its own warm base is the tightest and it is what caps this
        // at a low number rather than a bolder one.
        child: _Surface(
          // ShellKind, not a string. The enum is exhaustive everywhere else in
          // this codebase precisely so a new shell breaks the build rather than
          // silently defaulting, and comparing against a literal here would
          // have opted this one line out of that.
          glass: theme.spec.shell == ShellKind.aqua,
          // The distro's own colour, mixed into its own surface. See _Surface.
          accent: d.colors.accent,
          surface: d.colors.surface,
          radius: d.panelRadius,
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

/// The bar's surface: blurred for Pantheon, solid and accent-tinted otherwise.
class _Surface extends StatelessWidget {
  const _Surface({
    required this.glass,
    required this.accent,
    required this.surface,
    required this.radius,
    required this.child,
  });

  final bool glass;
  final Color accent;
  final Color surface;
  final double radius;
  final Widget child;

  /// How much of the accent goes into the surface.
  ///
  /// ─── ONE NUMBER, NOT FOURTEEN HAND-PICKED HEXES ─────────────────────────
  ///
  /// Every bar is `lerp(surface, accent, TINT)`, so 0 collapses to exactly the
  /// neutral surface this file used to draw and the value is a dial rather than
  /// two presets pretending to be one. Fourteen authored colours would drift
  /// the first time a palette changed.
  ///
  /// 0.14 because contrast was measured across all fourteen palettes and
  /// Ubuntu is the constraint: `#E95420` sits close in luminance to the warm
  /// base it mixes into, so orange-on-orange loses separation before any other
  /// pair does. It clears comfortably here and is thin by 0.20. Raising this
  /// without re-measuring Ubuntu is how the bar becomes unreadable on one
  /// distro and fine on thirteen.
  static const double tint = 0.14;

  /// The border takes twice the tint.
  ///
  /// A border that stays neutral while the surface warms reads as a seam rather
  /// than as an edge, which is worse than having no border at all.
  static const double borderTint = 0.28;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);

    if (glass) {
      // Pantheon really does blur, so the tint goes INSIDE the glass rather
      // than replacing it. Swapping in a tinted solid here would lose the one
      // thing this desktop actually does.
      return GlassPanel(borderRadius: shape, child: child);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(surface, accent, tint),
        borderRadius: shape,
        border: Border.all(
          color: Color.lerp(surface, accent, borderTint) ?? surface,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            // Solid, so it needs its own separation from the wallpaper. The
            // glass path gets that from the blur.
            color: const Color(0xFF000000).withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: shape, child: child),
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
