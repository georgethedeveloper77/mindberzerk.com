import 'launcher_prefs.dart';

/// Which block of settings a reset covers.
///
/// Named after the rows on the Restore defaults screen, because the promise a
/// reset makes is "put the things under this heading back". A section whose
/// name did not match the heading above it would be a reset the user cannot
/// predict.
///
/// [surfaces] deliberately OVERLAPS the other sections: it clears all four
/// opacity values, while [desktop] also clears the dock's and [drawer] also
/// clears the drawer's. That is not a contradiction. Each opacity control now
/// lives with its own section, so resetting that section has to include it,
/// and Surfaces is the one that puts the four back to moving together.
enum PrefsSection {
  icons,
  type,
  folders,
  drawer,
  wallpaper,
  gestures,
  desktop,
  surfaces,
}

/// Restoring defaults, as pure functions.
///
/// ─── THE ONE RULE: THIS CLEARS SETTINGS, NEVER CONTENT ──────────────────────
///
/// A setting is a preference with a default to fall back to. Content is
/// something the user MADE, and it has no default, so "restoring" it means
/// destroying it. The distinction is the whole reason this file is a map
/// written down in one place rather than a `clearing()` call typed out at each
/// row: typed out per row, the day somebody adds `drawerFolders` to a reset
/// "because folders are in the Folders section" is the day a reset button
/// deletes every folder on the phone.
///
/// So the following are NEVER touched by any section below, and adding one to
/// a list is a bug and not a judgement call:
///
///   hiddenApps           which apps they hid
///   favourites           what they pinned to the dock
///   homeItems, folders   the home screen they arranged
///   drawerFolders        the folders they made (Folders screen has Ungroup)
///   drawerSlots + geometry   the custom drawer arrangement they dragged
///   desklets             the widgets they placed
///   wallpapers           the photos they imported
///   wallpaperCurrent     which image is on screen right now
///   dismissedSuggestions what they told us to stop suggesting
///
/// [wallpaperCurrent] is the one that looks like a setting and is not. Clearing
/// it would make the next theme resolve seed the distro's own preset back over
/// the picture the user chose, so a "reset wallpaper settings" tap would change
/// their wallpaper. The rotation interval, the pool and the fit are settings;
/// which photo is up is theirs.
///
/// ─── THE PROMOTED HALF LOOKS AFTER ITSELF ───────────────────────────────────
///
/// Some of these fields live in the global bucket rather than the theme's file.
/// Nothing here needs to know which: `PrefsNotifier.edit` compares the promoted
/// fields before and after and routes the write, so clearing `iconTreatment`
/// through a section below clears it for every distro exactly as setting it
/// would have set it for every distro. That symmetry is the point.
abstract final class PrefsReset {
  const PrefsReset._();

  /// [p] with everything in [section] returned to its default.
  ///
  /// Returns an object equal to [p] when there was nothing set, which is what
  /// [canReset] tests, so the UI can hide an affordance that would do nothing
  /// rather than offering a button that appears broken.
  static LauncherPrefs section(LauncherPrefs p, PrefsSection s) =>
      switch (s) {
        // Icon look only. The icon PACK is included: it is a choice among
        // installed content, and clearing it uninstalls nothing.
        PrefsSection.icons => p.clearing(
            iconSizeDp: true,
            iconTreatment: true,
            cornerRadius: true,
            systemIconPack: true,
            iconPackId: true,
          ),

        PrefsSection.type => p.clearing(labelLines: true, textScale: true),

        // Folder APPEARANCE. The folders themselves are content and are
        // dissolved from the Folders screen's Ungroup rows, not from here.
        PrefsSection.folders => p.clearing(
            folderCols: true,
            folderRows: true,
            folderShape: true,
            folderOrderCustom: true,
          ),

        // Behaviour and density. `hiddenApps` is the set they built and
        // `drawerSlots` is the arrangement they dragged; both survive.
        PrefsSection.drawer => p.clearing(
            drawerCols: true,
            drawerSearchPosition: true,
            drawerScrollStyle: true,
            drawerGrouping: true,
            drawerSortMode: true,
            drawerPageCount: true,
            drawerOpacity: true,
            hiddenAppsSearchable: true,
          ),

        PrefsSection.wallpaper => p.clearing(
            wallpaperLock: true,
            wallpaperRotationMinutes: true,
            wallpaperRotationSource: true,
            wallpaperFit: true,
          ),

        // A Map rather than a nullable field, so this is a copyWith to empty
        // rather than a clearing flag, and `clearing(gestures: true)` does not
        // exist. Empty is exactly "the user has bound nothing", which is what
        // lets the distro's defaults and then the built-in defaults apply
        // again. See `resolveGestureBinding`.
        PrefsSection.gestures => p.copyWith(gestures: const {}),

        PrefsSection.desktop => p.clearing(
            dockSide: true,
            dockGridButton: true,
            rows: true,
            cols: true,
            topBar: true,
            topBarSide: true,
            topBarStats: true,
            workspaceCount: true,
            dockOpacity: true,
            barOpacity: true,
          ),

        // The four rejoin as one. See the note on [PrefsSection].
        PrefsSection.surfaces => p.clearing(
            surfaceOpacity: true,
            dockOpacity: true,
            drawerOpacity: true,
            barOpacity: true,
          ),
      };

  /// Is anything in [s] actually set?
  ///
  /// Compared through value equality rather than by listing the fields a second
  /// time. A second list is a second thing to update, and the failure mode is
  /// silent: a newly added field resets correctly but its section's button
  /// stays hidden, so the setting looks permanent.
  static bool canReset(LauncherPrefs p, PrefsSection s) => section(p, s) != p;
}
