import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/prefs/prefs_repository.dart';
import '../../data/repositories/app_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../engine/effective_theme.dart';
import '../../engine/theme_source.dart';
import '../../system/wallpaper_source.dart';

/// Rotation intervals we are willing to offer.
///
/// The 15-minute floor is WorkManager's, and it is enforced by the OS. Offering
/// "every 5 minutes" and silently delivering 15 is lying to the user about a
/// setting they can watch not happening.
const rotationOptions = <String, int?>{
  'Off': null,
  'Every 15 minutes': 15,
  'Hourly': 60,
  'Every 6 hours': 360,
  'Daily': 1440,
};

/// Wallpaper picker — Phase B, B2.
///
/// Every surface here reads the chrome, not a constant: the app bar, section
/// heads, rows and the rotation picker come from the primitives (see
/// design/components), so the screen is dressed in the active distro's palette
/// and family. The rotation control was a Material [DropdownButton] (which reads
/// the ambient theme); it is now a themed [ThemedSheet], matching how Settings
/// does every other picker.
class WallpaperScreen extends ConsumerWidget {
  const WallpaperScreen({super.key, required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Live, not the push-time snapshot — so a photo you add shows up in "Yours"
    // and the rotation count updates the instant you pick it, instead of only
    // after you back out and reopen this screen.
    // hasValue, not asData. See home_screen.dart: asData is null through a
    // reload, and every prefs write is a reload.
    final async = ref.watch(effectiveThemeProvider);
    final theme = async.hasValue ? async.requireValue : this.theme;
    final api = ref.read(launcherHostApiProvider);
    final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

    // Theme presets first, then whatever the user added. One pool; rotation
    // draws from all of it.
    final presets = theme.spec.wallpapers;
    final mine = theme.prefs.wallpapers;
    final all = [...presets, ...mine];

    final applyToLock = theme.prefs.wallpaperLock ?? false;

    /// A stored source, as native should receive it.
    ///
    /// THE ONE PLACE THIS SCREEN ENCODES A WALLPAPER. `apply` and the rotation
    /// schedule both go through it, and they used to disagree: `apply` called
    /// the encoder directly while rotation went via the deprecated `_encode`
    /// below. Both were wrong in the same way for an installed theme, and
    /// having two of them is why fixing one would have left the other.
    ///
    /// `spec.asset` is what turns a downloaded theme's bare `wall_x.webp` into
    /// the absolute path inside `packs/<id>/`. Without it the encoder emits
    /// `file://wall_x.webp`, which opens nothing, and the wallpaper silently
    /// does not change. `isThemeAssetRef` keeps the user's own photos out of
    /// that resolution — they are absolute paths and belong where they are.
    String encodeFor(String source) {
      final asset =
          isThemeAssetRef(source) ? theme.spec.asset(source) : null;
      return encodeWallpaperSource(asset?.path ?? source);
    }

    Future<void> apply(String source) async {
      // Stash the user's own wallpaper before the first time we replace it.
      // Idempotent on the native side — it refuses to overwrite an existing
      // stash, so calling it on every apply cannot lose the original.
      await api.stashWallpaper();

      final ok = await api.setWallpaper(
        encodeFor(source),
        applyToLock,
      );

      // Remember WHICH one, and that this theme now owns the screen.
      //
      // Without these two writes the choice is invisible to everything else:
      // effective_theme would stamp the theme's first preset back over it on
      // the next switch, and nothing would know a user choice had ever been
      // made. The second write is the same global key effective_theme reads.
      if (ok) {
        await notifier.edit((p) => p.copyWith(wallpaperCurrent: source));
        await ref
            .read(prefsStoreProvider)
            .write(wallpaperAppliedForKey, theme.spec.id);
      }
      if (!context.mounted) return;
      // Single-string message through the branded scaffold — the ecosystem
      // convention. Failure reads as failure from the words, not a tone enum.
      context.showMessage(ok ? 'Wallpaper set' : 'Could not set that image');
    }

    final canRotate = all.length >= 2;
    final currentMinutes = theme.prefs.wallpaperRotationMinutes;

    // Open the rotation picker as a themed sheet. Captures + re-provides the
    // chrome across the modal route boundary (ThemedSheet handles that), so the
    // options are dressed like the rest of the screen.
    void openRotation() {
      ThemedSheet.show<void>(
        context,
        title: 'Change wallpaper',
        builder: (ctx) {
          final c = ChromeScope.of(ctx).colors;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in rotationOptions.entries)
                ThemedListRow(
                  title: e.key,
                  trailing: e.value == currentMinutes
                      ? Icon(Icons.check, size: 20, color: c.accent)
                      : null,
                  onTap: () {
                    notifier.edit(
                      (p) => e.value == null
                          ? p.copyWith(wallpaperRotationMinutes: null)
                          : p.copyWith(wallpaperRotationMinutes: e.value),
                    );

                    if (e.value == null) {
                      api.cancelWallpaperRotation();
                    } else {
                      api.scheduleWallpaperRotation(
                        e.value!,
                        all.map(encodeFor).toList(),
                        applyToLock,
                      );
                    }
                    Navigator.pop(ctx);
                  },
                ),
              const SizedBox(height: 8),
            ],
          );
        },
      );
    }

    return ThemedScaffold(
      title: 'Wallpaper',
      body: ListView(
        children: [
          if (presets.isNotEmpty) ...[
            const ThemedSectionHeader('From this distro'),
            _Strip(sources: presets, source: theme.spec.source, onTap: apply),
          ],

          const ThemedSectionHeader('Yours'),
          _Strip(sources: mine, source: theme.spec.source, onTap: apply),

          ThemedListRow(
            icon: Icons.add_photo_alternate_outlined,
            title: 'Add a photo',
            onTap: () async {
              final picked = await ImagePicker().pickImage(
                source: ImageSource.gallery,
              );
              if (picked == null) return;

              // Store the URI, not a copy. Copying every wallpaper into app
              // storage doubles disk use for no benefit — and the photo is
              // already on the device.
              await notifier.edit(
                (p) => p.copyWith(wallpapers: [...p.wallpapers, picked.path]),
              );
            },
          ),

          const ThemedSectionHeader('Lock screen'),

          ThemedListRow(
            icon: Icons.lock_outline,
            title: 'Also set the lock screen',
            subtitle: 'Applies from the next wallpaper you pick',
            trailing: ThemedToggle(
              value: applyToLock,
              onChanged: (v) {
                notifier.edit((p) => p.copyWith(wallpaperLock: v));
                // Deliberately NOT retroactive: silently rewriting the lock
                // screen the instant a toggle flips is the surprise this
                // setting exists to avoid.
                context.showMessage(
                  v
                      ? 'Your next wallpaper will set the lock screen too'
                      : 'Wallpapers will set the home screen only',
                );
              },
            ),
          ),

          _RestoreRow(theme: theme),

          const ThemedSectionHeader('Rotation'),

          ThemedListRow(
            icon: Icons.schedule_outlined,
            title: 'Change wallpaper',
            subtitle: canRotate
                ? '${all.length} in rotation'
                : 'Add at least two wallpapers to rotate',
            enabled: canRotate,
            trailing: canRotate ? _RotationValue(currentMinutes) : null,
            onTap: canRotate ? openRotation : null,
          ),
        ],
      ),
    );
  }
}

/// "Put my wallpaper back", shown ONLY when a stash actually exists.
///
/// Native stashes the user's own wallpaper the first time a theme replaces it,
/// but that read is restricted on newer Android and impossible for a live
/// wallpaper — so it can genuinely fail. Asking native whether a stash exists,
/// rather than assuming one does, is the difference between a button that works
/// and a button that apologises. When there is nothing to restore, this renders
/// nothing at all.
class _RestoreRow extends ConsumerWidget {
  const _RestoreRow({required this.theme});

  final EffectiveTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(launcherHostApiProvider);

    return FutureBuilder<bool>(
      future: api.hasStashedWallpaper(),
      builder: (context, snap) {
        // Absent, not a placeholder row: the same rule the conky and the tray
        // follow for nullable stats.
        if (snap.data != true) return const SizedBox.shrink();

        return ThemedListRow(
          icon: Icons.settings_backup_restore,
          title: 'Restore my wallpaper',
          subtitle: 'The one you had before you applied a distro',
          onTap: () async {
            final ok = await api.restoreWallpaper();
            if (!context.mounted) return;
            context.showMessage(
              ok ? 'Wallpaper restored' : 'Could not restore that wallpaper',
            );
          },
        );
      },
    );
  }
}

/// The current rotation interval + chevron, in the chrome's muted ink. Reads the
/// label back out of [rotationOptions] so the two never drift.
class _RotationValue extends StatelessWidget {
  const _RotationValue(this.minutes);

  final int? minutes;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    final label = rotationOptions.entries
        .firstWhere(
          (e) => e.value == minutes,
          orElse: () => rotationOptions.entries.first, // 'Off'
        )
        .key;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: c.textMuted, fontSize: 12.5)),
        const SizedBox(width: 6),
        Icon(Icons.chevron_right, size: 18, color: c.textMuted),
      ],
    );
  }
}

/// A horizontal strip of wallpaper thumbnails. Empty renders a themed
/// placeholder line rather than a gap.
class _Strip extends StatelessWidget {
  const _Strip({
    required this.sources,
    required this.source,
    required this.onTap,
  });

  final List<String> sources;

  /// Where the ACTIVE theme's files live.
  ///
  /// Needed because the same `theme.json` string means two different things.
  /// This strip used to guess with `startsWith('assets/')` and fall through to
  /// `Image.file(File(src))`, so an installed pack's `wall_x.webp` became a
  /// RELATIVE File, failed to open, and drew the broken-image placeholder for
  /// every wallpaper a downloaded distro ships. `ThemeSource` is the one thing
  /// that knows whether to build an AssetImage or a FileImage, and it already
  /// existed for exactly this.
  final ThemeSource source;

  final Future<void> Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;

    if (sources.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('Nothing yet', style: TextStyle(color: c.textFaint)),
      );
    }

    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: sources.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final src = sources[i];
          // Remote first: it is the only case with its own loading state, and
          // `isThemeAssetRef` would otherwise have to exclude it twice.
          final isRemote = src.startsWith('http');
          // A theme reference — bundled OR installed. `source.asset` decides
          // which, and returns an AssetImage or a FileImage accordingly.
          final themed = !isRemote && isThemeAssetRef(src) ? source.asset(src) : null;

          return GestureDetector(
            onTap: () => onTap(src),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 90,
                child: switch ((themed != null, isRemote)) {
                  (true, _) => Image(
                      image: themed!.image,
                      fit: BoxFit.cover,
                      // A theme whose wallpaper files are missing must still show
                      // a usable list, not a red error box. Reachable for an
                      // installed pack whose files were swept as well as for a
                      // bundled path that no longer exists.
                      errorBuilder: (_, __, ___) => const _Missing(
                        Icons.image_not_supported_outlined,
                      ),
                    ),
                  (_, true) => Image.network(
                      src,
                      fit: BoxFit.cover,
                      // Themed spinner while the CDN thumbnail downloads.
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : const Center(
                              child: ThemedProgress.circular(size: 20),
                            ),
                      // Offline, or the CDN is down. Show a placeholder; the
                      // wallpaper still works once the network comes back.
                      errorBuilder: (_, __, ___) =>
                          const _Missing(Icons.cloud_off_outlined),
                    ),
                  // The user's own photo: an absolute path or a content URI.
                  _ => Image.file(
                      File(src),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const _Missing(Icons.broken_image_outlined),
                    ),
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;
    return ColoredBox(
      color: c.surfaceAlt,
      child: Icon(icon, color: c.textMuted),
    );
  }
}
