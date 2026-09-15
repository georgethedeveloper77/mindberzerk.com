/// The two modules that launch something: the menu button and a pinned app.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/shell_apps.dart';
import '../../../design/theme_mark.dart';
import '../../../engine/effective_theme.dart';
import '../../drawer/app_icon.dart';
import '../../drawer/drawer_actions.dart';

/// The kickoff button: Plasma's start menu, and Mint's Menu.
///
/// ─── THE DISTRO'S OWN MARK, WHEN IT SHIPS ONE ──────────────────────────────
///
/// This drew `Icons.grid_view_rounded` on an accent square for every distro,
/// which is a generic glyph on the one control that is most recognisable on a
/// real desktop. Mint's menu button is the leaf. Plasma's is the gear. Nobody
/// who has used either would reach for a grid.
///
/// Packs have carried `logo_light.webp` and `logo_dark.webp` since they
/// shipped, and `ThemeSpec.logoAsset` already resolves the right variant
/// through the pack source, so this needed no new field and no republish: the
/// asset was there and the module was not asking for it.
///
/// ─── THE ACCENT SQUARE IS FOR THE FALLBACK ONLY ────────────────────────────
///
/// A real desktop draws the mark bare on the panel. The tinted square exists to
/// make a SYSTEM GLYPH read as a button, and a brand mark does not need it: on
/// Mint it would put a green leaf inside a green box. So a distro with a logo
/// gets the mark, and a distro without gets the square it always had.
class PanelKickoffButton extends StatelessWidget {
  const PanelKickoffButton({
    super.key,
    required this.theme,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = theme.palette.accent;
    // The panel is chrome and dark on every pack here, so the dark-surface
    // variant is the right one. `onDarkSurface` describes the SURFACE, not the
    // ink of the artwork: see `ThemeSpec.logoAsset`.
    final logo = theme.spec.logoAsset(onDarkSurface: true);

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: logo == null
              ? Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.grid_view_rounded,
                    size: 20,
                    color: accent,
                  ),
                )
              : ThemeMark(
                  asset: logo,
                  size: 24,
                  // AS AUTHORED. The dark-surface variant is already artwork
                  // for chrome like this, and tinting it would turn Mint's leaf
                  // into a flat green shape and Garuda's bird into a pink one.
                  // The fallback below is still tinted, because a system glyph
                  // is nobody's mark.
                  tint: null,
                  fallback: Icon(
                    Icons.grid_view_rounded,
                    size: 20,
                    color: accent,
                  ),
                ),
        ),
      ),
    );
  }
}

/// One app on the panel, launched by tapping it.
///
/// The panel's apps are its own. The dock is a different surface with its own
/// capacity rules, and a panel holding Files beside a dock that does not is the
/// arrangement `PanelModule.app` exists to allow.
class PanelAppButton extends ConsumerWidget {
  const PanelAppButton({
    super.key,
    required this.theme,
    required this.package,
  });

  final EffectiveTheme theme;
  final String package;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `shellAppsProvider`, the same list the dock and the drawer read, so a
    // hidden app is hidden here too and the panel cannot become a way around
    // the drawer's own filtering.
    final apps = ref.watch(shellAppsProvider(theme));
    // ─── AN UNINSTALLED APP DRAWS NOTHING ──────────────────────────────────
    //
    // Not a placeholder and not a question mark. The package can vanish at any
    // time and the panel is not the place to report it; the entry is dropped on
    // the next write, which is the same not-fatal contract `PanelModule.parse`
    // keeps for a module this build has never heard of.
    final entry = apps.where((a) => a.packageName == package).firstOrNull;
    if (entry == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => launchDrawerApp(ref, entry),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AppIcon(entry: entry, size: 18),
      ),
    );
  }
}
