/// COSMIC's panel vocabulary: two words and a toggle.
///
/// ─── TEXT, NOT GLYPHS ──────────────────────────────────────────────────────
///
/// COSMIC opens its top panel with "Workspaces" and "Applications" written
/// out, where GNOME has one "Activities" and Plasma has a logo. Those words
/// are the most recognisable thing about the panel, so they are drawn as
/// words, translated, in the distro's bar font. Generic modules, not Pop's:
/// any distro can author them.
///
/// ─── AND THE TILING TOGGLE ─────────────────────────────────────────────────
///
/// COSMIC's panel carries a switch that tiles every window. A home screen has
/// no windows, but it has an arrangement: tiled (apps fill the screen edge to
/// edge) or a grid of icons. The toggle flips that, per distro, through the
/// `homeLayout` pref the Desktop settings row writes too.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../data/prefs/prefs_repository.dart';
import '../../../engine/effective_theme.dart';
import '../../../engine/layout_resolver.dart';
import '../../home/workspaces/workspace_controller.dart';
import '../../home/workspaces/workspace_overview.dart';

/// One word on the panel that does one thing.
class _PanelWord extends StatelessWidget {
  const _PanelWord({
    required this.theme,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final EffectiveTheme theme;
  final String label;
  final VoidCallback onTap;

  /// Washed while the thing it opens is open, as COSMIC marks its buttons.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        // The full panel thickness is the target; the wash is drawn inside it.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Center(
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? palette.onDark.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: theme.typography.display,
                  fontSize: 13 * theme.textScale,
                  fontWeight: FontWeight.w500,
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

/// "Workspaces": opens the overview.
class PanelWorkspacesButton extends ConsumerWidget {
  const PanelWorkspacesButton({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(workspaceOverviewProvider);
    return _PanelWord(
      theme: theme,
      label: context.t('shell.workspacesButton'),
      active: open,
      onTap: () => ref.read(workspaceOverviewProvider.notifier).toggle(),
    );
  }
}

/// "Applications": opens the app list, however this distro shows one.
class PanelAppsButton extends ConsumerWidget {
  const PanelAppsButton({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PanelWord(
      theme: theme,
      label: context.t('shell.appsButton'),
      onTap: () => openApps(ref),
    );
  }
}

/// The tiling toggle: tiled home screen or icon grid, per distro.
class PanelTilingToggle extends ConsumerWidget {
  const PanelTilingToggle({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = theme.palette;
    final tiled = theme.homeLayout == 'tiled';

    return Semantics(
      toggled: tiled,
      label: context.t('settings.tiledHome'),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setTiledHome(ref, theme, tiled: !tiled);
        },
        child: SizedBox(
          width: 44,
          child: Center(
            child: Container(
              width: 32,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tiled
                    ? palette.accent.withValues(alpha: 0.22)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.space_dashboard_outlined,
                size: 18,
                color: tiled ? palette.accent : palette.onDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Write the user's tiled-or-grid choice for this distro.
///
/// Shared by the panel toggle and the Desktop settings row, so the two can
/// never disagree about what the switch stores. Choosing what the theme
/// already authors CLEARS the pref, so a later theme change still reaches a
/// user who never really changed anything.
void setTiledHome(WidgetRef ref, EffectiveTheme theme, {required bool tiled}) {
  final want = tiled ? 'tiled' : 'grid';
  // The layout the user is actually on, preset included, so clearing lands on
  // what this desktop authors rather than on the distro's base layout.
  final authored = theme.spec.layoutFor(theme.prefs.layoutPreset).homeLayout ??
      LayoutResolver.defaultHomeLayout;
  ref.read(prefsProvider(theme.spec.id).notifier).edit(
        (p) => want == authored
            ? p.clearing(homeLayout: true)
            : p.copyWith(homeLayout: want),
      );
}
