// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/drawer_layout.dart';
import '../../data/prefs/hidden_apps.dart';
import '../../data/prefs/folder_suggestions.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/app_repository.dart';
import '../../data/repositories/shell_apps.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import 'package:g_launcher/i18n/i18n.dart';
import '../../design/device_preview.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../drawer/drawer_actions.dart';
import '../drawer/app_icon.dart';
import '../drawer/folder_glyph.dart';
import '../drawer/drawer_items.dart';

/// Folder settings — its own page, because folders grew past a row.
///
/// Four things live here, in the order you actually need them:
///  1. **Suggestions** — the auto-grouping proposals, accepted or dismissed one
///     at a time. Top of the page because they are the only part that expires:
///     the list shrinks as you act on it and is usually empty after a while.
///  2. **Folder grid** — columns and visible rows INSIDE an open folder.
///  3. **Folder shape** — how the folder tile itself is drawn.
///  4. **Your folders** — every folder you have, renameable and dissolvable
///     without hunting for it in the drawer.
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
    // Members are stored as component keys; the rows draw icons.
    final byKey = {for (final a in apps) a.componentKey: a};
    final suggestions = FolderSuggestions.propose(apps, theme.prefs);
    final folders = ref
        .watch(drawerItemsProvider(theme))
        .whereType<FolderDrawerItem>()
        .toList();

    final cols = theme.prefs.folderCols ?? 4;
    final rows = theme.prefs.folderRows ?? 3;

    return ThemedScaffold(
      // "Apps and folders", because hiding an app landed here and the page
      // stopped being only about folders. Naming it after half its contents is
      // how a setting becomes unfindable.
      title: context.t('settings.appsAndFolders'),
      body: ListView(
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

          // ── Existing folders ───────────────────────────────────────────
          ThemedSectionHeader(context.t('settings.yourFolders')),

          if (folders.isEmpty)
            const _Empty()
          else ...[
            // Drag to arrange. Alphabetical until you do, then your order is
            // the order of record — see DrawerLayout.orderedFolders.
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: folders.length,
              onReorder: (from, to) {
                // ReorderableListView reports `to` BEFORE the removal for
                // downward drags; normalise once here so the engine only ever
                // sees the post-removal index it documents.
                final target = to > from ? to - 1 : to;
                notifier.edit(
                  (p) => DrawerLayout.reorderFolders(p, from, target),
                );
              },
              itemBuilder: (context, i) {
                final f = folders[i];
                return _FolderRow(
                  key: ValueKey(f.folder.id),
                  theme: theme,
                  name: f.folder.name,
                  count: f.folder.members.length,
                  members: f.folder.members
                      .map((k) => byKey[k])
                      .whereType<AppEntry>()
                      .toList(),
                  index: i,
                  onTap: () => drawerFolderSettings(context, ref, theme, f),
                );
              },
            ),
            if (theme.prefs.folderOrderCustom == true)
              ThemedListRow(
                icon: Icons.sort_by_alpha,
                title: context.t('settings.sortFoldersATo'),
                subtitle: context.t('settings.discardsYourManualOrder'),
                onTap: () => notifier.edit(DrawerLayout.resetFolderOrder),
              ),
            // The bulk form of the Ungroup row every folder already carries in
            // its own sheet. Confirmed first: one tap here undoes every
            // grouping on the phone, and unlike a rename there is no single
            // obvious inverse to reach for afterwards. The wording leads with
            // what SURVIVES, because "remove" next to folders reads as
            // uninstall to someone skimming.
            ThemedListRow(
              icon: Icons.folder_off_outlined,
              title: 'Ungroup all folders',
              subtitle: 'Every app returns to the list',
              onTap: () async {
                final ok = await ThemedDialog.confirm(
                  context,
                  title: 'Ungroup all folders?',
                  message: 'The apps are not touched. They leave their '
                      'folders and return to the list, and the folders '
                      'themselves are removed.',
                  confirmLabel: 'Ungroup',
                  danger: true,
                );
                if (ok != true) return;
                await notifier.edit(DrawerLayout.dissolveAll);
                if (context.mounted) {
                  context.showMessage('All folders ungrouped');
                }
              },
            ),
          ],

          // ── Hidden apps ────────────────────────────────────────────────
          //
          // This lives HERE rather than in its own Settings group for one
          // practical reason: hiding is done from the drawer's long-press menu,
          // and UNHIDING cannot be, because a hidden app is not in the drawer to
          // long-press. Without this section the action is one-way, which is the
          // worst possible shape for a setting that removes things.
          ThemedSectionHeader(context.t('settings.hiddenApps')),

          _HiddenAppsRow(theme: theme),

          ThemedListRow(
            icon: Icons.manage_search,
            title: context.t('settings.findHiddenAppsBy'),
            subtitle: context.t('settings.onlyWhenYouType'),
            trailing: ThemedToggle(
              value: HiddenApps.searchable(theme.prefs),
              onChanged: (v) => notifier.edit(
                (p) => p.copyWith(hiddenAppsSearchable: v),
              ),
            ),
          ),

          // ── Suggestions ────────────────────────────────────────────────
          if (suggestions.isNotEmpty) ...[
            ThemedSectionHeader(context.t('settings.suggestedGroups')),

            // One tap for all of them. Most people who want any of these want
            // all of them, and making them accept four cards one at a time is
            // the kind of friction that gets a good feature ignored.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: ThemedButton(
                label: 'Create all ${suggestions.length} folders',
                icon: Icons.auto_awesome_outlined,
                expand: true,
                onPressed: () {
                  notifier.edit(
                    (p) => FolderSuggestions.acceptAll(
                      p,
                      suggestions,
                      newFolderId: newDrawerFolderId,
                    ),
                  );
                  context.showMessage(context.t('settings.foldersCreated'));
                },
              ),
            ),

            for (final s in suggestions)
              _SuggestionRow(
                suggestion: s,
                onAccept: () {
                  notifier.edit(
                    (p) => FolderSuggestions.accept(
                      p,
                      s,
                      newFolderId: newDrawerFolderId,
                    ),
                  );
                  context.showMessage('${s.name} folder created');
                },
                onDismiss: () => notifier.edit(
                  (p) => FolderSuggestions.dismiss(p, s),
                ),
              ),
          ],

          if (theme.prefs.dismissedSuggestions.isNotEmpty)
            ThemedListRow(
              icon: Icons.refresh,
              title: context.t('settings.showDismissedSuggestions'),
              subtitle:
                  '${theme.prefs.dismissedSuggestions.length} hidden group(s)',
              onTap: () => notifier.edit(FolderSuggestions.clearDismissals),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// The shape setting as a radius fraction, so the preview draws it. Mirrors
  /// `folderCornerRadius` in drawer_actions, which does the same job for the
  /// real tile — null still means "match my icon shape".
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
                  // copyWith cannot clear to null — the classic Dart trap — so
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

/// One proposal: what it would make, and the two things you can do about it.
///
/// Accept and Dismiss are both plainly visible — no swipe, no long-press. A
/// suggestion the user cannot obviously refuse reads as the launcher having
/// already decided.
/// One folder in the list, drawn as a FOLDER.
///
/// ─── WHY NOT ThemedListRow ──────────────────────────────────────────────────
///
/// It takes `icon: IconData`, so the leading slot can only ever be a glyph from
/// the icon font, and `Icons.folder_outlined` is exactly the generic outline
/// this screen was asked to stop using. Widening that primitive to accept an
/// arbitrary leading widget would touch every settings row in the app to serve
/// one screen.
///
/// So this builds its own row from the same chrome tokens, which is the idiom
/// [_SuggestionRow] directly below already uses for the same reason.
class _FolderRow extends StatelessWidget {
  const _FolderRow({
    super.key,
    required this.theme,
    required this.name,
    required this.count,
    required this.members,
    required this.index,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final String name;
  final int count;
  final List<AppEntry> members;

  /// The reorderable list's index, for the drag listener.
  final int index;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Row(
          children: [
            FolderGlyph(theme: theme, size: 42, members: members),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: d.text.body),
                  Text(
                    count == 1 ? '1 app' : '$count apps',
                    style: d.text.caption.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.drag_handle, size: 20, color: c.textFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.suggestion,
    required this.onAccept,
    required this.onDismiss,
  });

  final FolderSuggestion suggestion;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Exhaustive switch, not a ternary: a ternary silently gave the
              // new Social kind the publisher icon, which is the failure mode
              // where adding a case looks like it worked.
              Icon(
                switch (suggestion.kind) {
                  SuggestionKind.games => Icons.sports_esports_outlined,
                  SuggestionKind.social => Icons.forum_outlined,
                  SuggestionKind.publisher => Icons.business_outlined,
                },
                size: 20,
                color: c.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(suggestion.name, style: d.text.title),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Group ${suggestion.size} apps into a folder',
            style: d.text.caption,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ThemedButton(
                label: context.t('settings.notNow'),
                kind: ThemedButtonKind.text,
                onPressed: onDismiss,
              ),
              const SizedBox(width: 8),
              ThemedButton(label: context.t('settings.create'), onPressed: onAccept),
            ],
          ),
        ],
      ),
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

/// The hidden set, and the only way back out of it.
///
/// Reads [appListProvider] rather than [shellAppsProvider], and it has to:
/// shellApps is where hidden apps are FILTERED OUT, so asking it for the hidden
/// ones returns nothing and the row would honestly report "0 hidden" on a phone
/// with twenty. That is the sort of bug that reads as the feature not saving.
class _HiddenAppsRow extends ConsumerWidget {
  const _HiddenAppsRow({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(appListProvider).asData?.value ?? const <AppEntry>[];
    final keys = theme.prefs.hiddenApps;

    // Resolved against the live app list, so an app hidden and then uninstalled
    // does not sit in this list as a name with nothing behind it.
    final hidden = [
      for (final a in all)
        if (keys.contains(a.componentKey)) a,
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    return ThemedListRow(
      icon: Icons.visibility_off_outlined,
      title: context.t('settings.hiddenApps'),
      subtitle: hidden.isEmpty
          ? 'Hold an app in the drawer to hide it'
          : '${hidden.length} hidden',
      enabled: hidden.isNotEmpty,
      trailing: hidden.isEmpty
          ? null
          : const Icon(Icons.chevron_right, size: 18),
      onTap: hidden.isEmpty ? null : () => _show(context, ref, hidden),
    );
  }

  void _show(BuildContext context, WidgetRef ref, List<AppEntry> hidden) {
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

    ThemedSheet.show<void>(
      context,
      title: context.t('settings.hiddenApps'),
      isScrollControlled: true,
      builder: (sheet) => Consumer(
        builder: (ctx, r, __) {
          // Live inside the sheet: unhiding must remove the row under your
          // finger, or the only feedback is the count on the page behind.
          // hasValue, not asData: unhiding an app is itself a prefs write, so
          // with asData this sheet fell back to the stale snapshot on the very
          // action it exists to reflect.
          final liveAsync = r.watch(effectiveThemeProvider);
          final live = liveAsync.hasValue ? liveAsync.requireValue : theme;
          final keys = live.prefs.hiddenApps;
          final rows = [
            for (final a in hidden)
              if (keys.contains(a.componentKey)) a,
          ];

          if (rows.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Text(
                'Nothing is hidden.',
                style: ChromeScope.of(ctx).text.caption,
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final a = rows[i];
                    final c = ChromeScope.of(ctx).colors;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => notifier.edit(
                        (p) => HiddenApps.unhide(p, a.componentKey),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            AppIcon(entry: a, size: 32),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                a.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ChromeScope.of(ctx).text.body,
                              ),
                            ),
                            // "Unhide", spelled out. An eye glyph alone is
                            // ambiguous about which state it is describing —
                            // the current one or the one you get by tapping.
                            Text(
                              'Unhide',
                              style: ChromeScope.of(ctx)
                                  .text
                                  .caption
                                  .copyWith(color: c.accent),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: ThemedButton(
                  label: context.t('settings.unhideAll'),
                  kind: ThemedButtonKind.text,
                  expand: true,
                  onPressed: () {
                    Navigator.pop(sheet);
                    notifier.edit(HiddenApps.unhideAll);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        'Drag one app onto another in the drawer to make a folder.',
        style: d.text.caption,
      ),
    );
  }
}
