import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/prefs/prefs_repository.dart';
import '../../data/prefs/wallpaper_collections.dart';
import '../../data/repositories/app_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../engine/effective_theme.dart';
import '../../engine/theme_source.dart';
import '../../system/wallpaper_source.dart';
import 'wallpaper_collection_screen.dart';

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

/// A stored source, as native should receive it: THE one encoder, shared by
/// apply and rotation on this screen AND by the collection screen. The two
/// encode paths on this screen already drifted apart once (see the history in
/// [WallpaperScreen]); a third caller is exactly when a single implementation
/// starts paying rent.
///
/// `spec.asset` turns a downloaded theme's bare `wall_x.webp` into the
/// absolute path inside `packs/<id>/`; `isThemeAssetRef` keeps the user's own
/// photos and collection copies out of that resolution, since they are
/// absolute paths already where they belong.
String encodeWallpaperFor(EffectiveTheme theme, String source) {
  final asset = isThemeAssetRef(source) ? theme.spec.asset(source) : null;
  return encodeWallpaperSource(asset?.path ?? source);
}

/// Set [source] now, remember which, and stamp the applied token.
///
/// Extracted from [WallpaperScreen] so the collection screen applies through
/// the same three writes. Skipping either record re-creates a fixed bug: no
/// `wallpaperCurrent` and the theme resolve stamps its preset back over the
/// choice; a stale token and it does the same the next time the palette mode
/// flips. See wallpaper_source.dart for both histories.
Future<bool> applyWallpaper(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  String source, {
  // For the moment a fit is CHOSEN: the edit that stores it has not reloaded
  // [theme] yet, so the sheet passes the new value explicitly rather than
  // re-applying with the stale pref.
  String? fit,
}) async {
  final api = ref.read(launcherHostApiProvider);
  final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

  // Idempotent natively: it refuses to overwrite an existing stash.
  await api.stashWallpaper();

  final ok = await api.setWallpaper(
    encodeWallpaperFor(theme, source),
    theme.prefs.wallpaperLock ?? false,
    fit ?? theme.prefs.wallpaperFit ?? 'cover',
    // The theme's own background fills the bars contain and center leave, so
    // a letterboxed photo still reads as this distro's desktop.
    theme.palette.bgTop.toARGB32(),
  );

  if (ok) {
    await notifier.edit((p) => p.copyWith(wallpaperCurrent: source));
    await ref.read(prefsStoreProvider).write(
          wallpaperAppliedForKey,
          wallpaperAppliedToken(theme.spec.id, dark: theme.dark),
        );
  }
  if (context.mounted) {
    context.showMessage(ok ? 'Wallpaper set' : 'Could not set that image');
  }
  return ok;
}

/// The pool [source] names, for this theme.
///
/// Unknown values and dangling collection ids fall to the DISTRO pool, not to
/// an empty list: a rotation that silently stops because a collection was
/// deleted is the worse failure, and the distro pool is the state the setting
/// began in.
List<String> rotationPoolFor(
  EffectiveTheme theme,
  List<WallpaperCollection> collections,
  String? source,
) {
  final own = [...theme.spec.wallpapers, ...theme.prefs.wallpapers];
  if (source == 'all') {
    return [...own, for (final c in collections) ...c.paths];
  }
  if (source != null && source.startsWith('collection:')) {
    final id = source.substring('collection:'.length);
    for (final c in collections) {
      if (c.id == id) return c.paths;
    }
  }
  return own;
}

/// What the source row calls [source]. Falls to 'This distro' exactly when
/// [rotationPoolFor] falls to the distro pool, so the label and the behaviour
/// cannot disagree.
String rotationSourceLabel(
  String? source,
  List<WallpaperCollection> collections,
) {
  if (source == 'all') return 'Everything';
  if (source != null && source.startsWith('collection:')) {
    final id = source.substring('collection:'.length);
    for (final c in collections) {
      if (c.id == id) return c.name;
    }
  }
  return 'This distro';
}

/// Re-point an ACTIVE rotation at the pool [source] now names. A no-op when
/// rotation is off, which is exactly why Off must CLEAR the interval (see the
/// note in the rotation sheet): a stale interval here would turn a collection
/// edit into the rotation quietly switching itself back on.
Future<void> rescheduleRotation(
  WidgetRef ref,
  EffectiveTheme theme,
  List<WallpaperCollection> collections, {
  required String? source,
  String? fit,
}) async {
  final minutes = theme.prefs.wallpaperRotationMinutes;
  if (minutes == null) return;
  final pool = rotationPoolFor(theme, collections, source);
  // No length branch: Kotlin's schedule() cancels itself on an empty list,
  // and a one-item pool re-applying the same image is harmless.
  await ref.read(launcherHostApiProvider).scheduleWallpaperRotation(
        minutes,
        pool.map((p) => encodeWallpaperFor(theme, p)).toList(),
        theme.prefs.wallpaperLock ?? false,
        fit ?? theme.prefs.wallpaperFit ?? 'cover',
        theme.palette.bgTop.toARGB32(),
      );
}

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

    // Theme presets first, then whatever the user added: the distro pool.
    // Rotation may draw wider than it (every collection) or narrower (one
    // collection); [rotationPoolFor] is the one place that choice resolves.
    final presets = theme.spec.wallpapers;
    final mine = theme.prefs.wallpapers;

    final colsAsync = ref.watch(wallpaperCollectionsProvider);
    final collections = colsAsync.hasValue
        ? colsAsync.requireValue
        : const <WallpaperCollection>[];

    final applyToLock = theme.prefs.wallpaperLock ?? false;

    // The one encoder, now top-level as [encodeWallpaperFor] so the
    // collection screen shares it; its history moved there with it.
    String encodeFor(String source) => encodeWallpaperFor(theme, source);

    // Extracted to [applyWallpaper] so the collection screen sets, records
    // and stamps through the same writes; the history lives on the function.
    Future<void> apply(String source) =>
        applyWallpaper(context, ref, theme, source);

    final rotationSource = theme.prefs.wallpaperRotationSource;
    final pool = rotationPoolFor(theme, collections, rotationSource);
    final canRotate = pool.length >= 2;
    final currentMinutes = theme.prefs.wallpaperRotationMinutes;

    // Open the rotation picker as a themed sheet. Captures + re-provides the
    // chrome across the modal route boundary (ThemedSheet handles that), so the
    // options are dressed like the rest of the screen.
    void openRotation() {
      ThemedSheet.show<void>(
        context,
        title: context.t('settings.changeWallpaper'),
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
                      // clearing, not copyWith(null): copyWith cannot write
                      // null, so Off left the interval set while the worker
                      // was cancelled. Nothing re-read it then;
                      // rescheduleRotation does now, and a stale interval
                      // would resurrect a rotation the user turned off.
                      (p) => e.value == null
                          ? p.clearing(wallpaperRotationMinutes: true)
                          : p.copyWith(wallpaperRotationMinutes: e.value),
                    );

                    if (e.value == null) {
                      api.cancelWallpaperRotation();
                    } else {
                      api.scheduleWallpaperRotation(
                        e.value!,
                        pool.map(encodeFor).toList(),
                        applyToLock,
                        theme.prefs.wallpaperFit ?? 'cover',
                        theme.palette.bgTop.toARGB32(),
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

    // Which pool rotation draws from, as a themed sheet like the interval
    // picker beside it. Writing the choice re-points an ACTIVE schedule
    // immediately; without that, changing the source would do nothing until
    // the interval was picked again, which reads as the row being decorative.
    void openSourcePicker() {
      ThemedSheet.show<void>(
        context,
        title: 'Rotate from',
        builder: (ctx) {
          final c = ChromeScope.of(ctx).colors;
          Widget option(String label, String? value) => ThemedListRow(
                title: label,
                trailing: value == rotationSource
                    ? Icon(Icons.check, size: 20, color: c.accent)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  await notifier.edit(
                    (p) => value == null
                        ? p.clearing(wallpaperRotationSource: true)
                        : p.copyWith(wallpaperRotationSource: value),
                  );
                  await rescheduleRotation(
                    ref,
                    theme,
                    collections,
                    source: value,
                  );
                },
              );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              option('This distro', null),
              option('Everything', 'all'),
              for (final col in collections)
                option(col.name, 'collection:${col.id}'),
              const SizedBox(height: 8),
            ],
          );
        },
      );
    }

    return ThemedScaffold(
      title: context.t('settings.wallpaper'),
      body: ListView(
        children: [
          if (presets.isNotEmpty) ...[
            ThemedSectionHeader(context.t('wallpaper.fromThisDistro')),
            _Strip(sources: presets, source: theme.spec.source, onTap: apply),
          ],
          ThemedSectionHeader(context.t('wallpaper.yours')),
          _Strip(
            sources: mine,
            source: theme.spec.source,
            onTap: apply,
            // ─── ONLY YOUR OWN CAN BE REMOVED ──────────────────────────
            //
            // A photo could be added and never taken back, so a mistaken pick
            // sat in the rotation forever. The distro's presets have no remove:
            // they are not yours to delete and they come back with the theme.
            onRemove: (src) => _forget(context, ref, theme, src, apply),
          ),
          ThemedListRow(
            icon: Icons.add_photo_alternate_outlined,
            title: context.t('settings.addAPhoto'),
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
          const ThemedSectionHeader('Collections'),
          for (final col in collections)
            ThemedListRow(
              icon: Icons.photo_library_outlined,
              title: col.name,
              subtitle: col.paths.length == 1
                  ? '1 wallpaper'
                  : '${col.paths.length} wallpapers',
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WallpaperCollectionScreen(
                    theme: theme,
                    collectionId: col.id,
                  ),
                ),
              ),
            ),
          ThemedListRow(
            icon: Icons.create_new_folder_outlined,
            title: 'New collection',
            subtitle: collections.isEmpty
                ? 'Group photos and rotate through one set'
                : null,
            onTap: () => promptCollectionName(
              context,
              title: 'Name this collection',
              onSubmit: (name) async {
                final created = await ref
                    .read(wallpaperCollectionsProvider.notifier)
                    .create(name);
                if (created == null || !context.mounted) return;
                // Straight into the new collection, so adding photos is the
                // next tap rather than a hunt back through the list.
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WallpaperCollectionScreen(
                      theme: theme,
                      collectionId: created.id,
                    ),
                  ),
                );
              },
            ),
          ),
          ThemedSectionHeader(context.t('settings.lockScreen')),
          ThemedListRow(
            icon: Icons.lock_outline,
            title: context.t('settings.alsoSetTheLock'),
            subtitle: context.t('settings.appliesFromTheNext'),
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
          ThemedListRow(
            icon: Icons.fit_screen_outlined,
            title: 'Fit',
            subtitle: switch (theme.prefs.wallpaperFit) {
              'contain' => 'Whole image, bars if needed',
              'fill' => 'Stretched to the screen',
              'center' => 'Actual size, centred',
              _ => 'Fills the screen, edges crop',
            },
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              ThemedSheet.show<void>(
                context,
                title: 'Fit',
                builder: (ctx) {
                  final c = ChromeScope.of(ctx).colors;
                  final current = theme.prefs.wallpaperFit ?? 'cover';
                  Widget option(String label, String sub, String value) =>
                      ThemedListRow(
                        title: label,
                        subtitle: sub,
                        trailing: value == current
                            ? Icon(Icons.check, size: 20, color: c.accent)
                            : null,
                        onTap: () async {
                          Navigator.pop(ctx);
                          // Explicit always, including cover: choosing the
                          // value already on screen is still a choice, the
                          // same touched-marker rule the drawer rows follow.
                          await notifier.edit(
                            (p) => p.copyWith(wallpaperFit: value),
                          );
                          // The change must be visible NOW, not on the next
                          // pick: re-apply whatever is up, and re-point an
                          // active rotation so the next tick agrees. Both take
                          // the new fit explicitly; [theme] has not reloaded.
                          final applied = theme.prefs.wallpaperCurrent;
                          if (applied != null && context.mounted) {
                            await applyWallpaper(
                              context,
                              ref,
                              theme,
                              applied,
                              fit: value,
                            );
                          }
                          await rescheduleRotation(
                            ref,
                            theme,
                            collections,
                            source: rotationSource,
                            fit: value,
                          );
                        },
                      );
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      option('Cover', 'Fills the screen, edges crop', 'cover'),
                      option('Fit', 'Whole image, bars if needed', 'contain'),
                      option('Stretch', 'Exactly the screen shape', 'fill'),
                      option('Center', 'Actual size, no scaling', 'center'),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              );
            },
          ),
          _RestoreRow(theme: theme),
          ThemedSectionHeader(context.t('settings.rotation')),
          ThemedListRow(
            icon: Icons.schedule_outlined,
            title: context.t('settings.changeWallpaper'),
            subtitle: canRotate
                ? '${pool.length} in rotation'
                : 'Add at least two wallpapers to rotate',
            enabled: canRotate,
            trailing: canRotate ? _RotationValue(currentMinutes) : null,
            onTap: canRotate ? openRotation : null,
          ),
          if (collections.isNotEmpty)
            ThemedListRow(
              icon: Icons.collections_outlined,
              title: 'Rotate from',
              subtitle: rotationSourceLabel(rotationSource, collections),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: openSourcePicker,
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
          title: context.t('settings.restoreMyWallpaper'),
          subtitle: context.t('wallpaper.original'),
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
/// Forget one of the user's own wallpapers.
///
/// ─── REMOVING THE ONE THAT IS ON SCREEN ─────────────────────────────────────
///
/// The list is only a menu; the wallpaper itself belongs to Android and is
/// already set. So forgetting the picture that is currently applied does NOT
/// change what you are looking at, and pretending otherwise by reverting to a
/// preset would be a second surprise on top of a delete.
///
/// What it must do is clear `wallpaperCurrent`, because that field is what
/// `effective_theme` treats as "the user chose this". Leaving it pointing at a
/// path no longer in the list would make the theme resolve believe a choice
/// exists that the user cannot see or change.
Future<void> _forget(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  String src,
  Future<void> Function(String) apply,
) async {
  final ok = await ThemedDialog.confirm(
    context,
    title: context.t('wallpaper.removeTitle'),
    message: context.t('wallpaper.removeBody'),
    confirmLabel: context.t('desklets.remove'),
    danger: true,
  );
  if (ok != true) return;

  final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
  final wasCurrent = theme.prefs.wallpaperCurrent == src;

  await notifier.edit(
    (p) => p.copyWith(wallpapers: p.wallpapers.where((w) => w != src).toList()),
  );

  if (wasCurrent) {
    // clearing(), not copyWith: copyWith cannot write null, and leaving a
    // dangling path here is the exact state described above.
    await notifier.edit((p) => p.clearing(wallpaperCurrent: true));
  }

  if (context.mounted) context.showMessage(context.t('wallpaper.removed'));
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.sources,
    required this.source,
    required this.onTap,
    this.onRemove,
  });

  /// Null for the distro's own presets, which are not the user's to delete.
  final void Function(String source)? onRemove;

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
          final remove = onRemove;
          // Remote first: it is the only case with its own loading state, and
          // `isThemeAssetRef` would otherwise have to exclude it twice.
          final isRemote = src.startsWith('http');
          // A theme reference — bundled OR installed. `source.asset` decides
          // which, and returns an AssetImage or a FileImage accordingly.
          final themed =
              !isRemote && isThemeAssetRef(src) ? source.asset(src) : null;

          return GestureDetector(
            onTap: () => onTap(src),
            // Hold to remove, which is the gesture this app already uses for
            // "what else can I do with this" on drawer tiles, folder members
            // and desklets. A permanent X badge on every thumbnail would put a
            // destructive target under the thumb of someone browsing.
            onLongPress: remove == null ? null : () => remove(src),
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
