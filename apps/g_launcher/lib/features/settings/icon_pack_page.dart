import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/app_repository.dart';
import '../../engine/effective_theme.dart';
import '../../engine/theme_engine.dart';

/// PICK A THIRD-PARTY ICON PACK.
///
/// "Can I use my icon pack" is the second question anyone asks a launcher,
/// right after "can I change the grid". Every Nova/ADW-format pack on Play
/// works here, including anything exported from Icon Pack Studio, because the
/// pack is already installed, already drawn, and already licensed to the user.
/// The launcher reads its resources and hands a Drawable to the same renderer
/// that draws hero art.
///
/// ─── ITS OWN PAGE, NOT A ROW IN A SHEET ─────────────────────────────────────
///
/// A phone can plausibly have a dozen icon packs, and each one wants a name,
/// its own icon, and room for the empty state to explain itself. A bottom sheet
/// with a dozen radio rows is a scroll inside a scroll.
///
/// ─── EVERY COLOUR AND FACE COMES FROM EffectiveTheme ────────────────────────
///
/// Not from ThemeData, not from a constant, not from `Theme.of(context)`. This
/// file sits inside `scripts/no_constants.sh`'s settings scope and would fail
/// the gate otherwise, but the gate is downstream of the actual reason: a
/// settings page that renders in Ubuntu's orange while the desktop behind it is
/// Kali's teal reads as a different app.
class IconPackPage extends ConsumerWidget {
  const IconPackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(effectiveThemeProvider);

    return themeAsync.when(
      // The theme is already resolved by the time anything can navigate here,
      // so these two arms are formalities rather than real states. They render
      // nothing rather than a spinner or an error card, because a flash of
      // unthemed chrome on the way into a settings page is worse than a frame
      // of nothing.
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (theme) => _Page(theme: theme),
    );
  }
}

/// Installed packs, package name to label.
///
/// A FutureProvider rather than state on the widget: it survives a rebuild, and
/// `ref.invalidate` is the whole of "refresh" when the user installs a pack and
/// comes back. Native answers on a background thread; see `installedIconPacks`.
///
/// AN EMPTY MAP IS A REAL ANSWER and is drawn as the empty state, never as an
/// error. Note while debugging that empty is ALSO what a missing `<queries>`
/// declaration produces on Android 11+, silently, on a phone with forty packs
/// installed. Check the manifest before this code.
final installedIconPacksProvider = FutureProvider<Map<String, String>>((ref) {
  return ref.read(launcherHostApiProvider).installedIconPacks();
});

class _Page extends ConsumerWidget {
  const _Page({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = theme.palette;
    final packs = ref.watch(installedIconPacksProvider);
    final selected = theme.prefs.systemIconPack;

    return Scaffold(
      backgroundColor: palette.bgBottom,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(theme: theme),
            Expanded(
              child: packs.when(
                loading: () => const SizedBox.shrink(),
                // A failed query is indistinguishable from none installed as far
                // as what the user can do about it, so it draws the same thing.
                // Inventing an error state here would give them a retry button
                // for a package-manager call that does not fail transiently.
                error: (_, __) => _Empty(theme: theme),
                data: (map) => map.isEmpty
                    ? _Empty(theme: theme)
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          _PackRow(
                            theme: theme,
                            label: 'None',
                            sub: "Use the distro's own icons",
                            selected: selected == null,
                            onTap: () => _select(ref, null),
                          ),
                          for (final entry in map.entries)
                            _PackRow(
                              theme: theme,
                              label: entry.value,
                              sub: entry.key,
                              selected: selected == entry.key,
                              onTap: () => _select(ref, entry.key),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Write the pref and nothing else.
  ///
  /// `setIconPack` is deliberately NOT called from here. `effectiveThemeProvider`
  /// watches prefs and pushes it, which means there is exactly one place that
  /// tells native what the pack is. Calling it here too would be a second
  /// writer racing the first, and the loser would win about half the time.
  ///
  /// The grid repaints without being told to: `systemIconPack` lives in
  /// `LauncherPrefs`, `LauncherPrefs` is compared by value inside
  /// `EffectiveTheme.==`, and the app-list families are keyed on that object.
  /// Changing it re-keys them and every icon re-requests.
  Future<void> _select(WidgetRef ref, String? packageName) async {
    final spec = await ref.read(activeThemeSpecProvider.future);
    await ref.read(prefsProvider(spec.id).notifier).edit(
          // `.edit`, never `.update`. `.update` is a name collision on
          // AsyncNotifier that mutates in memory without writing to disk, so
          // the choice would revert on the next cold start.
          (p) => packageName == null
              // clearing(), not copyWith(systemIconPack: null): copyWith reads a
              // null argument as "leave it alone", so "None" would silently do
              // nothing and only for the one value that needs it to work.
              ? p.clearing(systemIconPack: true)
              : p.copyWith(systemIconPack: packageName),
        );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          _Tap(
            onTap: () => Navigator.of(context).maybePop(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.arrow_back,
                size: 20,
                color: palette.onDark,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Icon pack',
            style: TextStyle(
              fontFamily: theme.typography.display,
              fontSize: 20,
              color: palette.onDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({
    required this.theme,
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final EffectiveTheme theme;
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;

    return _Tap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: theme.typography.display,
                      fontSize: 15,
                      color: palette.onDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      // The package name, in the theme's mono face, because
                      // that is what it is.
                      fontFamily: theme.typography.mono,
                      fontSize: 11,
                      // Alpha off the palette rather than a second colour: a
                      // dimmed variant that is not derived from onDark stops
                      // matching the moment a distro changes its foreground.
                      color: palette.onDark.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check, size: 18, color: palette.accent),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context) {
    final palette = theme.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'No icon packs installed',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: theme.typography.display,
              fontSize: 16,
              color: palette.onDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Install any icon pack from Play, or make your own with Icon Pack '
            'Studio, and it will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: theme.typography.display,
              fontSize: 13,
              height: 1.4,
              color: palette.onDark.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable region with a ripple.
///
/// Wrapped in its own [Material] rather than relying on the [Scaffold]'s.
/// This page has one today, but the same rows will be wanted from a shell
/// overlay or a `showGeneralDialog` route, neither of which has a Material
/// ancestor, and the failure there is a thrown "No Material widget found"
/// rather than a missing ripple.
class _Tap extends StatelessWidget {
  const _Tap({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}
