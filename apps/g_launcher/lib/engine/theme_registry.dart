/// PHASE 5.
///
/// Holds every theme available to this install:
///   - bundled  (assets/themes/… — Ubuntu ships in the APK as the fallback)
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

/// Every bundled theme, by id.
///
/// This is the seam the CDN work plugs into. Installed (downloaded) packs and
/// the remote manifest merge on top later; the SHAPE the rest of the app reads,
/// id -> a resolvable ThemeSpec source, does not change. For now every source
/// is a local asset.
const bundledThemes = <String, BundledTheme>{
  'ubuntu-24-04': BundledTheme(
    'ubuntu-24-04',
    'assets/themes/ubuntu-24-04/theme.json',
  ),
  'fedora-41': BundledTheme(
    'fedora-41',
    'assets/themes/fedora-41/theme.json',
  ),
  'kde-plasma-6': BundledTheme(
    'kde-plasma-6',
    'assets/themes/kde-plasma-6/theme.json',
  ),
  'arch-hyprland': BundledTheme(
    'arch-hyprland',
    'assets/themes/arch-hyprland/theme.json',
  ),
  'terminal': BundledTheme(
    'terminal',
    'assets/themes/terminal/theme.json',
  ),
  'aqua': BundledTheme(
    'aqua',
    'assets/themes/aqua/theme.json',
  ),
};

/// Resolve an id to its bundled theme.json asset path, falling back to Ubuntu
/// when the id is unknown: a stale selection, a CDN id this build predates, or
/// a typo. A null id (nothing selected yet) also resolves to Ubuntu.
String bundledAssetFor(String? id) =>
    (bundledThemes[id] ?? bundledThemes[fallbackThemeId]!).assetPath;
