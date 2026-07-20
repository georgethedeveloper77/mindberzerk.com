import 'package:pigeon/pigeon.dart';

/// THE SOURCE OF TRUTH for the Dart↔Kotlin bridge.
///
/// Regenerate after ANY edit here:
///
///   dart run pigeon --input pigeons/launcher_api.dart
///
/// Outputs (both are generated — never hand-edit them):
///   lib/platform/launcher_api.g.dart
///   android/app/src/main/kotlin/com/mindhunter/g_launcher/LauncherApi.g.kt
///
/// ─────────────────────────────────────────────────────────────────────────────
/// THIS FILE HAS BEEN LOST TWICE.
///
/// Both times the generated output was kept and the schema discarded, which is
/// the wrong way round: the outputs are derived, this is the original. Losing it
/// means the wire format can only be changed by hand-editing two generated
/// files in lockstep, and getting a codec id wrong there is a silent
/// serialisation bug that shows up as garbage on the other side of the channel.
///
/// It lives OUTSIDE `lib/` deliberately: it is a codegen input, not app code,
/// and putting it under `lib/` would compile the schema into the shipped app.
/// That is also why `tree lib` will never show it — check `ls pigeons/`.
///
/// **Commit this file.** It is cheaper to keep than to reconstruct.
///
/// NOTE ON IMPORTS: a Pigeon schema may import ONLY 'package:pigeon/pigeon.dart'.
/// Anything else (including 'dart:typed_data') is rejected at parse time —
/// `Uint8List` is a built-in Pigeon type and needs no import.
/// ─────────────────────────────────────────────────────────────────────────────
///
/// DECLARATION ORDER IS THE WIRE FORMAT. Pigeon assigns codec ids in the order
/// types are declared here, and the current build is pinned to:
///
///   129 AppChangeReason   130 IconTreatment   131 AppEntry
///   132 AppChangeEvent    133 IconStyle
///
/// Enums first, then classes, each group in declaration order. ADD NEW TYPES AT
/// THE END of their group — inserting one in the middle renumbers everything
/// after it, and a Dart side talking 132 to a Kotlin side hearing 133 fails in
/// the least debuggable way possible.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/launcher_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/mindhunter/g_launcher/LauncherApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.mindhunter.g_launcher'),
    dartPackageName: 'g_launcher',
  ),
)
// ─── ENUMS (codec 129, 130) ──────────────────────────────────────────────────

/// Why the app list changed. Native pushes the FULL list every time, so this is
/// informational — nothing on the Dart side merges deltas.
enum AppChangeReason {
  added,
  removed,
  changed,
  availabilityChanged,
}

/// The shape an icon is forced into.
///
/// roundedSquare + a cornerRadius float covers most distros: 0.0 is square,
/// 0.22 the default, 0.5 a circle. squircle and teardrop stay separate because
/// they are genuinely different curves — a rounded rect cannot fake a
/// superellipse, and the eye picks that up across a grid of 40 icons.
enum IconTreatment {
  circle,
  squircle,
  roundedSquare,
  square,
  teardrop,
  original,
}

// ─── CLASSES (codec 131, 132, 133) ───────────────────────────────────────────

/// One launchable activity, for one user profile.
///
/// [componentKey] is the stable identity used everywhere: layout rows, icon
/// cache keys, folder membership, usage counts. Format is
/// "packageName/className#userSerial", and it is opaque to Dart — never
/// reconstruct it by hand.
class AppEntry {
  AppEntry({
    required this.componentKey,
    required this.packageName,
    required this.className,
    required this.userSerial,
    required this.label,
    required this.updateToken,
    required this.isWorkProfile,
    required this.isSuspended,
    required this.isSystem,
    required this.category,
    required this.isGame,
  });

  String componentKey;

  String packageName;

  String className;

  int userSerial;

  String label;

  /// Changes whenever the app is updated or reinstalled. Part of the icon cache
  /// key, and that is its ONLY job — it is not a version number. (It used to be
  /// called versionCode. It never was one: getting a real version code needs
  /// QUERY_ALL_PACKAGES, which we refuse to ship.)
  int updateToken;

  bool isWorkProfile;

  bool isSuspended;

  bool isSystem;

  /// `ApplicationInfo.category` — the manifest's own `android:appCategory`.
  /// -1 (CATEGORY_UNDEFINED) when the app declares none, which is most of them,
  /// and always -1 below API 26 where the field does not exist.
  ///
  /// APPENDED, not inserted: field order is the decode index, so adding to the
  /// END keeps AppEntry on codec 131 with every existing index unmoved.
  int category;

  /// True when the app is a game. Reads the modern category first, then falls
  /// back to the legacy `FLAG_IS_GAME` for apps that predate the category and
  /// never set it — a lot of the games actually installed on a budget phone.
  bool isGame;
}

class AppChangeEvent {
  AppChangeEvent({
    required this.reason,
    required this.apps,
  });

  AppChangeReason reason;

  List<AppEntry> apps;
}

/// The icon half of a ThemeSpec.
class IconStyle {
  IconStyle({
    required this.treatment,
    required this.cornerRadius,
    required this.foregroundScale,
    this.backgroundColor,
    this.monochromeTint,
    this.heroPack,
    this.backgroundGradientEnd,
    this.gradientAngle,
    this.brandPack,
    this.brandTreatment,
  });

  IconTreatment treatment;

  /// Fraction of icon size, for roundedSquare. 0.0 = square, 0.5 = circle.
  /// A float rather than more enum cases on purpose: a distro whose icons are
  /// slightly squarer than KDE's should be a CDN theme edit, not a Play release.
  double cornerRadius;

  /// <1 insets the glyph inside the shape. Papirus-ish sets want ~0.72.
  double foregroundScale;

  /// null = keep the app's own adaptive background layer.
  /// Set = flat fill, which is what makes an icon set feel coherent rather than
  /// a bag of vendor colours. ARGB int.
  int? backgroundColor;

  /// null = draw the app's real coloured foreground.
  /// Set = force the monochrome layer, tinted. Degrades to the coloured
  /// foreground when an app ships no monochrome layer — which is most of them.
  int? monochromeTint;

  /// Hand-crafted icon pack that OVERRIDES the generator, e.g. "yaru".
  /// ~40-60 icons: the ones that define the distro (Files, Terminal, Settings,
  /// Software) plus the common third-party apps people actually look at.
  ///
  /// null = generator only. Part of the cache key.
  String? heroPack;

  /// The far end of a background GRADIENT, as ARGB. Null = flat fill.
  ///
  /// APPENDED, not inserted — same rule AppEntry.category follows. Field order
  /// is the decode index, so adding at the END keeps IconStyle on codec 133
  /// with every existing index unmoved.
  ///
  /// [backgroundColor] is the near end, so a gradient REQUIRES it: end set with
  /// backgroundColor null means "no flat fill", and there is nothing to grade
  /// from, so the renderer keeps the app's own adaptive background and ignores
  /// this. That rule lives in IconRenderer.fillBackground and nowhere else.
  int? backgroundGradientEnd;

  /// Gradient direction in degrees, rotating from top-to-bottom (0) toward
  /// left-to-right (90). 45 is the top-left-to-bottom-right diagonal that most
  /// desktop icon sets use. Ignored when [backgroundGradientEnd] is null.
  ///
  /// Nullable rather than defaulted so an existing theme.json with no gradient
  /// block parses unchanged; the renderer substitutes 45.
  double? gradientAngle;

  /// CC0 brand-glyph pack, e.g. "simple-icons". The HEAD of the icon pipeline:
  /// a package-name map to a single 24x24 SVG path plus the brand's own hex.
  ///
  /// Sits BELOW [heroPack] in the lookup and above the generator. Hero art is
  /// hand-drawn for one distro and wins; a brand glyph is shared across every
  /// theme and only says "this is WhatsApp", not "this is Yaru's WhatsApp".
  ///
  /// null = skip the brand layer entirely. Part of the cache key.
  String? brandPack;

  /// How a brand glyph is coloured. "brandPlate" (default) fills the shape with
  /// the brand's own hex and draws the glyph in whichever of white/near-black
  /// reads on it — WhatsApp stays green and stays recognisable. "themePlate"
  /// fills with the theme's own background (flat or graded) and draws the glyph
  /// in the brand hex, so the whole grid reads as one set at the cost of some
  /// recognisability. Yaru does the first; Papirus-style sets do the second.
  ///
  /// A STRING, NOT AN ENUM, AND THAT IS DELIBERATE. Pigeon numbers enums before
  /// classes, so declaring a third enum would take codec 131 and shove AppEntry,
  /// AppChangeEvent and IconStyle each up by one — silently repartitioning the
  /// wire format this file's header pins down. Appending a nullable String to an
  /// existing class costs nothing. Unknown values degrade to "brandPlate", same
  /// contract as ShellKind.parse and the icon treatment.
  String? brandTreatment;
}

// ─── HOST API (Dart calls, Kotlin implements) ────────────────────────────────

/// Implemented by `LauncherHostApiImpl`, constructed in
/// `LauncherApplication.onCreate` against the warmed engine.
///
/// `@async` marks the methods whose Kotlin side takes a callback instead of
/// returning: anything that touches disk, decodes a bitmap, or hits the package
/// manager cold. Everything else is a straight synchronous call. Getting this
/// wrong does not fail to compile — it silently moves work onto the platform
/// thread — so the four below are exactly the four that are async today.
@HostApi()
abstract class LauncherHostApi {
  /// The full launchable-app list. Served from cache when warm, refreshed off
  /// the main thread when cold.
  @async
  List<AppEntry> getInstalledApps();

  /// [sourceLeft]..[sourceBottom] are the icon's on-screen rect in logical
  /// pixels, so the system can expand the opening app FROM the icon. All null =
  /// no animation origin.
  void launchApp(
    String componentKey,
    double? sourceLeft,
    double? sourceTop,
    double? sourceRight,
    double? sourceBottom,
  );

  void openAppInfo(String componentKey);

  /// Refused silently for apps that cannot be uninstalled (system, work
  /// profile) — the Dart side hides the option rather than relying on this.
  void requestUninstall(String componentKey);

  /// Swap the active icon theme. Invalidates the in-memory icon cache; the DISK
  /// cache is kept, so switching back to a theme you used before is instant.
  ///
  /// [themeId] is part of every cache key. Change the style without changing the
  /// id and you will serve stale icons — so version the id ("ubuntu-24-04.v2")
  /// whenever you edit a theme's icon block.
  void setIconTheme(String themeId, IconStyle style);

  /// PNG bytes for one icon at one size, under the active theme.
  /// Null if the component vanished (uninstalled mid-scroll).
  ///
  /// Memory LRU -> disk -> render. The render path is the only slow one, and it
  /// runs off the main thread.
  @async
  Uint8List? getIcon(String componentKey, int sizePx);

  /// Nukes memory + disk. For a "rebuild icon cache" button in Settings.
  @async
  void clearIconCache();

  /// Are we the home app right now? Drives the "Set as default" banner.
  bool isDefaultLauncher();

  /// Opens Android's Home-app picker.
  ///
  /// NOT RoleManager. RoleManager gives a prettier in-app dialog but needs an
  /// Activity + result plumbing, and several OEMs (Samsung, Xiaomi) intercept
  /// or ignore it anyway. ACTION_HOME_SETTINGS is boring and works everywhere.
  void requestDefaultLauncher();

  /// Sets the REAL system wallpaper.
  ///
  /// [source] is "asset:<path>" (a theme preset) or a content:// URI the user
  /// picked. Returns false on failure — a bad image must not take the launcher
  /// down; the user simply keeps the wallpaper they had.
  @async
  bool setWallpaper(String source, bool applyToLock);

  /// Rotates the wallpaper, desktop-style.
  ///
  /// [minutes] is CLAMPED TO 15 — WorkManager's hard floor. Do not offer a
  /// shorter interval in the UI and quietly deliver fifteen; lying about a
  /// setting is worse than not having it.
  void scheduleWallpaperRotation(
    int minutes,
    List<String> sources,
    bool applyToLock,
  );

  void cancelWallpaperRotation();

  /// Is the gesture accessibility service actually enabled?
  ///
  /// Checked live rather than cached: the user can revoke it in system settings
  /// at any moment, and a launcher whose gestures silently stopped working — with
  /// no explanation — is a launcher people give up on.
  bool isGestureServiceEnabled();

  /// Opens Android's accessibility settings so the user can enable it.
  void openAccessibilitySettings();

  /// "notifications" | "quickSettings" | "lockScreen" | "recents".
  /// Returns false when the service is off or the action is unsupported.
  /// NEVER throws — a gesture that crashes the home screen is unforgivable.
  bool performGlobalAction(String action);

  /// Copy the CURRENT system wallpaper aside, once, before a theme first
  /// replaces it. Returns true when a stash now exists.
  ///
  /// Best effort by necessity: reading the wallpaper back has been progressively
  /// restricted (Android 13+ limits `getWallpaperFile` for apps that did not set
  /// it), so on some devices this simply cannot succeed. It returns false rather
  /// than throwing, and the Dart side hides "restore" instead of offering a
  /// button that would not work — a restore that silently fails is worse than no
  /// restore.
  @async
  bool stashWallpaper();

  /// Is there a stash to go back to? Drives whether the UI offers a restore.
  @async
  bool hasStashedWallpaper();

  /// Put the stashed wallpaper back on both home and lock, and drop the stash.
  /// False when there was nothing stashed or the write failed.
  @async
  bool restoreWallpaper();

  /// Deep-link into a real Android settings screen instead of reimplementing it.
  /// [action] is a Settings.ACTION_* string, e.g.
  /// "android.settings.APPLICATION_DETAILS_SETTINGS".
  ///
  /// Reimplementing OS settings screens is how launchers rot: the OEM changes
  /// something and your copy is quietly wrong forever.
  void openAndroidSettings(String action);
}

// ─── FLUTTER API (Kotlin calls, Dart implements) ─────────────────────────────

/// Implemented in Dart by `AppList`. Native pushes the *full* list on every
/// change (install / uninstall / update / suspend / profile switch) and Dart
/// swaps it wholesale — no deltas, no merge logic, no way to drift out of sync
/// with the system.
@FlutterApi()
abstract class LauncherFlutterApi {
  void onAppsChanged(AppChangeEvent event);
}
