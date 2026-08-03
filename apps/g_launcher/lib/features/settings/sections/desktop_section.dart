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
            sub: context.t('settings.dockOpacitySub'),
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
            subtitle: context.t('settings.whereTheAppGrid'),
            trailing: Seg(
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
        FilterRow(
          // Relabeled from "Home grid". The authentic-desktop decision
          // removed home-screen app icons, so "Home grid" implied an
          // icon grid that no longer exists. This rows × columns is the
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
            subtitle: context.t('settings.rowsColumns'),
            trailing: ChipValue(
              label: '${theme.rows} × ${theme.cols}',
              preview: DevicePreview(
                palette: theme.palette,
                mode: DevicePreviewMode.desktop,
                dock: theme.dock,
                gridButton: theme.prefs.dockGridButton ?? 'end',
              ),
            ),
            onTap: () => showGridSheet(context, notifier, theme),
          ),
        ),
        FilterRow(
          const ['workspaces', 'pages', 'desktops', 'swipe'],
          SettingsRow(
            icon: Icons.dashboard_customize_outlined,
            accent: true,
            title: context.t('settings.workspaces'),
            subtitle: context.t('settings.verticalDesktopsYouSwipe'),
            trailing: ValueLabel('$workspaces'),
            onTap: () => showStepperSheet(
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
            sub: context.t('settings.barOpacitySub'),
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
