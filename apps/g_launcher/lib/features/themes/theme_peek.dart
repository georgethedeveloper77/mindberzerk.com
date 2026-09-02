/// PHASE 2: a distro's real look, for a distro nobody owns yet.
///
/// ─── WHAT THIS IS FOR ───────────────────────────────────────────────────────
///
/// The storefront draws a card for every distro in the signed index, and until
/// now the only thing it had to draw with was the index's preview block: five
/// colours and a layout enum. So a paid distro rendered as a coloured rectangle
/// and the thing being charged for was the emptiest picture on the screen.
///
/// [PackActions.peekTheme] fetches the pack's own `theme.json` without
/// installing anything. This file turns that string into the same
/// [EffectiveTheme] the live desktop resolves, so a preview can be drawn from
/// the distro's REAL palette, dock edge, top bar, panels and grid rather than
/// from a summary somebody remembered to fill in.
///
/// ─── IT RESOLVES WITH NEUTRAL PREFS, AND THAT IS THE POINT ──────────────────
///
/// `effectiveThemeProvider` merges the spec with the user's saved prefs for
/// that theme, which is right for the desktop and wrong here. A preview must
/// show what the DISTRO does, not what this user has already changed about a
/// distro they have never applied. `const LauncherPrefs()` is every field at
/// its default, so `LayoutResolver` falls through to the theme's own answer on
/// every one of them, which is exactly the picture the storefront is selling.
///
/// Everything a user CAN override is therefore absent from the preview by
/// construction, which is also the honest reading: those are the parts a buyer
/// can already reproduce for free.
///
/// ─── WHAT IT DELIBERATELY DOES NOT DO ───────────────────────────────────────
///
/// **It does not register fonts.** A peek fetches `theme.json` and nothing
/// else, so a distro's typeface is not on the device. `effectiveThemeProvider`
/// awaits `FontRegistry` before handing out a theme for exactly this reason,
/// but doing that here would mean a font download per card, and the preview
/// would still be wrong for any pack that ships its own face rather than naming
/// an OFL one. Previews render in the fallback face. That is a known gap and it
/// is smaller than the one it replaces.
///
/// **It does not touch pack assets for an uninstalled pack.** See
/// [PeekedTheme.assetsOnDisk]. A peeked spec carries `ThemeSource.remote`, so
/// asking it for a wallpaper reports `existsSync` false and every renderer in
/// the app already treats that as "draw the fallback". The flag is still the
/// thing to read: it says WHY, and it is what lets a caller substitute the
/// user's own wallpaper rather than simply drawing less.
///
/// **It does not fall back to the index preview.** Null means "no answer", and
/// the caller draws what it drew before. Putting that decision here would give
/// this file an opinion about a widget it cannot see.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cdn/pack_repository.dart';
import '../../data/prefs/launcher_prefs.dart';
import '../../engine/effective_theme.dart';
import '../../engine/theme_source.dart';
import '../../engine/theme_spec.dart';

/// What to peek: a pack, at a version.
///
/// ─── THE VERSION IS IN THE KEY, AND IT HAS TO BE ────────────────────────────
///
/// A family keyed on the packId alone would cache the first answer forever, so
/// republishing a distro through the panel would leave every device drawing the
/// old preview beside a card that already says Update. The version is the one
/// value that moves on a republish and it is already on [ThemeCard], so putting
/// it in the key makes a republish produce a new provider and a fresh peek with
/// no invalidation logic anywhere.
///
/// A RECORD rather than a class: records have structural equality in Dart, which
/// is the only property a family key needs, and a hand-written `==` here would
/// be six lines whose sole failure mode is forgetting to add the next field.
typedef PeekRequest = ({String packId, int version});

/// A distro's look, resolved, for a distro that may not be installed.
@immutable
class PeekedTheme {
  const PeekedTheme({
    required this.packId,
    required this.spec,
    required this.effective,
    required this.assetsOnDisk,
  });

  final String packId;

  /// Parsed from the pack's own `theme.json`, hash-checked against a signed
  /// manifest before it reached Dart.
  final ThemeSpec spec;

  /// The same object the shells render from, resolved with neutral prefs.
  final EffectiveTheme effective;

  /// Whether this pack's FILES are on the device.
  ///
  /// ─── THE ONE FLAG A RENDERER MUST NOT IGNORE ──────────────────────────────
  ///
  /// True when the pack is installed, in which case [spec] carries a
  /// `ThemeSource.installed` and its wallpapers, logo and desklet art resolve
  /// to real `FileImage`s.
  ///
  /// False for a peeked pack, where `theme.json` is the ONLY thing that was
  /// fetched. The spec still names `wall.jpg` because that is what the pack
  /// author wrote, and nothing on this device backs that name.
  ///
  /// The spec carries `ThemeSource.remote` for exactly this reason, so the
  /// worst case is now a fallback rather than a hole. It used to carry the
  /// bundled source, which handed back `AssetImage('wall.jpg')`: that throws
  /// inside the image pipeline, Flutter logs it once, nothing reaches the
  /// widget, and the preview painted a black rectangle where the distro's
  /// wallpaper should be.
  ///
  /// So the renderer reads this and draws the USER'S OWN wallpaper when it is
  /// false, which is also the agreed design: a card should show this distro's
  /// chrome over the background the phone actually has.
  final bool assetsOnDisk;
}

/// A pack's resolved look, or null.
///
/// ─── KEPT ALIVE ONLY WHEN IT SUCCEEDED ──────────────────────────────────────
///
/// Riverpod 3 auto-disposes, so without a `keepAlive` this would re-peek every
/// time a card scrolled out of the list and back, which on a slow connection is
/// a network round trip per scroll.
///
/// The `keepAlive` is therefore AFTER the answer and only for a real one. A
/// null is a failure worth retrying: offline, a CDN hiccup, an index that had
/// not arrived yet. Caching that for the life of the process would mean one bad
/// moment on a train permanently pinning a distro to its old flat rectangle.
///
/// A held [PeekedTheme] is a parsed spec and a resolved theme, tens of KB at
/// most, so holding one per distro is cheap next to the download it avoids.
///
/// ─── ONE PEEK PER PACK, NOT ONE PER CARD ────────────────────────────────────
///
/// The family key is the pack and its version, so the card, the detail page and
/// anything else that asks share a single in-flight future. That matters
/// because opening the detail page for a card that is already drawn must not
/// start a second fetch for the same bytes.
final peekedThemeProvider =
    FutureProvider.family<PeekedTheme?, PeekRequest>((ref, req) async {
  // Watched, not read: the preview should follow the phone's own dark mode the
  // way the desktop does, so a distro with both palettes previews as it would
  // actually look on this device right now.
  final systemDark = ref.watch(systemDarkProvider);

  final api = ref.read(packHostApiProvider);

  final raw = await ref.read(packActionsProvider).peekTheme(req.packId);
  if (raw == null || raw.isEmpty) return null;

  // ─── THE DIRECTORY DECIDES WHETHER ASSETS EXIST ──────────────────────────
  //
  // A path lookup, not a file read, and the same call `theme_engine` uses to
  // build a `ThemeSource`. Non-null means the pack is installed and its
  // wallpapers are real files this preview may open; null means `peekTheme`
  // took the remote path and `theme.json` is all that came down.
  //
  // AFTER the peek rather than before, deliberately. Doing it first would be a
  // stat on the main path for every card including the fourteen that will
  // answer from the network anyway, and this way a failed peek costs nothing
  // extra at all.
  final dir = await api.installedPackDir(req.packId);

  final ThemeSpec spec;
  try {
    spec = ThemeSpec.fromJson(
      (jsonDecode(raw) as Map).cast<String, dynamic>(),
    );
  } catch (_) {
    // Malformed, or authored against a newer schema than this build parses.
    // Null, like every other failure here: the card draws its index preview,
    // which is what it drew yesterday.
    return null;
  }

  // ─── STAMPED EITHER WAY, AND THE UNINSTALLED ARM IS THE NEW PART ─────────
  //
  // This used to leave an uninstalled peek on the default source, which was
  // harmless while bundled resolution returned its argument unchanged: the
  // spec named `wall.webp`, `AssetImage` found nothing, and the flag below was
  // what kept any renderer from asking.
  //
  // Bundled resolves against `assets/themes/<id>/` now, so leaving it there
  // would have a peeked Kali confidently name a plausible bundle key for a
  // directory that was never in the APK. `remote` says the true thing, and
  // `ThemeAsset.existsSync` reports false for everything it hands out, so a
  // renderer that forgets [PeekedTheme.assetsOnDisk] degrades to its fallback
  // instead of painting a hole.
  final sourced = dir == null || dir.isEmpty
      ? spec.withSource(const ThemeSource.remote())
      : spec.withSource(ThemeSource.installed(dir));

  // ─── NEUTRAL PREFS. SEE THE FILE DOC ─────────────────────────────────────
  //
  // `const LauncherPrefs()` is every field at its default, so `LayoutResolver`
  // answers from the THEME on all of them. Reading the user's saved prefs for
  // this theme id would preview their edits to a distro they have never worn,
  // and for the twelve distros nobody has applied it would silently inherit
  // whatever bucket happened to exist.
  final effective = EffectiveTheme.resolve(
    sourced,
    const LauncherPrefs(),
    systemDark: systemDark,
  );

  // Only now, and only because it worked. See the doc above.
  ref.keepAlive();

  return PeekedTheme(
    packId: req.packId,
    spec: sourced,
    effective: effective,
    assetsOnDisk: dir != null && dir.isNotEmpty,
  );
});
