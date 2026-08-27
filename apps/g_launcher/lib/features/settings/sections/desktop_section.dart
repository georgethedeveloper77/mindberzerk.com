/// Desktop: the dock, the bar, the grid and the workspaces.
///
/// A section builder. See `appearance_section.dart` for why these are functions
/// returning widget lists rather than pages.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../../data/prefs/prefs_repository.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../design/device_preview.dart';
import '../../../engine/theme_spec.dart' show DockSide;
import '../../../design/setting_previews.dart';
import '../../../engine/capabilities.dart';
import '../../../engine/effective_theme.dart';
import '../../home/workspaces/workspace_controller.dart';
import '../settings_rows.dart';
import '../settings_sheets.dart';

/// Desktop and drawer: dock, grid, workspaces, drawer layout.
///
/// Sliced VERBATIM out of the old single build method. The rows, their
/// `FilterRow` keywords and their order are byte-identical to what shipped;
/// only where they are mounted changed.
List<Widget> desktopSection(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  int workspaces,
  String q,
) {
  // Derived here rather than passed, so the signature never has to name the
  // Pigeon host API type, which this file does not import.
  final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
  ref.read(launcherHostApiProvider);

  return [
    SettingPreview(
      query: q,
      caption: 'Dock, bar and drawer, live',
      child: LayoutPreview(theme: theme),
    ),

    // ── Layout ─────────────────────────────────────────────────────
    SettingsGroup(
      label: context.t('settings.layout'),
      scope: 'This distro',
      query: q,
      rows: [
        // ── THE PICTURE IS THE CONTROL ─────────────────────────────
        //
        // A three-word segmented control told you "Left", "Bottom" or "Off"
        // and left you to imagine the desktop each produces. Dock side is the
        // single most visible thing on this page and the one people switch
        // back and forth on, so it is the row that pays most for being shown
        // rather than named.
        //
        // Unframed previews inside the tiles: the tile already has a border,
        // and a phone drawn inside a phone is a picture of the thing instead
        // of the thing.
        FilterRow(
          const ['dock', 'position', 'left', 'bottom', 'off', 'side'],
          PreviewChoice<String>(
            title: context.t('settings.dockPosition'),
            // ── AND WHETHER THIS DESKTOP HAS ONE TO POSITION ───────────
            //
            // Four tiles, live, on a tiling WM that draws no dock and on the
            // terminal that draws nothing. Aqua answers differently again: it
            // HAS a dock and refuses to move it, which is a different sentence
            // and gets its own reason. See [ThemeCapabilities.canPositionDock].
            enabled: theme.canPositionDock.available,
            subtitle: theme.canPositionDock.available
                ? null
                : context.t(theme.canPositionDock.why!),
            // theme.dock is already the effective value (pref or default).
            value: theme.dock.name,
            onSelect: (v) => notifier.edit((p) => p.copyWith(dockSide: v)),
            options: [
              // FOUR TILES IN ONE ROW, not a wrap to 2x2. At 360dp that is
              // about 75dp each, which is a legible phone at the 10:15 the
              // chooser draws them; a second row would put "Off" on a line of
              // its own and read as a different question.
              for (final o in const [
                ('left', 'Left'),
                ('bottom', 'Bottom'),
                ('right', 'Right'),
                ('off', 'Off'),
              ])
                PreviewOption(
                  value: o.$1,
                  label: o.$2,
                  child: DevicePreview(
                    palette: theme.palette,
                    mode: DevicePreviewMode.desktop,
                    dock: switch (o.$1) {
                      'bottom' => DockSide.bottom,
                      'off' => DockSide.off,
                      'right' => DockSide.right,
                      _ => DockSide.left,
                    },
                    gridButton: theme.prefs.dockGridButton ?? 'end',
                    framed: false,
                  ),
                ),
            ],
          ),
        ),
        // Beside the dock's position, because it is the dock's own look. The
        // main slider under Surfaces still governs it until this is moved.
        FilterRow(
          const ['opacity', 'dock', 'transparency', 'panel'],
          OpacityRow(
            label: context.t('settings.dockOpacity'),
            // A dash that lives in the overview has no surface on the desktop
            // to fade, and a `dock: off` distro has none at all. Separate from
            // `canPositionDock` because aqua answers the two differently: it
            // has a dock and refuses to MOVE it.
            enabled: theme.canFadeDock.available,
            sub: theme.canFadeDock.available
                ? context.t('settings.dockOpacitySub')
                : context.t(theme.canFadeDock.why!),
            value: theme.dockOpacity,
            following: theme.prefs.dockOpacity == null,
            onChanged: (v) => notifier.edit((p) => p.copyWith(dockOpacity: v)),
            onFollow: () =>
                notifier.edit((p) => p.clearing(dockOpacity: true)),
          ),
        ),
        FilterRow(
          const ['activities', 'grid button', 'app button', 'dock'],
          SettingsRow(
            icon: Icons.apps_outlined,
            accent: true,
            title: context.t('settings.activitiesButton'),
            // Nothing OPENS the apps on a workspace-surface distro, so a
            // control for where the button lives is a control for a button
            // that is not there.
            subtitle: theme.hasActivitiesButton.available
                ? context.t('settings.whereTheAppGrid')
                : context.t(theme.hasActivitiesButton.why!),
            trailing: Seg(
              enabled: theme.hasActivitiesButton.available,
              value: theme.prefs.dockGridButton ?? 'end', // Ubuntu default
              options: const {
                'start': 'Start',
                'end': 'End',
                'off': 'Off',
              },
              onChanged: (v) =>
                  notifier.edit((p) => p.copyWith(dockGridButton: v)),
            ),
          ),
        ),
        // ── DESKTOP ICONS ──────────────────────────────────────────
        //
        // DIMMED AND INERT ON A DISTRO WITH NO GRID, which is the rule
        // `SettingsToggleRow.enabled` already states: a setting that applies
        // only elsewhere is greyed with the reason in its subtitle rather than
        // hidden, because hiding it makes someone who has read about the
        // feature conclude this build does not have it.
        //
        // The override is one-way and `LayoutResolver` enforces it, so this
        // switch can only ever turn icons OFF. A Ubuntu user cannot turn them
        // on, because a bare desktop is what GNOME IS rather than a setting
        // somebody forgot to expose. The subtitle says exactly that: it
        // describes the distro instead of withholding a feature.
        FilterRow(
          const [
            'desktop icons',
            'icons on desktop',
            'folder view',
            'apps on home',
          ],
          SettingsToggleRow(
            icon: Icons.apps_outlined,
            accent: true,
            title: context.t('settings.desktopIcons'),
            subtitle: theme.spec.layout.desktopIcons
                ? context.t('settings.appsOnTheWorkspace')
                : context.t('settings.bareDesktop', {'name': theme.spec.name}),
            value: theme.desktopIcons,
            enabled: theme.spec.layout.desktopIcons,
            onChanged: (v) =>
                notifier.edit((p) => p.copyWith(desktopIcons: v)),
          ),
        ),
        FilterRow(
          // Relabeled from "Home grid". The authentic-desktop decision
          // removed home-screen app icons everywhere, so "Home grid"
          // implied an icon grid that did not exist. They are back on the
          // distros that authentically have one, and this grid now shapes
          // BOTH: it is the placement grid for icons where a distro carries
          // them, and the desklet grid everywhere. This rows × columns is the
          // desktop's placement grid — where widgets / conky tiles snap
          // once WidgetHost lands. The old "home grid" search term is kept
          // so anyone looking for the previous name still finds this.
          const [
            'desktop grid',
            'home grid',
            'rows',
            'columns',
            'grid size',
            'widgets',
          ],
          SettingsRow(
            icon: Icons.grid_view_outlined,
            accent: true,
            title: context.t('settings.desktopGrid'),
            // Follows the icons. Shaping a grid nothing draws is arithmetic
            // with no picture at the end of it.
            subtitle: theme.hasDesktopGrid.available
                ? context.t('settings.rowsColumns')
                : context.t(
                    theme.hasDesktopGrid.why!,
                    {'name': theme.spec.name},
                  ),
            trailing: ChipValue(
              label: '${theme.rows} × ${theme.cols}',
              preview: DevicePreview(
                palette: theme.palette,
                mode: DevicePreviewMode.desktop,
                dock: theme.dock,
                gridButton: theme.prefs.dockGridButton ?? 'end',
              ),
            ),
            onTap: theme.hasDesktopGrid.available
                ? () => showGridSheet(context, notifier, theme)
                : null,
          ),
        ),
        FilterRow(
          const ['workspaces', 'pages', 'desktops', 'swipe'],
          SettingsRow(
            icon: Icons.dashboard_customize_outlined,
            accent: true,
            title: context.t('settings.workspaces'),
            subtitle: theme.hasWorkspaces.available
                ? context.t('settings.verticalDesktopsYouSwipe')
                : context.t(theme.hasWorkspaces.why!),
            trailing: ValueLabel('$workspaces'),
            onTap: !theme.hasWorkspaces.available
                ? null
                : () => showStepperSheet(
              context,
              title: context.t('settings.workspaces'),
              value: workspaces,
              min: WorkspaceCount.min,
              max: WorkspaceCount.max,
              onChanged: (v) =>
                  ref.read(workspaceCountProvider.notifier).set(v),
            ),
          ),
        ),
      ],
    ),
    // ── Top bar ────────────────────────────────────────────────────
    //
    // MOVED FROM APPEARANCE, where it lived in a group called "Icons and
    // bar". The bar and the dock are the same decision twice: both are
    // permanent chrome, both are per distro because their placement is what
    // makes a desktop recognisable, and both carry an opacity that follows
    // the main surfaces slider until split. Having one on this page and the
    // other two pages away was the clearest single fault in the old layout.
    SettingsGroup(
      label: context.t('settings.topBar'),
      scope: 'This distro',
      query: q,
      rows: [
        FilterRow(
          const ['top bar', 'status bar', 'gnome bar'],
          SettingsToggleRow(
            icon: Icons.web_asset_outlined,
            accent: true,
            title: context.t('settings.topBar'),
            // NOT gated on hasTopBar: this switch is what CREATES one, so
            // greying it where there is none would be the row disabling
            // itself. The rows that consume a bar are the ones that follow it.
            value: theme.topBar,
            onChanged: (v) => notifier.edit((p) => p.copyWith(topBar: v)),
          ),
        ),
        // Directly under the switch that turns the bar on, which is where
        // someone deciding how the bar should look already is.
        FilterRow(
          const ['opacity', 'bar', 'panel', 'transparency', 'top'],
          OpacityRow(
            label: context.t('settings.barOpacity'),
            // A slider that moves and changes nothing, on every distro without
            // a bar. `hasTopBar` asks `panels` rather than the shell, so a
            // distro that turns its bar off greys this by saying one thing.
            enabled: theme.hasTopBar.available,
            sub: theme.hasTopBar.available
                ? context.t('settings.barOpacitySub')
                : context.t(theme.hasTopBar.why!),
            subWhenInert: true,
            value: theme.barOpacity,
            following: theme.prefs.barOpacity == null,
            onChanged: (v) => notifier.edit((p) => p.copyWith(barOpacity: v)),
            onFollow: () => notifier.edit((p) => p.clearing(barOpacity: true)),
          ),
        ),
      ],
    ),
  ];
}
