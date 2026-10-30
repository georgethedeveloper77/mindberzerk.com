import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';

import '../../data/prefs/drawer_layout.dart';
import '../../data/prefs/folder_suggestions.dart';
import '../../data/prefs/launcher_prefs.dart';
import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/shell_apps.dart';
import '../../data/search/search_text.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';
import '../drawer/app_icon.dart';
import '../drawer/drawer_actions.dart';
import '../drawer/drawer_items.dart';
import '../drawer/folder_glyph.dart';
import '../drawer/folder_glyph_picker.dart';
import '../drawer/folder_glyphs.dart' show kFolderGlyphCleared;

/// Your folders, as a grid of real folder tiles.
///
/// ─── ONE GRID FOR WHAT YOU MADE AND WHAT IS SUGGESTED ───────────────────────
///
/// Folders, suggested groups (dashed, with Create on them) and a New folder
/// tile share one two-column grid, so there is one place to look instead of
/// a list, a suggestions section and a "drag one app onto another" hint.
///
/// ─── THE TILE IS THE DRAWER'S TILE ──────────────────────────────────────────
///
/// [FolderGlyph] at a larger size, in the folder's own shape and glyph, and
/// tapping it opens the same overlay the drawer opens. This page cannot show
/// a folder the drawer would draw differently.
///
/// Reads `drawerFolders` directly rather than the drawer's items, because
/// under Library grouping those include generated category folders, which
/// are not the person's and cannot be reordered.
class FolderGridSection extends ConsumerWidget {
  const FolderGridSection({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ChromeScope.of(context);
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
    final apps = ref.watch(shellAppsProvider(theme));
    final byKey = {for (final a in apps) a.componentKey: a};
    final folders = DrawerLayout.orderedFolders(theme.prefs);
    final suggestions = FolderSuggestions.propose(apps, theme.prefs);
    final custom = theme.prefs.folderOrderCustom == true;

    final tiles = <Widget>[
      for (var i = 0; i < folders.length; i++)
        _ReorderTarget(
          key: ValueKey(folders[i].id),
          index: i,
          onMove: (from, to) =>
              notifier.edit((p) => DrawerLayout.reorderFolders(p, from, to)),
          child: _FolderCard(
            theme: theme,
            folder: folders[i],
            members: [
              for (final k in folders[i].members)
                if (byKey[k] != null) byKey[k]!,
            ],
          ),
        ),
      for (final s in suggestions)
        _SuggestionCard(
          key: ValueKey('suggest:${s.id}'),
          suggestion: s,
          onCreate: () {
            notifier.edit(
              (p) => FolderSuggestions.accept(
                p,
                s,
                newFolderId: newDrawerFolderId,
              ),
            );
            context.showMessage(
              context.t('settings.folderCreated', {'name': s.name}),
            );
          },
          onDismiss: () {
            HapticFeedback.mediumImpact();
            notifier.edit((p) => FolderSuggestions.dismiss(p, s));
            context.showMessage(
              context.t('folders.suggestionDismissed', {'name': s.name}),
            );
          },
        ),
      _NewFolderCard(
        key: const ValueKey('new-folder'),
        onTap: () => pickFolderApps(context, ref, theme),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: context.t('settings.yourFolders'),
                    children: [
                      if (folders.isNotEmpty)
                        TextSpan(
                          text: '  ${folders.length}',
                          style: d.text.caption,
                        ),
                    ],
                  ),
                  style: d.text.title,
                ),
              ),
              if (folders.length > 1)
                _OrderChip(
                  custom: custom,
                  onPick: (wantCustom) => notifier.edit(
                    (p) => wantCustom
                        ? p.copyWith(
                            drawerFolders: DrawerLayout.orderedFolders(p),
                            folderOrderCustom: true,
                          )
                        : DrawerLayout.resetFolderOrder(p),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.92,
            children: tiles,
          ),
        ),
        if (folders.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              context.t('folders.holdToReorder'),
              style: d.text.caption,
            ),
          ),
      ],
    );
  }
}

/// Alphabetical or Custom order, in a sheet.
class _OrderChip extends StatelessWidget {
  const _OrderChip({required this.custom, required this.onPick});

  final bool custom;
  final ValueChanged<bool> onPick;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => ThemedSheet.show<void>(
        context,
        title: context.t('folders.order'),
        builder: (sheet) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in const [false, true])
              ThemedListRow(
                icon: option ? Icons.drag_indicator : Icons.sort_by_alpha,
                title: context.t(
                  option ? 'folders.orderCustom' : 'folders.orderAz',
                ),
                subtitle: option
                    ? context.t('folders.orderCustomSub')
                    : context.t('settings.discardsYourManualOrder'),
                trailing: option == custom
                    ? Icon(Icons.check, size: 20, color: c.accent)
                    : null,
                onTap: () {
                  Navigator.pop(sheet);
                  if (option != custom) onPick(option);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.t(custom ? 'folders.orderCustom' : 'folders.orderAz'),
              style: d.text.caption.copyWith(color: c.text),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Hold to pick a tile up, drop it on another to put it there.
///
/// Dropping uses the post-removal index [DrawerLayout.reorderFolders]
/// documents: a tile dragged forward lands after its target, one dragged
/// back lands before it, which is how a home screen grid behaves.
class _ReorderTarget extends StatelessWidget {
  const _ReorderTarget({
    super.key,
    required this.index,
    required this.onMove,
    required this.child,
  });

  final int index;
  final void Function(int from, int to) onMove;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    return LayoutBuilder(
      builder: (context, box) => DragTarget<int>(
        onWillAcceptWithDetails: (d) => d.data != index,
        onAcceptWithDetails: (d) {
          HapticFeedback.selectionClick();
          onMove(d.data, index);
        },
        builder: (context, hovering, _) => LongPressDraggable<int>(
          data: index,
          hapticFeedbackOnStart: true,
          feedback: SizedBox(
            width: box.maxWidth,
            height: box.maxHeight,
            child: Material(
              type: MaterialType.transparency,
              child: Opacity(opacity: 0.9, child: child),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hovering.isNotEmpty ? c.accent : Colors.transparent,
                width: 2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// One folder: its real tile, name, count, and a ⋮ for the rest.
class _FolderCard extends ConsumerWidget {
  const _FolderCard({
    required this.theme,
    required this.folder,
    required this.members,
  });

  final EffectiveTheme theme;
  final AppFolder folder;
  final List<AppEntry> members;

  FolderDrawerItem get _item => FolderDrawerItem(folder, members);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openDrawerFolder(context, ref, theme, _item),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Center(
                      child: FolderGlyph(
                        theme: theme,
                        size: 72,
                        members: members,
                        glyph: folder.glyph,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    folder.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: d.text.body,
                  ),
                  Text(
                    context.t('folders.appCount', {'n': '${members.length}'}),
                    style: d.text.caption,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Builder(
                builder: (anchor) => IconButton(
                  icon: Icon(Icons.more_vert, size: 20, color: c.textMuted),
                  tooltip: context.t('folders.folderOptions'),
                  onPressed: () => _menu(anchor, ref),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext anchor, WidgetRef ref) {
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
    final host = anchor;
    return AnchoredMenu.show(
      context: anchor,
      chrome: ChromeScope.of(anchor),
      anchor: AnchoredMenu.anchorOf(anchor),
      title: folder.name,
      width: 236,
      rows: (menu) => [
        ThemedListRow(
          icon: Icons.drive_file_rename_outline,
          title: host.t('drawer.renameFolder'),
          onTap: () {
            Navigator.pop(menu);
            renameDrawerFolder(
              host,
              ref,
              theme,
              folderId: folder.id,
              currentName: folder.name,
            );
          },
        ),
        ThemedListRow(
          icon: Icons.emoji_symbols_outlined,
          title: host.t('drawer.folderIcon'),
          onTap: () async {
            Navigator.pop(menu);
            final picked =
                await showFolderGlyphPicker(host, current: folder.glyph);
            // Null is cancelled; the sentinel is "back to the folder".
            if (picked == null) return;
            await notifier.edit(
              (p) => DrawerLayout.setGlyph(
                p,
                folder.id,
                picked == kFolderGlyphCleared ? null : picked,
              ),
            );
          },
        ),
        ThemedListRow(
          icon: Icons.add_circle_outline,
          title: host.t('drawer.addAppsToThis'),
          onTap: () {
            Navigator.pop(menu);
            pickFolderApps(host, ref, theme, into: folder);
          },
        ),
        ThemedListRow(
          icon: Icons.folder_off_outlined,
          title: host.t('drawer.ungroup'),
          subtitle: host.t('drawer.theAppsReturnTo'),
          danger: true,
          onTap: () {
            Navigator.pop(menu);
            notifier.edit((p) => DrawerLayout.dissolve(p, folder.id));
          },
        ),
      ],
    );
  }
}

/// A suggested group, drawn as a dashed ghost of the folder it would make.
/// Tap Create to make it; hold to dismiss it.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    super.key,
    required this.suggestion,
    required this.onCreate,
    required this.onDismiss,
  });

  final FolderSuggestion suggestion;
  final VoidCallback onCreate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    final icon = switch (suggestion.kind) {
      SuggestionKind.games => Icons.sports_esports_outlined,
      SuggestionKind.social => Icons.forum_outlined,
      SuggestionKind.publisher => Icons.business_outlined,
    };
    return GestureDetector(
      onLongPress: onDismiss,
      child: CustomPaint(
        painter: _DashedBorder(color: c.accent, radius: 16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onCreate,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child:
                        Center(child: Icon(icon, size: 40, color: c.accent))),
                const SizedBox(height: 8),
                Text(
                  suggestion.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: d.text.body,
                ),
                Text(
                  context.t('folders.suggested', {
                    'n': '${suggestion.componentKeys.length}',
                  }),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: d.text.caption,
                ),
                Text(
                  context.t('settings.create'),
                  style: d.text.caption.copyWith(color: c.accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewFolderCard extends StatelessWidget {
  const _NewFolderCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    return CustomPaint(
      painter: _DashedBorder(color: c.lineStrong, radius: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.create_new_folder_outlined, size: 34, color: c.text),
              const SizedBox(height: 6),
              Text(context.t('folders.newFolder'), style: d.text.caption),
            ],
          ),
        ),
      ),
    );
  }
}

/// A rounded dashed outline, for tiles that are not folders yet.
class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(0.75),
        Radius.circular(radius),
      ));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}

/// Make a folder from a picker, or with [into], add apps to one.
///
/// Hidden apps are not offered (they come from `shellAppsProvider`). An app
/// already in another folder is offered with a badge and MOVED when ticked:
/// here the person is choosing on purpose, which is the case the drawer's
/// refusal to move silently does not cover.
Future<void> pickFolderApps(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme, {
  AppFolder? into,
}) async {
  final result = await ThemedSheet.show<({String name, List<String> keys})>(
    context,
    title: into == null
        ? context.t('folders.newFolder')
        : context.t('folders.addTo', {'name': into.name}),
    isScrollControlled: true,
    builder: (_) => _FolderPicker(theme: theme, into: into),
  );
  if (result == null || result.keys.isEmpty) return;

  final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
  await notifier.edit((p) {
    var next = p;
    // Out of wherever they are first, so the add below is never refused.
    // dissolveBelow 2 keeps the drawer's rule: a folder left with one app
    // goes back to being that app.
    for (final k in result.keys) {
      final from = DrawerLayout.folderOf(next, k);
      if (from != null && from.id != into?.id) {
        next = DrawerLayout.removeFromFolder(next, from.id, k);
      }
    }
    if (into != null) {
      for (final k in result.keys) {
        next = DrawerLayout.addToFolder(next, into.id, k);
      }
      return next;
    }
    return DrawerLayout.materialise(
      next,
      result.name,
      result.keys,
      newFolderId: newDrawerFolderId,
    );
  });
}

class _FolderPicker extends ConsumerStatefulWidget {
  const _FolderPicker({required this.theme, this.into});

  final EffectiveTheme theme;
  final AppFolder? into;

  @override
  ConsumerState<_FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends ConsumerState<_FolderPicker> {
  final _name = TextEditingController();
  final _search = TextEditingController();
  final _picked = <String>[];
  String _query = '';

  bool get _adding => widget.into != null;

  /// The drawer's minimum for a new folder; adding needs just one.
  int get _needed => _adding ? 1 : 2;

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  String _resolvedName(Map<String, AppEntry> byKey) {
    final typed = _name.text.trim();
    if (typed.isNotEmpty) return typed;
    // The first pick's category, which is usually what the group is.
    final first = _picked.isEmpty ? null : byKey[_picked.first];
    final category = first == null
        ? null
        : CategorySet.forTheme(widget.theme).nameFor(first);
    return category ?? defaultFolderName;
  }

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    final theme = widget.theme;
    final prefs = theme.prefs;
    final apps = [...ref.watch(shellAppsProvider(theme))]..sort(
        (a, b) => SearchText.fold(a.label).compareTo(SearchText.fold(b.label)),
      );
    final byKey = {for (final a in apps) a.componentKey: a};
    final members = widget.into?.members.toSet() ?? const <String>{};
    final shown = [
      for (final a in apps)
        if (!members.contains(a.componentKey) &&
            (_query.isEmpty || SearchText.contains(a.label, _query)))
          a,
    ];
    final ready = _picked.length >= _needed;
    final height = MediaQuery.sizeOf(context).height * 0.78;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_adding)
              _field(
                d,
                controller: _name,
                hint: context.t('folders.nameHint'),
                icon: Icons.folder_outlined,
              ),
            _field(
              d,
              controller: _search,
              hint: context.t('drawer.search'),
              icon: Icons.search,
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 10,
                ),
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final a = shown[i];
                  final picked = _picked.contains(a.componentKey);
                  final elsewhere =
                      DrawerLayout.folderOf(prefs, a.componentKey);
                  return _PickCell(
                    entry: a,
                    iconSize: theme.iconSizeDp,
                    picked: picked,
                    badge: elsewhere?.name,
                    onTap: () => setState(() {
                      HapticFeedback.selectionClick();
                      picked
                          ? _picked.remove(a.componentKey)
                          : _picked.add(a.componentKey);
                    }),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12 + context.bottomInset),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t('folders.selected', {'n': '${_picked.length}'}),
                      style: d.text.caption,
                    ),
                  ),
                  ThemedButton(
                    label: context.t('common.cancel'),
                    kind: ThemedButtonKind.text,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  ThemedButton(
                    label:
                        context.t(_adding ? 'folders.add' : 'settings.create'),
                    onPressed: ready
                        ? () => Navigator.of(context).pop((
                              name: _resolvedName(byKey),
                              keys: List<String>.of(_picked),
                            ))
                        : null,
                  ),
                ],
              ),
            ),
            if (!ready)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  context.t(
                    _adding ? 'folders.pickOne' : 'folders.pickTwo',
                  ),
                  style: d.text.caption.copyWith(color: c.textFaint),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    ChromeData d, {
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    ValueChanged<String>? onChanged,
  }) {
    final c = d.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: c.line),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: d.text.body,
                cursorColor: c.accent,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: d.text.body.copyWith(color: c.textFaint),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One app in the picker: icon, label, tick ring, and the folder it is in.
class _PickCell extends StatelessWidget {
  const _PickCell({
    required this.entry,
    required this.iconSize,
    required this.picked,
    required this.onTap,
    this.badge,
  });

  final AppEntry entry;
  final double iconSize;
  final bool picked;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = ChromeScope.of(context);
    final c = d.colors;
    return Semantics(
      checked: picked,
      button: true,
      label: entry.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AppIcon(entry: entry, size: iconSize),
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: picked ? c.accent : c.bg.withValues(alpha: 0.7),
                      border: Border.all(
                        color: picked ? c.accent : c.textMuted,
                        width: 1.5,
                      ),
                    ),
                    child: picked
                        ? Icon(Icons.check, size: 13, color: c.onAccent)
                        : null,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    bottom: -4,
                    left: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.line),
                      ),
                      child: Icon(
                        Icons.folder,
                        size: 11,
                        color: c.textMuted,
                        semanticLabel: badge,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: d.text.caption.copyWith(color: c.text),
            ),
          ],
        ),
      ),
    );
  }
}
