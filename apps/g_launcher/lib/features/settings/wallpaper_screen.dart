import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g_launcher/i18n/i18n.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/prefs/prefs_repository.dart';
import '../../data/prefs/prefs_reset.dart';
import '../../data/prefs/wallpaper_collections.dart';
import '../../data/repositories/app_repository.dart';
import '../../design/branded_message.dart';
import '../../design/components/components.dart';
import '../../design/device_preview.dart';
import '../../design/setting_previews.dart';
import '../../engine/effective_theme.dart';
import '../../engine/theme_source.dart';
import '../../engine/wallpaper_framing.dart';
import '../../system/wallpaper_source.dart';
import 'wallpaper_collection_screen.dart';
import 'wallpaper_framing_screen.dart';

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
/// Ask where a wallpaper should land, once.
///
/// ─── WHY THIS IS A PROMPT AND NOT A STEP ON EVERY APPLY ─────────────────────
///
/// The finding was that `wallpaperLock` sat as a toggle below Collections, so
/// nobody found it and the lock screen never got set. The obvious fix is the
/// one Android's own picker uses: a Choose where to apply screen between
/// picking and finishing, every single time.
///
/// It is the wrong fix HERE, because tapping a thumbnail in this app applies
/// immediately and that is the whole appeal of the strip: browse a distro's
/// wallpapers by tapping through them. Putting a wizard in front of that turns
/// six taps into eighteen to answer a question whose answer does not change.
///
/// So it is asked ONCE and remembered. `wallpaperLock` is already nullable and
/// null already means nobody has chosen, so the state to hang this on exists
/// and needs no migration: everyone who has already set the toggle is past this
/// and everyone who has not gets asked the first time it matters.
///
/// Returns the choice, or null if they backed out, which must cancel the apply
/// rather than default: dismissing a question is not answering it.
Future<bool?> chooseApplyTarget(
  BuildContext context,
  EffectiveTheme theme,
  String source,
) {
  var lock = true;
  var home = true;

  return ThemedSheet.show<bool>(
    context,
    title: 'Choose where to apply',
    isScrollControlled: true,
    builder: (ctx) {
      final d = ChromeScope.of(ctx);
      final c = d.colors;
      final image = wallpaperImageFor(theme, source);
      final framing = resolveWallpaperFraming(
        user: theme.prefs.wallpaperFraming,
        authored: theme.spec.wallpaperMeta,
        source: source,
        legacyFit: theme.prefs.wallpaperFit,
      );

      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          Widget pane({
            required String label,
            required bool on,
            required VoidCallback toggle,
            required Widget preview,
          }) =>
              Expanded(
                child: GestureDetector(
                  onTap: toggle,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      // Dimmed rather than removed when off, so the pair keeps
                      // its shape and the choice reads as two switches rather
                      // than a picture appearing and disappearing.
                      Opacity(opacity: on ? 1 : 0.4, child: preview),
                      const SizedBox(height: 10),
                      Text(label, style: d.text.body.copyWith(color: c.text)),
                      const SizedBox(height: 8),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: on ? c.accent : c.surfaceAlt,
                          shape: BoxShape.circle,
                          border: Border.all(color: on ? c.accent : c.line),
                        ),
                        child: Icon(
                          Icons.check,
                          size: 16,
                          color: on ? c.onAccent : c.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              );

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      pane(
                        label: context.t('settings.lockScreen'),
                        on: lock,
                        toggle: () => setSheetState(() => lock = !lock),
                        preview: DevicePreview(
                          palette: theme.palette,
                          mode: DevicePreviewMode.lock,
                          background: image,
                          backgroundFraming: framing,
                        ),
                      ),
                      const SizedBox(width: 14),
                      pane(
                        label: 'Home screen',
                        on: home,
                        toggle: () => setSheetState(() => home = !home),
                        preview: DevicePreview(
                          palette: theme.palette,
                          mode: DevicePreviewMode.desktop,
                          dock: theme.dock,
                          gridButton: theme.prefs.dockGridButton ?? 'end',
                          background: image,
                          backgroundFraming: framing,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: ThemedButton(
                    label: 'Next',
                    expand: true,
                    // Neither selected is not a third answer, it is a request to
                    // change nothing, and a button that would do nothing should
                    // not be pressable.
                    onPressed:
                        (lock || home) ? () => Navigator.pop(ctx, lock) : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  child: Text(
                    'You can change this later under Applies to.',
                    textAlign: TextAlign.center,
                    style: d.text.caption.copyWith(color: c.textFaint),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<bool> applyWallpaper(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  String source, {
  // For the moment a fit is CHOSEN: the edit that stores it has not reloaded
  // [theme] yet, so the sheet passes the new value explicitly rather than
  // re-applying with the stale pref. Same reason [framing] exists beside it.
  String? fit,
  WallpaperFraming? framing,
}) async {
  // ─── EVERY PROVIDER READ HAPPENS HERE, BEFORE THE FIRST await ────────────
  //
  // `ref` belongs to a widget element, and reading it after that element is
  // gone throws `Bad state: Using "ref" after the widget was disposed`. This
  // function awaits four times: a sheet the user may sit on, two prefs writes,
  // and `setWallpaper`, which `LauncherHostApiImpl` puts on its IO executor
  // precisely because decoding and pushing a wallpaper takes hundreds of
  // milliseconds. Any of those is long enough for the screen to go.
  //
  // `api` and `notifier` were already captured here for that reason. The store
  // was NOT: it was read at the write near the bottom of this function, after
  // all four awaits, and it reached Crashlytics as a fatal FlutterError.
  //
  // Backing out of the wallpaper screen while an apply is in flight is an
  // ordinary thing to do, which is why it found two users in a day. Capturing
  // is the fix, not a `context.mounted` check: mounted can pass and then the
  // element can be gone by the time `ref.read` runs, and the object being
  // reached for here does not depend on the widget at all.
  final api = ref.read(launcherHostApiProvider);
  final notifier = ref.read(prefsProvider(theme.spec.id).notifier);
  final store = ref.read(prefsStoreProvider);

  // ─── ASKED ONCE, BEFORE ANYTHING IS TOUCHED ───────────────────────────────
  //
  // Before the stash, deliberately. Backing out of the question has to leave
  // the device exactly as it was, and stashing first would have already moved
  // the user's existing wallpaper to make room for one that never arrives.
  var applyToLock = theme.prefs.wallpaperLock;
  if (applyToLock == null) {
    final chosen = await chooseApplyTarget(context, theme, source);
    // Dismissing a question is not answering it. Defaulting here is how the
    // old toggle ended up never being set: something decided for them.
    if (chosen == null) return false;
    applyToLock = chosen;
    await notifier.edit((p) => p.copyWith(wallpaperLock: chosen));
  }
  if (!context.mounted) return false;

  // Idempotent natively: it refuses to overwrite an existing stash.
  await api.stashWallpaper();

  // Explicit argument first, then the resolved three-arm answer. Passing a
  // bare `fit` still works and now means "this fit, framing otherwise as
  // resolved", which is what the old fit sheet is actually asking for.
  final resolved = framing ??
      resolveWallpaperFraming(
        user: theme.prefs.wallpaperFraming,
        authored: theme.spec.wallpaperMeta,
        source: source,
        legacyFit: fit ?? theme.prefs.wallpaperFit,
      );

  final ok = await api.setWallpaper(
    encodeWallpaperFor(theme, source),
    // The local answer, not the pref. The write above has not round-tripped
    // through the provider yet, so reading `theme.prefs` here would send the
    // null it started with and the very first apply would miss the lock screen
    // the user had just asked for.
    applyToLock,
    fit ?? resolved.resolvedFit,
    // The theme's own background fills the bars contain and center leave, so
    // a letterboxed photo still reads as this distro's desktop.
    theme.palette.bgTop.toARGB32(),
    resolved.focalX,
    resolved.focalY,
    resolved.zoom,
  );

  if (ok) {
    await notifier.edit(
      (p) => p.copyWith(
        wallpaperCurrent: source,
        // Written only when this call carried framing, and only when that
        // framing says something. An apply that merely picked an image must
        // not stamp a row of defaults into the map for it.
        // PARENTHESISED. Without the brackets the cascade binds to the whole
        // conditional rather than to the map literal, so the receiver is the
        // nullable expression and it does not compile.
        wallpaperFraming: framing == null
            ? null
            : ({
                ...p.wallpaperFraming,
                if (!framing.isDefault) source: framing,
              }..removeWhere((_, v) => v.isDefault)),
      ),
    );
    await store.write(
      wallpaperAppliedForKey,
      // The stamp is composed HERE from the same two lists the resolve
      // reads, because the two must agree exactly. They are the pair the
      // token's doc warns about: they drifted once when the mode was added
      // and the screen's pick quietly undid itself on the next rebuild.
      wallpaperAppliedToken(
        theme.spec.id,
        dark: theme.dark,
        stamp: wallpaperContentStamp(
          theme.spec.wallpapers,
          theme.spec.wallpapersLight,
        ),
      ),
    );
  }
  if (context.mounted) {
    context.showMessage(ok ? 'Wallpaper set' : 'Could not set that image');
  }
  return ok;
}

/// Hide one of the distro's presets, or bring it back.
///
/// ─── HIDDEN, NOT DELETED, AND THE STRIP KEEPS SHOWING IT ────────────────────
///
/// A preset lives inside the pack and is not the user's to delete: an installed
/// pack is signature-verified as a whole, and a bundled one is in the APK. So
/// hiding greys the thumbnail and drops it out of the rotation pool, and the
/// dimmed tile stays exactly where it was as the way back. A wallpaper that
/// VANISHED on a long press would be indistinguishable from a delete, and the
/// user would have no idea the set could be restored.
///
/// ─── AND IT DOES NOT CHANGE WHAT IS ON SCREEN ───────────────────────────────
///
/// The same contract [_forget] spells out. The wallpaper belongs to Android and
/// is already set, so hiding the picture you are looking at does not swap it
/// out from under you. What it must do is clear `wallpaperCurrent`, because
/// that field is what the theme resolve treats as "the user chose this", and
/// leaving it pointed at something no longer in the list is a choice the user
/// can neither see nor change.
Future<void> setPresetHidden(
  BuildContext context,
  WidgetRef ref,
  EffectiveTheme theme,
  List<WallpaperCollection> collections,
  String src,
  bool hide,
) async {
  final notifier = ref.read(prefsProvider(theme.spec.id).notifier);

  // TWO sets, and they are not redundant. This one is for the rotation call at
  // the bottom, which needs the new value before the provider has reloaded; the
  // WRITE below builds its own off the live prefs inside `edit`, so two quick
  // taps cannot each write a set derived from the same stale snapshot.
  final next = {...theme.prefs.wallpapersHidden};
  if (hide) {
    next.add(src);
  } else {
    next.remove(src);
  }

  await notifier.edit((p) {
    final live = {...p.wallpapersHidden};
    if (hide) {
      live.add(src);
    } else {
      live.remove(src);
    }
    return p.copyWith(wallpapersHidden: live);
  });

  if (hide && theme.prefs.wallpaperCurrent == src) {
    // clearing(), not copyWith: copyWith cannot write null.
    await notifier.edit((p) => p.clearing(wallpaperCurrent: true));
  }

  // Explicit set, because [theme] here is the pre-edit snapshot. See the note
  // on [rotationPoolFor].
  await rescheduleRotation(
    ref,
    theme,
    collections,
    source: theme.prefs.wallpaperRotationSource,
    hidden: next,
  );

  if (context.mounted) {
    context.showMessage(hide ? 'Hidden from this distro' : 'Back in the set');
  }
}

/// The wallpaper on screen right now, as something drawable, or null.
///
/// ─── THE SAME THREE KINDS OF STRING, FOR THE THIRD TIME ─────────────────────
///
/// `wallpaperCurrent` holds a theme reference, an absolute path, or a URL, and
/// which one decides whether it resolves through the pack directory. That is
/// exactly the split [isThemeAssetRef] exists for and exactly what
/// [encodeWallpaperFor] does for native. This is the Flutter-side twin: same
/// question, different answer type.
///
/// Remote sources return null rather than a NetworkImage. The preview is a
/// still picture at the top of a settings page and pulling a CDN wallpaper to
/// draw it would spend someone's data on decoration; the strip below already
/// fetches it when they actually look.
ImageProvider? wallpaperImageFor(EffectiveTheme theme, String? source) {
  if (source == null || source.isEmpty) return null;
  if (source.startsWith('http')) return null;
  if (isThemeAssetRef(source)) {
    final asset = theme.spec.asset(source);
    // A pack whose files were swept, or a bundled path that no longer exists.
    // Checked here rather than in the widget because the preview would
    // otherwise paint a hole and log into a console nobody reads, which is the
    // failure mode this whole area keeps producing.
    return asset.existsSync ? asset.image : null;
  }
  final f = File(source);
  return f.existsSync() ? FileImage(f) : null;
}

/// What the previews at the top of the screen show: the user's current pick,
/// else the first preset this distro offers that they have not hidden.
///
/// Falling back matters on a first run, where nothing has been applied yet and
/// an empty pair of phones would be the first thing on the screen.
String? previewWallpaperFor(EffectiveTheme theme) {
  final current = theme.prefs.wallpaperCurrent;
  if (current != null && current.isNotEmpty) return current;
  for (final w in theme.spec.wallpapers) {
    if (!theme.prefs.wallpapersHidden.contains(w)) return w;
  }
  return null;
}

/// One line describing how [source] is framed right now.
///
/// Says the fit, and says whether the position was chosen or inherited, because
/// those are the two facts the row is standing in for. It deliberately does not
/// print the focal numbers: "0.5, 0.38" is a coordinate, not an answer, and the
/// screen behind the row shows the actual thing.
String framingSummary(EffectiveTheme theme, String source) {
  final framing = resolveWallpaperFraming(
    user: theme.prefs.wallpaperFraming,
    authored: theme.spec.wallpaperMeta,
    source: source,
    legacyFit: theme.prefs.wallpaperFit,
  );
  final fit = switch (framing.resolvedFit) {
    'contain' => 'Whole image, bars if needed',
    'cover' => 'Fills the screen, edges crop',
    'center' => 'Actual size',
    // 'fill' is the default, so it is the arm an unnamed fit lands on and the
    // wording has to be the one that is true by default rather than a
    // leftover describing whichever fit used to hold that position.
    _ => 'Whole image, matched to the screen',
  };
  return theme.prefs.wallpaperFraming.containsKey(source)
      ? '$fit, framed by you'
      : fit;
}

/// This distro's presets, in the order the user put them.
///
/// ─── ABSENT NAMES SORT LAST, THEY DO NOT DISAPPEAR ──────────────────────────
///
/// The order is a list of names and the pack is the list of files, and the two
/// go out of sync the moment a distro is republished. Treating the order as
/// authoritative would silently drop every wallpaper added since the user last
/// touched the strip, which is the failure that looks like the CDN update
/// having gone wrong. So the order filters, the remainder appends, and a name
/// nobody ships any more simply never matches.
List<String> orderedPresets(EffectiveTheme theme) {
  final presets = theme.spec.wallpapers;
  final order = theme.prefs.wallpaperOrder;
  if (order.isEmpty) return presets;

  final known = presets.toSet();
  final ranked = [
    for (final name in order)
      if (known.contains(name)) name,
  ];
  final seen = ranked.toSet();
  return [
    ...ranked,
    for (final name in presets)
      if (!seen.contains(name)) name,
  ];
}

/// The pool [source] names, for this theme.
///
/// Unknown values and dangling collection ids fall to the DISTRO pool, not to
/// an empty list: a rotation that silently stops because a collection was
/// deleted is the worse failure, and the distro pool is the state the setting
/// began in.
/// [hidden] overrides `theme.prefs.wallpapersHidden`, for the same reason
/// [applyWallpaper] takes a `fit`: the caller that has just written a new set
/// is holding a [theme] that has not reloaded yet, and rescheduling off the
/// stale one would leave the wallpaper the user just hid still in the worker's
/// list. Null means read it off [theme], which is what every other caller does.
/// The `framingJson` blob for a rotation pool.
///
/// Keyed by the ENCODED source, not the stored one, because that is the string
/// the worker hands back to `setWallpaper` and therefore the only key it can
/// look itself up by. Getting this wrong is silent: every wallpaper in the
/// rotation renders centred with the schedule's fit, which is exactly what it
/// did before framing existed, so nothing looks broken and nothing works.
String rotationFramingJson(
  EffectiveTheme theme,
  List<String> pool,
) {
  final out = <String, dynamic>{};
  for (final source in pool) {
    final framing = resolveWallpaperFraming(
      user: theme.prefs.wallpaperFraming,
      authored: theme.spec.wallpaperMeta,
      source: source,
      legacyFit: theme.prefs.wallpaperFit,
    );
    if (framing.isDefault) continue;
    out[encodeWallpaperFor(theme, source)] = framing.toJson();
  }
  // An empty map serialises to "{}" and the worker treats a blank string as
  // "nothing to say", so send the blank rather than a JSON object that parses
  // to nothing. One fewer parse per tick, and the prefs entry stays empty
  // instead of holding two characters that mean nothing.
  return out.isEmpty ? '' : jsonEncode(out);
}

List<String> rotationPoolFor(
  EffectiveTheme theme,
  List<WallpaperCollection> collections,
  String? source, {
  Set<String>? hidden,
}) {
  // Hiding applies to the DISTRO'S presets only. The user's own photos have a
  // real Remove that deletes a real copy, and a collection is theirs to edit,
  // so neither is filtered here.
  final skip = hidden ?? theme.prefs.wallpapersHidden;
  final own = [
    for (final w in theme.spec.wallpapers)
      if (!skip.contains(w)) w,
    ...theme.prefs.wallpapers,
  ];
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
  Set<String>? hidden,
}) async {
  final minutes = theme.prefs.wallpaperRotationMinutes;
  if (minutes == null) return;
  final pool = rotationPoolFor(theme, collections, source, hidden: hidden);
  // No length branch: Kotlin's schedule() cancels itself on an empty list,
  // and a one-item pool re-applying the same image is harmless.
  await ref.read(launcherHostApiProvider).scheduleWallpaperRotation(
        minutes,
        pool.map((p) => encodeWallpaperFor(theme, p)).toList(),
        theme.prefs.wallpaperLock ?? false,
        // The schedule's own fallback, used by the worker for any source in
        // the pool that carries no framing. It tracks the app default rather
        // than naming a fit, so changing the default cannot leave rotation
        // rendering differently from a manual apply.
        fit ?? theme.prefs.wallpaperFit ?? WallpaperFraming.defaultFit,
        theme.palette.bgTop.toARGB32(),
        rotationFramingJson(theme, pool),
      );
}

/// Keeps the rotation worker pointed at the ACTIVE distro.
///
/// ─── THE BUG THIS EXISTS FOR ────────────────────────────────────────────────
///
/// `scheduleWallpaperRotation` was only ever called from the wallpaper screen,
/// so the worker was only ever corrected while somebody was standing on that
/// page. Switch distro anywhere else and the job keeps the OLD distro's
/// encoded sources, its fit, its framing and its lock target, because nothing
/// told it the theme had changed. Fifteen minutes later Kali's dragon lands on
/// a Pop desktop, and it keeps happening until the wallpaper screen is opened
/// for some unrelated reason.
///
/// Worse in the direction nobody looks: `wallpaperRotationMinutes` is PER
/// THEME, so a distro with rotation off inherits a running job from the distro
/// that had it on. The setting says Off, the wallpaper changes anyway, and the
/// screen showing Off is telling the truth about a preference that is not the
/// one driving the worker.
///
/// ─── WHY A PROVIDER AND NOT A CALL AT THE SWITCH SITE ───────────────────────
///
/// There is more than one way the active theme changes: the theme picker, a
/// pack auto-update, an entitlement resolving, a restore. Hanging the fix on
/// the picker fixes the path somebody thought of. Watching the resolved theme
/// covers all of them, including the ones added later, and the reconcile is
/// idempotent so running it more often than strictly needed costs one native
/// call that replaces a job with the same job.
final wallpaperRotationSyncProvider = FutureProvider<void>((ref) async {
  final theme = await ref.watch(effectiveThemeProvider.future);
  final collections = await ref.watch(wallpaperCollectionsProvider.future);
  final api = ref.read(launcherHostApiProvider);

  final minutes = theme.prefs.wallpaperRotationMinutes;
  if (minutes == null) {
    // CANCEL, not leave alone. This is the inherited-job case, and it is the
    // half of the bug that looks like the launcher ignoring a setting.
    api.cancelWallpaperRotation();
    return;
  }

  final pool = rotationPoolFor(
    theme,
    collections,
    theme.prefs.wallpaperRotationSource,
  );
  api.scheduleWallpaperRotation(
    minutes,
    pool.map((p) => encodeWallpaperFor(theme, p)).toList(),
    theme.prefs.wallpaperLock ?? false,
    theme.prefs.wallpaperFit ?? WallpaperFraming.defaultFit,
    theme.palette.bgTop.toARGB32(),
    rotationFramingJson(theme, pool),
  );
});

/// Wallpaper picker — Phase B, B2.
///
/// Every surface here reads the chrome, not a constant: the app bar, section
/// heads, rows and the rotation picker come from the primitives (see
/// design/components), so the screen is dressed in the active distro's palette
/// and family. The rotation control was a Material [DropdownButton] (which reads
/// the ambient theme); it is now a themed [ThemedSheet], matching how Settings
/// does every other picker.
/// Bring a theme's legacy "Yours" entries into app storage, once.
///
/// ─── WHY THIS RUNS AT ALL, AND WHY IT IS BEST EFFORT ────────────────────────
///
/// Entries stored before the copy rule point into `image_picker`'s cache. Some
/// of those files still exist and some were evicted months ago, and there is no
/// way to tell which from the string. So: every entry we can still READ is
/// copied into our own directory and the entry rewritten to the copy; every
/// entry we cannot read is LEFT EXACTLY AS IT WAS.
///
/// Leaving the dead ones is deliberate. Dropping them would be the launcher
/// silently deleting records the user created, to fix a problem the user cannot
/// see, with no way to tell afterwards what went missing. A broken thumbnail
/// they can remove themselves is the more honest failure, and Forget already
/// handles it.
///
/// PER THEME, because `wallpapers` is. Another distro's list migrates the first
/// time its wallpaper screen is opened, which is also the first moment it could
/// matter.
///
/// Once per process: the flag stops a rebuild storm from re-running it, and the
/// work is idempotent anyway, since a migrated entry already sits under our own
/// directory and is skipped.
final Set<String> _migratedThemes = <String>{};

Future<void> migrateOwnWallpapers(WidgetRef ref, EffectiveTheme theme) async {
  if (!_migratedThemes.add(theme.spec.id)) return;

  final mine = theme.prefs.wallpapers;
  if (mine.isEmpty) return;

  // Resolved ONCE. `isOwnWallpaperCopy` crosses a platform channel for the
  // support directory, and asking per entry would put a channel round trip in
  // a loop for an answer that cannot change.
  final dir = await ownWallpapersDir();

  // Absolute paths only. A theme preset is an asset reference and a picked
  // document can be a content:// URI; neither is a file we may copy.
  final legacy = [
    for (final w in mine)
      if (w.startsWith('/') && !w.startsWith('${dir.path}/')) w,
  ];
  if (legacy.isEmpty) return;
  final moved = <String, String>{};
  for (final old in legacy) {
    if (!await File(old).exists()) continue;
    final copy = await copyWallpaperInto(dir, old);
    if (copy != null) moved[old] = copy;
  }
  if (moved.isEmpty) return;

  await ref.read(prefsProvider(theme.spec.id).notifier).edit(
        (p) => p.copyWith(
          wallpapers: [for (final w in p.wallpapers) moved[w] ?? w],
          // The applied wallpaper follows its entry. Without this the record
          // would point at a cache path the list no longer contains, which is
          // the dangling state Forget exists to prevent.
          wallpaperCurrent: moved[p.wallpaperCurrent] ?? p.wallpaperCurrent,
        ),
      );
}

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

    // POST-FRAME, because it writes prefs and Riverpod forbids writing a
    // provider during build. Self-guarded and idempotent, so scheduling it on
    // every build costs one set lookup after the first run.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => migrateOwnWallpapers(ref, theme),
    );

    // Theme presets first, then whatever the user added: the distro pool.
    // Rotation may draw wider than it (every collection) or narrower (one
    // collection); [rotationPoolFor] is the one place that choice resolves.
    final presets = orderedPresets(theme);
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
                        theme.prefs.wallpaperFit ?? WallpaperFraming.defaultFit,
                        theme.palette.bgTop.toARGB32(),
                        rotationFramingJson(theme, pool),
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
        // Clears the navigation bar. Trailing padding rather than a SafeArea,
        // so the list still scrolls behind a transparent bar.
        padding: EdgeInsets.only(bottom: context.bottomInset),
        children: [
          // ── THE PAIR AT THE TOP ────────────────────────────────────────
          //
          // Lock and home, side by side, both showing the wallpaper that is
          // actually on. It is the shape Android's own Wallpaper and style
          // screen uses, and the reason is the same: this page has a LOCK
          // SCREEN toggle, and without a picture of one that setting is a
          // promise you have to lock the phone to check.
          //
          // Both panes are drawn by the SAME widget the rest of Settings uses,
          // so a distro switch repaints them with no wiring, and the home pane
          // shows this distro's real dock side rather than a generic phone.
          if (previewWallpaperFor(theme) case final src?)
            SettingPreview(
              caption: applyToLock
                  ? 'Lock and home'
                  : 'Lock screen unchanged, home only',
              child: _WallpaperPreviewPair(theme: theme, source: src),
            ),

          if (presets.isNotEmpty) ...[
            _StripHeader(
              title: context.t('wallpaper.fromThisDistro'),
              presets: true,
            ),
            _Strip(
              sources: presets,
              source: theme.spec.source,
              onTap: apply,
              // Intersected with what this distro actually ships, so a name
              // hidden under an older version of the pack cannot inflate the
              // count below after a republish drops that file.
              hidden: {
                for (final w in presets)
                  if (theme.prefs.wallpapersHidden.contains(w)) w,
              },
              onHide: (src, hide) => setPresetHidden(
                context,
                ref,
                theme,
                collections,
                src,
                hide,
              ),
              // ─── STORED AS A WHOLE LIST, NOT AS A MOVE ─────────────────
              //
              // Writing the entire resulting order rather than the pair that
              // changed is what makes the first reorder work at all: before
              // one happens `wallpaperOrder` is empty and means "the pack's
              // order", so there is no existing list for a move to be applied
              // against. Persisting the result makes the empty case a
              // starting value rather than a special case anybody has to
              // remember.
              onReorder: (oldIndex, newIndex) async {
                final next = [...presets];
                next.insert(newIndex, next.removeAt(oldIndex));
                await notifier.edit((p) => p.copyWith(wallpaperOrder: next));
                await rescheduleRotation(
                  ref,
                  theme,
                  collections,
                  source: rotationSource,
                );
              },
            ),
          ],
          _StripHeader(title: context.t('wallpaper.yours'), presets: false),
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
            // ─── ORDER IS NOT DECORATION HERE ──────────────────────────
            //
            // Rotation walks this list in sequence rather than shuffling, so
            // the order is the order wallpapers actually appear in over a
            // day. It is also the list `rotationPoolFor` hands the worker, so
            // a reorder has to reschedule or the running job keeps cycling
            // the old sequence until something else happens to touch it.
            onReorder: (oldIndex, newIndex) async {
              // No off-by-one correction: the strip is on onReorderItem, which
              // hands back an index already adjusted for the removal.
              final next = [...mine];
              next.insert(newIndex, next.removeAt(oldIndex));
              await notifier.edit((p) => p.copyWith(wallpapers: next));
              // The pool is this list, and the worker holds its own copy, so
              // without this the running rotation keeps cycling the old
              // sequence. `source` is required rather than defaulted because
              // rescheduling off a stale theme is the bug its doc warns about.
              await rescheduleRotation(
                ref,
                theme,
                collections,
                source: rotationSource,
              );
            },
          ),
          ThemedListRow(
            icon: Icons.add_photo_alternate_outlined,
            title: context.t('settings.addAPhoto'),
            onTap: () async {
              final picked = await ImagePicker().pickImage(
                source: ImageSource.gallery,
              );
              if (picked == null) return;

              // ── COPIED, NOT REFERENCED ────────────────────────────────
              //
              // This used to store `picked.path` and say copying "doubles
              // disk use for no benefit, the photo is already on the
              // device". The photo is; that PATH is not. image_picker hands
              // back a file in cacheDir, the OS evicts caches whenever
              // storage gets tight, and the entry then outlives the file it
              // names. Every user photo here would eventually become a
              // broken thumbnail nobody removed. See [copyWallpaperInto].
              final copy = await copyWallpaperInto(
                await ownWallpapersDir(),
                picked.path,
              );
              if (copy == null) {
                if (context.mounted) {
                  context.showMessage('Could not add that photo');
                }
                return;
              }

              await notifier.edit(
                (p) => p.copyWith(wallpapers: [...p.wallpapers, copy]),
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
          const ThemedSectionHeader('Applies to'),
          // ─── A ROW, NOT A TOGGLE ────────────────────────────────────────
          //
          // The toggle was the buried control this whole change exists to
          // unbury, and leaving it here beside the prompt would be two places
          // holding one answer. It is a row now for two reasons: it STATES the
          // current answer rather than making you read a switch position, and
          // it reopens the same sheet the first apply showed, so changing your
          // mind and making up your mind look identical.
          //
          // Still deliberately not retroactive. Rewriting the lock screen the
          // instant an answer changes is the surprise the old comment was
          // right about; the sheet says so itself.
          ThemedListRow(
            icon: Icons.lock_outline,
            title: applyToLock ? 'Lock and home screen' : 'Home screen only',
            subtitle: theme.prefs.wallpaperLock == null
                // Never asked. Saying so is more useful than describing a
                // default, because the next wallpaper is when it gets decided.
                ? 'You will be asked when you pick a wallpaper'
                : context.t('settings.appliesFromTheNext'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () async {
              if (previewWallpaperFor(theme) case final src?) {
                final chosen = await chooseApplyTarget(context, theme, src);
                if (chosen == null) return;
                await notifier.edit((p) => p.copyWith(wallpaperLock: chosen));
              }
            },
          ),
          // ── FRAMING REPLACES THE FIT SHEET ─────────────────────────────
          //
          // The sheet it replaces wrote `prefs.wallpaperFit`, one value for the
          // whole distro, and a distro ships a portrait logo render beside a
          // 2:1 screenshot: one fit is wrong for at least one of them whatever
          // it holds. The old pref is NOT deleted and not migrated. It survives
          // as the lowest arm of `resolveWallpaperFraming`, so anyone who set
          // it keeps it on every wallpaper they have not framed individually.
          // It simply stops having a control of its own, because a control that
          // sets the wrong scope is worse than no control.
          if (previewWallpaperFor(theme) case final src?)
            ThemedListRow(
              icon: Icons.crop_free,
              title: 'Framing',
              subtitle: framingSummary(theme, src),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WallpaperFramingScreen(
                    theme: theme,
                    source: src,
                  ),
                ),
              ),
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

          if (PrefsReset.canReset(theme.prefs, PrefsSection.wallpaper))
            ThemedListRow(
              icon: Icons.settings_backup_restore,
              title: 'Reset wallpaper settings',
              subtitle: 'Rotation, fit and lock screen',
              onTap: () async {
                final ok = await ThemedDialog.confirm(
                  context,
                  title: 'Reset wallpaper settings?',
                  message: 'Rotation, fit and the lock-screen switch go back '
                      'to their defaults. Your photos, your collections and '
                      'the wallpaper on screen right now are untouched.',
                  confirmLabel: 'Reset',
                );
                if (ok != true) return;

                await notifier.edit(
                  (p) => PrefsReset.section(p, PrefsSection.wallpaper),
                );
                // Rotation is the one setting here with a live schedule behind
                // it. Clearing the interval is what turns it off, so the worker
                // has to be told; otherwise the screen says off and the
                // wallpaper keeps changing.
                await ref
                    .read(launcherHostApiProvider)
                    .cancelWallpaperRotation();
                if (context.mounted) {
                  context.showMessage('Wallpaper settings reset');
                }
              },
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

  // The RECORD goes first and the file second, so a failed delete leaves an
  // orphaned file rather than a listed wallpaper that cannot be opened. Only
  // our own copies: a legacy cache path or a theme asset is not ours to
  // remove on the strength of a string.
  if (await isOwnWallpaperCopy(src)) {
    try {
      await File(src).delete();
    } catch (_) {}
  }

  if (context.mounted) context.showMessage(context.t('wallpaper.removed'));
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.sources,
    required this.source,
    required this.onTap,
    this.onRemove,
    this.hidden = const {},
    this.onHide,
    this.onReorder,
  });

  /// Null for the distro's own presets, which are not the user's to delete.
  final void Function(String source)? onRemove;

  /// Which of [sources] are hidden. Presets only; see [setPresetHidden].
  final Set<String> hidden;

  /// Null for the user's own photos, which are removed rather than hidden. The
  /// two are deliberately never both set: one strip, one long-press meaning.
  final void Function(String source, bool hide)? onHide;

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

  /// Null when this strip's order is not the user's to change.
  ///
  /// ─── WHY ONLY ONE STRIP GETS THIS ───────────────────────────────────────
  ///
  /// The presets strip is the PACK'S order, and the pack means it: the first
  /// entry is the one seeded on first use of the theme, so the author picked it
  /// as the distro's opening impression. A user reorder there would need a
  /// fourth per-theme preference to store an override, and would then have to
  /// answer what happens to it when the pack republishes with a different list.
  /// The strip below it is already a stored list of the user's own files, where
  /// order is theirs by construction and rotation walks it in sequence.
  final void Function(int oldIndex, int newIndex)? onReorder;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;

    if (sources.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('Nothing yet', style: TextStyle(color: c.textFaint)),
      );
    }

    final reorder = onReorder;
    if (reorder != null) {
      return SizedBox(
        height: 160,
        child: ReorderableListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: sources.length,
          // OFF, because the default handles are built for a vertical list of
          // rows and draw nothing useful on a 90px thumbnail. The whole tile is
          // the handle instead, wrapped below.
          buildDefaultDragHandles: false,
          // onReorderItem, NOT onReorder. The old callback reports the
          // destination as an index in the list before the removal, so every
          // caller has to subtract one when dragging rightwards; the
          // replacement does that itself. Keeping the manual correction
          // alongside it would double-count and make a rightward drag land one
          // slot short, which reads as the drag being imprecise rather than
          // wrong.
          onReorderItem: reorder,
          // The tile lifts and tilts on its own; the default is a Material
          // elevation shadow that a themed strip has no other examples of.
          proxyDecorator: (child, index, animation) => Transform.scale(
            scale: 1.06,
            child: child,
          ),
          itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
            key: ValueKey(sources[i]),
            index: i,
            child: Padding(
              padding: EdgeInsets.only(
                right: i == sources.length - 1 ? 0 : 12,
              ),
              child: _tile(context, i),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: sources.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: _tile,
      ),
    );
  }

  Widget _tile(BuildContext context, int i) {
    final c = ChromeScope.of(context).colors;
    final src = sources[i];
    final remove = onRemove;
    // Remote first: it is the only case with its own loading state, and
    // `isThemeAssetRef` would otherwise have to exclude it twice.
    final isRemote = src.startsWith('http');
    // A theme reference, bundled OR installed. `source.asset` decides which,
    // and returns an AssetImage or a FileImage accordingly.
    final themed = !isRemote && isThemeAssetRef(src) ? source.asset(src) : null;

    final hide = onHide;
    final isHidden = hidden.contains(src);

    return Stack(
      children: [
        GestureDetector(
          // A dimmed tile is not a wallpaper you can pick, it is one you told
          // us you did not want, so tapping it means "actually, keep it"
          // rather than "apply the thing I just rejected".
          onTap: () {
            if (isHidden && hide != null) {
              hide(src, false);
            } else {
              onTap(src);
            }
          },
          // ─── WHAT A LONG PRESS MEANS, PER STRIP ────────────────────────
          //
          // It used to mean remove here and hide on the presets strip: one
          // gesture, one meaning per strip, and no badge putting a
          // destructive target under the thumb of someone browsing.
          //
          // Reordering takes the gesture back. Drag to reorder IS a long
          // press everywhere it exists, including this app's own home grid,
          // and a second gesture for it would be one nobody finds. So on a
          // strip that reorders, the hold drags and removal moves to the
          // badge that comment argued against. The argument was right while
          // the hold was free; it is not a reason to ship a reorder nobody
          // can perform.
          //
          // The presets strip keeps the old arrangement exactly, because it
          // does not reorder and its hold is still spare.
          onLongPress: onReorder != null
              ? null
              : (hide != null
                  ? () => hide(src, !isHidden)
                  : (remove == null ? null : () => remove(src))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 90,
              child: _dim(
                isHidden,
                c.text,
                switch ((themed != null, isRemote)) {
                  (true, _) => Image(
                      image: themed!.image,
                      fit: BoxFit.cover,
                      // A theme whose wallpaper files are missing must still
                      // show a usable list, not a red error box. Reachable
                      // for an installed pack whose files were swept as well
                      // as for a bundled path that no longer exists.
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
          ),
        ),
        // ─── WHY A BADGE AND NOT A SECOND HOLD ─────────────────────────
        //
        // Hold-then-drag and hold-then-release cannot be told apart at the
        // moment the hold fires: the drag has already started by then, and
        // deciding retroactively means either a delay before the tile lifts or
        // a hide that fires whenever somebody thinks better of a drag. Both
        // are worse than a target you can see. So on a strip that reorders,
        // the hold drags and the second action moves to this badge: × on your
        // own photos, an eye on presets, which are hidden rather than deleted.
        if (onReorder != null && (remove != null || hide != null))
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => remove != null ? remove(src) : hide!(src, !isHidden),
              // Bigger than it looks. The visible dot is 20px and the padding
              // around it brings the target up to what a thumb needs, without
              // a circle that size covering a third of the thumbnail.
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.bg.withValues(alpha: 0.72),
                    shape: BoxShape.circle,
                    border: Border.all(color: c.line),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      remove != null
                          ? Icons.close
                          : (isHidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                      size: 14,
                      color: c.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// A hidden thumbnail, knocked back and marked.
  ///
  /// Opacity ALONE is not enough. A dark wallpaper at 30% and a dark wallpaper
  /// at 100% are the same rectangle on a phone in daylight, and the strip would
  /// read as a rendering fault rather than a state. The struck-through eye is
  /// the part that says which one this is.
  Widget _dim(bool isHidden, Color ink, Widget child) {
    if (!isHidden) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(opacity: 0.3, child: child),
        Center(
          child: Icon(Icons.visibility_off_outlined, size: 22, color: ink),
        ),
      ],
    );
  }
}

/// A strip's heading, with the gestures behind an info button.
///
/// ─── WHY THE INSTRUCTIONS ARE NOT ON THE PAGE ANY MORE ──────────────────────
///
/// They used to be a line under the strip, and the argument for it was sound:
/// a long press is invisible until somebody finds it, and this screen is the
/// only place that gesture does something you cannot reach another way.
///
/// It stopped being true twice over. The gesture now REORDERS rather than
/// hides, so the sentence was describing behaviour the screen no longer had,
/// and hiding moved to a badge that is visible on every tile, so the thing the
/// line existed to reveal reveals itself. What was left was a paragraph of
/// help text sitting permanently above the content on a page whose whole job
/// is showing pictures.
///
/// A button reads once and then gets ignored, which is the correct lifetime
/// for this content: nobody needs to be told twice that dragging reorders.
class _StripHeader extends StatelessWidget {
  const _StripHeader({required this.title, required this.presets});

  final String title;

  /// The distro's own wallpapers, which are hidden rather than deleted.
  final bool presets;

  @override
  Widget build(BuildContext context) {
    final c = ChromeScope.of(context).colors;

    return Row(
      children: [
        Expanded(child: ThemedSectionHeader(title)),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => ThemedSheet.show<void>(
              context,
              title: title,
              builder: (ctx) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ThemedListRow(
                    icon: Icons.touch_app_outlined,
                    title: 'Tap',
                    subtitle: 'Sets it as your wallpaper',
                  ),
                  ThemedListRow(
                    icon: Icons.drag_indicator,
                    title: 'Hold and drag',
                    subtitle: presets
                        // Said plainly, because the consequence is not
                        // obvious from the gesture: the first one is the one
                        // a fresh install of this distro applies by itself.
                        ? 'Reorders them. The first is what a new install gets'
                        : 'Reorders them, which is the order rotation follows',
                  ),
                  ThemedListRow(
                    icon: presets ? Icons.visibility_off_outlined : Icons.close,
                    title: presets ? 'The eye' : 'The cross',
                    subtitle: presets
                        ? 'Hides it from this distro. Tap a dimmed one to '
                            'bring it back'
                        : 'Removes your photo',
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // The icon is small and the row it sits in is not, so the target
            // is the padding rather than the glyph.
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.info_outline, size: 17, color: c.textFaint),
            ),
          ),
        ),
      ],
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

/// Two phones: the lock screen and the desktop, both under the live wallpaper.
///
/// ─── THE LOCK PANE IS DRAWN EVEN WHEN THE TOGGLE IS OFF ─────────────────────
///
/// It shows what the lock screen currently looks like, not what this wallpaper
/// would do to it, and the caption says which. Hiding the pane when the toggle
/// is off would answer the question by omission and leave the row above it
/// still unillustrated; drawing it with the wallpaper regardless would claim a
/// change the launcher has deliberately not made, since the lock setting is
/// applied from the NEXT wallpaper on and never retroactively.
///
/// So: the toggle off means the lock pane keeps the distro's own colours, which
/// is honest about both.
class _WallpaperPreviewPair extends StatelessWidget {
  const _WallpaperPreviewPair({required this.theme, required this.source});

  final EffectiveTheme theme;
  final String source;

  @override
  Widget build(BuildContext context) {
    final image = wallpaperImageFor(theme, source);
    final onLock = theme.prefs.wallpaperLock ?? false;

    // Resolved here rather than passed in, so the pair updates the moment the
    // framing screen pops: it reads the same provider the row's summary does,
    // and there is no second copy to forget to refresh.
    final framing = resolveWallpaperFraming(
      user: theme.prefs.wallpaperFraming,
      authored: theme.spec.wallpaperMeta,
      source: source,
      legacyFit: theme.prefs.wallpaperFit,
    );

    // ── FORMATTED HERE, WITHOUT A TICKER ───────────────────────────────
    //
    // MaterialLocalizations rather than a clock provider: the delegates are
    // already installed in app.dart for RTL, so this is locale-correct for
    // free and costs no subscription. It does not tick, which is right for a
    // still picture of a lock screen and would be wrong for a clock desklet.
    final now = DateTime.now();
    final clock = TimeOfDay.fromDateTime(now).format(context);
    final date = MaterialLocalizations.of(context).formatMediumDate(now);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DevicePreview(
            palette: theme.palette,
            mode: DevicePreviewMode.lock,
            background: onLock ? image : null,
            backgroundFraming: framing,
            clockLabel: clock,
            dateLabel: date,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: DevicePreview(
            palette: theme.palette,
            mode: DevicePreviewMode.desktop,
            dock: theme.dock,
            gridButton: theme.prefs.dockGridButton ?? 'end',
            background: image,
            backgroundFraming: framing,
          ),
        ),
      ],
    );
  }
}
