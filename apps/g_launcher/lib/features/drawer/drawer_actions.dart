import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/drawer_layout.dart';
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
import 'app_icon.dart';
import 'drawer_items.dart';

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
void showDrawerAppMenu(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  AppEntry entry,
) {
  HapticFeedback.mediumImpact();
  final notifier = ref.read(appListProvider.notifier);
  final prefs = ref.read(prefsProvider(theme.spec.id).notifier);
  final isPinned = HomeLayout.isPinned(theme.prefs, entry.componentKey);
  final host = context; // outlives the sheet; safe for showMessage post-pop

  ThemedSheet.show<void>(
    context,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // "Add to home" became "Pin to dock": the authentic desktop has no
        // grid, so the old item added apps to a screen that displays nothing.
        // The dock is where home apps live now.
        if (isPinned)
          ThemedListRow(
            icon: Icons.push_pin_outlined,
            title: 'Unpin from dock',
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
            title: 'Pin to dock',
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
                if (host.mounted) host.showMessage('Dock is full');
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
          title: 'App info',
          onTap: () {
            Navigator.pop(sheet);
            notifier.openInfo(entry);
          },
        ),
        // System apps cannot be uninstalled. A button that silently does
        // nothing is worse than no button.
        if (!entry.isSystem && !entry.isWorkProfile)
          ThemedListRow(
            icon: Icons.delete_outline,
            title: 'Uninstall',
            onTap: () {
              Navigator.pop(sheet);
              notifier.uninstall(entry);
            },
          ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

/// The open folder.
///
/// The header IS the controls: tap the name to rename it in place, hit the
/// button on the right to ungroup. No settings rows underneath — a folder holds
/// two verbs, and burying them in a list below the apps made you scroll past
/// the contents to reach them.
///
/// Reads the folder LIVE out of prefs on every build rather than trusting the
/// [FolderDrawerItem] captured at open time — otherwise removing an app leaves
/// the sheet showing it until you close and reopen, and the sheet lies.
void openDrawerFolder(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  FolderDrawerItem item,
) {
  ThemedSheet.show<void>(
    context,
    isScrollControlled: true,
    builder: (sheet) => Consumer(
      builder: (ctx, r, __) {
        final items = r.watch(drawerItemsProvider(theme));
        final matches = items
            .whereType<FolderDrawerItem>()
            .where((f) => f.folder.id == item.folder.id)
            .toList();
        final live = matches.isEmpty ? null : matches.first;

        // Dissolved while open (the last-but-one app was pulled out). Close
        // rather than sit here showing a folder that no longer exists.
        if (live == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.canPop(sheet)) Navigator.pop(sheet);
          });
          return const SizedBox.shrink();
        }

        final d = ChromeScope.of(ctx);
        final cols = theme.prefs.folderCols ?? 4;
        final rows = theme.prefs.folderRows ?? 3;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: name (tap to rename) + ungroup ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.pop(sheet);
                        renameDrawerFolder(
                          context,
                          ref,
                          theme,
                          folderId: live.folder.id,
                          currentName: live.folder.name,
                        );
                      },
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              live.folder.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: d.text.title,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // The only hint that the name is tappable. Without it
                          // renaming becomes a hidden gesture.
                          Icon(
                            Icons.edit_outlined,
                            size: 15,
                            color: d.colors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ThemedButton(
                    label: 'Ungroup',
                    icon: Icons.folder_off_outlined,
                    kind: ThemedButtonKind.text,
                    onPressed: () {
                      Navigator.pop(sheet);
                      r.read(prefsProvider(theme.spec.id).notifier).edit(
                            (p) => DrawerLayout.dissolve(p, live.folder.id),
                          );
                    },
                  ),
                ],
              ),
            ),

            // ── Apps ────────────────────────────────────────────────────────
            // Height derived from the row count rather than fixed, so "3 rows"
            // means three rows on any screen; past that the folder scrolls.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: rows * (theme.iconSizeDp + 34),
              ),
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  childAspectRatio: 0.78,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 14,
                ),
                itemCount: live.members.length,
                itemBuilder: (_, i) {
                  final m = live.members[i];
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Navigator.pop(sheet);
                      launchDrawerApp(r, m);
                    },
                    // Hold for the app's own menu, which inside a folder gains
                    // "Remove from folder" — the one action that only exists
                    // here. Previously this REMOVED the app outright on hold,
                    // with no menu and no way back; a destructive action with
                    // no confirmation and no undo does not belong on a gesture.
                    onLongPress: () => _folderMemberMenu(
                      ctx,
                      r,
                      theme,
                      folderId: live.folder.id,
                      entry: m,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(entry: m, size: theme.iconSizeDp),
                        const SizedBox(height: 6),
                        Text(
                          m.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: d.colors.text,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    ),
  );
}

/// The long-press menu for an app INSIDE a folder.
///
/// Same shape as the drawer's app menu, plus the one action that only makes
/// sense in here. Pin/uninstall stay available: being in a folder does not stop
/// an app being an app.
void _folderMemberMenu(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme, {
  required String folderId,
  required AppEntry entry,
}) {
  HapticFeedback.mediumImpact();
  final notifier = ref.read(appListProvider.notifier);

  ThemedSheet.show<void>(
    context,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ThemedListRow(
          icon: Icons.folder_off_outlined,
          title: 'Remove from folder',
          subtitle: 'Back to the drawer; the app stays installed',
          onTap: () {
            Navigator.pop(sheet);
            ref.read(prefsProvider(theme.spec.id).notifier).edit(
                  (p) => DrawerLayout.removeFromFolder(
                    p,
                    folderId,
                    entry.componentKey,
                  ),
                );
          },
        ),
        ThemedListRow(
          icon: Icons.info_outline,
          title: 'App info',
          onTap: () {
            Navigator.pop(sheet);
            notifier.openInfo(entry);
          },
        ),
        if (!entry.isSystem && !entry.isWorkProfile)
          ThemedListRow(
            icon: Icons.delete_outline,
            title: 'Uninstall',
            onTap: () {
              Navigator.pop(sheet);
              notifier.uninstall(entry);
            },
          ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

/// Folder settings from a long-press, without opening the folder first.
void drawerFolderSettings(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  FolderDrawerItem item,
) {
  HapticFeedback.mediumImpact();
  ThemedSheet.show<void>(
    context,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ThemedListRow(
          icon: Icons.folder_open_outlined,
          title: 'Open',
          onTap: () {
            Navigator.pop(sheet);
            openDrawerFolder(context, ref, theme, item);
          },
        ),
        ThemedListRow(
          icon: Icons.drive_file_rename_outline,
          title: 'Rename folder',
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
          title: 'Ungroup',
          subtitle: 'The apps return to the drawer; nothing is uninstalled',
          onTap: () {
            Navigator.pop(sheet);
            ref.read(prefsProvider(theme.spec.id).notifier).edit(
                  (p) => DrawerLayout.dissolve(p, item.folder.id),
                );
          },
        ),
        const SizedBox(height: 8),
      ],
    ),
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
  // Preselected, so the first keystroke REPLACES the placeholder instead of
  // appending to it. Nobody wants to name a folder "FolderGames".
  final controller = TextEditingController(text: currentName)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: currentName.length,
    );

  ThemedSheet.show<void>(
    context,
    title: 'Name this folder',
    isScrollControlled: true,
    builder: (sheet) {
      final d = ChromeScope.of(sheet);

      void commit() {
        final name = controller.text;
        Navigator.pop(sheet);
        ref
            .read(prefsProvider(theme.spec.id).notifier)
            .edit((p) => DrawerLayout.rename(p, folderId, name));
      }

      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(sheet).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => commit(),
              style: d.text.body,
              decoration: InputDecoration(
                hintText: 'Folder name',
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
            ThemedButton(label: 'Save', onPressed: commit, expand: true),
          ],
        ),
      );
    },
  ).whenComplete(controller.dispose);
}
