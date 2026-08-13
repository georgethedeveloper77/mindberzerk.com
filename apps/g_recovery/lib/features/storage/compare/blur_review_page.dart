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
import '../../../ui/g_sheet.dart';
import '../state/storage_files.dart';
import '../state/storage_providers.dart';
import 'compare_viewer_page.dart';

/// PHOTOS THAT CAME OUT SOFT.
///
/// A grid, not groups, because blur has no pairs: each photo is judged alone.
/// Worst first, so the ones a person will certainly not miss are the ones they
/// see before they get bored and leave.
///
/// ─── NOTHING IS PRESELECTED HERE, AND THAT IS THE DIFFERENCE ─────────────────
///
/// The duplicate screens preselect, because a byte identical copy is waste by
/// definition. Softness is not: a portrait with a deliberately blurred
/// background, a photograph of fog, a picture taken through a rainy window all
/// score low and none is a mistake. No measurement can tell blur from intent, so
/// the app suggests and the user chooses every single one.
class BlurReviewPage extends ConsumerStatefulWidget {
  const BlurReviewPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (BuildContext context) => const BlurReviewPage(),
  );

  @override
  ConsumerState<BlurReviewPage> createState() => _BlurReviewPageState();
}

class _BlurReviewPageState extends ConsumerState<BlurReviewPage> {
  final Set<String> _picked = <String>{};

  /// Already trashed. The findings are held natively and do not change when
  /// files are removed, so without this a photo stays in the grid after it has
  /// gone to the bin.
  final Set<String> _done = <String>{};

  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final List<BlurredImage> blurred = ref
        .watch(blurredProvider)
        .where((BlurredImage b) => !_done.contains(b.fileId))
        .toList();

    final int bytes = blurred
        .where((BlurredImage b) => _picked.contains(b.fileId))
        .fold<int>(0, (int sum, BlurredImage b) => sum + b.sizeBytes);

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSpace.gutter),
              child: GAppBar(
                title: 'Blurred',
                subtitle: blurred.isEmpty
                    ? null
                    : '${GFormat.count(blurred.length)} worth a look',
                leading: GIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                actions: <Widget>[
                  GIconButton(
                    icon: Icons.info_outline_rounded,
                    onTap: () => _explain(context),
                  ),
                ],
              ),
            ),

            if (blurred.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GSpace.gutter,
                  0,
                  GSpace.gutter,
                  GSpace.md,
                ),
                child: Text(
                  // Sets expectations before the first tap. A screen that
                  // offered to delete a deliberately soft portrait without
                  // warning would lose someone's favourite photograph.
                  'Softest first. Some of these will be deliberate, so nothing '
                  'is selected until you choose it.',
                  style: GType.bodySmall.copyWith(color: t.muted),
                ),
              ),

            Expanded(
              child: blurred.isEmpty
                  ? Center(
                      child: Text(
                        'Everything looks sharp.',
                        style: GType.bodySmall.copyWith(color: t.muted),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        GSpace.gutter,
                        0,
                        GSpace.gutter,
                        GSpace.xl,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 140,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                      itemCount: blurred.length,
                      itemBuilder: (BuildContext context, int index) {
                        final BlurredImage item = blurred[index];
                        return _Cell(
                          item: item,
                          selected: _picked.contains(item.fileId),
                          onTap: () => setState(() {
                            if (!_picked.remove(item.fileId)) {
                              _picked.add(item.fileId);
                            }
                          }),
                          onOpen: () => _open(blurred, index),
                        );
                      },
                    ),
            ),

            if (_picked.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GSpace.gutter,
                  0,
                  GSpace.gutter,
                  GSpace.lg,
                ),
                child: GButton(
                  label:
                      'Trash ${_picked.length}, free '
                      '${GFormat.bytes(bytes)}',
                  icon: Icons.restore_from_trash_rounded,
                  onPressed: _busy ? null : _remove,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Enlarges, with no keeper.
  ///
  /// Blur has no groups and no winner, so the viewer opens without its compare
  /// bar or its keep button. It is purely a bigger look, which is the whole
  /// question on this screen.
  void _open(List<BlurredImage> blurred, int at) {
    Navigator.of(context, rootNavigator: true).push(
      CompareViewerPage.route(
        fileIds: blurred.map((BlurredImage b) => b.fileId).toList(),
        sizes: <String, int>{
          for (final BlurredImage b in blurred) b.fileId: b.sizeBytes,
        },
        index: at,
        keeperId: '',
      ),
    );
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    final List<StorageOutcome> outcomes = await ref
        .read(storageBridgeProvider)
        .remove(_picked.toList(), permanent: false);
    if (!mounted) return;

    final int ok = outcomes
        .where(
          (StorageOutcome o) => o.status == 'trashed' || o.status == 'deleted',
        )
        .length;

    GMessenger.show(context, GMessage.success('$ok moved to trash'));

    // Stays on the page. Trashing four photos out of sixty three is not a
    // reason to close a list someone is halfway through.
    setState(() {
      _busy = false;
      _done.addAll(_picked);
      _picked.clear();
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
    // On the way out only, so the card on the storage tab recomputes rather
    // than counting photos that are now in the bin.
    //
    // Only the photos trashed here, not the whole scan. Removing four soft
    // photos is no reason to discard every duplicate group the same pass found.
    if (_done.isNotEmpty) {
      _compare.forgetBlurred(_done);
    }
    super.dispose();
  }

  void _explain(BuildContext context) {
    final GTokens t = context.g;
    showGSheet(
      context: context,
      title: 'How this is measured',
      children: <Widget>[
        Text(
          'Each photo is scored on how abruptly its brightness changes. A sharp '
          'picture has hard edges somewhere; a soft one changes gently '
          'everywhere.',
          style: GType.bodySmall.copyWith(color: t.muted),
        ),
        const GSheetHeading('What it cannot tell'),
        GSheetPoint(
          text:
              'A portrait with a deliberately blurred background scores low '
              'and is not a mistake.',
        ),
        GSheetPoint(
          text:
              'So does fog, a plain wall, and anything photographed in the '
              'dark.',
        ),
        const GSheetHeading('So nothing is chosen for you'),
        GSheetPoint(
          icon: Icons.check_rounded,
          tone: t.success,
          text:
              'Every photo here is a suggestion. Nothing is selected until '
              'you tap it, and everything goes to the trash rather than being '
              'deleted.',
        ),
      ],
    );
  }
}

/// Same first tap rule as the duplicate strips.
///
/// onDoubleTap would withhold onTap for 300ms, which on a selection grid reads
/// as the tick simply not appearing. The double tap is detected by hand so the
/// first tap always does something.
class _Cell extends ConsumerStatefulWidget {
  const _Cell({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onOpen,
  });

  final BlurredImage item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  ConsumerState<_Cell> createState() => _CellState();
}

class _CellState extends ConsumerState<_Cell> {
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
            ThumbRequest(
              fileId: widget.item.fileId,
              kind: 'image',
              maxPixels: 256,
            ),
          ),
        )
        .value;

    return GestureDetector(
      // Same gesture pair as the duplicate screens: tap chooses, double tap
      // opens. Deciding whether a photo is artistically soft or simply ruined
      // is not possible at 140 pixels, which is why the open matters most here.
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: GRadius.all(GRadius.tile),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (bytes == null)
              ColoredBox(color: t.panelAlt)
            else
              Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),

            Positioned(
              left: 5,
              bottom: 4,
              child: Text(
                // The raw score, shown rather than hidden behind a verdict. It
                // lets someone calibrate: after three photos they know what a
                // 40 looks like on their own camera.
                widget.item.sharpness.round().toString(),
                style: GType.monoSmall.copyWith(
                  color: t.text,
                  fontSize: 9.5,
                  shadows: <Shadow>[Shadow(color: t.scrim, blurRadius: 4)],
                ),
              ),
            ),

            Positioned(
              right: 5,
              top: 5,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: widget.selected ? t.accent : t.scrim,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.selected
                        ? t.accent
                        : t.text.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
                child: widget.selected
                    ? Icon(Icons.check_rounded, size: 12, color: t.onAccent)
                    : null,
              ),
            ),

            if (widget.selected)
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
}
