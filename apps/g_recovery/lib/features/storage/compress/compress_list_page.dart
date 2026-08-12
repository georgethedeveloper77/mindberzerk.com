import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/compress_api.g.dart';
import '../../../bridge/compress_bridge.dart';
import '../../../core/format.dart';
import '../../../core/messenger/g_message.dart';
import '../../../core/messenger/g_messenger.dart';
import '../../../ui/g_app_bar.dart';
import '../../../ui/g_button.dart';
import '../../../ui/g_card.dart';
import '../../../ui/g_enter.dart';
import '../../../ui/g_sort.dart';
import '../../../ui/g_view_switch.dart';
import '../state/storage_files.dart';
import '../state/storage_providers.dart';
import 'compress_viewer_page.dart';

/// ONE CATEGORY, AS A FILE LIST LIKE EVERY OTHER FILE LIST.
///
/// ─── IT USES THE SHARED CONTROLS, WHICH IS THE POINT ─────────────────────────
///
/// GViewSwitch and GSortButton are app wide notifiers, so someone who prefers
/// details and largest first arrives here in details and largest first without
/// setting anything. The earlier version of this screen had a bespoke row and
/// no controls at all, which made it the only list in the app you could not lay
/// out or order.
///
/// ─── SELECTION STARTS AT EVERYTHING, VISIBLY ─────────────────────────────────
///
/// Same shape as the compare pages. What must never happen is a run beginning
/// on a file nobody could see, so the list is on screen before anything can be
/// started and every row carries its own measured saving.
///
/// ─── MEASURING IS LAZY AND BOUNDED ───────────────────────────────────────────
///
/// A saving is a real re-encode, so measuring three thousand photos to draw a
/// list would take minutes. Only the first page is measured up front and more
/// arrives as the list is scrolled, which is why a row can legitimately show
/// nothing yet rather than showing a zero.
class CompressListPage extends ConsumerStatefulWidget {
  const CompressListPage({required this.kind, super.key});

  /// "screenshot" or "photo".
  final String kind;

  static Route<void> route(String kind) => MaterialPageRoute<void>(
    builder: (BuildContext context) => CompressListPage(kind: kind),
  );

  @override
  ConsumerState<CompressListPage> createState() => _CompressListPageState();
}

class _CompressListPageState extends ConsumerState<CompressListPage> {
  /// Files the user has taken OUT of the run.
  ///
  /// Exclusions rather than inclusions, deliberately. Everything is selected to
  /// begin with, so storing the selection would mean writing three thousand ids
  /// on open and rewriting the set on every tap.
  final Set<String> _excluded = <String>{};

  /// fileId to what a re-encode really produced.
  final Map<String, CompressPreview> _measured = <String, CompressPreview>{};

  /// Ids currently out at the bridge, so a scroll cannot ask twice.
  final Set<String> _inFlight = <String>{};

  bool _busy = false;

  bool get _lossless => widget.kind == 'screenshot';

  /// Quality is meaningless for a lossless pass and native ignores it, so the
  /// slider is absent on that list rather than present and inert.
  int get _quality => _lossless ? 100 : ref.read(compressQualityProvider);

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final GViewMode mode = ref.watch(gViewModeProvider);
    final GSortMode sort = ref.watch(gSortProvider);

    final List<CompressCandidate> all =
        ref.watch(compressScopeProvider(widget.kind)).value ??
        const <CompressCandidate>[];
    final List<CompressCandidate> items = _sorted(all, sort);

    int saving = 0;

    // What the files behind that saving weigh now.
    //
    // Only the ones actually measured, never the whole selection. Mixing
    // measured savings against a total that includes unmeasured files would
    // make the bar creep as the list scrolled, which looks like the encoder
    // getting worse.
    int weighed = 0;

    for (final CompressCandidate item in items) {
      if (_excluded.contains(item.fileId)) continue;
      final CompressPreview? p = _measured[item.fileId];
      if (p == null) continue;
      final int delta = p.originalBytes - p.newBytes;
      if (delta <= 0) continue;
      saving += delta;
      weighed += p.originalBytes;
    }

    final bool none = _excluded.length >= items.length;

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
              child: GAppBar(
                title: _lossless ? 'Screenshots' : 'Photos',
                subtitle: items.isEmpty
                    ? null
                    : '${GFormat.count(items.length)} files',
                leading: GIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),

            if (_busy)
              const Expanded(child: _Running())
            else if (items.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'Nothing here over a megabyte.',
                    style: GType.bodySmall.copyWith(color: t.muted),
                  ),
                ),
              )
            else ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GSpace.gutter,
                  0,
                  GSpace.gutter,
                  GSpace.md,
                ),
                // Two rows, not one.
                //
                // The first attempt put the view switch, the sort pill and the
                // select control on one line and it overflowed, because the
                // sort label is a whole phrase and the switch is a fixed 118dp.
                // storage_files_page already solved this by stacking them, and
                // matching it is better than inventing a narrower control.
                // One row again, now that GSortButton can shrink.
                //
                // It was split across two because the label overflowed, but the
                // real fault was inside GSortButton: its Row is
                // MainAxisSize.min, so it asked for the label's full width no
                // matter what the parent offered. That is fixed at the source,
                // and stacking a lone pill under the view switch left it
                // stranded in the middle of the screen belonging to nothing.
                child: Row(
                  children: <Widget>[
                    const GViewSwitch(),
                    const SizedBox(width: GSpace.sm + 1),
                    // Expanded, not Flexible beside a Spacer. Two flex children
                    // would share the leftover room and push the sort pill into
                    // the middle; this gives it everything the other two do not
                    // need, left aligned, and lets it ellipsize when the sort
                    // is one of the longer names.
                    const Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GSortButton(),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        if (none) {
                          _excluded.clear();
                        } else {
                          _excluded.addAll(
                            items.map((CompressCandidate c) => c.fileId),
                          );
                        }
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: GSpace.sm,
                          vertical: GSpace.sm,
                        ),
                        child: Text(
                          none ? 'ALL' : 'NONE',
                          style: GType.micro.copyWith(color: t.accentText),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (!_lossless)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    GSpace.gutter,
                    0,
                    GSpace.gutter,
                    GSpace.md,
                  ),
                  child: _Quality(
                    quality: ref.watch(compressQualityProvider),
                    originalBytes: weighed,
                    newBytes: weighed - saving,
                    onChanged: (int value) {
                      ref.read(compressQualityProvider.notifier).select(value);
                      // Everything on screen was measured at the old setting,
                      // so it is all wrong now. Clearing is the honest move;
                      // leaving stale numbers under a changed slider is how a
                      // measured figure quietly becomes a guess.
                      setState(_measured.clear);

                      // And the no-gain verdicts go with them. A photo that
                      // gains nothing at 85 may gain plenty at 65, so a verdict
                      // reached at one setting must not survive a move to
                      // another.
                      ref.read(compressBridgeProvider).clearNoGain().then((_) {
                        if (mounted) {
                          ref.invalidate(compressScopeProvider(widget.kind));
                        }
                      });
                    },
                    onSettled: () => _measureVisible(items, 0),
                  ),
                ),

              Expanded(
                child: mode == GViewMode.grid
                    ? _grid(items)
                    : _rows(items, detailed: mode == GViewMode.details),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GSpace.gutter,
                  0,
                  GSpace.gutter,
                  GSpace.lg,
                ),
                child: _Action(
                  none: none,
                  saving: saving,
                  onPressed: _run,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Layouts
  // ───────────────────────────────────────────────────────────────────────────

  Widget _grid(List<CompressCandidate> items) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        GSpace.gutter,
        0,
        GSpace.gutter,
        GSpace.xl,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        crossAxisSpacing: GSpace.sm - 1,
        mainAxisSpacing: GSpace.sm - 1,
      ),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        _measureVisible(items, index);
        final CompressCandidate item = items[index];
        return _Cell(
          item: item,
          excluded: _excluded.contains(item.fileId),
          preview: _measured[item.fileId],
          onTap: () => _toggle(item.fileId),
          onOpen: () => _open(items, index),
        );
      },
    );
  }

  Widget _rows(List<CompressCandidate> items, {required bool detailed}) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        GSpace.gutter,
        0,
        GSpace.gutter,
        GSpace.xl,
      ),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        _measureVisible(items, index);
        final CompressCandidate item = items[index];
        return GEnter(
          index: index,
          child: _Row(
            item: item,
            detailed: detailed,
            excluded: _excluded.contains(item.fileId),
            preview: _measured[item.fileId],
            onTap: () => _toggle(item.fileId),
            onOpen: () => _open(items, index),
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Behaviour
  // ───────────────────────────────────────────────────────────────────────────

  void _toggle(String fileId) => setState(() {
    if (!_excluded.remove(fileId)) _excluded.add(fileId);
  });

  void _open(List<CompressCandidate> items, int index) {
    Navigator.of(context, rootNavigator: true).push(
      CompressViewerPage.route(
        fileIds: items.map((CompressCandidate c) => c.fileId).toList(),
        index: index,
        quality: _quality,
        lossless: _lossless,
        excluded: _excluded,
        onExclude: _toggle,
      ),
    );
  }

  /// Measures a window around whatever is being built.
  ///
  /// ─── DURING BUILD, WHICH NEEDS THE POST FRAME CALLBACK ───────────────────
  ///
  /// This is called from an itemBuilder, so it cannot setState directly: that
  /// would mark the tree dirty while it is being built. The bridge call is
  /// started here and the result lands after the frame, which is also why
  /// _inFlight exists rather than just checking _measured.
  void _measureVisible(List<CompressCandidate> items, int index) {
    final List<String> wanted = <String>[];
    for (int i = index; i < items.length && wanted.length < 12; i++) {
      final String id = items[i].fileId;
      if (_excluded.contains(id)) continue;
      if (_measured.containsKey(id) || _inFlight.contains(id)) continue;
      wanted.add(id);
    }
    if (wanted.isEmpty) return;

    _inFlight.addAll(wanted);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure(wanted));
  }

  Future<void> _measure(List<String> ids) async {
    final List<CompressPreview> results = await ref
        .read(compressBridgeProvider)
        .preview(ids, quality: _quality);
    if (!mounted) return;

    setState(() {
      _inFlight.removeAll(ids);
      for (final CompressPreview p in results) {
        _measured[p.fileId] = p;
      }
    });
  }

  Future<void> _run() async {
    final List<CompressCandidate> all =
        ref.read(compressScopeProvider(widget.kind)).value ??
        const <CompressCandidate>[];

    // Only what actually shrinks. Sending a file that would grow means native
    // measures it again and skips it, which is work for nothing.
    final List<String> ids = all
        .map((CompressCandidate c) => c.fileId)
        .where((String id) {
          if (_excluded.contains(id)) return false;
          final CompressPreview? p = _measured[id];
          return p != null && p.newBytes < p.originalBytes;
        })
        .toList();
    // ─── THE FILES THAT CANNOT BE IMPROVED ARE ALSO AN ANSWER ─────────────
    //
    // They are deliberately not sent to the encoder, and until now that meant
    // they were never recorded either, so the very next scan measured all of
    // them again from scratch. After one run the list becomes nothing but these
    // files, which is indistinguishable from the run having achieved nothing.
    //
    // Telling native once costs a single call and no encoding.
    final List<String> pointless = all
        .map((CompressCandidate c) => c.fileId)
        .where((String id) {
          if (_excluded.contains(id)) return false;
          final CompressPreview? p = _measured[id];
          return p != null && p.newBytes >= p.originalBytes;
        })
        .toList();
    if (pointless.isNotEmpty) {
      await ref.read(compressBridgeProvider).markNoGain(pointless);
    }

    if (ids.isEmpty) {
      // Everything selected turned out to be pointless. Nothing to encode, but
      // the verdicts above are still worth keeping.
      if (mounted) {
        ref.invalidate(compressScopeProvider(widget.kind));
        ref.invalidate(compressSummaryProvider);
      }
      return;
    }

    setState(() => _busy = true);
    final List<CompressOutcome> outcomes = await ref
        .read(compressBridgeProvider)
        .compress(ids, quality: _quality);
    if (!mounted) return;

    final int replaced = outcomes
        .where((CompressOutcome o) => o.status == 'replaced')
        .length;
    final int saved = outcomes.fold<int>(
      0,
      (int sum, CompressOutcome o) => sum + o.savedBytes,
    );

    setState(() {
      _busy = false;
      _excluded.clear();
      _measured.clear();
    });

    ref.invalidate(compressScopeProvider(widget.kind));
    ref.invalidate(compressSummaryProvider);
    ref.invalidate(compressHistoryProvider);
    ref.invalidate(storageOverviewProvider);

    GMessenger.show(
      context,
      GMessage.success('$replaced compressed, ${GFormat.bytes(saved)} freed'),
    );
  }

  /// The shared sort, applied to what this list actually has.
  ///
  /// Expiring is not offered here and would sort by a field that is null for
  /// every row, so it falls through to newest. Everything else maps cleanly.
  List<CompressCandidate> _sorted(
    List<CompressCandidate> items,
    GSortMode sort,
  ) {
    final List<CompressCandidate> out = List<CompressCandidate>.of(items);
    out.sort((CompressCandidate a, CompressCandidate b) {
      switch (sort) {
        case GSortMode.largest:
          return b.sizeBytes.compareTo(a.sizeBytes);
        case GSortMode.smallest:
          return a.sizeBytes.compareTo(b.sizeBytes);
        case GSortMode.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case GSortMode.oldest:
          return (a.dateMillis ?? 0).compareTo(b.dateMillis ?? 0);
        case GSortMode.newest:
        case GSortMode.expiring:
          return (b.dateMillis ?? 0).compareTo(a.dateMillis ?? 0);
      }
    });
    return out;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rows
// ─────────────────────────────────────────────────────────────────────────────

/// A preview, from the STORAGE thumbnailer.
///
/// ─── NOT GThumbnail, AND THAT WAS THE BUG ────────────────────────────────────
///
/// GThumbnail is backed by RecoveryBridge, which serves items out of the
/// recovery index: things that were scanned or trashed. The ids on this screen
/// are plain MediaStore ids for files that are present and healthy, so every
/// request missed and every tile fell through to the grey placeholder glyph.
///
/// Nothing failed loudly. The provider is built to treat a missing preview as
/// normal, because audio and documents genuinely have none, so a wholly wrong
/// bridge looked exactly like a folder of unpreviewable files.
///
/// storageThumbProvider is what every other storage screen uses, including the
/// compare grid this one was modelled on.
class _Thumb extends ConsumerWidget {
  const _Thumb({required this.fileId, this.radius});

  final String fileId;
  final double? radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final BorderRadius corners = GRadius.all(radius ?? GRadius.tile);

    final Uint8List? bytes = ref
        .watch(
          storageThumbProvider(
            // Kind is known: only images reach this screen, and a wrong kind
            // would only cost the fallback glyph.
            ThumbRequest(fileId: fileId, kind: 'image', maxPixels: 256),
          ),
        )
        .value;

    return ClipRRect(
      borderRadius: corners,
      child: bytes == null
          ? ColoredBox(
              color: t.panelAlt,
              child: Center(
                child: Icon(Icons.photo_outlined, size: 18, color: t.dim),
              ),
            )
          : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
    );
  }
}

/// The saving, or nothing at all while it is still being measured.
///
/// Never a zero and never a dash. A measured saving is the one thing this app
/// has that a formula based cleaner does not, and printing a placeholder in its
/// slot would throw that away for the sake of a tidy column.
class _Saving extends StatelessWidget {
  const _Saving({required this.preview, this.compact = false});

  final CompressPreview? preview;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final CompressPreview? p = preview;
    if (p == null) return const SizedBox.shrink();

    final int delta = p.originalBytes - p.newBytes;
    if (delta <= 0) {
      return Text(
        'no gain',
        style: GType.micro.copyWith(color: t.dim),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '-${GFormat.bytes(delta)}',
          style: GType.monoSmall.copyWith(
            color: t.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (!compact)
          Text(
            p.lossless ?? false ? 'IDENTICAL' : 'MEASURED',
            style: GType.badge.copyWith(color: t.dim),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.item,
    required this.excluded,
    required this.preview,
    required this.onTap,
    required this.onOpen,
  });

  final CompressCandidate item;
  final bool excluded;
  final CompressPreview? preview;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return GestureDetector(
      // Tap selects. Reversed from the first version, which opened the viewer
      // on tap and hid selection behind a long press.
      //
      // The reasoning then was that every file is already chosen so looking is
      // the useful act. That was reasoning about the feature rather than about
      // the hand: a grid of ticked squares reads as a selection list in every
      // other app on the phone, and the first tap is always an attempt to
      // untick something. Opening now has its own visible glyph.
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _Thumb(fileId: item.fileId, radius: GRadius.tile),
          if (!excluded)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: GRadius.all(GRadius.tile),
                  border: Border.all(color: t.accent, width: 2),
                ),
              ),
            ),
          // The tick is a state light, not a target. The whole cell toggles,
          // so a second hit area inside it would only create a dead zone where
          // the two recognisers argue.
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: excluded ? const Color(0x66000000) : t.accent,
                borderRadius: GRadius.all(6),
                border: Border.all(
                  color: excluded ? const Color(0x88FFFFFF) : t.accent,
                ),
              ),
              child: excluded
                  ? null
                  : Icon(Icons.check_rounded, size: 13, color: t.onAccent),
            ),
          ),

          // Opening is a button now rather than a long press.
          //
          // A gesture with no glyph is a feature only its author knows about,
          // and on the one screen in this app that rewrites originals, checking
          // the result must not be the hidden option.
          Positioned(
            top: 5,
            left: 5,
            child: GestureDetector(
              onTap: onOpen,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0x8C000000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.zoom_out_map_rounded,
                  size: 13,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
          if (preview != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(5, 12, 5, 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(GRadius.tile),
                  ),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0x00000000), Color(0xBF000000)],
                  ),
                ),
                child: _Saving(preview: preview, compact: true),
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.detailed,
    required this.excluded,
    required this.preview,
    required this.onTap,
    required this.onOpen,
  });

  final CompressCandidate item;
  final bool detailed;
  final bool excluded;
  final CompressPreview? preview;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return Padding(
      padding: const EdgeInsets.only(bottom: GSpace.sm),
      child: GCard(
        // The card toggles; the thumbnail opens. Same split as the grid, and
        // the picture is the obvious thing to tap when you want to see it
        // bigger.
        onTap: onTap,
        padding: const EdgeInsets.all(GSpace.sm + 2),
        borderColour: excluded ? null : t.accent.withValues(alpha: 0.4),
        child: Row(
          children: <Widget>[
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: excluded ? null : t.accent,
                borderRadius: GRadius.all(7),
                border: Border.all(color: excluded ? t.lineStrong : t.accent),
              ),
              child: excluded
                  ? null
                  : Icon(Icons.check_rounded, size: 14, color: t.onAccent),
            ),
            const SizedBox(width: GSpace.md - 2),
            GestureDetector(
              onTap: onOpen,
              child: SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _Thumb(fileId: item.fileId),
                    const Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.zoom_out_map_rounded,
                          size: 11,
                          color: Color(0xCCFFFFFF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: GSpace.md - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GType.bodySmall.copyWith(color: t.text),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _facts(),
                    maxLines: detailed ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: GType.monoSmall.copyWith(color: t.dim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: GSpace.sm),
            _Saving(preview: preview),
          ],
        ),
      ),
    );
  }

  /// One line in list mode, everything in details.
  ///
  /// Details exists for the moment a phone has forty files called
  /// IMG_20260714, where the name is no longer an answer to "which one is
  /// this". Folder and date are what tell them apart.
  String _facts() {
    final List<String> parts = <String>[GFormat.bytes(item.sizeBytes)];

    if (item.widthPx > 0 && item.heightPx > 0) {
      parts.add('${item.widthPx}x${item.heightPx}');
    }
    if (detailed) {
      final String? folder = item.folder;
      if (folder != null && folder.isNotEmpty) parts.add(folder);

      final int? millis = item.dateMillis;
      if (millis != null && millis > 0) {
        final DateTime when = DateTime.fromMillisecondsSinceEpoch(millis);
        parts.add(GFormat.relativeDay(when, DateTime.now()));
      }
    }
    return parts.join('  ·  ');
  }
}

/// QUALITY, TIED TO A MEASURED BAR RATHER THAN TO A NUMBER.
///
/// ─── 85 MEANS NOTHING TO ANYONE ──────────────────────────────────────────────
///
/// A bare JPEG quality figure is a number from inside the encoder. The sentence
/// under it helped, but the thing a person actually wants to know is how much
/// smaller their own files get, and that is measured and sitting right there in
/// the previews.
///
/// So the bar is the control's real output: full width is what the selection
/// weighs now, the filled part is what it would weigh after, and the gap is the
/// saving. Moving the slider moves the bar, which is the only feedback here
/// that is about the pictures rather than about the codec.
///
/// It also animates in on open, because a bar that is simply present reads as a
/// static diagram, and one that arrives reads as a measurement that was taken.
class _Quality extends StatelessWidget {
  const _Quality({
    required this.quality,
    required this.originalBytes,
    required this.newBytes,
    required this.onChanged,
    required this.onSettled,
  });

  final int quality;

  /// What the measured files weigh now, and what they would weigh after.
  /// Both zero until the first previews land, which draws an empty track.
  final int originalBytes;
  final int newBytes;

  final void Function(int) onChanged;
  final VoidCallback onSettled;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final int saved = originalBytes - newBytes;
    final double fraction = originalBytes <= 0
        ? 0
        : (newBytes / originalBytes).clamp(0.0, 1.0);

    return GCard(
      padding: const EdgeInsets.fromLTRB(
        GSpace.md,
        GSpace.md - 2,
        GSpace.md,
        GSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Text(
                  saved > 0
                      ? 'Selected files would lose ${GFormat.bytes(saved)}'
                      : 'Quality',
                  style: GType.bodySmall.copyWith(color: t.text),
                ),
              ),
              Text(
                '$quality',
                style: GType.monoNumber.copyWith(color: t.dim, fontSize: 13),
              ),
            ],
          ),

          const SizedBox(height: GSpace.sm + 2),
          _SqueezeBar(fraction: fraction),
          const SizedBox(height: GSpace.sm),

          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: t.accent,
              inactiveTrackColor: t.panelAlt,
              thumbColor: t.accent,
              overlayColor: t.accentSoft,
            ),
            child: Slider(
              value: quality.toDouble(),
              min: 60,
              max: 95,
              divisions: 7,
              onChanged: (double value) => onChanged(value.round()),
              onChangeEnd: (_) => onSettled(),
            ),
          ),
          Text(_describe(quality), style: GType.micro.copyWith(color: t.muted)),
        ],
      ),
    );
  }

  /// What the number means to someone who does not know what JPEG quality is.
  static String _describe(int quality) {
    if (quality >= 90) return 'Almost no visible change, smaller saving';
    if (quality >= 80) return 'No visible change on a phone screen';
    if (quality >= 70) return 'Slightly soft in skies and skin';
    return 'Visible on close inspection, biggest saving';
  }
}

/// The bar the quality control is really about.
///
/// One track holding two lengths: what remains, and what goes. It animates to
/// every new value rather than cutting, because the point of moving the slider
/// is watching this move, and a bar that teleports gives no sense of how much
/// the last five points of quality actually bought.
class _SqueezeBar extends StatelessWidget {
  const _SqueezeBar({required this.fraction});

  /// New size over original. 0 draws an empty track, which is the honest state
  /// before anything has been measured.
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: fraction),
      duration: GMotion.slow,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? _) => ClipRRect(
        borderRadius: GRadius.all(5),
        child: SizedBox(
          height: 10,
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: ColoredBox(color: t.accentSoft)),
              FractionallySizedBox(
                widthFactor: value,
                child: ColoredBox(color: t.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// WHAT IS HAPPENING, WHILE IT HAPPENS.
///
/// ─── THE PROGRESS WAS ALWAYS THERE ───────────────────────────────────────────
///
/// This screen used to be a spinner and a paragraph, over a run that can take a
/// minute on fifty photos. CompressProgress has carried the count, the file and
/// the bytes saved since the first version of the bridge and nothing read it.
///
/// ─── THE ANIMATION SAYS WHAT THE WORD SAYS ───────────────────────────────────
///
/// Two plates closing on a stack of bars, over and over. A spinner means "the
/// app is busy" and nothing more; this means compression, which is worth the
/// pixels on the one screen in the app where a person is waiting with nothing
/// to do.
class _Running extends ConsumerWidget {
  const _Running();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    final CompressProgress? p = ref.watch(compressProgressProvider).value;

    final int done = p?.done ?? 0;
    final int total = p?.total ?? 0;
    final int saved = p?.savedBytes ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const _Squeezing(),
          const SizedBox(height: GSpace.xl),

          Text(
            saved > 0 ? GFormat.bytes(saved) : 'Working',
            style: GType.monoDisplay.copyWith(color: t.accent),
          ),
          const SizedBox(height: GSpace.xs),
          Text(
            saved > 0 ? 'freed so far' : 'reading the first one',
            style: GType.micro.copyWith(color: t.muted),
          ),

          const SizedBox(height: GSpace.xl),

          if (total > 0) ...<Widget>[
            ClipRRect(
              borderRadius: GRadius.all(4),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(child: ColoredBox(color: t.panelAlt)),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: (done / total).clamp(0.0, 1.0),
                      ),
                      duration: GMotion.slow,
                      curve: Curves.easeOut,
                      builder:
                          (BuildContext context, double value, Widget? _) =>
                              FractionallySizedBox(
                                widthFactor: value,
                                child: ColoredBox(color: t.accent),
                              ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: GSpace.sm + 2),
            Text(
              '${GFormat.count(done)} of ${GFormat.count(total)}',
              style: GType.monoSmall.copyWith(color: t.dim),
            ),
          ],

          // The name only while there is one. Between files it is null, and a
          // row that empties and refills every second is worse than a row that
          // is sometimes absent.
          if (p?.currentName != null) ...<Widget>[
            const SizedBox(height: GSpace.sm),
            Text(
              p!.currentName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GType.micro.copyWith(color: t.dim),
            ),
          ],
        ],
      ),
    );
  }
}

/// THE ACTION BUTTON, AND ITS NUMBER CLIMBS.
///
/// ─── THE LABEL LEADS WITH THE VERB AND ENDS WITH THE PAYOFF ──────────────────
///
/// It read "Shrink 57, save 51.2 MB", which puts a count the user can already
/// see in the app bar ahead of the only figure they came for. Compress is also
/// the word on every other surface that points here, and a button that renames
/// the action at the moment of pressing it is a small betrayal of the path that
/// got them there.
///
/// ─── THE FIGURE IS TWEENED, WHICH IS NOT DECORATION ──────────────────────────
///
/// Measurement lands twelve files at a time as the list is scrolled, so the
/// total arrives in steps. Snapping between them looks like a glitch; climbing
/// says the app is still measuring and the number is still going up, which is
/// exactly what is happening and is the reason to keep scrolling.
///
/// It tweens from whatever was last shown rather than from zero, so a scroll
/// that adds two files nudges the figure instead of replaying the whole count.
class _Action extends StatefulWidget {
  const _Action({
    required this.none,
    required this.saving,
    required this.onPressed,
  });

  final bool none;
  final int saving;
  final VoidCallback onPressed;

  @override
  State<_Action> createState() => _ActionState();
}

class _ActionState extends State<_Action> {
  /// Where the last tween finished, so the next one starts from it.
  int _shown = 0;

  @override
  Widget build(BuildContext context) {
    final bool ready = !widget.none && widget.saving > 0;

    if (widget.none || widget.saving == 0) {
      _shown = 0;
      return GButton(
        label: widget.none ? 'Select files to compress' : 'Measuring',
        icon: Icons.compress_rounded,
        onPressed: null,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _shown.toDouble(), end: widget.saving.toDouble()),
      duration: GMotion.slow,
      curve: Curves.easeOut,
      onEnd: () => _shown = widget.saving,
      builder: (BuildContext context, double value, Widget? _) => GButton(
        label: 'Compress and free ${GFormat.bytes(value.round())}',
        icon: Icons.compress_rounded,
        onPressed: ready ? widget.onPressed : null,
      ),
    );
  }
}

/// A tall stack of layers settling into a shorter, denser one.
///
/// ─── WHY THIS AND NOT THE JAWS ───────────────────────────────────────────────
///
/// The first version was two plates crushing a stack, which reads instantly and
/// says the wrong thing: it is a machine destroying something, and the thing on
/// the screen is the user's photograph. A scanning beam says scanning, which
/// this app already has three screens for. A contracting pixel grid says fewer
/// pixels, which is the single promise this feature makes and keeps.
///
/// Layers settling is the same material occupying less room. That is the claim,
/// so that is the picture.
///
/// ─── BOTTOM UP, ONE AT A TIME ────────────────────────────────────────────────
///
/// A whole stack scaling at once reads as a zoom out. Staggering from the
/// bottom reads as weight, which is the difference between something shrinking
/// and something compacting.
///
/// ─── AND ITS RESTING SHAPE IS THE FINISHED STATE ─────────────────────────────
///
/// Held still at any point it is a legible stack, so reduce-motion renders the
/// settled position and needs no separate illustration.
class _Squeezing extends StatefulWidget {
  const _Squeezing();

  @override
  State<_Squeezing> createState() => _SqueezingState();
}

class _SqueezingState extends State<_Squeezing>
    with SingleTickerProviderStateMixin {
  // Constructed in initState, never as a late final field initialiser: a field
  // initialiser cannot reach `this` for the vsync and the failure is at
  // runtime rather than at compile time.
  late final AnimationController _controller;

  /// Deterministic widths, so it reads as a stack of content rather than as a
  /// widget. Never Random, which would reshuffle on every rebuild.
  static const List<double> _widths = <double>[
    0.94, 0.72, 0.88, 0.63, 0.80, 0.70, 0.86, 0.58,
  ];

  static const double _tall = 9;
  static const double _short = 3;
  static const double _gap = 3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return _stack(1);

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) => _stack(null),
    );
  }

  /// [forced] pins every layer to one point in the cycle, for reduce motion.
  Widget _stack(double? forced) {
    // Not const. `.length` on a const list is not itself a constant
    // expression, which the analyzer allows and the kernel compiler rejects.
    final int count = _widths.length;

    return SizedBox(
      // Fixed, and bottom aligned. The bars really change height rather than
      // being scaled, so the Column shrinks, and without a fixed box the whole
      // screen would breathe around it once a second.
      height: count * _tall + (count - 1) * _gap,
      width: 104,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = count - 1; i >= 0; i--) ...<Widget>[
              _Layer(
                widthFactor: _widths[i],
                settled: forced ?? _settledAt(i, count),
                tall: _tall,
                short: _short,
              ),
              if (i > 0) const SizedBox(height: _gap),
            ],
          ],
        ),
      ),
    );
  }

  /// How far through its own settle this layer is, 0 to 1.
  double _settledAt(int index, int count) {
    // Bottom first. Index 0 is the bottom layer and leads.
    final double delay = index * 0.045;
    double t = (_controller.value - delay) % 1.0;
    if (t < 0) t += 1;

    // Wait, fall, hold, rise. The hold is what makes it read as settled rather
    // than as a bounce.
    if (t < 0.35) return 0;
    if (t < 0.62) return Curves.easeOut.transform((t - 0.35) / 0.27);
    if (t < 0.88) return 1;
    return 1 - Curves.easeIn.transform((t - 0.88) / 0.12);
  }
}

class _Layer extends StatelessWidget {
  const _Layer({
    required this.widthFactor,
    required this.settled,
    required this.tall,
    required this.short,
  });

  final double widthFactor;
  final double settled;
  final double tall;
  final double short;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: tall - (tall - short) * settled,
        decoration: BoxDecoration(
          // Denser as it settles, which is the other half of the idea: the
          // same content, packed tighter.
          color: t.accent.withValues(alpha: 0.35 + settled * 0.6),
          borderRadius: GRadius.all(3),
        ),
      ),
    );
  }
}
