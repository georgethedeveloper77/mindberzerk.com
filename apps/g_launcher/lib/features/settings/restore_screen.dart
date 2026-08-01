import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/prefs_reset.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/app_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../engine/effective_theme.dart';

/// Restore defaults, per section or wholesale.
///
/// Every section is one bundle over the merged prefs, and that is the whole
/// design: `PrefsNotifier.edit` already routes each cleared field to the
/// global bucket or the theme's own file via `promotedChanged`, so a bundle
/// needs to know WHICH fields make up a section and nothing about where they
/// live. Content is never touched by a section reset: folders, the custom
/// drawer arrangement, desklets, hidden apps, your wallpapers and collections
/// all survive, because "reset my settings" and "delete my stuff" are
/// different requests and conflating them is how trust dies.
///
/// ─── THE FIELD LISTS LIVE IN prefs_reset.dart, NOT HERE ─────────────────────
///
/// This screen used to spell out each `clearing` bundle inline, which put a
/// second copy of the map beside the one the Folders and Wallpaper screens
/// already used. Two copies drift, and both of this file's compile errors were
/// that drift surfacing: it cleared `topBarOpacity`, which is called
/// `barOpacity`, and `clearing(gestures: true)`, which cannot exist because
/// gestures is a Map with no null state. Naming the section instead means a
/// field added to a section is added once.
class RestoreScreen extends ConsumerWidget {
  const RestoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(effectiveThemeProvider);
    if (!async.hasValue) {
      return const ThemedScaffold(title: 'Restore defaults', body: SizedBox());
    }
    final theme = async.requireValue;
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
    final c = ChromeScope.of(context).colors;

    Future<void> run({
      required String title,
      required String message,
      required Future<void> Function() action,
      required String done,
      bool danger = false,
    }) async {
      final ok = await ThemedDialog.confirm(
        context,
        title: title,
        message: message,
        confirmLabel: 'Restore',
        danger: danger,
      );
      if (ok != true) return;
      await action();
      if (context.mounted) context.showMessage(done);
    }

    Widget section({
      required IconData icon,
      required String title,
      required String subtitle,
      required PrefsSection which,
      Future<void> Function()? also,
    }) =>
        ThemedListRow(
          icon: icon,
          title: title,
          subtitle: subtitle,
          onTap: () => run(
            title: '$title?',
            message: 'These settings return to the distro defaults. Nothing '
                'you made or added is removed.',
            done: 'Restored',
            action: () async {
              await notifier.edit((p) => PrefsReset.section(p, which));
              if (also != null) await also();
            },
          ),
        );

    return ThemedScaffold(
      title: 'Restore defaults',
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Settings only. Folders, desklets, arrangements and photos '
              'stay exactly where they are.',
              style: TextStyle(color: c.textFaint),
            ),
          ),
          section(
            icon: Icons.category_outlined,
            title: 'Icons',
            subtitle: 'Shape, size, corners, packs',
            which: PrefsSection.icons,
          ),
          section(
            icon: Icons.text_fields,
            title: 'Type',
            subtitle: 'Label lines and text size',
            which: PrefsSection.type,
          ),
          section(
            icon: Icons.folder_outlined,
            title: 'Folders',
            subtitle: 'Grid and shape. Your folders stay',
            which: PrefsSection.folders,
          ),
          section(
            icon: Icons.apps,
            title: 'Drawer',
            subtitle: 'Style, sorting, columns. A custom arrangement is kept',
            which: PrefsSection.drawer,
          ),
          section(
            icon: Icons.image_outlined,
            title: 'Wallpaper',
            subtitle: 'Rotation, fit and lock. Your photos stay',
            which: PrefsSection.wallpaper,
            also: () async =>
                ref.read(launcherHostApiProvider).cancelWallpaperRotation(),
          ),
          section(
            icon: Icons.swipe,
            title: 'Gestures',
            subtitle: 'Every swipe back to its default',
            which: PrefsSection.gestures,
          ),
          section(
            icon: Icons.desktop_windows_outlined,
            title: 'Desktop',
            subtitle: 'Dock, bar, grid and workspaces',
            which: PrefsSection.desktop,
          ),
          section(
            icon: Icons.opacity,
            title: 'Surfaces',
            subtitle: 'All four opacity sliders rejoin as one',
            which: PrefsSection.surfaces,
          ),
          const SizedBox(height: 10),
          ThemedListRow(
            icon: Icons.restart_alt,
            title: 'Reset everything',
            subtitle: 'This distro back to a clean install',
            onTap: () => run(
              danger: true,
              title: 'Reset everything?',
              message: 'Every setting on this distro returns to its default, '
                  'including your folders, desklets and arrangements here, '
                  'and the settings shared across distros. Other distros '
                  'keep their own setups. Photos, collections and installed '
                  'packs are not deleted.',
              done: 'Everything reset',
              action: () async {
                // `resetEverything`, not `resetAll`: the theme file AND the
                // global bucket, in that order, for the reason spelled out on
                // the method. `resetAll` alone leaves every promoted field
                // (icon shape, label lines, opacity, theme mode) to be
                // re-applied by the next build, which is the bug that made
                // the old Settings reset row lie about what it did.
                await notifier.resetEverything();
                await ref
                    .read(launcherHostApiProvider)
                    .cancelWallpaperRotation();
              },
            ),
          ),
        ],
      ),
    );
  }
}
