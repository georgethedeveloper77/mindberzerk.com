import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/drawer_layout.dart';
import '../../data/prefs/folder_suggestions.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/shell_apps.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../engine/effective_theme.dart';
import '../drawer/drawer_actions.dart';
import '../drawer/drawer_items.dart';
import '../../design/device_preview.dart';

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
    final theme = ref.watch(effectiveThemeProvider).asData?.value ?? this.theme;
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

    final apps = ref.watch(shellAppsProvider(theme));
    final suggestions = FolderSuggestions.propose(apps, theme.prefs);
    final folders = ref
        .watch(drawerItemsProvider(theme))
        .whereType<FolderDrawerItem>()
        .toList();

    final cols = theme.prefs.folderCols ?? 4;
    final rows = theme.prefs.folderRows ?? 3;

    return ThemedScaffold(
      title: 'Folders',
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
          const ThemedSectionHeader('Folder grid'),

          ThemedListRow(
            icon: Icons.view_column_outlined,
            title: 'Columns',
            subtitle: 'Apps per row inside an open folder',
            trailing: _Stepper(
              value: cols,
              min: 3,
              max: 6,
              onChanged: (v) => notifier.edit((p) => p.copyWith(folderCols: v)),
            ),
          ),

          ThemedListRow(
            icon: Icons.table_rows_outlined,
            title: 'Rows',
            subtitle: 'How tall a folder opens before it scrolls',
            trailing: _Stepper(
              value: rows,
              min: 2,
              max: 5,
              onChanged: (v) => notifier.edit((p) => p.copyWith(folderRows: v)),
            ),
          ),

          // ── Shape ──────────────────────────────────────────────────────
          const ThemedSectionHeader('Appearance'),

          ThemedListRow(
            icon: Icons.category_outlined,
            title: 'Folder shape',
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
          const ThemedSectionHeader('Your folders'),

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
                return ThemedListRow(
                  key: ValueKey(f.folder.id),
                  icon: Icons.folder_outlined,
                  title: f.folder.name,
                  subtitle: '${f.folder.members.length} apps',
                  trailing: ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_handle, size: 20),
                  ),
                  onTap: () => drawerFolderSettings(context, ref, theme, f),
                );
              },
            ),
            if (theme.prefs.folderOrderCustom == true)
              ThemedListRow(
                icon: Icons.sort_by_alpha,
                title: 'Sort folders A to Z',
                subtitle: 'Discards your manual order',
                onTap: () => notifier.edit(DrawerLayout.resetFolderOrder),
              ),
          ],

          // ── Suggestions ────────────────────────────────────────────────
          if (suggestions.isNotEmpty) ...[
            const ThemedSectionHeader('Suggested groups'),

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
                  context.showMessage('Folders created');
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
              title: 'Show dismissed suggestions',
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
      title: 'Folder shape',
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
              Icon(
                suggestion.kind == SuggestionKind.games
                    ? Icons.sports_esports_outlined
                    : Icons.business_outlined,
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
                label: 'Not now',
                kind: ThemedButtonKind.text,
                onPressed: onDismiss,
              ),
              const SizedBox(width: 8),
              ThemedButton(label: 'Create', onPressed: onAccept),
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
