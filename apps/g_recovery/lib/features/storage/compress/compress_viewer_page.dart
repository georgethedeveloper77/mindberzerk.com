import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../bridge/compress_api.g.dart';
import '../../../bridge/compress_bridge.dart';
import '../../../core/format.dart';
import '../../../ui/g_button.dart';

/// LOOKING BEFORE AGREEING TO SOMETHING PERMANENT.
///
/// ─── THE PIECE WITHOUT WHICH THIS FEATURE SHOULD NOT SHIP ────────────────────
///
/// Photo compression is lossy and the original goes to the trash. Every other
/// destructive screen in this app puts the file in front of the user first: the
/// compare pages got a full screen viewer for a decision that only trashes
/// copies. Compression rewrites the picture itself and had nothing, which meant
/// people were approving artefacts they had never been shown.
///
/// ─── HOLD TO SEE THE ORIGINAL ────────────────────────────────────────────────
///
/// A press and hold swap rather than a split wipe. A wipe puts the two versions
/// side by side, so no part of the picture is ever seen in both states, and a
/// JPEG artefact is invisible unless you can watch the same pixels change. The
/// swap is also one handed, which matters when the other hand is holding the
/// phone up to the light.
///
/// ─── ONE TRANSFORM, SHARED ───────────────────────────────────────────────────
///
/// Both versions render inside a single InteractiveViewer rather than one each.
/// Two viewers would reset the zoom on every swap, and a comparison that cannot
/// be held at 1:1 while toggling shows nothing at all. This is the detail that
/// makes the screen work.
class CompressViewerPage extends ConsumerStatefulWidget {
  const CompressViewerPage({
    required this.fileIds,
    required this.index,
    required this.quality,
    required this.lossless,
    required this.excluded,
    this.onExclude,
    super.key,
  });

  final List<String> fileIds;
  final int index;
  final int quality;

  /// Screenshots. The two versions are identical, so no comparison is offered.
  final bool lossless;

  /// Live set from the list, so the button reads correctly on arrival.
  final Set<String> excluded;

  final void Function(String fileId)? onExclude;

  static Route<void> route({
    required List<String> fileIds,
    required int index,
    required int quality,
    required bool lossless,
    required Set<String> excluded,
    void Function(String)? onExclude,
  }) => MaterialPageRoute<void>(
    builder: (BuildContext context) => CompressViewerPage(
      fileIds: fileIds,
      index: index,
      quality: quality,
      lossless: lossless,
      excluded: excluded,
      onExclude: onExclude,
    ),
  );

  @override
  ConsumerState<CompressViewerPage> createState() => _CompressViewerPageState();
}

class _CompressViewerPageState extends ConsumerState<CompressViewerPage> {
  late final PageController _pages;
  late int _at;

  /// True while a finger is down.
  bool _showingOriginal = false;

  @override
  void initState() {
    super.initState();
    _at = widget.index;
    _pages = PageController(initialPage: widget.index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final String current = widget.fileIds[_at];
    final bool excluded = widget.excluded.contains(current);

    final CompressComparison? shot = ref
        .watch(
          compressComparisonProvider((
            fileId: current,
            quality: widget.quality,
          )),
        )
        .value;

    return Scaffold(
      backgroundColor: t.ink,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(GSpace.sm),
              child: Row(
                children: <Widget>[
                  _Round(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: GSpace.md),
                  Expanded(
                    child: Text(
                      '${_at + 1} of ${widget.fileIds.length}',
                      style: GType.bodySmall.copyWith(color: t.muted),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: widget.fileIds.length,
                onPageChanged: (int i) => setState(() {
                  _at = i;
                  // Released implicitly by the swipe. Leaving it true would put
                  // the next picture under an ORIGINAL label with no finger
                  // down to explain it.
                  _showingOriginal = false;
                }),
                itemBuilder: (BuildContext context, int i) => _Frame(
                  fileId: widget.fileIds[i],
                  quality: widget.quality,
                  lossless: widget.lossless,
                  showingOriginal: _showingOriginal && i == _at,
                  onHold: (bool down) =>
                      setState(() => _showingOriginal = down),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                GSpace.gutter,
                GSpace.md,
                GSpace.gutter,
                GSpace.lg,
              ),
              child: Column(
                children: <Widget>[
                  if (widget.lossless)
                    _Identical(saved: _delta(shot))
                  else
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _Side(
                            label: 'Original',
                            value: GFormat.bytesOrNull(shot?.originalBytes),
                            highlight: false,
                          ),
                        ),
                        const SizedBox(width: GSpace.sm + 1),
                        Expanded(
                          child: _Side(
                            label: 'After',
                            value: GFormat.bytesOrNull(shot?.newBytes),
                            highlight: true,
                          ),
                        ),
                      ],
                    ),
                  if (widget.onExclude != null) ...<Widget>[
                    const SizedBox(height: GSpace.md),
                    GButton(
                      label: excluded
                          ? 'Include this one'
                          : 'Leave this one alone',
                      icon: excluded
                          ? Icons.check_rounded
                          : Icons.block_rounded,
                      kind: GButtonKind.ghost,
                      onPressed: () {
                        widget.onExclude!(current);
                        setState(() {});
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int? _delta(CompressComparison? shot) => shot == null
      ? null
      : shot.originalBytes - shot.newBytes;
}

/// One picture, in both its versions, under one transform.
class _Frame extends ConsumerWidget {
  const _Frame({
    required this.fileId,
    required this.quality,
    required this.lossless,
    required this.showingOriginal,
    required this.onHold,
  });

  final String fileId;
  final int quality;
  final bool lossless;
  final bool showingOriginal;
  final void Function(bool down) onHold;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;

    final CompressComparison? shot = ref
        .watch(
          compressComparisonProvider((fileId: fileId, quality: quality)),
        )
        .value;

    if (shot == null) {
      return Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(color: t.accent, strokeWidth: 2.2),
        ),
      );
    }

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 6,
            child: Center(
              child: Stack(
                children: <Widget>[
                  // Both are laid out, and one is hidden with Opacity rather
                  // than swapped out of the tree. Rebuilding the child would
                  // decode the image again on every press and drop frames on a
                  // picture this size; it would also collapse the Stack's own
                  // size for an instant and make the whole thing jump.
                  Image.memory(shot.encoded, fit: BoxFit.contain),
                  if (!lossless)
                    Positioned.fill(
                      child: Opacity(
                        opacity: showingOriginal ? 1 : 0,
                        child: Image.memory(
                          shot.original,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        if (!lossless)
          Positioned.fill(
            child: GestureDetector(
              // Opaque so the whole frame is a hold target, and behind the
              // InteractiveViewer's own gestures so a pinch still zooms.
              behavior: HitTestBehavior.translucent,
              onTapDown: (_) => onHold(true),
              onTapUp: (_) => onHold(false),
              onTapCancel: () => onHold(false),
              onLongPressDown: (_) => onHold(true),
              onLongPressEnd: (_) => onHold(false),
              onLongPressCancel: () => onHold(false),
            ),
          ),

        Positioned(
          top: GSpace.md,
          left: 0,
          right: 0,
          child: Center(
            child: _Pill(
              label: lossless
                  ? 'Identical'
                  : showingOriginal
                  ? 'Original'
                  : 'After, quality $quality',
              tone: lossless
                  ? t.muted
                  : showingOriginal
                  ? t.warning
                  : t.accent,
            ),
          ),
        ),

        if (!lossless)
          Positioned(
            bottom: GSpace.md,
            left: 0,
            right: 0,
            child: Center(
              child: _Pill(
                label: 'Hold to see the original',
                tone: t.muted,
              ),
            ),
          ),
      ],
    );
  }
}

class _Identical extends StatelessWidget {
  const _Identical({required this.saved});

  final int? saved;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.10),
        border: Border.all(color: t.accent.withValues(alpha: 0.32)),
        borderRadius: GRadius.all(GRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(GSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.verified_outlined, size: 18, color: t.accent),
            const SizedBox(width: GSpace.md - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Nothing to compare',
                    style: GType.heading.copyWith(color: t.accent),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    saved == null
                        ? 'A screenshot is re-saved losslessly, so the new '
                              'file is identical to this one.'
                        : 'A screenshot is re-saved losslessly, so the new '
                              'file is identical to this one, at '
                              '${GFormat.bytes(saved!)} less.',
                    style: GType.bodySmall.copyWith(color: t.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.label,
    required this.value,
    required this.highlight,
  });

  final String label;

  /// Null while the comparison is still being made. Renders as an absent value
  /// rather than a zero, the same rule the rest of the app follows.
  final String? value;

  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.panel,
        border: Border.all(
          color: highlight ? t.accent.withValues(alpha: 0.4) : t.line,
        ),
        borderRadius: GRadius.all(GRadius.tile),
      ),
      child: Padding(
        padding: const EdgeInsets.all(GSpace.md - 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label.toUpperCase(),
              style: GType.badge.copyWith(color: t.dim),
            ),
            const SizedBox(height: 4),
            Text(
              value ?? '',
              style: GType.monoNumber.copyWith(
                color: highlight ? t.accent : t.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GSpace.md,
        vertical: GSpace.sm - 2,
      ),
      decoration: BoxDecoration(
        color: t.ink.withValues(alpha: 0.72),
        borderRadius: GRadius.all(GRadius.chip),
        border: Border.all(color: t.line),
      ),
      child: Text(label, style: GType.micro.copyWith(color: tone)),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    return Material(
      color: t.panelAlt,
      borderRadius: GRadius.all(GRadius.tile),
      child: InkWell(
        borderRadius: GRadius.all(GRadius.tile),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: t.muted),
        ),
      ),
    );
  }
}
