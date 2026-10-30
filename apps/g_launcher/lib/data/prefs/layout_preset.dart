/// Switching a distro's desktop layout preset (Zorin's Appearance, Kali's
/// Xfce, GNOME and KDE), shared by Appearance and the quick settings sheet so
/// both mean the same thing by one tap.
library;

import 'launcher_prefs.dart';

/// Switch to a layout preset, clearing the overrides that preset owns.
///
/// ─── WHY A SWITCH THROWS WORK AWAY, DELIBERATELY ────────────────────────────
///
/// `LayoutResolver` reads `prefs.X ?? layout.X` for the dock, the bar, its
/// side, its readouts, its modules, its height, the grid and the drawer width.
/// So a user who has ever moved any one of those would tap macOS-like and watch
/// the desktop not change, because their old override still beats the new
/// layout. The control would be visibly broken for exactly the people who use
/// the launcher most.
///
/// Three ways out were on the table. Leaving prefs to win is the least code and
/// ships that broken control. Scoping every layout pref per preset is correct
/// and multiplies the stored surface by the number of presets, permanently, for
/// a feature with no users yet. Clearing is what Zorin Appearance itself does:
/// a deliberate act with a visible whole-desktop result.
///
/// ONLY THE FIELDS A PRESET CAN EXPRESS are cleared. Opacity, fonts, icon pack,
/// wallpaper, folders, gestures and the accent all survive, because none of
/// them appears in a `layouts` entry and throwing them away would make this
/// button a theme reset wearing a layout label.
LauncherPrefs applyLayoutPreset(LauncherPrefs p, String id) => p
    .clearing(
      dockSide: true,
      topBar: true,
      topBarSide: true,
      topBarStats: true,
      panelModules: true,
      panelHeight: true,
      panelSide: true,
      desktopIcons: true,
      rows: true,
      cols: true,
      drawerCols: true,
    )
    .copyWith(layoutPreset: id);
