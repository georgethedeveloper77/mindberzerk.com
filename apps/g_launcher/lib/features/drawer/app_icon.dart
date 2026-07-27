import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/repositories/app_repository.dart';
import '../../data/cdn/pack_repository.dart';
import '../../engine/effective_theme.dart';
import '../../platform/launcher_api.g.dart';

/// Dart-side icon access.
///
/// Native already has a memory LRU + disk cache, so this layer exists only to
/// stop the SAME widget re-crossing the platform channel on every rebuild. It
/// caches the in-flight Future, not the bytes — the bytes live natively, where
/// they are shared across every widget that wants them.
///
/// ─── THIS FILE HAD A TWIN AT `features/icons/app_icon.dart` ─────────────────
///
/// The twin held the [IconRequest.cacheId] fix below and NOTHING IMPORTED IT.
/// Eight files import this path; zero imported that one. So the fix existed, was
/// correct, was carefully documented, and had never executed — every icon on
/// every device was served from a family keyed on `(componentKey, sizePx)`
/// alone.
///
/// That is the worst shape a bug can take in this codebase, and it is the third
/// instance of it: written, right, unwired. `IconPackPage`, `ThemeSource` and
/// this. When something here looks finished, check that something imports it.

final iconProvider =
    FutureProvider.family<Uint8List?, IconRequest>((ref, request) async {
  final api = ref.read(launcherHostApiProvider);
  return api.getIcon(request.componentKey, request.sizePx);
});

@immutable
class IconRequest {
  const IconRequest(this.componentKey, this.sizePx, this.cacheId);
  final String componentKey;
  final int sizePx;

  /// WHAT THE BYTES WERE RENDERED WITH, as one opaque string.
  ///
  /// It has to mirror `IconCache.cacheKey` on the native side, which is
  /// (componentKey, updateToken, themeId, sizePx, style fingerprint,
  /// systemIconPack). Anything native keys on and Dart does not is a stale icon
  /// that native would happily have re-rendered if anyone had asked.
  ///
  /// Composed in [AppIcon.build] from four things:
  ///   * `EffectiveTheme.iconCacheId` — themeId and the IconStyle fingerprint
  ///   * `prefs.systemIconPack`       — the third-party pack, if any
  ///   * the pack generation counter  — a downloaded pack landing
  ///   * `AppEntry.updateToken`       — the app itself changing its icon
  ///
  /// ─── THIS FIELD IS THE FIX, AND ITS ABSENCE WAS A REAL BUG ───────────────
  ///
  /// The key used to be (componentKey, sizePx) only, which describes WHICH icon
  /// and HOW BIG, and says nothing about how it was drawn. Native's cache is
  /// keyed properly — `IconCache.cacheKey` folds in themeId and the whole
  /// IconStyle fingerprint — so the platform side was always correct. The
  /// problem was that Dart never asked it again: `setIconTheme` evicted native's
  /// memory tier, and this provider went on serving the Uint8List it resolved
  /// under the previous theme, from the same family key, to the same widgets.
  ///
  /// It has been getting away with it because Riverpod 3 auto-disposes by
  /// default, so a theme switch that rebuilt the whole shell often left every
  /// icon provider momentarily unwatched and therefore disposed. That is a
  /// coincidence of rebuild ordering, not a mechanism. Anything that kept one
  /// listener alive across the switch — a dock that does not rebuild, a
  /// preview pane, a drawer already on screen — served the old bitmap.
  ///
  /// Including it here makes the Dart key say the same thing the native key
  /// says, which is the only arrangement that cannot drift. The orphaned
  /// entries under the old id are unwatched immediately and auto-disposed.
  final String cacheId;

  @override
  bool operator ==(Object other) =>
      other is IconRequest &&
      other.componentKey == componentKey &&
      other.sizePx == sizePx &&
      other.cacheId == cacheId;

  @override
  int get hashCode => Object.hash(componentKey, sizePx, cacheId);
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

    // ── WHAT THESE BYTES WERE DRAWN WITH ──────────────────────────────────
    //
    // Read HERE rather than passed in as a constructor argument, deliberately.
    // AppIcon is built from the drawer, the home grid, the dock, folder tiles,
    // the settings previews and the setup wizard; threading a cache id through
    // all of them means every one of those is a place to forget it, and
    // forgetting it looks like nothing at all until someone switches theme with
    // that surface on screen.
    //
    // `.select` keeps this cheap. `effectiveThemeProvider` re-emits on EVERY
    // prefs write — hiding an app, nudging a column, toggling verbose boot — and
    // without the selector every icon on the phone would rebuild each time. With
    // it, only a change that actually alters how icons are DRAWN gets through.
    final styleId = ref.watch(
      effectiveThemeProvider.select((t) => t.asData?.value.iconCacheId ?? ''),
    );

    // A pack landing does not change the style id: a hero or brand pack keeps
    // its own id, and that is what an UPDATE means. But native clears its disk
    // tier on any pack install, so those bitmaps genuinely have to be re-made.
    // The counter is what tells Dart to ask again; without it the launcher shows
    // the old artwork until the process dies, which is indistinguishable from
    // the download having failed.
    final packGeneration = ref.watch(iconPackGenerationProvider);

    // ── THE THIRD-PARTY PACK, AND WHY IT IS NOT IN iconCacheId ────────────
    //
    // `iconCacheId` documents itself as covering EVERY field of `IconStyle`,
    // and `systemIconPack` is deliberately not one — it names an installed APK
    // rather than theme content. Folding it in there would quietly break that
    // contract and make the next person wonder which fields the rule covers.
    //
    // It has to be in the DART key regardless, because native already has it in
    // its own. Without this line, choosing an icon pack changed the native cache
    // key, native stood ready to render every icon afresh, and Dart went on
    // serving the bitmaps it already held. The picker would have looked
    // completely inert on any surface that was already on screen.
    final systemPack = ref.watch(
      effectiveThemeProvider
          .select((t) => t.asData?.value.prefs.systemIconPack ?? '-'),
    );

    final icon = ref.watch(
      iconProvider(
        IconRequest(
          entry.componentKey,
          sizePx,
          // updateToken is the app changing its OWN icon, which native keys on
          // and Dart did not. Update WhatsApp, get WhatsApp's old icon until
          // something else happened to move the key.
          '$styleId|$systemPack|$packGeneration|${entry.updateToken}',
        ),
      ),
    );

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
    _ => 'assets/brand/mindhunter_mark.webp',
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
      'assets/brand/mindhunter_mark.webp',
      width: size,
      height: size,
      color: onDark,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.medium,
    );
    return SizedBox(width: size, height: size, child: fallback);
  }
}
