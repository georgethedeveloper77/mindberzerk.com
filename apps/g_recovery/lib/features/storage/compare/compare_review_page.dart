import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/compare_api.g.dart';
import '../../../bridge/compare_bridge.dart';
import '../../../bridge/storage_api.g.dart';
import '../../../core/format.dart';
import '../../../core/messenger/g_message.dart';
import '../../../core/messenger/g_messenger.dart';
import '../../../ui/g_app_bar.dart';
import '../../../ui/g_button.dart';
import '../../../ui/g_card.dart';
import '../../../ui/g_enter.dart';
import '../../../ui/g_sheet.dart';
import '../state/storage_files.dart';
import '../state/storage_providers.dart';
import 'compare_viewer_page.dart';

/// CHOOSING BETWEEN COPIES, WITH THEM BOTH IN FRONT OF YOU.
///
/// The screen the compare engine was built for. Without it the three cards on
/// the storage tab compute real findings that nothing displays, which is a
/// placeholder wearing the clothes of a feature.
///
/// ─── THE KEEPER IS PRESELECTED, NEVER PREDELETED ─────────────────────────────
///
/// Native suggests the largest file in each group and this screen selects the
/// OTHERS for removal, so the default action does what a person expects and the
/// suggestion is visible rather than silent. Tapping any thumbnail moves the
/// keeper, which reselects the rest.
///
/// ─── EXACT AND SIMILAR ARE THE SAME SCREEN AND DIFFERENT PROMISES ────────────
///
/// For byte identical copies the choice genuinely does not matter and the saving
/// is exact. For near duplicates it matters a great deal: one may be the crop
/// you wanted, and the largest is only a guess. The header says which kind is on
/// screen and the copy changes with it.
class CompareReviewPage extends ConsumerStatefulWidget {
  const CompareReviewPage({required this.kind, super.key});

  /// "exact" or "similar".
  final String kind;

  static Route<void> route(String kind) => MaterialPageRoute<void>(
    builder: (BuildContext context) => CompareReviewPage(kind: kind),
  );

  @override
  ConsumerState<CompareReviewPage> createState() => _CompareReviewPageState();
}

class _CompareReviewPageState extends ConsumerState<CompareReviewPage> {
  /// groupId to the files kept from that group.
  ///
  /// A SET, not a single id. A burst of six can easily contain two frames worth
  /// keeping, and forcing a choice of one meant either losing the second or
  /// skipping the whole group.
  ///
  /// Still stores what is KEPT rather than what is removed, and that has not
  /// changed for the same reason: storing removals would let a group reach a
  /// state with nothing kept, which is a delete everything bug waiting for a
  /// mis-tap. Keeping is the thing that cannot go to zero.
  final Map<String, Set<String>> _keep = <String, Set<String>>{};

  Set<String> _keptIn(CompareGroup group) =>
      _keep[group.groupId] ?? <String>{group.keepFileId};

  /// Toggles one file, refusing to empty the group.
  ///
  /// Tapping the last kept photo does nothing rather than clearing it. Anything
  /// else means a tap can queue an entire set for the bin, which is the one
  /// mistake this screen must make impossible.
  void _toggleKeep(CompareGroup group, String fileId) {
    final Set<String> kept = <String>{..._keptIn(group)};
    if (kept.contains(fileId)) {
      if (kept.length == 1) return;
      kept.remove(fileId);
    } else {
      kept.add(fileId);
    }
    setState(() => _keep[group.groupId] = kept);
  }

  /// What a group would free, from real per file sizes.
  int _freedBy(CompareGroup group) {
    final Set<String> kept = _keptIn(group);
    int freed = 0;
    for (int i = 0; i < group.fileIds.length; i++) {
      if (kept.contains(group.fileIds[i])) continue;
      freed += i < group.sizes.length ? group.sizes[i] : 0;
    }
    return freed;
  }

  List<String> _doomedIn(CompareGroup group) {
    final Set<String> kept = _keptIn(group);
    return group.fileIds.where((String id) => !kept.contains(id)).toList();
  }

  /// Groups already acted on.
  ///
  /// The findings are held natively and do not change when files are trashed,
  /// so without this a group would still be listed after its copies were
  /// removed, offering to free space that is already free.
  final Set<String> _done = <String>{};

  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final bool exact = widget.kind == 'exact';

    final List<CompareGroup> groups =
        (exact
                ? ref.watch(exactGroupsProvider)
                : ref.watch(similarGroupsProvider))
            .where((CompareGroup g) => !_done.contains(g.groupId))
            .toList();

    int freed = 0;
    int count = 0;
    for (final CompareGroup group in groups) {
      final List<String> doomed = _doomedIn(group);
      count += doomed.length;
      // Real sizes, not wastedBytes. That figure assumed exactly one keeper and
      // is wrong the moment a second is kept.
      freed += _freedBy(group);
    }

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
              child: GAppBar(
                title: exact ? 'Duplicates' : 'Similar photos',
                subtitle: groups.isEmpty
                    ? null
                    : '${GFormat.count(groups.length)} sets',
                leading: GIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                actions: <Widget>[
                  GIconButton(
                    icon: Icons.info_outline_rounded,
                    onTap: () => _explain(context, exact: exact),
                  ),
                ],
              ),
            ),

            Expanded(
              child: groups.isEmpty
                  ? _Empty(exact: exact)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        GSpace.gutter,
                        0,
                        GSpace.gutter,
                        GSpace.xl,
                      ),
                      itemCount: groups.length,
                      itemBuilder: (BuildContext context, int index) {
                        final CompareGroup group = groups[index];
                        return GEnter(
                          index: index,
                          child: _GroupCard(
                            group: group,
                            exact: exact,
                            kept: _keptIn(group),
                            freed: _freedBy(group),
                            onKeep: (String id) => _toggleKeep(group, id),
                            onOpen: (int at) => _open(group, at),
                            onTrashGroup: () => _remove(<CompareGroup>[group]),
                          ),
                        );
                      },
                    ),
            ),

            if (groups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GSpace.gutter,
                  0,
                  GSpace.gutter,
                  GSpace.lg,
                ),
                child: GButton(
                  label: 'Trash $count, free ${GFormat.bytes(freed)}',
                  icon: Icons.restore_from_trash_rounded,
                  onPressed: _busy ? null : () => _remove(groups),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Opens the set at the tapped photo.
  ///
  /// Sizes are handed over rather than looked up: the group already knows them
  /// and the viewer should not have to query for a number it is only comparing.
  void _open(CompareGroup group, int at) {
    Navigator.of(context, rootNavigator: true).push(
      CompareViewerPage.route(
        fileIds: group.fileIds,
        // Real per file sizes now, straight from the group.
        sizes: <String, int>{
          for (int i = 0; i < group.fileIds.length; i++)
            group.fileIds[i]: i < group.sizes.length ? group.sizes[i] : 0,
        },
        index: at,
        keeperId: _keptIn(group).first,
        onKeep: (String id) => _toggleKeep(group, id),
      ),
    );
  }

  /// Trash, never permanent delete.
  ///
  /// This is the one screen in the app that removes many files on one tap, and
  /// the files are chosen by an algorithm rather than by a person looking at
  /// each one. A wrong keeper is recoverable for thirty days; a permanent
  /// delete on the same tap would not be, and no saving is worth that.
  Future<void> _remove(List<CompareGroup> groups) async {
    final List<String> ids = <String>[];
    for (final CompareGroup group in groups) {
      ids.addAll(_doomedIn(group));
    }
    if (ids.isEmpty) return;

    setState(() => _busy = true);
    final List<StorageOutcome> outcomes = await ref
        .read(storageBridgeProvider)
        .remove(ids, permanent: false);
    if (!mounted) return;

    final int ok = outcomes
        .where(
          (StorageOutcome o) => o.status == 'trashed' || o.status == 'deleted',
        )
        .length;
    final bool consent = outcomes.any(
      (StorageOutcome o) => o.status == 'needsConsent',
    );

    GMessenger.show(
      context,
      consent
          ? GMessage('Android is asking you to confirm those')
          : GMessage.success('$ok moved to trash'),
    );

    // STAYS ON THE PAGE, and keeps the rest of the findings.
    //
    // This used to drop every result and pop, which was right when the only
    // button was the one at the bottom. With a bin on each group that behaviour
    // threw the user out of a list they were halfway through reading.
    //
    // The findings are dropped when they leave, in dispose, so the card on the
    // storage tab recomputes rather than showing a total that includes files
    // that are now in the trash.
    setState(() {
      _busy = false;
      for (final CompareGroup group in groups) {
        _done.add(group.groupId);
      }
    });

    ref.invalidate(storageOverviewProvider);
  }

  /// Held from initState. See the note on the field: ref cannot be read once
  /// the widget is deactivated, and dispose runs after that point.
  late final CompareController _compare;

  @override
  void initState() {
    super.initState();
    _compare = ref.read(compareProvider.notifier);
  }

  @override
  void dispose() {
    // ─── PRUNES, AND NO LONGER WIPES ────────────────────────────────────────
    //
    // This called forget(), which dropped the entire result. The reasoning was
    // right about the groups that were trashed and wrong about everything else:
    // clearing one set of duplicates threw away the other thirty nine, both
    // similar lists and the whole blur grid, and sent the user back to a tab
    // showing four cards that said "Scan" again.
    //
    // Only the groups actually acted on go. Still on the way out rather than
    // after each removal, so the list does not rebuild under a finger.
    if (_done.isNotEmpty) {
      _compare.forgetGroups(_done);
    }
    super.dispose();
  }

  void _explain(BuildContext context, {required bool exact}) {
    final GTokens t = context.g;
    showGSheet(
      context: context,
      title: exact ? 'Identical copies' : 'Near copies',
      children: <Widget>[
        Text(
          exact
              ? 'Every file in a set here is byte for byte the same as the '
                    'others. Which one you keep genuinely does not matter, and '
                    'the space freed is exact.'
              : 'These look like the same picture to a comparison of their '
                    'shapes and edges. They are NOT identical: one may be a crop, '
                    'a different exposure, or the one frame in a burst where '
                    'nobody blinked.',
          style: GType.bodySmall.copyWith(color: t.muted),
        ),
        const GSheetHeading('What is preselected'),
        GSheetPoint(
          icon: Icons.check_circle_outline_rounded,
          tone: t.success,
          text: exact
              ? 'The largest file is kept and the rest are trashed. With '
                    'identical files this is arbitrary and safe.'
              : 'The largest file is kept, because between two encodings of one '
                    'photo the bigger one carries more detail. It is a guess. Tap '
                    'any photo to keep that one instead.',
        ),
        const GSheetHeading('Nothing is deleted'),
        GSheetPoint(
          icon: Icons.restore_from_trash_outlined,
          tone: t.docs,
          text:
              'Everything goes to the system trash, where Android keeps it '
              'for thirty days. If a keeper was wrong, the others are still '
              'there.',
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.exact,
    required this.kept,
    required this.freed,
    required this.onKeep,
    required this.onOpen,
    required this.onTrashGroup,
  });

  final CompareGroup group;
  final bool exact;
  final Set<String> kept;
  final int freed;
  final void Function(String) onKeep;
  final void Function(int) onOpen;
  final VoidCallback onTrashGroup;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.md - 1),
      child: GCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${GFormat.count(group.fileIds.length)} copies',
                    style: GType.heading.copyWith(color: t.text),
                  ),
                ),
                Text(
                  freed == 0 ? 'keeping all' : 'frees ${GFormat.bytes(freed)}',
                  style: GType.monoSmall.copyWith(color: t.dim),
                ),
              ],
            ),
            const SizedBox(height: GSpace.sm + 2),

            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: group.fileIds.length,
                separatorBuilder: (BuildContext _, int index) =>
                    const SizedBox(width: GSpace.sm),
                itemBuilder: (BuildContext context, int index) {
                  final String id = group.fileIds[index];
                  return _Thumb(
                    fileId: id,
                    keeping: kept.contains(id),
                    onTap: () => onKeep(id),
                    onOpen: () => onOpen(index),
                  );
                },
              ),
            ),

            const SizedBox(height: GSpace.sm + 2),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    // Says that keeping more than one is possible. Nobody
                    // discovers a toggle by tapping something already marked
                    // Keep, so it has to be stated.
                    kept.length > 1
                        ? 'Keeping ${kept.length}. Tap to add or remove.'
                        : 'Tap to keep more than one. Double tap to open.',
                    style: GType.micro.copyWith(color: t.muted),
                  ),
                ),
                // A COUNTED BIN, not a bare icon.
                //
                // The keeper is one of the photos on screen, so an unlabelled
                // bin beside them could be read as "delete this photo". The
                // number says exactly what would go: the copies that are not
                // the keeper, applied to this group now.
                //
                // It earns its place because 142 sets is a long scroll. Someone
                // who agrees with most groups can clear as they read instead of
                // committing everything at the bottom.
                _GroupTrash(
                  count: group.fileIds.length - kept.length,
                  onTap: onTrashGroup,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A thumbnail that responds on the FIRST tap.
///
/// ─── WHY THE DOUBLE TAP IS DETECTED BY HAND ──────────────────────────────────
///
/// Registering onDoubleTap makes GestureDetector withhold onTap until the
/// double tap window expires, roughly 300ms. On a grid where tapping is the
/// common action that reads as the app ignoring you: the keeper simply does not
/// move, and by the time it does the finger has gone.
///
/// So onDoubleTap is not used. onTap fires immediately, moves the keeper, and
/// notes the time. A second tap inside the window opens the photo instead. The
/// first tap has already done something, which is the point.
class _Thumb extends ConsumerStatefulWidget {
  const _Thumb({
    required this.fileId,
    required this.keeping,
    required this.onTap,
    required this.onOpen,
  });

  final String fileId;
  final bool keeping;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  ConsumerState<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends ConsumerState<_Thumb> {
  DateTime? _lastTap;

  static const Duration _window = Duration(milliseconds: 300);

  void _handleTap() {
    final DateTime now = DateTime.now();
    final DateTime? previous = _lastTap;
    _lastTap = now;

    if (previous != null && now.difference(previous) < _window) {
      widget.onOpen();
      return;
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final Uint8List? bytes = ref
        .watch(
          storageThumbProvider(
            // Kind is known here: only images and video reach the compare
            // engine, and a wrong kind only costs the fallback glyph.
            ThumbRequest(fileId: widget.fileId, kind: 'image', maxPixels: 256),
          ),
        )
        .value;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 100,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ClipRRect(
              borderRadius: GRadius.all(GRadius.tile),
              child: bytes == null
                  ? ColoredBox(color: t.panelAlt)
                  : Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder:
                          (BuildContext context, Object e, StackTrace? s) =>
                              ColoredBox(color: t.panelAlt),
                    ),
            ),

            // The one being kept is marked positively rather than the others
            // being dimmed. A row of greyed thumbnails reads as damaged; one
            // marked keeper reads as a choice.
            if (widget.keeping)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: t.success, width: 2.5),
                    borderRadius: GRadius.all(GRadius.tile),
                  ),
                ),
              ),
            Positioned(
              left: 5,
              top: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: GSpace.sm - 2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: widget.keeping ? t.success : t.scrim,
                  borderRadius: GRadius.all(GRadius.chip),
                ),
                child: Text(
                  widget.keeping ? 'Keep' : 'Trash',
                  style: GType.micro.copyWith(
                    color: widget.keeping ? t.onAccent : t.text,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.exact});

  final bool exact;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: GSpace.xl),
        child: Text(
          exact
              ? 'No identical copies on this phone.'
              : 'Nothing here looks like anything else.',
          textAlign: TextAlign.center,
          style: GType.bodySmall.copyWith(color: t.muted),
        ),
      ),
    );
  }
}

/// The bin beside a group, carrying what it would take.
class _GroupTrash extends StatelessWidget {
  const _GroupTrash({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final BorderRadius radius = GRadius.all(GRadius.chip);

    return Material(
      color: t.danger.withValues(alpha: 0.13),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: GSpace.sm + 2,
            vertical: GSpace.xs + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.delete_outline_rounded, size: 14, color: t.danger),
              const SizedBox(width: GSpace.xs + 1),
              Text('$count', style: GType.monoSmall.copyWith(color: t.danger)),
            ],
          ),
        ),
      ),
    );
  }
}
