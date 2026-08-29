/// How ONE wallpaper meets the screen, and the rule for deciding whose answer
/// wins when the pack and the user disagree.
///
/// A LEAF. No imports, deliberately. Both sides of the argument need this type:
/// [ThemeSpec.wallpaperMeta] is what the pack author said, and
/// [LauncherPrefs.wallpaperFraming] is what the user did instead. Putting the
/// class in either of those files would make the other one import it, and
/// `launcher_prefs.dart` importing the theme engine is an arrow pointing the
/// wrong way: the engine already reads prefs.
library;

/// The fit and the focal point for one wallpaper.
///
/// ─── WHY FRAMING IS PER WALLPAPER AND NOT PER THEME ─────────────────────────
///
/// It used to be per theme, one `prefs.wallpaperFit` covering everything, and
/// that is not a smaller version of this: it is a setting that cannot be right.
/// A distro ships a portrait logo render and a 2:1 desktop screenshot in the
/// same pack, and the user adds a photograph from their camera roll on top.
/// Those three want different answers, so a single fit is wrong for at least
/// two of them whatever value it holds, and the user reads that as the picker
/// being broken rather than as a setting they could change.
///
/// ─── THE UNITS, AND WHY THEY ARE FRACTIONS ──────────────────────────────────
///
/// [focalX] and [focalY] are 0 to 1 across the SOURCE image, not pixels and not
/// screen coordinates. Pixels break the moment `decodeSampled` picks a
/// different sample size, which it does on every different screen; screen
/// coordinates break on rotation and on every other device. A fraction of the
/// source survives both, and it is also the only form a pack author can write
/// into a theme.json without knowing what phone it lands on.
///
/// 0.5, 0.5 is the centre and is the default everywhere, so anything that says
/// nothing behaves exactly as it did before this type existed.
class WallpaperFraming {
  const WallpaperFraming({
    this.fit,
    this.focalX = 0.5,
    this.focalY = 0.5,
    this.zoom = 1.0,
  });

  factory WallpaperFraming.fromJson(Map<String, dynamic> json) =>
      WallpaperFraming(
        fit: _fit(json['fit']),
        focalX: _fraction(json['focalX']),
        focalY: _fraction(json['focalY']),
        // `.toDouble()` AFTER the clamp, not before. `num.clamp` is declared to
        // return `num` and `double` does not override it, so without this the
        // field assignment does not compile. It reads like a redundant
        // conversion and is not one.
        zoom: ((json['zoom'] as num?)?.toDouble() ?? 1.0)
            .clamp(1.0, 4.0)
            .toDouble(),
      );

  /// The four fits native understands.
  ///
  /// Public because the picker builds its selector from this list, and a
  /// selector that can offer a fifth value native would silently degrade is the
  /// bug this constant exists to make impossible.
  static const List<String> fits = ['cover', 'contain', 'fill', 'center'];

  /// The fit used when nobody has chosen one.
  ///
  /// ─── WHY THIS IS 'fill' AND NOT 'cover' ─────────────────────────────────
  ///
  /// 'cover' was the historical answer and it is the one that produced the
  /// complaint this whole area exists to fix. It hands the bitmap to the system
  /// spread across a surface roughly twice the screen's width, so what you see
  /// depends on the source aspect, the OEM, and a crop hint that only exists
  /// now because it was added. 'fill' maps the image onto exactly this screen:
  /// nothing is cropped, nothing is guessed, and the picture the settings page
  /// draws is the picture the phone draws, on every device, before anybody
  /// touches a control.
  ///
  /// It costs two things and they are worth naming rather than discovering.
  /// Aspect is not preserved, so an image whose shape differs from the screen
  /// is stretched; for pack wallpapers authored tall this is small, and for a
  /// landscape photo it is not. And there is no page parallax, because the
  /// composite path draws one screen and has nothing left over to pan into.
  /// Both are one tap away in the framing screen, which is where a user who
  /// cares about either will go.
  static const String defaultFit = 'fill';

  /// Whether framing can move anything on this fit.
  ///
  /// `fill` maps the whole image onto the whole screen and `contain` shows the
  /// whole image inside it, so in both cases every pixel is already visible and
  /// there is nothing to choose between. The UI hides the drag on these and
  /// native ignores the focal point for them; this getter is the single place
  /// that fact is written down, so the two cannot drift apart.
  static bool fitIsFramable(String? fit) {
    final resolved = fit ?? defaultFit;
    return resolved == 'cover' || resolved == 'center';
  }

  /// 'cover' | 'contain' | 'fill' | 'center', or null to take the default.
  ///
  /// A STRING, not an enum, matching the Pigeon boundary it feeds: an
  /// unrecognised value from a newer build degrades natively rather than
  /// failing to parse. Null rather than a defaulted 'cover' because those are
  /// not the same fact. Null means nobody expressed an opinion and should
  /// follow [defaultFit] if it ever changes; 'cover' means somebody chose it.
  final String? fit;

  /// Where the subject is, as a fraction of the source image. 0.5 is centre.
  final double focalX;
  final double focalY;

  /// 1.0 is the whole frame. Above 1 keeps less of the picture.
  ///
  /// NEVER BELOW 1. A zoom under one asks for a region larger than the image,
  /// which produces either a degenerate crop rect or letterbox bars the fit did
  /// not ask for. Clamped here AND natively, because prefs written by one build
  /// are read by the next.
  final double zoom;

  /// The fit to actually use, never null.
  String get resolvedFit => fit ?? defaultFit;

  /// Nothing here differs from the default, so nothing needs storing.
  ///
  /// Used to keep prefs from filling with entries that say nothing: the map is
  /// per theme and the wallpaper list can be long, and an entry per wallpaper
  /// the user merely looked at is a prefs blob that grows and never shrinks.
  bool get isDefault =>
      fit == null && focalX == 0.5 && focalY == 0.5 && zoom == 1.0;

  WallpaperFraming copyWith({
    String? fit,
    double? focalX,
    double? focalY,
    double? zoom,
  }) =>
      WallpaperFraming(
        fit: fit ?? this.fit,
        focalX: focalX ?? this.focalX,
        focalY: focalY ?? this.focalY,
        zoom: zoom ?? this.zoom,
      );

  /// Drops the fit back to "no opinion". Not expressible through [copyWith],
  /// whose null means "keep", which is the same trap `clearing` exists for on
  /// LauncherPrefs.
  WallpaperFraming clearingFit() => WallpaperFraming(
        focalX: focalX,
        focalY: focalY,
        zoom: zoom,
      );

  /// Only what differs from the default is written.
  ///
  /// A framing that has been reset therefore serialises to `{}`, and the
  /// writer drops empty entries, so resetting genuinely removes the key rather
  /// than storing a row of defaults forever.
  Map<String, dynamic> toJson() => {
        if (fit != null) 'fit': fit,
        if (focalX != 0.5) 'focalX': focalX,
        if (focalY != 0.5) 'focalY': focalY,
        if (zoom != 1.0) 'zoom': zoom,
      };

  static String? _fit(Object? raw) {
    final value = (raw as String?)?.trim();
    if (value == null || value.isEmpty) return null;
    // An unknown fit is DROPPED to null rather than carried. Carrying it would
    // push a value native has to degrade through every preview in the picker,
    // where nothing degrades it, so the UI would show a fit the phone is not
    // using.
    return fits.contains(value) ? value : null;
  }

  static double _fraction(Object? raw) {
    final value = (raw as num?)?.toDouble();
    if (value == null || value.isNaN) return 0.5;
    return value.clamp(0.0, 1.0).toDouble();
  }

  @override
  bool operator ==(Object other) =>
      other is WallpaperFraming &&
      other.fit == fit &&
      other.focalX == focalX &&
      other.focalY == focalY &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(fit, focalX, focalY, zoom);

  @override
  String toString() =>
      'WallpaperFraming($resolvedFit, $focalX, $focalY, x$zoom)';
}

/// Which framing applies to [source], given both maps and the legacy per-theme
/// fit.
///
/// ─── THE SAME THREE-ARM SHAPE LayoutResolver USES ───────────────────────────
///
/// User first, then what the pack authored, then the default. The arms are not
/// interchangeable and the order is the whole point: a pack republished with
/// new framing must not silently move a wallpaper the user has already framed
/// themselves, and a user who has never touched framing must get the author's
/// intent rather than a centred guess.
///
/// ─── WHY [legacyFit] IS STILL READ ──────────────────────────────────────────
///
/// `prefs.wallpaperFit` is the old per-theme setting. It is NOT deleted and not
/// migrated. Deleting it silently resets everyone who ever chose Fit for a
/// letterboxed screenshot, and a migration would have to guess which wallpaper
/// they meant it for, which is unknowable: the setting never named one. So it
/// survives as the lowest arm above the default. Someone who set it keeps it
/// everywhere until they frame an individual wallpaper, at which point that
/// wallpaper stops asking.
WallpaperFraming resolveWallpaperFraming({
  required Map<String, WallpaperFraming> user,
  required Map<String, WallpaperFraming> authored,
  required String source,
  String? legacyFit,
}) {
  final mine = user[source];
  if (mine != null) return mine;

  final theirs = authored[source];
  if (theirs != null) {
    // The author gets the focal point regardless, but a legacy per-theme fit
    // still outranks an unopinionated pack: the user set that one by hand.
    return theirs.fit == null && legacyFit != null
        ? theirs.copyWith(fit: legacyFit)
        : theirs;
  }

  return WallpaperFraming(fit: legacyFit);
}
