/// PHASE 5, revised in T1.
///
/// Holds every theme available to this install:
///   - bundled  (assets/themes/… — ships in the APK, and is ALWAYS free)
///   - installed (downloaded packs on disk)
///   - available (in the CDN root manifest, not yet downloaded)
///
/// Responsibilities:
///   - load + verify signatures (see ThemeAssetLoader.kt — do not skip)
///   - resolve the active theme, with a guaranteed fallback to bundled Ubuntu
///   - honour `minAppVersion` so a new pack can't break an old client
///
/// Rule: the launcher must ALWAYS render. A corrupt or missing theme falls back
/// to Ubuntu silently. A user with a broken home screen has a bricked phone.
///
/// ─── BUNDLED IMPLIES FREE ───────────────────────────────────────────────────
///
/// Not a convention, a security property. A paid distro sitting in the APK is
/// one boolean flip from being unlocked, and `tier` in a bundled theme.json is
/// a string in a file anyone can read. Paid distros therefore arrive over the
/// CDN, where the entitlement is checked before the bytes are handed over, and
/// the admin panel owns tier for exactly the packs it can actually enforce it
/// on.
///
/// It also means initial setup needs no curated list of its own: the distros
/// setup offers ARE the bundled ones, and the two can never drift apart.
///
/// ─── WHY THESE THREE ────────────────────────────────────────────────────────
///
/// They demonstrate the RANGE, rather than being three distros that happen to
/// be free:
///
///   ubuntu-24-04   a full desktop with a dock down the left  (gnome)
///   kde-plasma-6   a full desktop with a bottom panel and a start menu
///                  (plasma) — immediately legible to anyone who has used
///                  Windows, which on a budget Android phone is the second
///                  most familiar metaphor there is
///   terminal       no desktop at all (tui)
///
/// Arch is deliberately NOT here despite being the most screenshot-worthy of
/// the set: no dock, no icons and launch-by-typing is a hard first experience,
/// and it is one of the strongest things there is to sell. Aqua likewise.
library;

/// One theme that ships inside the APK: an id and the asset holding its
/// ThemeSpec JSON. Bundled themes are the tier that is ALWAYS present and never
/// fails to resolve: the floor the fallback stands on.
class BundledTheme {
  const BundledTheme(this.id, this.assetPath);
  final String id;
  final String assetPath;
}

/// The one theme guaranteed to exist. Every fallback path lands here, so it can
/// never be removed from [bundledThemes] without breaking the promise above.
const fallbackThemeId = 'ubuntu-24-04';

/// Every bundled theme, by id. All free, by the rule above.
///
/// This is the seam the CDN work plugs into. Installed (downloaded) packs and
/// the remote manifest merge on top; the SHAPE the rest of the app reads,
/// id -> a resolvable ThemeSpec source, does not change.
///
/// ─── A BUNDLED ID CAN NOW BE SUPERSEDED ─────────────────────────────────────
///
/// It used to be a stated invariant that a bundled id could never also be
/// installed, and `activeThemeSpecProvider` checked bundled first because of
/// it. That is no longer true and the ordering there is now the other way
/// round: publishing `ubuntu-24-04` over the CDN replaces the copy in the APK
/// on any phone that downloads it.
///
/// This is what makes a fix to a free distro shippable without a Play release,
/// which was the reason for the pipeline in the first place.
///
/// What has NOT changed is that bundled implies free. A republished free distro
/// is still free: it carries no SKU, the panel adds no entitlement for it, and
/// nothing about the security property above is weakened. And the APK copy
/// stays the floor, so a corrupt or too-new upload falls back to it rather than
/// taking the distro away from anyone.
///
/// `fedora-41`, `arch-hyprland` and `aqua` USED TO BE HERE and were moved out
/// to the CDN when the free/paid line was drawn. Removing them from this map is
/// what takes them out of the APK; their `assets/themes/<id>/` directories and
/// their `pubspec.yaml` entries go with them, and a stale selection pointing at
/// one now resolves to Ubuntu through [bundledAssetFor] until the pack is
/// downloaded. That fallback is why removing them is safe.
const bundledThemes = <String, BundledTheme>{
  'ubuntu-24-04': BundledTheme(
    'ubuntu-24-04',
    'assets/themes/ubuntu-24-04/theme.json',
  ),
  'kde-plasma-6': BundledTheme(
    'kde-plasma-6',
    'assets/themes/kde-plasma-6/theme.json',
  ),
  'terminal': BundledTheme(
    'terminal',
    'assets/themes/terminal/theme.json',
  ),
};

/// Resolve an id to its bundled theme.json asset path, falling back to Ubuntu
/// when the id is unknown: a stale selection, a CDN id this build predates, a
/// pack that has not downloaded yet, or a typo. A null id (nothing selected
/// yet) also resolves to Ubuntu.
String bundledAssetFor(String? id) =>
    (bundledThemes[id] ?? bundledThemes[fallbackThemeId]!).assetPath;
