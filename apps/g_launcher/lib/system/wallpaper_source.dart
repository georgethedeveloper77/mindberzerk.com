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
