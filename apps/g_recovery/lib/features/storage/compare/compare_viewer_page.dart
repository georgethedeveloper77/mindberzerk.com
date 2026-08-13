import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format.dart';
import '../../../ui/g_button.dart';
import '../state/storage_files.dart';
import '../../../core/i18n/g_strings.dart';

/// LOOKING PROPERLY BEFORE CHOOSING.
///
/// The piece the review screens were missing. A person deciding which of four
/// identical photos to keep was doing it from a 96 pixel thumbnail, which is not
/// a decision, it is a guess.
///
/// ─── IT COMPARES, IT DOES NOT JUST ENLARGE ───────────────────────────────────
///
/// The bar at the bottom shows the current keeper beside the one on screen, so
/// the question being answered is "is this one better than the one I am
/// keeping" rather than "is this one good". On a burst of six that is the only
/// question that matters.
///
/// ─── ONE BUTTON, AND IT IS THE ONLY ACTION ───────────────────────────────────
///
/// Nothing is trashed from here. The viewer moves the keeper and closes; every
/// removal happens on the review screen where the count is visible. A full
/// screen photo with a delete button under it is how someone removes the wrong
/// thing quickly.
class CompareViewerPage extends ConsumerStatefulWidget {
  const CompareViewerPage({
    required this.fileIds,
    required this.sizes,
    required this.index,
    required this.keeperId,
    this.onKeep,
    super.key,
  });

  final List<String> fileIds;

  /// Size per file id, so the comparison bar has something to compare. Passed in
  /// rather than looked up, because the review screen already holds it.
  final Map<String, int> sizes;

  final int index;
  final String keeperId;

  /// Null on the blurred grid, which has no keeper: there the viewer is only an
  /// enlargement and the button does not appear.
  final void Function(String fileId)? onKeep;

  static Route<void> route({
    required List<String> fileIds,
    required Map<String, int> sizes,
    required int index,
    required String keeperId,
    void Function(String)? onKeep,
  }) => MaterialPageRoute<void>(
    builder: (BuildContext context) => CompareViewerPage(
      fileIds: fileIds,
      sizes: sizes,
      index: index,
      keeperId: keeperId,
      onKeep: onKeep,
    ),
  );

  @override
  ConsumerState<CompareViewerPage> createState() => _CompareViewerPageState();
}

class _CompareViewerPageState extends ConsumerState<CompareViewerPage> {
  late final PageController _pages;
  late int _at;
  late String _keeper;

  @override
  void initState() {
    super.initState();
    _at = widget.index;
    _keeper = widget.keeperId;
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
    final bool isKeeper = current == _keeper;

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
                      '${_at + 1} of ${widget.fileIds.length} in this set',
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
                onPageChanged: (int i) => setState(() => _at = i),
                itemBuilder: (BuildContext context, int i) =>
                    _Frame(fileId: widget.fileIds[i]),
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
                  if (widget.onKeep != null)
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _Side(
                            label: context.s('Keeping'),
                            value: GFormat.bytes(widget.sizes[_keeper] ?? 0),
                            highlight: true,
                          ),
                        ),
                        const SizedBox(width: GSpace.sm + 1),
                        Expanded(
                          child: _Side(
                            label: isKeeper ? 'This one' : 'Would be trashed',
                            value: GFormat.bytes(widget.sizes[current] ?? 0),
                            highlight: false,
                          ),
                        ),
                      ],
                    ),
                  if (widget.onKeep != null && !isKeeper) ...<Widget>[
                    const SizedBox(height: GSpace.md),
                    GButton(
                      label: context.s('Keep this one instead'),
                      icon: Icons.check_rounded,
                      onPressed: () {
                        widget.onKeep!(current);
                        setState(() => _keeper = current);
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
}

class _Frame extends ConsumerWidget {
  const _Frame({required this.fileId});

  final String fileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GTokens t = context.g;
    // 1600, not the grid's 256. The whole point of this screen is seeing
    // detail, and a thumbnail stretched to full width shows less than the grid
    // it came from.
    final Uint8List? bytes = ref
        .watch(
          storageThumbProvider(
            ThumbRequest(fileId: fileId, kind: 'image', maxPixels: 1600),
          ),
        )
        .value;

    if (bytes == null) {
      return Center(
        child: Text(
          context.s('Loading'),
          style: GType.monoSmall.copyWith(color: t.dim),
        ),
      );
    }

    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
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
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlight ? t.success.withValues(alpha: 0.16) : t.panel,
        border: Border.all(
          color: highlight ? t.success.withValues(alpha: 0.4) : t.line,
        ),
        borderRadius: GRadius.all(GRadius.tile),
      ),
      child: Padding(
        padding: const EdgeInsets.all(GSpace.md - 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              value,
              style: GType.monoNumber.copyWith(
                color: highlight ? t.success : t.text,
                fontSize: 16,
              ),
            ),
            Text(label, style: GType.micro.copyWith(color: t.muted)),
          ],
        ),
      ),
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
      color: t.panel,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(GSpace.sm + 1),
          child: Icon(icon, size: 19, color: t.text),
        ),
      ),
    );
  }
}
