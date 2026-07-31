/// How a wallpaper source is handed to native, and who currently owns the
/// screen. One file, because both facts were duplicated and both copies were
/// wrong in a different way.
library;

/// Encode a stored wallpaper source for `LauncherHostApi.setWallpaper`.
///
/// ─── THE BUG THIS FIXES: YOUR OWN PHOTOS NEVER APPLIED ──────────────────────
///
/// Native distinguishes sources by SCHEME. The old encoder attached one to
/// bundled assets and to nothing else:
///
///     source.startsWith('assets/') ? 'asset:$source' : source
///
/// `image_picker` returns a BARE ABSOLUTE PATH, something like
/// `/data/user/0/com.mindhunter.g_launcher/cache/image_picker123.jpg`. No
/// scheme at all. So a theme preset arrived as `asset:...` and applied, an
/// http URL arrived with its own scheme and applied, and a photo the user had
/// just picked arrived as a naked path, matched no branch on the native side,
/// and silently did nothing. Every other path worked, which is exactly why it
/// looked like the picker was broken rather than the encoding.
///
/// Four cases, in the order they can be told apart:
///   `assets/…`      bundled          -> `asset:…`
///   `http…`         CDN              -> unchanged
///   `…://…`         content or file  -> unchanged, it already has a scheme
///   `/…`            a bare path      -> `file://…`
String encodeWallpaperSource(String source) {
  if (source.startsWith('assets/')) return 'asset:$source';
  if (source.startsWith('http')) return source;
  // Anything that already names a scheme is native's problem, not ours:
  // `content://` from a document picker, `file://` from an earlier write.
  if (source.contains('://')) return source;
  return 'file://$source';
}

/// Is [source] a reference INTO the active theme, rather than a device path or
/// a URL?
///
/// ─── THE BUG THIS EXISTS TO FIX: A DOWNLOADED DISTRO HAS NO WALLPAPER ───────
///
/// [encodeWallpaperSource] takes a string and nothing else, so it cannot know
/// where a theme's files live. That is correct for a BUNDLED theme, whose
/// `theme.json` says `assets/themes/ubuntu-24-04/wallpapers/numbat_color.webp`
/// and which resolves through the asset bundle. It is silently wrong for an
/// INSTALLED pack, whose `theme.json` says `wall_x.webp` — a bare filename,
/// because `PackPaths` refuses separators — with the directory known only to
/// `ThemeSource`.
///
/// A bare name falls through all four branches above and comes out as
/// `file://wall_x.webp`: two slashes and a relative remainder, which parses as
/// an authority with an empty path. There is nothing for native to open, so the
/// system wallpaper never changes. And the launcher runs TRANSPARENT over the
/// system wallpaper (see `_WallpaperParallax` in gnome_shell.dart — "the
/// wallpaper is drawn by WindowManager underneath Flutter"), so this is not a
/// cosmetic miss: it is the whole reason a downloaded distro appeared to arrive
/// with no wallpaper at all.
///
/// ─── WHY A SEPARATE PREDICATE AND NOT A `spec.asset()` CALL AT THE SITE ─────
///
/// Because `prefs.wallpaperCurrent` holds TWO different kinds of string and
/// only one of them may be resolved against the pack directory:
///
///   `wall_x.webp`                       a theme reference     -> resolve
///   `assets/themes/…/numbat.webp`       a theme reference     -> resolve
///   `/data/…/cache/image_picker1.jpg`   the user's own photo  -> DO NOT
///   `content://…`                       a document picker URI -> DO NOT
///
/// Resolving the third against the pack directory relocates someone's photo
/// into a folder it is not in, which is a new bug traded for an old one. The
/// rule is exactly the inverse of [encodeWallpaperSource]'s last three
/// branches, and it lives here so the encoder and its discriminator cannot
/// drift apart — the same reason the encoder and [wallpaperAppliedForKey]
/// share this file.
///
/// TRUE FOR BUNDLED PATHS TOO, deliberately. `ThemeSource.asset` returns a
/// bundled path unchanged, so passing one through costs nothing and means the
/// call sites need one branch instead of two.
bool isThemeAssetRef(String source) =>
    !source.startsWith('http') &&
    !source.contains('://') &&
    !source.startsWith('/');

/// Which theme's wallpaper is currently on the screen.
///
/// ─── WHY THIS IS GLOBAL AND NOT A PER-THEME FLAG ────────────────────────────
///
/// Android has ONE wallpaper. `LauncherPrefs` is stored per theme. The old
/// code reconciled those with a per-theme `wallpaperInitialized` bool, which
/// cannot work, and fails in a way that looks random:
///
///   1. first run of Ubuntu   -> applies Ubuntu's, flag(ubuntu) = true
///   2. first run of KDE      -> applies KDE's,    flag(kde)    = true
///   3. back to Ubuntu        -> flag(ubuntu) is already true, so nothing is
///                               applied and you are looking at KDE's
///                               wallpaper under Ubuntu's palette
///
/// The flag answers "has this theme ever applied one". The question that
/// actually matters is "whose is on screen right now", and that is a single
/// global fact, so it lives above the per-theme store exactly like
/// `selectedThemeId` does.
///
/// Held here rather than in `prefs_repository` so the encoder and the key that
/// must agree with it sit in one file.
const wallpaperAppliedForKey = 'wallpaperAppliedFor.v1';

/// The value stored under [wallpaperAppliedForKey].
///
/// ─── WHY THIS IS A FUNCTION AND NOT A BARE THEME ID ─────────────────────────
///
/// It used to be `spec.id`, which was right until light mode existed. A theme
/// has two palettes and can ship two wallpapers, so "whose wallpaper is on
/// screen" needs the mode as well as the distro, or a light session sits on a
/// dark photograph.
///
/// It is a FUNCTION because TWO places write this key: the theme resolve, when
/// it seeds or swaps a wallpaper, and the wallpaper screen, when the user picks
/// one. They composed the token separately and stopped agreeing the moment the
/// mode was added, so the screen wrote `ubuntu-24-04` while the resolve looked
/// for `ubuntu-24-04|dark`, concluded the wrong wallpaper was up, and stamped
/// the theme's own preset back over the user's choice on the next rebuild.
/// Picking a wallpaper appeared to work and then quietly undid itself.
String wallpaperAppliedToken(String themeId, {required bool dark}) =>
    '$themeId|${dark ? 'dark' : 'light'}';
