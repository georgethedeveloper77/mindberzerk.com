import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/repositories/app_repository.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';

/// Dart-side icon access.
///
/// Native already has a memory LRU + disk cache, so this layer exists only to
/// stop the SAME widget re-crossing the platform channel on every rebuild. It
/// caches the in-flight Future, not the bytes — the bytes live natively, where
/// they are shared across every widget that wants them.
final iconProvider =
    FutureProvider.family<Uint8List?, IconRequest>((ref, request) async {
  final api = ref.read(launcherHostApiProvider);
  return api.getIcon(request.componentKey, request.sizePx);
});

@immutable
class IconRequest {
  const IconRequest(this.componentKey, this.sizePx);
  final String componentKey;
  final int sizePx;

  @override
  bool operator ==(Object other) =>
      other is IconRequest &&
      other.componentKey == componentKey &&
      other.sizePx == sizePx;

  @override
  int get hashCode => Object.hash(componentKey, sizePx);
}

/// Applies the active theme's icon style natively and drops the memory cache.
///
/// Call this on theme switch. Bump [themeId] whenever the style changes — it is
/// part of every cache key, and a stale id means stale icons.
final setIconThemeProvider =
    Provider<Future<void> Function(String, IconStyle)>((ref) {
  return (themeId, style) =>
      ref.read(launcherHostApiProvider).setIconTheme(themeId, style);
});

/// One themed app icon.
///
/// Deliberately NOT animated on first paint. A drawer where 40 icons each fade
/// in on their own schedule looks like a slow web page. Cached icons resolve in
/// microseconds and should appear instantly; only genuinely cold ones show the
/// placeholder, and they should be rare after first run.
class AppIcon extends ConsumerWidget {
  const AppIcon({
    super.key,
    required this.entry,
    required this.size,
  });

  final AppEntry entry;

  /// Logical pixels. The native side is asked for the DEVICE-pixel size, since
  /// upscaling a 96px bitmap to 144px looks exactly as bad as it sounds.
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final sizePx = (size * dpr).round();

    final icon =
        ref.watch(iconProvider(IconRequest(entry.componentKey, sizePx)));

    return SizedBox(
      width: size,
      height: size,
      child: icon.when(
        data: (bytes) {
          if (bytes == null) return const SizedBox.shrink();
          return Opacity(
            // Suspended apps grey out rather than disappear — hiding them makes
            // people think the app was uninstalled.
            opacity: entry.isSuspended ? 0.4 : 1.0,
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

/// The brand glyph for a launcher-owned drawer entry, chosen by the active theme.
///
/// **Superseded by `ThemeSpec.logo`.** [LauncherBrandIcon] no longer calls this;
/// it reads the theme's own light/dark logo pair as DATA. Kept only so any
/// remaining caller compiles — point those at `theme.spec.logo` and delete this.
///
/// This is a bundled ASSET, not a native package icon: launcher entries have no
/// component key, so they never go through [AppIcon] / native `getIcon`.
String launcherBrandAsset(String themeSpecId) {
  return switch (themeSpecId) {
    'ubuntu-24-04' => 'assets/svg/ubuntu2410.svg',
    _ => 'assets/brand/mindhunter_mark.png',
  };
}

/// Renders the active theme's brand mark at drawer-icon size, for the launcher's
/// own entries (which have no component key and never touch native `getIcon`).
///
/// Two rendering paths, chosen by whether the theme ships a logo:
///
///  - **Theme HAS a logo** ([ThemeSpec.logo]): pick the surface-matched variant.
///    On a LIGHT surface it renders as authored (the light variant is dark-ink
///    art that reads on a pale background). On a DARK surface it is tinted to
///    `onDark`, because a coloured mark can go muddy on dark chrome and a
///    whitened silhouette guarantees contrast and matches the gear beside it.
///    Surface brightness is read from `onDark`'s own luminance (the colour is,
///    by definition, the one legible on this theme's surface).
///
///  - **Theme has NO logo**: fall back to the Mindhunter mark. HERE srcIn earns
///    its place — one monochrome silhouette, tinted to `onDark`, legible on any
///    theme, reading as chrome the same as the Device Settings gear, until that
///    distro ships its own logo.
class LauncherBrandIcon extends StatelessWidget {
  const LauncherBrandIcon({
    super.key,
    required this.theme,
    required this.size,
  });

  final EffectiveTheme theme;
  final double size;

  @override
  Widget build(BuildContext context) {
    final logo = theme.spec.logo;
    final onDark = theme.palette.onDark;

    // onDark is the colour chosen to read on this theme's chrome, so its own
    // luminance IS that chrome's brightness, read backwards. A light onDark
    // (e.g. white on Ubuntu's aubergine) means a dark surface. No new theme
    // field needed to know which artwork to show.
    final surfaceIsDark = onDark.computeLuminance() > 0.5;

    if (logo != null) {
      final asset = surfaceIsDark ? logo.dark : logo.light;

      // The rule: light-surface art is rendered AS AUTHORED (the light variant
      // is already dark-ink and reads on a pale background on its own), while
      // the dark-surface variant is tinted to onDark. A coloured mark can go
      // muddy on dark chrome, and srcIn-to-onDark guarantees contrast and makes
      // it a matched pair with the label and the Device Settings gear beside it.
      final ColorFilter? svgTint =
          surfaceIsDark ? ColorFilter.mode(onDark, BlendMode.srcIn) : null;

      final Widget mark = asset.endsWith('.svg')
          ? SvgPicture.asset(
              asset,
              width: size,
              height: size,
              colorFilter: svgTint,
            )
          : Image.asset(
              asset,
              width: size,
              height: size,
              // color: null on a light surface leaves the raster untinted; the
              // blend mode is ignored when color is null.
              color: surfaceIsDark ? onDark : null,
              colorBlendMode: BlendMode.srcIn,
              filterQuality: FilterQuality.medium,
            );
      return SizedBox(width: size, height: size, child: mark);
    }

    final Widget fallback = Image.asset(
      'assets/brand/mindhunter_mark.png',
      width: size,
      height: size,
      color: onDark,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.medium,
    );
    return SizedBox(width: size, height: size, child: fallback);
  }
}
