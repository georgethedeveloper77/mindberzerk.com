import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/theme/tokens.dart';
import '../bridge/recovery_bridge.dart';

/// An ImageProvider backed by the native thumbnailer.
///
/// Custom rather than Image.memory with a FutureBuilder, and the reason is
/// Flutter's own image cache. An ImageProvider gets LRU caching, deduplicated
/// in-flight loads, and automatic eviction for free; a FutureBuilder re-fetches
/// and re-decodes on every rebuild, which in a scrolling list means a platform
/// channel round trip per frame.
///
/// Equality is (itemId, maxPixels) ONLY. The bridge is excluded on purpose: it
/// is an injected collaborator, not part of the image's identity, and including
/// it would make every provider instance unique and defeat the cache entirely.
@immutable
class ItemThumbnail extends ImageProvider<ItemThumbnail> {
  const ItemThumbnail({
    required this.itemId,
    required this.bridge,
    this.maxPixels = 512,
  });

  final String itemId;
  final RecoveryBridge bridge;
  final int maxPixels;

  @override
  Future<ItemThumbnail> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<ItemThumbnail>(this);

  @override
  ImageStreamCompleter loadImage(
    ItemThumbnail key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: 1,
      debugLabel: key.itemId,
    );
  }

  Future<ui.Codec> _load(ItemThumbnail key, ImageDecoderCallback decode) async {
    final Uint8List? bytes = await key.bridge.thumbnail(
      key.itemId,
      key.maxPixels,
    );
    if (bytes == null || bytes.isEmpty) {
      // Evicting first stops the failure being cached as a permanent hole: a
      // trashed item whose thumbnail was not ready yet should get another
      // chance on the next build.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      throw StateError('no preview for ${key.itemId}');
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is ItemThumbnail &&
      other.itemId == itemId &&
      other.maxPixels == maxPixels;

  @override
  int get hashCode => Object.hash(itemId, maxPixels);
}

/// Draws a preview, or a kind glyph when there is none.
///
/// The fallback is not an error state. Audio files and documents have no
/// preview and never will, and a broken image icon would say the app failed at
/// something it never attempted.
class GThumbnail extends StatelessWidget {
  const GThumbnail({
    required this.itemId,
    required this.bridge,
    required this.kind,
    super.key,
    this.maxPixels = 512,
    this.fit = BoxFit.cover,
    this.radius,
  });

  final String itemId;
  final RecoveryBridge bridge;
  final String kind;
  final int maxPixels;
  final BoxFit fit;
  final double? radius;

  bool get _renderable => kind == 'image' || kind == 'video';

  @override
  Widget build(BuildContext context) {
    final GTokens t = context.g;
    final BorderRadius corners = GRadius.all(radius ?? GRadius.tile);

    if (!_renderable) {
      return ClipRRect(
        borderRadius: corners,
        child: ColoredBox(
          color: t.panelAlt,
          child: Center(child: Icon(_glyph(), size: 20, color: t.dim)),
        ),
      );
    }

    return ClipRRect(
      borderRadius: corners,
      child: Image(
        image: ItemThumbnail(
          itemId: itemId,
          bridge: bridge,
          maxPixels: maxPixels,
        ),
        fit: fit,
        gaplessPlayback: true,
        frameBuilder:
            (
              BuildContext context,
              Widget child,
              int? frame,
              bool wasSynchronouslyLoaded,
            ) {
              if (wasSynchronouslyLoaded || frame != null) return child;
              return ColoredBox(color: t.panelAlt);
            },
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            ColoredBox(
              color: t.panelAlt,
              child: Center(child: Icon(_glyph(), size: 20, color: t.dim)),
            ),
      ),
    );
  }

  IconData _glyph() {
    switch (kind) {
      case 'image':
        return Icons.photo_outlined;
      case 'video':
        return Icons.play_circle_outline;
      case 'audio':
        return Icons.graphic_eq_rounded;
      case 'document':
        return Icons.description_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}
