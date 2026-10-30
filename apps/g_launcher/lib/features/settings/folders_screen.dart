// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../data/prefs/drawer_layout.dart';
import '../../data/prefs/folder_suggestions.dart';
import '../../data/prefs/hidden_lock.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/prefs/prefs_reset.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/repositories/shell_apps.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../design/device_preview.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../drawer/drawer_actions.dart';
import 'folder_grid_section.dart';
import 'hide_apps_screen.dart';

/// Folder settings, on their own page because folders grew past a row.
///
/// In the order you need them:
///  1. **Folder grid and shape**: columns and rows inside an open folder, and
///     how the tile itself is drawn, with a live preview above.
///  2. **Your folders**: [FolderGridSection], the real tiles, the suggested
///     groups and New folder in one grid.
///  3. **Hidden apps**: the way into Hide apps.
///
/// Bulk actions (create every suggestion, reset appearance, ungroup all) are
/// in the title bar's menu, so they never sit between a person and their
/// folders.
///
/// Chrome, not Material: everything reads [ChromeScope] through the primitives,
/// so this page wears the active distro exactly like Settings and Wallpaper.
class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Live, not the push-time snapshot: accepting a suggestion must remove it
    // from the list under your finger, and renaming must show immediately.
    // hasValue, not asData. See home_screen.dart: asData is null through a
    // reload, and every prefs write is a reload.
    final async = ref.watch(effectiveThemeProvider);
    final theme = async.hasValue ? async.requireValue : this.theme;
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

    final apps = ref.watch(shellAppsProvider(theme));
    final suggestions = FolderSuggestions.propose(apps, theme.prefs);

    final cols = theme.prefs.folderCols ?? 4;
    final rows = theme.prefs.folderRows ?? 3;

    return ThemedScaffold(
      // "Apps and folders", because hiding an app landed here and the page
      // stopped being only about folders. Naming it after half its contents is
      // how a setting becomes unfindable.
      title: context.t('settings.appsAndFolders'),
      actions: [
        // ChromeScope is provided BY ThemedScaffold, so read it from below.
        Builder(
          builder: (ctx) => IconButton(
            icon: Icon(
              Icons.more_vert,
              color: ChromeScope.of(ctx).colors.textMuted,
            ),
            tooltip: ctx.t('folders.moreOptions'),
            onPressed: () => _bulkMenu(ctx, notifier, theme, suggestions),
          ),
        ),
      ],
      body: ListView(
        // Clears the navigation bar. Trailing padding rather than a SafeArea,
        // so the list still scrolls behind a transparent bar.
        padding: EdgeInsets.only(bottom: context.bottomInset),
        children: [
          // The folder itself, drawn at the current settings. Columns, rows and
          // shape are all visible in one picture, which is the whole reason
          // this page exists rather than three rows in Settings.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
            child: Center(
              child: SizedBox(
                width: 150,
                child: DevicePreview(
                  palette: theme.palette,
                  mode: DevicePreviewMode.folder,
                  cols: cols,
                  rows: rows,
                  tileRadiusFraction: _radiusFraction(theme),
                ),
              ),
            ),
          ),

          // ── Folder grid ────────────────────────────────────────────────
          ThemedSectionHeader(context.t('settings.folderGrid')),

          ThemedListRow(
            icon: Icons.view_column_outlined,
            title: context.t('settings.columns'),
            subtitle: context.t('settings.appsPerRowInside'),
            trailing: _Stepper(
              value: cols,
              min: 3,
              max: 6,
              onChanged: (v) => notifier.edit((p) => p.copyWith(folderCols: v)),
            ),
          ),

          ThemedListRow(
            icon: Icons.table_rows_outlined,
            title: context.t('settings.rows'),
            subtitle: context.t('settings.howTallAFolder'),
            trailing: _Stepper(
              value: rows,
              min: 2,
              max: 5,
              onChanged: (v) => notifier.edit((p) => p.copyWith(folderRows: v)),
            ),
          ),

          // ── Shape ──────────────────────────────────────────────────────
          ThemedSectionHeader(context.t('settings.appearance')),

          ThemedListRow(
            icon: Icons.category_outlined,
            title: context.t('settings.folderShape'),
            // null follows the theme's icon treatment, which is the right
            // default: a folder should look like the icons it sits among
            // without anyone configuring it.
            subtitle: theme.prefs.folderShape == null
                ? 'Matches your icon shape'
                : _shapeLabel(theme.prefs.folderShape!),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => _showShapeSheet(context, notifier, theme),
          ),

          // ── Your folders ───────────────────────────────────────────────
          // Folders, suggestions and New folder in one grid. The bulk actions
          // that used to sit under it are in the title bar's menu.
          FolderGridSection(theme: theme),

          // ── Hidden apps ────────────────────────────────────────────────
          //
          // This lives HERE rather than in its own Settings group for one
          // practical reason: hiding is done from the drawer's long-press menu,
          // and UNHIDING cannot be, because a hidden app is not in the drawer to
          // long-press. Without this section the action is one-way, which is the
          // worst possible shape for a setting that removes things.
          ThemedSectionHeader(context.t('settings.hiddenApps')),

          // Find-by-name and the lock moved into Hide apps' own options.
          _HiddenAppsRow(theme: theme),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// The actions that act on every folder at once, in one sheet. Each is
  /// listed only when it would do something.
  void _bulkMenu(
    BuildContext context,
    PrefsNotifier notifier,
    EffectiveTheme theme,
    List<FolderSuggestion> suggestions,
  ) {
    final host = context;
    final prefs = theme.prefs;
    ThemedSheet.show<void>(
      context,
      title: context.t('settings.yourFolders'),
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (suggestions.length > 1)
            ThemedListRow(
              icon: Icons.auto_awesome_outlined,
              title: host.t('settings.createAllFolders', {
                'count': '${suggestions.length}',
              }),
              onTap: () {
                Navigator.pop(sheet);
                notifier.edit(
                  (p) => FolderSuggestions.acceptAll(
                    p,
                    suggestions,
                    newFolderId: newDrawerFolderId,
                  ),
                );
                host.showMessage(host.t('settings.foldersCreated'));
              },
            ),
          if (prefs.dismissedSuggestions.isNotEmpty)
            ThemedListRow(
              icon: Icons.refresh,
              title: host.t('settings.showDismissedSuggestions'),
              subtitle: host.t('settings.hiddenGroups', {
                'count': '${prefs.dismissedSuggestions.length}',
              }),
              onTap: () {
                Navigator.pop(sheet);
                notifier.edit(FolderSuggestions.clearDismissals);
              },
            ),
          if (PrefsReset.canReset(prefs, PrefsSection.folders))
            ThemedListRow(
              icon: Icons.settings_backup_restore,
              title: host.t('settings.resetFolderAppearance'),
              subtitle: host.t('settings.sizeAndShapeOnly'),
              onTap: () async {
                Navigator.pop(sheet);
                final ok = await ThemedDialog.confirm(
                  host,
                  title: host.t('settings.resetFolderAppearanceConfirm'),
                  message: host.t('settings.folderSizeShapeAnd'),
                  confirmLabel: host.t('settings.reset'),
                );
                if (ok != true) return;
                await notifier
                    .edit((p) => PrefsReset.section(p, PrefsSection.folders));
                if (host.mounted) {
                  host.showMessage(host.t('settings.folderAppearanceReset'));
                }
              },
            ),
          // Last, and confirmed: it undoes every grouping on the phone.
          if (prefs.drawerFolders.isNotEmpty)
            ThemedListRow(
              icon: Icons.folder_off_outlined,
              title: host.t('settings.ungroupAllFolders'),
              subtitle: host.t('settings.everyAppReturnsTo'),
              danger: true,
              onTap: () async {
                Navigator.pop(sheet);
                final ok = await ThemedDialog.confirm(
                  host,
                  title: host.t('settings.ungroupAllFoldersConfirm'),
                  message: host.t('settings.theAppsAreNot'),
                  confirmLabel: host.t('drawer.ungroup'),
                  danger: true,
                );
                if (ok != true) return;
                await notifier.edit(DrawerLayout.dissolveAll);
                if (host.mounted) {
                  host.showMessage(host.t('settings.allFoldersUngrouped'));
                }
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// The shape setting as a radius fraction, so the preview draws it. Mirrors
  /// `folderCornerRadius` in drawer_actions, which does the same job for the
  /// real tile; null still means "match my icon shape".
  static double _radiusFraction(EffectiveTheme theme) =>
      switch (theme.prefs.folderShape) {
        'circle' => 0.5,
        'square' => 0.0,
        'squircle' => 0.30,
        'roundedSquare' => 0.22,
        _ => theme.icons.cornerRadius,
      };

  static String _shapeLabel(String id) => switch (id) {
        'circle' => 'Circle',
        'squircle' => 'Squircle',
        'square' => 'Square',
        _ => 'Rounded square',
      };

  void _showShapeSheet(
    BuildContext context,
    PrefsNotifier notifier,
    EffectiveTheme theme,
  ) {
    // null first: "match my icons" is the default and the right answer for
    // most people, so it should not be buried under the explicit choices.
    const options = <String?>[
      null,
      'roundedSquare',
      'squircle',
      'circle',
      'square'
    ];
    final current = theme.prefs.folderShape;

    ThemedSheet.show<void>(
      context,
      title: context.t('settings.folderShape'),
      builder: (sheet) {
        final c = ChromeScope.of(sheet).colors;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              ThemedListRow(
                title: o == null ? 'Match my icon shape' : _shapeLabel(o),
                trailing: o == current
                    ? Icon(Icons.check, size: 20, color: c.accent)
                    : null,
                onTap: () {
                  Navigator.pop(sheet);
                  // copyWith cannot clear to null (the classic Dart trap), so
                  // "match my icons" goes through clearing().
                  notifier.edit(
                    (p) => o == null
                        ? p.clearing(folderShape: true)
                        : p.copyWith(folderShape: o),
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

/// A compact −/value/+ control. Steppers rather than a slider because these are
/// small integers where every value matters and a slider makes you fight for 4.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Btn(
          icon: Icons.remove,
          enabled: value > min,
          onTap: () => onChanged(value - 1),
        ),
        SizedBox(
          width: 34,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: d.text.value.copyWith(color: c.text),
          ),
        ),
        _Btn(
          icon: Icons.add,
          enabled: value < max,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 17,
          // Disabled reads as faint rather than vanishing: the control should
          // still look like a stepper at its limit.
          color: enabled ? c.text : c.textFaint,
        ),
      ),
    );
  }
}

/// The hidden apps entry: a count, and the way into Hide apps.
///
/// Reads [appListProvider] rather than [shellAppsProvider], and it has to:
/// shellApps is where hidden apps are FILTERED OUT, so asking it for the hidden
/// ones returns nothing and the row would honestly report "0 hidden" on a phone
/// with twenty. Resolved against the live list, so an app hidden and then
/// uninstalled is not counted.
///
/// Always enabled now: Hide apps is where hiding happens as well as undoing
/// it, so an empty set is a reason to open the page, not to grey the row.
class _HiddenAppsRow extends ConsumerWidget {
  const _HiddenAppsRow({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(appListProvider).asData?.value ?? const <AppEntry>[];
    final keys = theme.prefs.hiddenApps;
    final count = all.where((a) => keys.contains(a.componentKey)).length;
    final locked = ref.watch(hiddenLockProvider).asData?.value ?? false;

    return ThemedListRow(
      icon: locked ? Icons.lock_outline : Icons.visibility_off_outlined,
      title: context.t('hidden.title'),
      subtitle: count == 0
          ? context.t('hidden.rowEmpty')
          : context.t('hidden.rowCount', {'count': '$count'}),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => openHideApps(context, ref, theme),
    );
  }
}
