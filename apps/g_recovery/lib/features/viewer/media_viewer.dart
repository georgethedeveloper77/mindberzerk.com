import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../bridge/recovery_api.g.dart';
import '../../core/format.dart';
import '../../ui/g_badge.dart';
import '../../ui/g_thumbnail.dart';
import '../recovery/state/recovery_providers.dart';

/// Full screen view of one item, swipeable across the whole list.
///
/// Its own route rather than an overlay, so pinch and pan have the surface to
/// themselves. That is the same reason the review deck opens a route instead of
/// zooming in place: a scale gesture and a horizontal drag on one surface fight
/// each other, and every pinch starts life as a pan.
class MediaViewer extends ConsumerStatefulWidget {
  const MediaViewer({required this.items, required this.index, super.key});

  final List<RecoverableItem> items;
  final int index;

  static Route<void> route({
    required List<RecoverableItem> items,
    required int index,
  }) =>
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: GMotion.fast,
        pageBuilder: (BuildContext context, Animation<double> a,
                Animation<double> b) =>
            MediaViewer(items: items, index: index),
        transitionsBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondary,
          Widget child,
        ) =>
            FadeTransition(opacity: animation, child: child),
      );

  @override
  ConsumerState<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends ConsumerState<MediaViewer> {
  late final PageController _pages;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.index;
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
    final RecoverableItem item = widget.items[_current];

    return Scaffold(
      backgroundColor: t.scrim,
      body: Stack(
        children: <Widget>[
          PageView.builder(
            controller: _pages,
            itemCount: widget.items.length,
            onPageChanged: (int index) => setState(() => _current = index),
            itemBuilder: (BuildContext context, int index) {
              return InteractiveViewer(
                minScale: 1,
                maxScale: 6,
                child: Center(
                  child: GThumbnail(
                    itemId: widget.items[index].itemId,
                    bridge: ref.watch(recoveryBridgeProvider),
                    kind: widget.items[index].kind,
                    // 2048, the largest the native thumbnailer will produce.
                    // Full resolution would be the original file, which for a
                    // 108 megapixel photo is a decode nobody asked for.
                    maxPixels: 2048,
                    fit: BoxFit.contain,
                    radius: 0,
                  ),
                ),
              );
            },
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(GSpace.md),
              child: Row(
                children: <Widget>[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.panel,
                        borderRadius: GRadius.all(GRadius.glyph),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: t.text,
                        size: 19,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_current + 1} / ${widget.items.length}',
                    style: GType.monoSmall.copyWith(color: t.text),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(GSpace.gutter, 24,
                    GSpace.gutter, GSpace.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      t.scrim.withValues(alpha: 0),
                      t.scrim,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        if (item.role == 'status')
                          GBadge.partial('Status')
                        else if (item.fidelity == 'preview')
                          GBadge.partial('Preview only')
                        else
                          GBadge.full('Full quality'),
                        if (item.origin != null) ...<Widget>[
                          const SizedBox(width: GSpace.sm),
                          GBadge(label: item.origin!),
                        ],
                      ],
                    ),
                    const SizedBox(height: GSpace.sm + 2),
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GType.monoNumber.copyWith(color: t.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      <String>[
                        GFormat.bytes(item.sizeBytes),
                        if (item.width != null && item.height != null)
                          '${item.width} x ${item.height}',
                        if (item.durationMillis != null)
                          GFormat.duration(
                            Duration(milliseconds: item.durationMillis!),
                          ),
                      ].join('  /  '),
                      style: GType.monoSmall.copyWith(color: t.muted),
                    ),
                    if (item.kind == 'video') ...<Widget>[
                      const SizedBox(height: GSpace.sm),
                      Text(
                        // Honest rather than a dead play button. Playback
                        // needs a decoder this build does not carry yet.
                        'Playback arrives in the next update. This is the '
                        'first frame.',
                        style: GType.micro.copyWith(color: t.dim),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
