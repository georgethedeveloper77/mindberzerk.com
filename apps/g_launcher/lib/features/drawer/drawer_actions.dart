import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/drawer_layout.dart';
import '../../data/prefs/hidden_apps.dart';
import '../../data/prefs/home_layout.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/usage/usage_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../engine/effective_theme.dart';
import '../../features/dock/dock_metrics.dart';
import '../../platform/launcher_api.g.dart';
import '../settings/settings_screen.dart';
import 'drawer_items.dart';
import 'folder_overlay.dart';
import 'package:g_launcher/i18n/i18n.dart';

/// Everything a drawer DOES, independent of how it looks.
///
/// Each shell paints its own drawer — GNOME's Activities grid, KDE's Kickoff
/// menu, the tiling launcher, the terminal's command line — but tapping an app,
/// holding it, opening a folder and naming one must behave identically in all of
/// them. Five presentations, one set of actions.
///
/// This file exists because those actions started out private to
/// `app_drawer.dart`. Leaving them there would have meant Kickoff either
/// importing the GNOME drawer (absurd) or growing its own copy of the pin /
/// uninstall / rename sheets (worse — they drift, and the folder sheet is
/// load-bearing). Same reasoning that moved `shellAppsProvider` out of
/// `gnome_shell.dart`.
///
/// Everything here is themed through the chrome primitives, so the sheets
/// inherit the active distro's look automatically in whichever drawer opened
/// them.

/// What a freshly merged folder is called until the user names it. Named once
/// so the merge and the rename sheet cannot disagree about it.
const defaultFolderName = 'Folder';

/// Generates a drawer folder id. Prefixed `df` so it is obvious at a glance in
/// a prefs dump that this is a DRAWER folder, not a home-screen one.
String newDrawerFolderId() =>
    'df${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

/// The corner radius a folder tile should use, in logical pixels.
///
/// `folderShape` null means "match my icon shape", which is the default and the
/// right one: a folder sits in a grid of app icons, and a rounded-square folder
/// among circular icons looks like a bug. Only when the user picks an explicit
/// shape does the folder stop following.
///
/// Returned as a radius rather than a shape enum because every call site is a
/// BorderRadius — resolving it here keeps the mapping in one place instead of
/// three widgets each guessing what "squircle" is worth.
double folderCornerRadius(EffectiveTheme theme, double size) {
  final fraction = switch (theme.prefs.folderShape) {
    'circle' => 0.5,
    'square' => 0.0,
    'squircle' => 0.30,
    'roundedSquare' => 0.22,
    // null (or anything unrecognised, e.g. a pref written by a newer build):
    // follow the theme's own icon treatment.
    _ => switch (theme.icons.treatment) {
        IconTreatment.circle => 0.5,
        IconTreatment.square => 0.0,
        IconTreatment.squircle => 0.30,
        // A teardrop has no single radius; a circle is the closest honest
        // approximation and beats a square sitting among teardrops.
        IconTreatment.teardrop => 0.5,
        // `original` keeps each app's own artwork, so there is no shape to
        // match — fall back to the neutral default.
        IconTreatment.original => 0.22,
        IconTreatment.roundedSquare => theme.icons.cornerRadius,
      },
  };
  return size * fraction;
}

/// Launch a real app and record the usage that feeds the dock's defaults and
/// Kickoff's Frequent rail.
void launchDrawerApp(WidgetRef ref, AppEntry entry, {Rect? iconBounds}) {
  HapticFeedback.lightImpact();
  ref.read(appListProvider.notifier).launch(entry, iconBounds: iconBounds);
  ref.read(usageProvider.notifier).record(entry.componentKey);
}

/// Activate any drawer entry. Real apps launch natively and record usage;
/// folders open; launcher-owned entries route in-app or hand off to the OS.
///
/// The sealed switch is the point: a new [DrawerItem] variant stops compiling
/// here until every drawer knows what tapping it does.
void activateDrawerItem(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  DrawerItem item, {
  Rect? iconBounds,
}) {
  switch (item) {
    case AppDrawerItem(:final entry):
      launchDrawerApp(ref, entry, iconBounds: iconBounds);
    case final FolderDrawerItem folder:
      // Activating a folder means opening it. Bound with a pattern variable so
      // the sheet gets the concrete item, not the sealed supertype.
      HapticFeedback.lightImpact();
      openDrawerFolder(context, ref, theme, folder);
    case LauncherSettingsItem():
      HapticFeedback.lightImpact();
      openLauncherSettings(context, theme);
    case DeviceSettingsItem():
      HapticFeedback.lightImpact();
      // Reuse the API's existing generic deep-link seam rather than a bespoke
      // method. ACTION_SETTINGS is the top-level Android Settings and always
      // resolves, so there is nothing to catch and no branded-message fallback
      // to write. Unlike an app-specific deep link, this one cannot miss.
      ref
          .read(launcherHostApiProvider)
          .openAndroidSettings('android.settings.SETTINGS');
  }
}

/// Push G Launcher's own settings. SettingsScreen re-reads the live theme, so
/// the push-time snapshot is only its fallback.
void openLauncherSettings(BuildContext context, EffectiveTheme theme) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => SettingsScreen(theme: theme)),
  );
}

/// The app long-press menu: pin/unpin, app info, uninstall.
///
/// ─── IT WAS A BOTTOM SHEET, AND IT WAS THE LAST ONE ─────────────────────────
///
/// Every other contextual menu in the drawer had already been converted to a
/// panel anchored at the thing it is about: the folder-member menu (the comment
/// a few lines below records its conversion), the drawer's overflow menu, the
/// desklet menu. This one and [drawerFolderSettings] were missed, which is why
/// the single most-used menu in the launcher was also the only one still
/// climbing up from the bottom edge.
///
/// That is the same category error the folder overlay documents at length: the
/// bottom sheet is the nearest primitive to hand on Android, so every secondary
/// surface becomes one, and a launcher imitating a desktop stops looking like
/// one. A menu about ONE APP belongs beside that app. On a full-screen grid the
/// app you held is usually nowhere near the bottom of the screen, so the sheet
/// opened as far from its subject as the display allows, with the subject
/// itself behind the scrim.
void showDrawerAppMenu(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  AppEntry entry, {
  /// Where the menu opens. Null centres it, which is what a caller that cannot
  /// measure itself gets; see [AnchoredMenu.show].
  Rect? anchor,
}) {
  HapticFeedback.mediumImpact();
  final notifier = ref.read(appListProvider.notifier);
  final prefs = ref.read(prefsProvider(theme.spec.id).notifier);
  final isPinned = HomeLayout.isPinned(theme.prefs, entry.componentKey);
  final host = context; // outlives the menu; safe for showMessage post-pop

  // Built from the theme rather than looked up. The drawer body is not
  // guaranteed to sit under a ChromeScope, and the tiling launcher and Kickoff
  // both call this from surfaces that certainly do not.
  final chrome = ChromeData.fromPalette(
    theme.palette,
    typography: theme.typography,
    textScale: theme.textScale,
    family: theme.chromeFamily,
    opacity: theme.surfaceOpacity,
    panelBlur: theme.panelBlur,
    panelTint: theme.panelTint,
    panelRadius: theme.panelRadius,
  );

  AnchoredMenu.show(
    context: context,
    chrome: chrome,
    anchor: anchor,
    width: 236,
    rows: (sheet) => [
        // "Add to home" became "Pin to dock": the authentic desktop has no
        // grid, so the old item added apps to a screen that displays nothing.
        // The dock is where home apps live now.
        if (isPinned)
          ThemedListRow(
            icon: Icons.push_pin_outlined,
            title: context.t('shell.unpinFromDock'),
            onTap: () {
              Navigator.pop(sheet);
              prefs.edit(
                (p) => HomeLayout.unpinFromDock(p, entry.componentKey),
              );
            },
          )
        else
          ThemedListRow(
            icon: Icons.push_pin,
            title: context.t('shell.pinToDock'),
            onTap: () {
              Navigator.pop(sheet);
              // Pin against the ceiling; the dock displays what fits its
              // current side. Pinning #11 on a bottom dock isn't lost — it
              // appears when the dock is moved to the left.
              final before = theme.prefs;
              final after = HomeLayout.pinToDock(
                before,
                entry.componentKey,
                capacity: DockMetrics.maxCapacity,
              );
              if (identical(before, after)) {
                // Refused = full. A silently dropped pin is worse than a
                // refused one. Single-string message per the convention.
                if (host.mounted) {
                  host.showMessage(host.t('drawer.dockIsFull'));
                }
                return;
              }
              prefs.edit((p) => HomeLayout.pinToDock(
                    p,
                    entry.componentKey,
                    capacity: DockMetrics.maxCapacity,
                  ));
            },
          ),
        ThemedListRow(
          icon: Icons.info_outline,
          title: context.t('shell.appInfo'),
          onTap: () {
            Navigator.pop(sheet);
            notifier.openInfo(entry);
          },
        ),

        // Hide it from THIS theme's drawer. Per-theme, like the set it writes
        // to: an app hidden under Ubuntu is still in KDE's drawer, because
        // hiding is "off my desktop", not "gone from the phone".
        //
        // The message is doing real work, not decoration. A hidden app is not
        // in the drawer to long-press, so the ONLY way back is the Apps and
        // folders page — and a user who just hid their first app has no reason
        // to know that exists. Naming it is the difference between a reversible
        // action and one that feels permanent. Single string, per the
        // convention.
        ThemedListRow(
          icon: Icons.visibility_off_outlined,
          title: context.t('drawer.hideApp'),
          subtitle: context.t('drawer.unhideItUnderApps'),
          onTap: () {
            Navigator.pop(sheet);
            prefs.edit((p) => HiddenApps.hide(p, entry.componentKey));
            if (host.mounted) {
              host.showMessage(
                host.t('drawer.appHidden', {'name': entry.label}),
              );
            }
          },
        ),

        // System apps cannot be uninstalled. A button that silently does
        // nothing is worse than no button.
        if (!entry.isSystem && !entry.isWorkProfile)
          ThemedListRow(
            icon: Icons.delete_outline,
            title: context.t('drawer.uninstall'),
            onTap: () {
              Navigator.pop(sheet);
              notifier.uninstall(entry);
            },
          ),
    ],
  );
}

/// Open a folder.
///
/// ─── THE BODY OF THIS MOVED, AND ON PURPOSE ─────────────────────────────────
///
/// This used to draw the folder itself: a bottom [ThemedSheet] with a header
/// row, an Ungroup button and a grid. That was some 160 lines of layout living
/// in the file that owns the drawer's VERBS, which is how a folder ends up
/// looking like a settings panel — the sheet was the nearest primitive to hand,
/// so the folder became one.
///
/// The presentation now lives in `folder_overlay.dart` and this is the seam
/// again: every shell, the drawer, the search page and the folder settings
/// sheet all call this, and none of them needs to know that opening a folder
/// now pushes a full-screen route rather than a sheet. Changing the
/// presentation a second time is one file.
void openDrawerFolder(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  FolderDrawerItem item,
) {
  showFolderOverlay(context, ref, theme, item);
}

// The folder-member long-press menu USED TO LIVE HERE.
//
// It was a ThemedSheet, and it is now a context menu anchored at the finger
// (see `showFolderMemberMenu` in folder_overlay.dart). It is deleted rather
// than kept "in case", because its only caller was the folder body that moved,
// and leaving a second implementation of "remove from folder" behind is exactly
// how two paths drift until one of them is subtly wrong.

/// Folder settings from a long-press, without opening the folder first.
///
/// Anchored, for the same reason [showDrawerAppMenu] is: it is about ONE
/// folder, and it was the other menu the conversion missed.
void drawerFolderSettings(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  FolderDrawerItem item, {
  Rect? anchor,
}) {
  HapticFeedback.mediumImpact();

  final chrome = ChromeData.fromPalette(
    theme.palette,
    typography: theme.typography,
    textScale: theme.textScale,
    family: theme.chromeFamily,
    opacity: theme.surfaceOpacity,
    panelBlur: theme.panelBlur,
    panelTint: theme.panelTint,
    panelRadius: theme.panelRadius,
  );

  AnchoredMenu.show(
    context: context,
    chrome: chrome,
    anchor: anchor,
    // The folder's own name as the header. A three-row menu with Open, Rename
    // and Ungroup on it says nothing about WHICH folder when two are adjacent,
    // which is exactly the case a long-press menu appears in.
    title: item.folder.name,
    width: 236,
    rows: (sheet) => [
        ThemedListRow(
          icon: Icons.folder_open_outlined,
          title: context.t('drawer.open'),
          onTap: () {
            Navigator.pop(sheet);
            openDrawerFolder(context, ref, theme, item);
          },
        ),
        ThemedListRow(
          icon: Icons.drive_file_rename_outline,
          title: context.t('drawer.renameFolder'),
          onTap: () {
            Navigator.pop(sheet);
            renameDrawerFolder(
              context,
              ref,
              theme,
              folderId: item.folder.id,
              currentName: item.folder.name,
            );
          },
        ),
        ThemedListRow(
          icon: Icons.folder_off_outlined,
          title: context.t('drawer.ungroup'),
          subtitle: context.t('drawer.theAppsReturnTo'),
          onTap: () {
            Navigator.pop(sheet);
            ref.read(prefsProvider(theme.spec.id).notifier).edit(
                  (p) => DrawerLayout.dissolve(p, item.folder.id),
                );
          },
        ),
    ],
  );
}

/// Rename, in a themed sheet. A blank name is refused by [DrawerLayout.rename]
/// rather than stored — an unnamed folder in an alphabetical list has nowhere to
/// sort and nothing to tap.
///
/// Takes the id and current name rather than a folder object so the
/// just-merged case can call it before the new folder has been read back out of
/// prefs.
void renameDrawerFolder(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme, {
  required String folderId,
  required String currentName,
}) {
  ThemedSheet.show<void>(
    context,
    title: context.t('drawer.nameThisFolder'),
    isScrollControlled: true,
    builder: (sheet) => _RenameFolderBody(
      ref: ref,
      theme: theme,
      folderId: folderId,
      currentName: currentName,
    ),
  );
}

/// The rename sheet's body, as a StatefulWidget so it OWNS its controller.
///
/// ─── WHY THIS IS NOT A CLOSURE ANY MORE ─────────────────────────────────────
///
/// It was: the controller was built beside the `ThemedSheet.show` call and
/// disposed with `.whenComplete(controller.dispose)`. That reads as careful
/// lifecycle management and is a crash. The route's Future completes the moment
/// the sheet is POPPED, while the sheet is still on screen playing its exit
/// animation, and every frame of that animation rebuilds the TextField against
/// a controller that has just been disposed:
///
///   A TextEditingController was used after being disposed.
///
/// It fired hardest right after merging two apps, because that path opens this
/// sheet automatically and users dismiss it fast, which is the shortest gap
/// between pop and the next rebuild.
///
/// Owning the controller in a State fixes it by construction rather than by
/// timing: Flutter disposes the State when the subtree is actually gone, not
/// when a Future resolves. No delay to tune, nothing to get wrong again.
class _RenameFolderBody extends StatefulWidget {
  const _RenameFolderBody({
    required this.ref,
    required this.theme,
    required this.folderId,
    required this.currentName,
  });

  final WidgetRef ref;
  final EffectiveTheme theme;
  final String folderId;
  final String currentName;

  @override
  State<_RenameFolderBody> createState() => _RenameFolderBodyState();
}

class _RenameFolderBodyState extends State<_RenameFolderBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Preselected, so the first keystroke REPLACES the placeholder instead of
    // appending to it. Nobody wants to name a folder "FolderGames".
    _controller = TextEditingController(text: widget.currentName)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.currentName.length,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final name = _controller.text;
    Navigator.pop(context);
    widget.ref
        .read(prefsProvider(widget.theme.spec.id).notifier)
        .edit((p) => DrawerLayout.rename(p, widget.folderId, name));
  }

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _commit(),
            style: d.text.body,
            decoration: InputDecoration(
              hintText: context.t('drawer.folderName'),
              hintStyle: d.text.body.copyWith(color: d.colors.textFaint),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: d.colors.line),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: d.colors.accent),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ThemedButton(
            label: context.t('common.save'),
            onPressed: _commit,
            expand: true,
          ),
        ],
      ),
    );
  }
}
