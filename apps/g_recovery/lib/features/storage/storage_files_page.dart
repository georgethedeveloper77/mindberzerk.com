import '../../app/theme/category_colors.dart';
import '../../app/theme/tokens.dart';
import '../../bridge/storage_api.g.dart';
import '../../core/date_groups.dart';
import '../../core/format.dart';
import '../../core/messenger/g_message.dart';
import '../../core/messenger/g_messenger.dart';
import '../../ui/g_app_bar.dart';
import '../../ui/g_button.dart';
import '../../ui/g_card.dart';
import '../../ui/g_count_up.dart';
import '../../ui/g_detail_page.dart';
import '../../ui/g_empty_state.dart';
import '../../ui/g_group_header.dart';
import '../../ui/g_sheet.dart';
import '../../ui/g_sort.dart';
import '../../ui/g_view_switch.dart';
import 'dart:typed_data';
import 'file_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'state/storage_files.dart';
import 'state/storage_providers.dart';
import '../../core/i18n/g_strings.dart';

/// EVERYTHING OF ONE KIND, BY DAY.
///
/// The other half of the storage tab. The ledger says where the space went; this
/// is where a person actually gets it back, and until now the legend rows had
/// chevrons that led nowhere.
///
/// Same grammar as the recovery grid on purpose: date headers with a count and a
/// size, a square cell with a stamp, long press to select. A user who learned it
/// on one screen should not have to learn it again on the other.
///
/// ─── THESE FILES ARE NOT DELETED ─────────────────────────────────────────────
///
/// Every difference from the recovery grid follows from that. There is no expiry
/// stamp because nothing here is expiring, no fidelity because everything is the
/// original, and the primary action is to REMOVE rather than restore. The stamp
/// slot carries size instead.
class StorageFilesPage extends ConsumerStatefulWidget {
  const StorageFilesPage({required this.scope, super.key});

  final StorageScope scope;

  static Route<void> route(StorageScope scope) => MaterialPageRoute<void>(
    builder: (BuildContext context) => StorageFilesPage(scope: scope),
  );

  @override
  ConsumerState<StorageFilesPage> createState() => _StorageFilesPageState();
}

class _StorageFilesPageState extends ConsumerState<StorageFilesPage> {
  @override
  void initState() {
    super.initState();
    // A scope can declare the order it is about.
    //
    // "Biggest files" opening on newest first is the page contradicting its own
    // title. Applied once, on the way in, and the user can change it afterwards
    // like any other page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(gSortProvider.notifier).select(widget.scope.sort);
    });
  }

  /// Selection is local to this page.
  ///
  /// Unlike the recovery grid, which shares one app wide set because a restore
  /// can be started from three different screens. Nothing else in the app acts
  /// on storage file ids, so keeping them here means they cannot leak into a
  /// category page and arm a bar over items that are not in its list.
  final Set<String> _picked = <String>{};

  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    // The scope carries the order, so changing sort makes a new family key and
    // native re-queries the whole library rather than reordering this page.
    final GSortMode sort = ref.watch(gSortProvider);
    final StorageScope scope = widget.scope.sorted(sort);
    final StorageQueryResult? result = ref
        .watch(storageFilesProvider(scope))
        .value;
    final List<StorageFile> files = result?.files ?? const <StorageFile>[];

    // Anything picked that is no longer in the list, after a delete, stops
    // counting. The set is not cleared on rebuild because a failed removal
    // should leave the selection intact for a second try.
    final List<String> chosen = files
        .map((StorageFile file) => file.fileId)
        .where(_picked.contains)
        .toList();

    return GDetailSliverPage(
      // categoryTint is the single source of truth for category hues, so a
      // Photos page opens photo coloured because the ledger row that led here
      // was photo coloured. Nothing new is decided at this call site.
      hue: categoryTint(t, scope.kind ?? 'other'),
      icon: _Cell._glyph(scope.kind ?? ''),
      title: widget.scope.title,
      subtitle: result == null
          ? null
          : '${GFormat.count(result.matchCount)} files  ·  '
                '${GFormat.bytes(result.matchBytes)}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(right: GSpace.sm),
            child: GViewSwitch(),
          ),
          GIconButton(
            icon: Icons.info_outline_rounded,
            onTap: () => _showDetail(context),
          ),
        ],
      ),
      // The action bar is the one thing here that must not scroll away. A
      // selection made at the top of a thousand files cannot require scrolling
      // back down to act on it.
      footer: chosen.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(
                GSpace.gutter,
                GSpace.sm,
                GSpace.gutter,
                GSpace.lg,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: GButton(
                      label: 'Delete ${chosen.length}',
                      icon: Icons.delete_forever_rounded,
                      kind: GButtonKind.danger,
                      onPressed: _busy ? null : () => _confirmPermanent(chosen),
                    ),
                  ),
                  const SizedBox(width: GSpace.md - 2),
                  Expanded(
                    child: GButton(
                      // The default is the REVERSIBLE one. Android's trash
                      // holds these for thirty days, and a storage screen
                      // whose easiest action is permanent is a screen that
                      // will eventually take something irreplaceable.
                      label: 'Trash ${chosen.length}',
                      icon: Icons.restore_from_trash_rounded,
                      onPressed: _busy ? null : () => _remove(chosen, false),
                    ),
                  ),
                ],
              ),
            ),
      slivers: <Widget>[
        if (result != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              GSpace.gutter,
              0,
              GSpace.gutter,
              GSpace.sm + 2,
            ),
            sliver: const SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerLeft,
                child: GSortButton(),
              ),
            ),
          ),

        if (result != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              GSpace.gutter,
              0,
              GSpace.gutter,
              GSpace.md,
            ),
            sliver: SliverToBoxAdapter(
              child: _Facts(result: result, shown: files.length),
            ),
          ),

        if (files.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: GEmptyState(
              shape: shapeForKind(scope.kind),
              title: result == null
                  ? 'Reading storage'
                  : 'Nothing of this kind',
              body: result == null
                  ? 'Asking Android what is on the phone'
                  : 'Android has no files matching this on the phone.',
            ),
          )
        else
          ..._fileSlivers(
            tokens: t,
            mode: ref.watch(gViewModeProvider),
            sort: sort,
            files: files,
            picked: _picked,
            onToggle: (String id) => setState(() {
              if (!_picked.remove(id)) _picked.add(id);
            }),
            onToggleGroup: (List<String> ids) => setState(() {
              final bool all = ids.every(_picked.contains);
              if (all) {
                _picked.removeAll(ids);
              } else {
                _picked.addAll(ids);
              }
            }),
            onOpen: (StorageFile file) => _open(files, file),
          ),
      ],
    );
  }

  /// Opens the viewer on the tapped file.
  ///
  /// Every kind goes in. The viewer draws images, video, text, CSV and PDF
  /// itself and hands anything else to an app that can open it, so there is no
  /// longer a file for which tapping should do nothing. The whole list travels
  /// with it, which keeps the swipe deck continuous rather than skipping the
  /// documents sitting between two photos.
  void _open(List<StorageFile> files, StorageFile file) {
    final int index = files.indexOf(file);
    if (index < 0) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(FileViewer.route(files: files, index: index));
  }

  Future<void> _confirmPermanent(List<String> ids) async {
    final GTokens t = context.g;
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: t.panel,
        shape: RoundedRectangleBorder(borderRadius: GRadius.all(GRadius.card)),
        title: Text(
          'Delete ${GFormat.count(ids.length)} permanently',
          style: GType.title.copyWith(color: t.text),
        ),
        content: Text(
          context.s(
            'These skip the trash and leave the phone for good. Nothing on this '
            'device, including this app, can bring them back.',
          ),
          style: GType.bodySmall.copyWith(color: t.muted),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              context.s('Keep'),
              style: GType.label.copyWith(color: t.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              context.s('Delete'),
              style: GType.label.copyWith(color: t.danger),
            ),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    await _remove(ids, true);
  }

  Future<void> _remove(List<String> ids, bool permanent) async {
    setState(() => _busy = true);
    final List<StorageOutcome> outcomes = await ref
        .read(storageBridgeProvider)
        .remove(ids, permanent: permanent);
    if (!mounted) return;

    // Two success statuses, not one. Native reports `trashed` and `deleted`
    // separately on purpose, because telling someone a file was deleted when it
    // is sitting in the bin is the same overclaim this app refuses to make in
    // the other direction.
    bool worked(StorageOutcome o) =>
        o.status == 'trashed' || o.status == 'deleted';

    final int ok = outcomes.where(worked).length;
    StorageOutcome? problem;
    for (final StorageOutcome outcome in outcomes) {
      if (!worked(outcome)) {
        problem = outcome;
        break;
      }
    }

    // needsConsent is not a failure. On Android 11 and up, removing a file this
    // app did not create puts a system dialog in front of the user, and until
    // they answer it nothing has gone wrong: it is simply waiting.
    final bool consent = outcomes.any(
      (StorageOutcome o) => o.status == 'needsConsent',
    );

    GMessenger.show(
      context,
      consent
          ? GMessage('Android is asking you to confirm those')
          : problem == null
          ? GMessage.success(permanent ? '$ok deleted' : '$ok moved to trash')
          : GMessage.warning('$ok done. ${problem.detail}'),
    );

    setState(() {
      _picked.removeAll(ids);
      _busy = false;
    });

    // The list, the overview and the reclaim figures all just changed.
    ref.invalidate(storageFilesProvider(widget.scope));
    ref.invalidate(storageOverviewProvider);
  }

  void _showDetail(BuildContext context) {
    final GTokens t = context.g;
    showGSheet(
      context: context,
      title: context.s('These files are not deleted'),
      children: <Widget>[
        Text(
          context.s(
            'Everything here is still on your phone and still yours. This screen '
            'is for clearing space, not for recovering anything.',
          ),
          style: GType.bodySmall.copyWith(color: t.muted),
        ),
        const GSheetHeading('Trash or delete'),
        GSheetPoint(
          icon: Icons.restore_from_trash_outlined,
          tone: t.success,
          text: context.s(
            'Trash puts a file in the system bin, where Android keeps it '
            'for thirty days. You can change your mind, and it shows up on '
            'the home screen as recoverable.',
          ),
        ),
        GSheetPoint(
          icon: Icons.remove_circle_outline_rounded,
          tone: t.danger,
          text: context.s(
            'Delete skips the bin. The space comes back immediately and the '
            'file does not, ever, by any means.',
          ),
        ),
        const GSheetHeading('Why some files are missing'),
        Text(
          context.s(
            'This list comes from the Android media index, which covers your own '
            'files but not app code or the private data each app keeps. Those are '
            'shown on the previous screen as apps and system, and no app can '
            'enumerate them.',
          ),
          style: GType.bodySmall.copyWith(color: t.muted),
        ),
      ],
    );
  }
}

/// Four numbers about the match, not about the device.
class _Facts extends StatelessWidget {
  const _Facts({required this.result, required this.shown});

  final StorageQueryResult result;
  final int shown;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    // matchCount is the real total and files is what the limit allowed through.
    // Saying so is the difference between a capped list and a wrong headline.
    final bool capped = result.matchCount > shown;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Fact(
          value: result.matchCount,
          format: (num n) => GFormat.count(n.round()),
          label: 'files',
          tone: t.text,
        ),
        _Fact(
          value: result.matchBytes,
          format: (num n) => GFormat.bytes(n.round()),
          label: context.s('in total'),
          tone: t.text,
        ),
        if (capped)
          _Fact(
            value: shown,
            format: (num n) => GFormat.count(n.round()),
            label: context.s('shown here'),
            tone: t.warning,
          ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.value,
    required this.format,
    required this.label,
    required this.tone,
  });

  final num value;
  final String Function(num) format;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GCountUp(
            value: value,
            format: format,
            style: GType.monoNumber.copyWith(color: tone, fontSize: 19),
          ),
          Text(label, style: GType.micro.copyWith(color: t.muted)),
        ],
      ),
    );
  }
}

/// The day groups, as a flat list of slivers.
///
/// ─── A FUNCTION, NOT A WIDGET ────────────────────────────────────────────────
///
/// A widget returns exactly one sliver, and this body is inherently many: a
/// header and a grid per day. Returning the list and spreading it at the call
/// site puts every one of them directly in the page's own CustomScrollView,
/// rather than nesting them in a wrapper sliver that has to be reasoned about
/// separately.
///
/// [tokens] is passed in rather than read from a context, because a function has
/// none.
List<Widget> _fileSlivers({
  required GTokens tokens,
  required GViewMode mode,
  required GSortMode sort,
  required List<StorageFile> files,
  required Set<String> picked,
  required void Function(String) onToggle,
  required void Function(List<String>) onToggleGroup,
  required void Function(StorageFile) onOpen,
}) {
  final GTokens t = tokens;
  final bool selecting = picked.isNotEmpty;

  // Grouped only when the order is a date order.
  //
  // Under a size sort, a header reading "Today" over a 94 MB video explains
  // nothing about why it is first, so the days come off and the list is one
  // ranked run. The helper is still the same one; it is simply given
  // everything as a single group.
  // Days always. Under a size sort the days are then ranked by their largest
  // file, so the top of the list is still the answer to "what is taking the
  // space" and the header still means what it says.
  //
  // Native has already ordered the files, so within each day they are in the
  // chosen order without a second sort here.
  List<DateGroup<StorageFile>> groups = groupByDate<StorageFile>(
    files,
    dateOf: (StorageFile f) => f.dateModifiedMillis,
    sizeOf: (StorageFile f) => f.sizeBytes,
  );
  if (sort.ranksGroups) {
    groups = rankGroupsBySize<StorageFile>(
      groups,
      smallestFirst: sort == GSortMode.smallest,
    );
  }

  return <Widget>[
    for (final DateGroup<StorageFile> group in groups) ...<Widget>[
      // NOT PINNED, AND THIS IS THE BUG THAT HID EVERY PHOTO.
      //
      // A pinned sliver adds its extent to constraints.overlap for every
      // sliver after it, so pinned headers ACCUMULATE rather than pushing
      // each other out. Two or three is the case everyone tests. Forty days
      // of photos is forty headers, each painting an opaque background, and
      // by the fourteenth the stack covers the whole viewport and paints
      // over the grids behind it. The grids were laying out correctly the
      // entire time and being hidden.
      //
      // Unpinned, each header scrolls away with its own day, which is also
      // what the rest of the app now does: one surface that moves together.
      //
      // Sticky day labels are recoverable later by wrapping EACH day in its
      // own SliverMainAxisGroup, which scopes a pinned child to that group's
      // extent. One group around all the days, which is what I tried first,
      // does the opposite and is what made this look like an extent bug.
      SliverPersistentHeader(
        delegate: GGroupHeader(
          label: group.label,
          meta:
              '${GFormat.count(group.count)}  ·  '
              '${GFormat.bytes(group.bytes)}',
          tokens: t,
          muted: !group.dated,
          // A day is the unit people think in when clearing a phone.
          // Without this, a Saturday of ninety photos is ninety taps.
          selected: selecting
              ? group.items.every((StorageFile f) => picked.contains(f.fileId))
              : null,
          onToggleAll: selecting
              ? () => onToggleGroup(
                  group.items.map((StorageFile f) => f.fileId).toList(),
                )
              : null,
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
        sliver: mode == GViewMode.grid
            ? SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 128,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                delegate: SliverChildBuilderDelegate((
                  BuildContext context,
                  int index,
                ) {
                  final StorageFile file = group.items[index];
                  return _Cell(
                    file: file,
                    selected: picked.contains(file.fileId),
                    selecting: selecting,
                    // Tap views, long press selects, and once anything is
                    // selected tap selects too. Same grammar as the
                    // recovery grid, because a person who learned it there
                    // should not have to learn it again here.
                    onTap: () =>
                        selecting ? onToggle(file.fileId) : onOpen(file),
                    onLongPress: () => onToggle(file.fileId),
                  );
                }, childCount: group.items.length),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate((
                  BuildContext context,
                  int index,
                ) {
                  final StorageFile file = group.items[index];
                  return _Row(
                    file: file,
                    selected: picked.contains(file.fileId),
                    detailed: mode == GViewMode.details,
                    onTap: () =>
                        selecting ? onToggle(file.fileId) : onOpen(file),
                    onLongPress: () => onToggle(file.fileId),
                  );
                }, childCount: group.items.length),
              ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: GSpace.md)),
    ],
  ];
}

class _Cell extends ConsumerWidget {
  const _Cell({
    required this.file,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
  });

  final StorageFile file;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    // Asked for on every kind now. Audio carries cover art in its tags and a
    // PDF has a first page, and native returns null for the rest, which falls
    // through to the glyph exactly as before.
    final Uint8List? bytes = ref
        .watch(storageThumbProvider(ThumbRequest.of(file)))
        .value;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: GRadius.all(GRadius.tile),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (bytes != null)
              Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (BuildContext context, Object e, StackTrace? s) =>
                    ColoredBox(color: t.panel),
              )
            else
              ColoredBox(
                color: t.panel,
                child: Center(
                  child: Icon(_glyph(file.kind), size: 26, color: t.dim),
                ),
              ),

            Positioned(
              right: 5,
              bottom: 4,
              child: Text(
                GFormat.bytes(file.sizeBytes),
                style: GType.monoSmall.copyWith(
                  color: t.text,
                  fontSize: 9.5,
                  shadows: <Shadow>[Shadow(color: t.scrim, blurRadius: 4)],
                ),
              ),
            ),

            if (selecting)
              Positioned(
                right: 5,
                top: 5,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: selected ? t.accent : t.scrim,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? t.accent
                          : t.text.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? Icon(Icons.check_rounded, size: 12, color: t.onAccent)
                      : null,
                ),
              ),

            if (selected)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.24),
                    border: Border.all(color: t.accent, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _glyph(String kind) {
    switch (kind) {
      case 'audio':
        return Icons.graphic_eq_rounded;
      case 'document':
        return Icons.description_outlined;
      case 'video':
        return Icons.play_circle_outline;
      case 'image':
        return Icons.photo_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}

/// A file as a row.
///
/// The storage twin of ItemRow, and separate from it for the same reason the
/// viewers are separate: that one carries expiry stamps and a restore verb,
/// none of which applies to a file that was never deleted.
class _Row extends ConsumerWidget {
  const _Row({
    required this.file,
    required this.selected,
    required this.detailed,
    required this.onTap,
    required this.onLongPress,
  });

  final StorageFile file;
  final bool selected;
  final bool detailed;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final Uint8List? bytes = ref
        .watch(storageThumbProvider(ThumbRequest.of(file, maxPixels: 128)))
        .value;

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.sm),
      child: GCard(
        onTap: onTap,
        onLongPress: onLongPress,
        borderColour: selected ? t.accent : null,
        padding: const EdgeInsets.symmetric(
          horizontal: GSpace.md,
          vertical: GSpace.sm + 3,
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: GRadius.all(GRadius.glyph),
              child: SizedBox(
                width: 38,
                height: 38,
                child: bytes != null
                    ? Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : ColoredBox(
                        color: t.panelAlt,
                        child: Icon(
                          _Cell._glyph(file.kind),
                          size: 18,
                          color: t.dim,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: GSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GType.body.copyWith(
                      color: t.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    GFormat.bytes(file.sizeBytes),
                    style: GType.monoSmall.copyWith(color: t.dim),
                  ),
                  if (detailed) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      _detail(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GType.micro.copyWith(color: t.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (selected) ...<Widget>[
              const SizedBox(width: GSpace.sm),
              Icon(Icons.check_circle_rounded, size: 19, color: t.accent),
            ],
          ],
        ),
      ),
    );
  }

  /// Only what is actually recorded. Every one of these is nullable in the
  /// schema, and a row reading "Unknown / Unknown" is worse than a short one.
  String _detail() {
    final List<String> parts = <String>[
      if (file.relativePath != null)
        file.relativePath!.replaceAll(RegExp(r'/$'), ''),
      if (file.mimeType != null) file.mimeType!,
      if (file.durationMillis != null) _duration(file.durationMillis!),
      if (file.dateModifiedMillis != null) _when(file.dateModifiedMillis!),
    ];
    return parts.isEmpty ? file.kind : parts.join('  ·  ');
  }

  static String _duration(int millis) {
    final int total = millis ~/ 1000;
    final String seconds = (total % 60).toString().padLeft(2, '0');
    return '${total ~/ 60}:$seconds';
  }

  static String _when(int millis) {
    final DateTime at = DateTime.fromMillisecondsSinceEpoch(millis);
    final int days = DateTime.now().difference(at).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 30) return '$days days ago';
    return '${at.day}/${at.month}/${at.year}';
  }
}
