/// A glyph for panel chrome, drawn from the distro's own icon pack.
///
/// The quick-settings button is the one control every panel distro shares, and
/// a stock Material `tune` makes it the one thing in the bar that belongs to no
/// distro. Every pack already draws Android's Settings app in its own style, so
/// the button wears that drawing, bare, in the bar's ink.
///
/// The bitmap comes from native (`getBareGlyph`), never from a Dart renderer:
/// native owns the pack, its parser and the stroke rules, and two renderers
/// would drift. Native returns white on transparency and this widget tints it
/// with `srcIn`, so the ink can change when Quick Settings opens without a
/// second round trip.
library;

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/cdn/pack_repository.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../engine/effective_theme.dart';

/// Android's Settings app. The same package on AOSP, Pixel, Samsung and the
/// other large OEMs, which is why it is a constant rather than a lookup.
const String kSettingsPackage = 'com.android.settings';

/// What a bare glyph was drawn with. [styleId] is `EffectiveTheme.iconCacheId`
/// plus the pack generation, the same pair `AppIcon` keys on, so a pack change
/// re-asks exactly when the drawing could have changed.
@immutable
class GlyphRequest {
  const GlyphRequest(this.packageName, this.sizePx, this.styleId);

  final String packageName;
  final int sizePx;
  final String styleId;

  @override
  bool operator ==(Object other) =>
      other is GlyphRequest &&
      other.packageName == packageName &&
      other.sizePx == sizePx &&
      other.styleId == styleId;

  @override
  int get hashCode => Object.hash(packageName, sizePx, styleId);
}

/// PNG bytes, or null when the applied pack has no drawing for the package.
final bareGlyphProvider =
    FutureProvider.family<Uint8List?, GlyphRequest>((ref, request) async {
  // No style yet means no pack loaded: answer null and let the fallback draw,
  // rather than asking native a question it cannot answer correctly.
  if (request.styleId.isEmpty) return null;
  final api = ref.read(launcherHostApiProvider);
  return api.getBareGlyph(request.packageName, request.sizePx);
});

/// The distro pack's drawing of [packageName] at [size], tinted [color], or
/// [fallback] when the pack has none.
///
/// The fallback is also what shows while the bitmap is in flight. It is the
/// same size and ink, so the first frame is a glyph rather than a hole.
class DistroGlyph extends ConsumerWidget {
  const DistroGlyph({
    super.key,
    required this.packageName,
    required this.size,
    required this.color,
    required this.fallback,
  });

  final String packageName;
  final double size;
  final Color color;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `hasValue`, not `asData`, for the reason spelled out in `AppIcon`: a
    // refresh must not blank the key and send every glyph back to loading.
    final styleId = ref.watch(
      effectiveThemeProvider
          .select((t) => t.hasValue ? t.requireValue.iconCacheId : ''),
    );
    final generation = ref.watch(iconPackGenerationProvider);
    final sizePx = (size * MediaQuery.devicePixelRatioOf(context)).round();

    final bytes = ref
        .watch(bareGlyphProvider(
          GlyphRequest(
            packageName,
            sizePx,
            styleId.isEmpty ? '' : '$styleId|$generation',
          ),
        ))
        .asData
        ?.value;

    if (bytes == null) return fallback;
    return Image.memory(
      bytes,
      width: size,
      height: size,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
  }
}
