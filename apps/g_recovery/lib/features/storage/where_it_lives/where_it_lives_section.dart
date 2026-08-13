library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/storage_api.g.dart';
import '../../../core/format.dart';
import '../../../ui/g_view_switch.dart';
import 'folder_entry.dart';
import 'folder_map.dart';
import 'known_folders.dart';

/// Which way the section is showing itself.
///
/// Its own controller rather than GViewModeController, because that one is the
/// app wide grid and list choice for files. Toggling a map here must not
/// reformat every file list in the app.
///
/// NOT PERSISTED YET, for the same reason the file view mode is not: it needs a
/// key in GPrefsKeys and adding one blind is how a prefs file ends up with two
/// spellings of the same setting.
class WhereItLivesViewController extends Notifier<WhereItLivesView> {
  @override
  WhereItLivesView build() => WhereItLivesView.map;

  void select(WhereItLivesView view) {
    if (view == state) return;
    state = view;
  }
}

final NotifierProvider<WhereItLivesViewController, WhereItLivesView>
whereItLivesViewProvider =
    NotifierProvider<WhereItLivesViewController, WhereItLivesView>(
      WhereItLivesViewController.new,
    );

/// Where the storage actually sits, as a map or as a ranked list.
///
/// The map answers "what does my storage look like" and the list answers "what
/// do I open next". Both draw the same folders in the same order and lead to the
/// same place, so neither is a lesser view.
class WhereItLivesSection extends ConsumerStatefulWidget {
  const WhereItLivesSection({
    required this.folders,
    required this.overline,
    required this.onOpen,
    super.key,
  });

  final List<FolderUsage> folders;

  /// The section heading, passed in so this widget does not need to know which
  /// heading component the page uses.
  final Widget overline;

  final void Function(FolderEntry folder) onOpen;

  @override
  ConsumerState<WhereItLivesSection> createState() =>
      _WhereItLivesSectionState();
}

class _WhereItLivesSectionState extends ConsumerState<WhereItLivesSection> {
  /// Rows past the fifth, revealed by the tail row. The map has no equivalent:
  /// past four tiles a phone cannot label them, so the map sends you here.
  bool _expanded = false;

  /// Below this many folders a map is a bar chart in costume, so the toggle
  /// disappears and the list stands alone.
  static const int _minimumForMap = 4;

  /// Rows before the tail. One more than the map draws, because a row costs far
  /// less height than a tile.
  static const int _rowsBeforeTail = 5;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    // Merged before anything is drawn. Native returns folders at whatever depth
    // it walked to, so a dozen WhatsApp media directories and every per app
    // trash folder arrive separately. Summing them under one key is what stops
    // the map spending three of its four tiles on the same thing.
    final Map<String, int> merged = <String, int>{};
    for (final FolderUsage folder in widget.folders) {
      if (folder.totalBytes <= 0) continue;
      final String key = folderGroupKey(folder.path);
      merged[key] = (merged[key] ?? 0) + folder.totalBytes;
    }

    final List<FolderEntry> entries = <FolderEntry>[
      for (final MapEntry<String, int> e in merged.entries)
        folderEntryFor(path: e.key, bytes: e.value),
    ]..sort((FolderEntry a, FolderEntry b) => b.bytes.compareTo(a.bytes));

    if (entries.isEmpty) return const SizedBox.shrink();

    final int total = entries.fold<int>(
      0,
      (int sum, FolderEntry e) => sum + e.bytes,
    );

    final bool canMap = entries.length >= _minimumForMap;
    final WhereItLivesView view = canMap
        ? ref.watch(whereItLivesViewProvider)
        : WhereItLivesView.list;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: widget.overline),
            if (canMap)
              GSegmentedIcons(
                index: view == WhereItLivesView.map ? 0 : 1,
                icons: const <IconData>[
                  Icons.view_quilt_rounded,
                  Icons.view_list_rounded,
                ],
                labels: const <String>['Map', 'List'],
                onChanged: (int index) => ref
                    .read(whereItLivesViewProvider.notifier)
                    .select(
                      index == 0 ? WhereItLivesView.map : WhereItLivesView.list,
                    ),
              ),
          ],
        ),
        const SizedBox(height: GSpace.sm),
        Text(
          '${GFormat.count(entries.length)} folders hold '
          '${GFormat.bytes(total)}',
          style: GType.micro.copyWith(color: t.dim),
        ),
        const SizedBox(height: GSpace.md),
        if (view == WhereItLivesView.map)
          FolderMap(
            folders: entries,
            totalBytes: total,
            tintFor: (FolderEntry f) => _tint(t, f.kind),
            restTint: t.dim,
            titleStyle: GType.micro.copyWith(
              color: t.text,
              fontWeight: FontWeight.w600,
            ),
            subtitleStyle: GType.monoSmall.copyWith(
              color: t.muted,
              fontSize: 9.5,
            ),
            formatBytes: GFormat.bytes,
            onTapFolder: widget.onOpen,
            onTapRest: () {
              setState(() => _expanded = true);
              ref
                  .read(whereItLivesViewProvider.notifier)
                  .select(WhereItLivesView.list);
            },
          )
        else
          _list(t, entries, total),
      ],
    );
  }

  Widget _list(GTokens t, List<FolderEntry> entries, int total) {
    final bool folds = !_expanded && entries.length > _rowsBeforeTail;
    final List<FolderEntry> shown = folds
        ? entries.take(_rowsBeforeTail).toList(growable: false)
        : entries;

    final int restBytes = folds
        ? entries
              .skip(_rowsBeforeTail)
              .fold<int>(0, (int sum, FolderEntry e) => sum + e.bytes)
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final FolderEntry entry in shown) _row(t, entry, total),
        if (folds) _tailRow(t, entries.length - _rowsBeforeTail, restBytes),
      ],
    );
  }

  Widget _row(GTokens t, FolderEntry entry, int total) {
    final Color tint = _tint(t, entry.kind);
    final double share = entry.shareOf(total);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: GRadius.all(GRadius.tile),
        onTap: () => widget.onOpen(entry),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: GSpace.sm + 2,
            horizontal: GSpace.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GType.bodySmall.copyWith(color: t.text),
                    ),
                  ),
                  const SizedBox(width: GSpace.sm),
                  Text(
                    GFormat.bytes(entry.bytes),
                    style: GType.monoSmall.copyWith(color: t.text),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      entry.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GType.micro.copyWith(color: t.dim),
                    ),
                  ),
                  const SizedBox(width: GSpace.sm),
                  Text(
                    GFormat.percent(share),
                    style: GType.micro.copyWith(color: t.dim),
                  ),
                ],
              ),
              const SizedBox(height: GSpace.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Container(
                  height: 4,
                  color: t.panelAlt,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: share == 0 ? 0.004 : share,
                    child: ColoredBox(color: tint),
                  ),
                ),
              ),
              if (entry.regenerable) ...<Widget>[
                const SizedBox(height: GSpace.sm),
                Text(
                  'Rebuilds itself',
                  style: GType.micro.copyWith(color: t.accentText),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tailRow(GTokens t, int count, int bytes) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: GRadius.all(GRadius.tile),
        onTap: () => setState(() => _expanded = true),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: GSpace.md - 2,
            horizontal: GSpace.xs,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${GFormat.count(count)} smaller folders',
                  style: GType.bodySmall.copyWith(color: t.accentText),
                ),
              ),
              Text(
                GFormat.bytes(bytes),
                style: GType.monoSmall.copyWith(color: t.dim),
              ),
              const SizedBox(width: GSpace.xs),
              Icon(Icons.expand_more_rounded, size: 18, color: t.dim),
            ],
          ),
        ),
      ),
    );
  }

  /// Colour is a hint from the folder, not a measurement of its contents, so it
  /// carries no figure and drives no action.
  Color _tint(GTokens t, FolderKind kind) {
    switch (kind) {
      case FolderKind.photos:
        return t.photo;
      case FolderKind.video:
        return t.video;
      case FolderKind.audio:
        return t.audio;
      case FolderKind.docs:
        return t.docs;
      case FolderKind.apps:
        return t.chat;
      case FolderKind.cache:
        return t.dim;
      case FolderKind.other:
        return t.apps;
    }
  }
}
