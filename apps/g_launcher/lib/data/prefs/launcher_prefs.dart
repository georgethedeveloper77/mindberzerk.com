import 'package:collection/collection.dart';

import '../../platform/launcher_api.g.dart' as api;

/// User overrides for ONE theme.
///
/// The rule from plan §5.3: the theme provides defaults, the user's choices
/// always win, and they are stored PER THEME — so switching Ubuntu → KDE → back
/// to Ubuntu returns you to your Ubuntu setup rather than wiping it.
///
/// That is why nearly every field here is nullable. **null means "inherit from
/// the theme"**, and it is not the same as a default value. If [cols] were
/// non-null with a default of 4, then a theme that ships a 5-column grid would
/// be silently overridden by a preference the user never set. Nullable is the
/// whole design.
class LauncherPrefs {
  const LauncherPrefs({
    this.dockSide,
    this.dockGridButton,
    this.topBar,
    this.rows,
    this.cols,
    this.drawerCols,
    this.drawerSearchPosition,
    this.drawerScrollStyle,
    this.drawerGrouping,
    this.workspaceCount,
    this.verboseBoot,
    this.iconSizeDp,
    this.iconTreatment,
    this.iconPackId,
    this.systemIconPack,
    this.cornerRadius,
    this.labelLines,
    this.textScale,
    this.gestures = const {},
    this.hiddenApps = const {},
    this.hiddenAppsSearchable,
    this.favourites = const [],
    this.homeItems = const [],
    this.folders = const [],
    this.drawerFolders = const [],
    this.desklets = const [],
    this.dismissedSuggestions = const {},
    this.folderCols,
    this.folderRows,
    this.folderShape,
    this.folderOrderCustom,
    this.wallpapers = const [],
    this.wallpaperLock,
    this.wallpaperCurrent,
    this.wallpaperRotationMinutes,
    this.wallpaperInitialized = false,
    this.deskletsInitialized = false,
  });

  /// Bumped when the JSON shape changes incompatibly. Read it before parsing;
  /// an unknown future version should reset to defaults, not throw on the home
  /// screen.
  ///
  /// Still 1: `dockGridButton` and `workspaceCount` are additive and `fromJson`
  /// tolerates their absence, so old prefs files parse unchanged. Additive
  /// fields never bump the schema.
  static const int schemaVersion = 1;

  // --- layout (null = inherit from ThemeSpec) ---
  final String? dockSide; // 'left' | 'bottom' | 'off'

  /// Where the Activities grid button sits in the dock.
  /// 'start' | 'end' | 'off'. null = theme decides (Ubuntu: 'end').
  ///
  /// Exists because the grid button is the most-tapped thing in the dock, and
  /// the far end of a tall left dock is a stretch on a big phone.
  final String? dockGridButton;

  final bool? topBar;
  final int? rows;
  final int? cols;

  /// The drawer is denser than home by convention — more columns, smaller
  /// icons. Separate from [cols] because tying them together means widening the
  /// drawer also thins out your home screen, which nobody wants.
  final int? drawerCols;

  /// Where the drawer's search field sits: 'top' | 'bottom'. null = the theme
  /// decides, and the grid drawers resolve that to 'bottom' (thumb-reachable,
  /// matching the One UI search page); a theme may pin it to 'top' for an
  /// authentic GNOME feel. Only the grid drawers (GNOME, KDE, macOS) read this.
  /// Tiling and TUI own their own input placement and ignore it.
  final String? drawerSearchPosition;

  /// How the drawer moves: 'vertical' (null, the default), 'pages', or 'cube'.
  ///
  /// Vertical is one long scroll — what every Android drawer does, and what
  /// nobody notices. Pages and cube are paged; the cube is the old
  /// Nova/CyanogenMod rotation. Both are pure transforms over already-built
  /// pages, so they cost nothing at runtime — and they are the kind of thing
  /// people screenshot, which is what makes them worth having at all.
  final String? drawerScrollStyle;

  /// How the drawer's app list is GROUPED. null | 'none' | 'az'.
  ///
  /// ─── WHY THIS IS NOT A FOURTH drawerScrollStyle VALUE ──────────────────
  ///
  /// It was going to be, and that would have been a bug in the settings UI
  /// rather than in the code. A-to-Z means letter headers, and letter headers
  /// need a continuous scroll to sit in: there is nowhere to put "M" on a page
  /// that turns. So as a fourth value of drawerScrollStyle, picking 'az' would
  /// have had to silently mean "and also stop being paged", and two of the
  /// four options in one row would have quietly disabled each other.
  ///
  /// Grouping is therefore ORTHOGONAL to layout, and only meaningful when
  /// drawerScrollStyle is the list. Settings hides this row otherwise.
  final String? drawerGrouping;

  /// How many vertical workspaces the desktop has, 1–5. null = default (3).
  ///
  /// Purely a user preference, not a themed default: the authentic empty
  /// desktop has no icons, so nothing in the ThemeSpec has an opinion about how
  /// many pages there should be. Stored per-theme all the same, so it rides the
  /// same reset/switch machinery as everything else.
  final int? workspaceCount;

  /// Play the full verbose boot log every time the shell opens, not only on
  /// first run. null = off (a quick splash instead). This is the geek toggle:
  /// leave it on for Arch, off for Ubuntu, and each theme remembers, because it
  /// rides the same per-theme store as every other override.
  final bool? verboseBoot;

  final double? iconSizeDp;

  // --- icons ---
  /// The user's shape choice. Overrides the theme's treatment entirely.
  final String? iconTreatment; // matches api.IconTreatment names

  /// The hero icon pack to draw with, overriding the theme's own `heroPack`.
  /// null = the theme decides, which is the out-of-box behaviour.
  ///
  /// ─── WHY THIS EXISTS AS A SEPARATE SETTING ────────────────────────────────
  ///
  /// Because icon packs are sold separately from distros. `icons_pop_cosmic` is
  /// its own Play product precisely so someone can run the Kali desktop with
  /// Pop!_OS icons, and `ThemeSpec.icons.heroPack` cannot express that: it is
  /// authored by whoever made the theme, so buying an icon pack would do
  /// nothing until the theme's author happened to name it. A pack that cannot
  /// be applied is a refund.
  ///
  /// PER-THEME, like everything else in this file, and that is the right shape
  /// rather than an accident of where it landed. "Kali desktop, Pop icons" is a
  /// statement about the Kali desktop; switching to Garuda and back should
  /// return you to it, not carry it along.
  ///
  /// This is an id, NOT a path. `EffectiveTheme.resolve` substitutes it into the
  /// `IconStyle` it hands native, and it MUST also be folded into
  /// `iconCacheId` — a change to the pack that does not change the cache key is
  /// invisible: the correct icons render once for anything not already cached
  /// and every previously-seen app keeps its old bitmap forever. That failure
  /// looks exactly like the setting being unwired, which is why it costs a day
  /// to find.
  final String? iconPackId;

  /// A THIRD-PARTY icon pack installed as its own APK: Icon Pack Studio
  /// exports, and every Nova/ADW-format pack on Play. Null = none.
  ///
  /// ─── NOT THE SAME FIELD AS [iconPackId], AND NOT A DUPLICATE ──────────────
  ///
  /// [iconPackId] names a hero pack that arrived over the CDN: content this
  /// ecosystem authored, signed and possibly sold. This names an APK that
  /// happens to be installed on this one device and was authored by a stranger.
  /// They resolve through completely different code (one is `IconStyle.heroPack`
  /// handed to the renderer, the other is `IconPackResolver` reading another
  /// app's resources), and a user can reasonably have both — a pack from Play
  /// for the apps it covers, the distro's hero art for the rest.
  ///
  /// ─── WHY IT IS NOT IN [api.IconStyle] ─────────────────────────────────────
  ///
  /// IconStyle is theme CONTENT: it is authored in a theme.json and delivered
  /// over the CDN. No distro could fill this in even if it wanted to, because
  /// the answer is a package name that exists on one phone. It is pushed to
  /// native separately, by `setIconPack`.
  ///
  /// PER-THEME, like everything else in this file, and deliberately the same
  /// scoping as [iconPackId]. Two icon-pack settings with opposite scope would
  /// be genuinely confusing, and "Ubuntu with Yaru, Kali with Whicons" is a
  /// reasonable thing to want.
  final String? systemIconPack;

  final double? cornerRadius;

  // --- labels ---
  /// 1 or 2. Two lines lets long app names wrap instead of "Secure Fold…".
  final int? labelLines;
  final double? textScale;

  // --- gestures ---
  /// gestureId -> binding. A binding is a GestureAction id, or "app:<key>".
  /// Unset gestures fall back to defaultGestures — including the v1
  /// double-tap-left-edge, which existing users have in muscle memory.
  final Map<String, String> gestures;

  // --- content ---
  final Set<String> hiddenApps; // componentKeys

  /// Whether a hidden app may still be reached by TYPING ITS WHOLE NAME.
  ///
  /// null means the default, which is `true` — see `HiddenApps.searchable`, the
  /// one place that decision is written down. Hiding is "off my drawer", not
  /// "uninstalled", so the app stays launchable for the person who knows it is
  /// there; turning this off is the stronger promise, that the name produces
  /// nothing at all.
  ///
  /// Per theme like [hiddenApps] itself, because the two only make sense
  /// together: a hidden set with a global search rule would mean hiding an app
  /// in Ubuntu quietly changed how KDE's search behaved.
  final bool? hiddenAppsSearchable;

  /// The dock's pinned apps, in dock order.
  ///
  /// **Empty is meaningful.** Empty means "the user has never arranged the
  /// dock", and the dock shows their most-used apps instead. The moment one app
  /// is pinned, the dock is theirs and stops moving on its own. See
  /// `HomeLayout.dockKeys`.
  final List<String> favourites; // componentKeys, dock order

  final List<HomeItem> homeItems;
  final List<AppFolder> folders;

  /// Folders the user built IN THE DRAWER by dragging one app onto another.
  ///
  /// Separate from [folders], which is home-screen folders living in slots. The
  /// drawer has no slots, so its folders have their own rules (see
  /// `DrawerLayout`) and their own storage — merging in the drawer must not
  /// rearrange the home screen, and vice versa.
  final List<AppFolder> drawerFolders;

  /// Desklets placed on the desktop, across every workspace.
  ///
  /// PHASE D2. Additive, so [schemaVersion] stays 1 and an older prefs file
  /// parses unchanged as "no desklets", which is what every existing user has.
  ///
  /// FLAT, WITH `page` ON THE RECORD — the same shape [homeItems] already uses,
  /// and for the same three reasons:
  ///   * per-workspace content needs no new container type
  ///   * dropping the workspace count from 5 to 2 HIDES pages 3-5 rather than
  ///     destroying what is on them, because nothing prunes by page
  ///   * raising it back restores them intact
  ///
  /// Order is meaningful ONLY on the pane surface (the terminal shell), where
  /// desklets are command output in sequence rather than cards on a grid. On a
  /// grid surface the order is irrelevant and `col`/`row` carry the position.
  final List<Desklet> desklets;

  /// Folder suggestions the user said no to, by suggestion id.
  ///
  /// Without this, "ignore" means "ask me again on every rebuild", which is how
  /// a helpful suggestion turns into nagging. Accepting needs no such record:
  /// an accepted suggestion becomes a real folder, its members are then folded,
  /// and the suggester skips folded apps — so it cannot propose the same group
  /// twice.
  final Set<String> dismissedSuggestions;

  /// Columns inside an OPEN folder. null = 4.
  ///
  /// Separate from [drawerCols] on purpose: a folder holds a handful of apps in
  /// a sheet, the drawer holds two hundred on a full screen. Tying them together
  /// means widening the drawer squeezes every folder, which is not what anyone
  /// asked for.
  final int? folderCols;

  /// Rows of a folder visible before it scrolls. null = 3.
  final int? folderRows;

  /// The folder tile's shape: 'roundedSquare' | 'circle' | 'squircle' | 'square'.
  /// null = follow the theme's icon treatment, so a folder looks like the icons
  /// around it without the user setting anything.
  final String? folderShape;

  /// Has the user dragged folders into their own order?
  ///
  /// null/false = alphabetical, which is the right default: a folder you just
  /// named lands where its name says it should, and you can find it. Once you
  /// reorder ANYTHING, [drawerFolders] becomes the order of record and we stop
  /// re-sorting behind you — otherwise the next rename would silently undo the
  /// arrangement you just made.
  final bool? folderOrderCustom;

  // --- wallpaper ---
  /// Content URIs the user added, on top of the theme's presets.
  final List<String> wallpapers;

  /// Also set this theme's wallpaper on the LOCK screen. null = home only.
  ///
  /// Off by default, deliberately. The lock screen is the one surface a user
  /// sees before they have decided to use their phone, and silently replacing it
  /// because they tried a launcher theme is a step further than they asked for.
  /// Opt in, per theme, like everything else here.
  final bool? wallpaperLock;

  /// The wallpaper currently chosen FOR THIS THEME, as an unencoded source.
  ///
  /// ─── WHY THIS HAD TO EXIST ─────────────────────────────────────────────
  ///
  /// Android's wallpaper is ONE GLOBAL SETTING, but this launcher's prefs are
  /// per theme. Nothing recorded which wallpaper belonged to which distro, so
  /// switching Ubuntu to KDE and back left KDE's wallpaper on screen under
  /// Ubuntu's palette, with nothing to put back.
  ///
  /// The old `wallpaperInitialized` flag could not fix that: it answers "has
  /// this theme ever applied one", which is true for both themes by the second
  /// switch, so the re-apply was skipped exactly when it was needed.
  ///
  /// Null means this theme has no user choice yet, and its own first preset is
  /// used instead.
  final String? wallpaperCurrent;

  /// null = no rotation. Android's WorkManager floor is 15 minutes; anything
  /// smaller is silently clamped, so do not offer "every 5 minutes" in the UI
  /// and quietly lie.
  final int? wallpaperRotationMinutes;

  /// Has this theme's default wallpaper been applied yet?
  ///
  /// Per-theme, and ONCE. Ubuntu applies Numbat the first time you use it; if
  /// you then pick your own photo and switch to KDE and back, Ubuntu must NOT
  /// stamp Numbat over your choice again. A theme that keeps resetting your
  /// wallpaper is a theme people uninstall.
  final bool wallpaperInitialized;

  /// Has this theme's STARTER DESKTOP been laid out yet?
  ///
  /// Per theme, and ONCE, for exactly the reason [wallpaperInitialized] is:
  /// choosing Arch should lay out a waybar-ish desktop the first time, and must
  /// never re-stamp it over an arrangement the user has since made. Removing
  /// every desklet is a legitimate arrangement, so "the list is empty" cannot
  /// stand in for this flag.
  final bool deskletsInitialized;

  LauncherPrefs copyWith({
    String? dockSide,
    String? dockGridButton,
    bool? topBar,
    int? rows,
    int? cols,
    int? drawerCols,
    String? drawerSearchPosition,
    String? drawerScrollStyle,
    String? drawerGrouping,
    int? workspaceCount,
    bool? verboseBoot,
    double? iconSizeDp,
    String? iconTreatment,
    String? iconPackId,
    String? systemIconPack,
    double? cornerRadius,
    int? labelLines,
    double? textScale,
    Map<String, String>? gestures,
    Set<String>? hiddenApps,
    bool? hiddenAppsSearchable,
    List<String>? favourites,
    List<HomeItem>? homeItems,
    List<AppFolder>? folders,
    List<AppFolder>? drawerFolders,
    List<Desklet>? desklets,
    Set<String>? dismissedSuggestions,
    int? folderCols,
    int? folderRows,
    String? folderShape,
    bool? folderOrderCustom,
    List<String>? wallpapers,
    bool? wallpaperLock,
    String? wallpaperCurrent,
    int? wallpaperRotationMinutes,
    bool? wallpaperInitialized,
    bool? deskletsInitialized,
  }) {
    return LauncherPrefs(
      dockSide: dockSide ?? this.dockSide,
      dockGridButton: dockGridButton ?? this.dockGridButton,
      topBar: topBar ?? this.topBar,
      rows: rows ?? this.rows,
      cols: cols ?? this.cols,
      drawerCols: drawerCols ?? this.drawerCols,
      drawerSearchPosition: drawerSearchPosition ?? this.drawerSearchPosition,
      drawerScrollStyle: drawerScrollStyle ?? this.drawerScrollStyle,
      drawerGrouping: drawerGrouping ?? this.drawerGrouping,
      workspaceCount: workspaceCount ?? this.workspaceCount,
      verboseBoot: verboseBoot ?? this.verboseBoot,
      iconSizeDp: iconSizeDp ?? this.iconSizeDp,
      iconTreatment: iconTreatment ?? this.iconTreatment,
      iconPackId: iconPackId ?? this.iconPackId,
      systemIconPack: systemIconPack ?? this.systemIconPack,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      labelLines: labelLines ?? this.labelLines,
      textScale: textScale ?? this.textScale,
      gestures: gestures ?? this.gestures,
      hiddenApps: hiddenApps ?? this.hiddenApps,
      hiddenAppsSearchable:
          hiddenAppsSearchable ?? this.hiddenAppsSearchable,
      favourites: favourites ?? this.favourites,
      homeItems: homeItems ?? this.homeItems,
      folders: folders ?? this.folders,
      drawerFolders: drawerFolders ?? this.drawerFolders,
      dismissedSuggestions: dismissedSuggestions ?? this.dismissedSuggestions,
      folderCols: folderCols ?? this.folderCols,
      folderRows: folderRows ?? this.folderRows,
      folderShape: folderShape ?? this.folderShape,
      folderOrderCustom: folderOrderCustom ?? this.folderOrderCustom,
      wallpapers: wallpapers ?? this.wallpapers,
      wallpaperLock: wallpaperLock ?? this.wallpaperLock,
      wallpaperCurrent: wallpaperCurrent ?? this.wallpaperCurrent,
      wallpaperRotationMinutes:
          wallpaperRotationMinutes ?? this.wallpaperRotationMinutes,
      desklets: desklets ?? this.desklets,
      wallpaperInitialized: wallpaperInitialized ?? this.wallpaperInitialized,
      deskletsInitialized: deskletsInitialized ?? this.deskletsInitialized,
    );
  }

  /// copyWith cannot clear a field to null — that is the classic Dart trap, and
  /// "reset this setting back to the theme default" is a thing users do.
  LauncherPrefs clearing({
    bool dockSide = false,
    bool dockGridButton = false,
    bool rows = false,
    bool cols = false,
    bool drawerCols = false,
    bool drawerSearchPosition = false,
    bool drawerScrollStyle = false,
    bool drawerGrouping = false,
    bool folderCols = false,
    bool folderRows = false,
    bool folderShape = false,
    bool folderOrderCustom = false,
    bool workspaceCount = false,
    bool verboseBoot = false,
    bool hiddenAppsSearchable = false,
    bool iconSizeDp = false,
    bool iconTreatment = false,
    bool iconPackId = false,
    bool systemIconPack = false,
    bool cornerRadius = false,
    bool labelLines = false,
    bool textScale = false,
  }) {
    return LauncherPrefs(
      dockSide: dockSide ? null : this.dockSide,
      dockGridButton: dockGridButton ? null : this.dockGridButton,
      topBar: topBar,
      rows: rows ? null : this.rows,
      cols: cols ? null : this.cols,
      drawerCols: drawerCols ? null : this.drawerCols,
      drawerSearchPosition:
          drawerSearchPosition ? null : this.drawerSearchPosition,
      // BUG FIX (D2): this line did not exist, so EVERY call to clearing() —
      // whatever it was clearing — silently reset the drawer scroll style back
      // to null. A field omitted from this method is not "left alone", it is
      // dropped, because the constructor defaults it.
      drawerScrollStyle:
          drawerScrollStyle ? null : this.drawerScrollStyle,
      drawerGrouping: drawerGrouping ? null : this.drawerGrouping,
      workspaceCount: workspaceCount ? null : this.workspaceCount,
      verboseBoot: verboseBoot ? null : this.verboseBoot,
      iconSizeDp: iconSizeDp ? null : this.iconSizeDp,
      iconTreatment: iconTreatment ? null : this.iconTreatment,
      iconPackId: iconPackId ? null : this.iconPackId,
      systemIconPack: systemIconPack ? null : this.systemIconPack,
      cornerRadius: cornerRadius ? null : this.cornerRadius,
      labelLines: labelLines ? null : this.labelLines,
      textScale: textScale ? null : this.textScale,
      gestures: gestures,
      hiddenApps: hiddenApps,
      hiddenAppsSearchable:
          hiddenAppsSearchable ? null : this.hiddenAppsSearchable,
      favourites: favourites,
      homeItems: homeItems,
      folders: folders,
      drawerFolders: drawerFolders,
      desklets: desklets,
      dismissedSuggestions: dismissedSuggestions,
      folderCols: folderCols ? null : this.folderCols,
      folderRows: folderRows ? null : this.folderRows,
      folderShape: folderShape ? null : this.folderShape,
      folderOrderCustom:
          folderOrderCustom ? null : this.folderOrderCustom,
      wallpapers: wallpapers,
      wallpaperLock: wallpaperLock,
      // Pass-through, not clearable. A field OMITTED from this method is
      // dropped rather than preserved, which is how drawerScrollStyle was
      // once silently reset by every unrelated clear.
      wallpaperCurrent: wallpaperCurrent,
      wallpaperRotationMinutes: wallpaperRotationMinutes,
      wallpaperInitialized: wallpaperInitialized,
      deskletsInitialized: deskletsInitialized,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        if (dockSide != null) 'dockSide': dockSide,
        if (dockGridButton != null) 'dockGridButton': dockGridButton,
        if (topBar != null) 'topBar': topBar,
        if (rows != null) 'rows': rows,
        if (cols != null) 'cols': cols,
        if (drawerCols != null) 'drawerCols': drawerCols,
        if (drawerScrollStyle != null) 'drawerScrollStyle': drawerScrollStyle,
        if (drawerGrouping != null) 'drawerGrouping': drawerGrouping,
        if (drawerSearchPosition != null)
          'drawerSearchPosition': drawerSearchPosition,
        if (workspaceCount != null) 'workspaceCount': workspaceCount,
        if (verboseBoot != null) 'verboseBoot': verboseBoot,
        if (iconSizeDp != null) 'iconSizeDp': iconSizeDp,
        if (iconTreatment != null) 'iconTreatment': iconTreatment,
        if (iconPackId != null) 'iconPackId': iconPackId,
        if (systemIconPack != null) 'systemIconPack': systemIconPack,
        if (cornerRadius != null) 'cornerRadius': cornerRadius,
        if (labelLines != null) 'labelLines': labelLines,
        if (textScale != null) 'textScale': textScale,
        'gestures': gestures,
        'hiddenApps': hiddenApps.toList(),
        if (hiddenAppsSearchable != null)
          'hiddenAppsSearchable': hiddenAppsSearchable,
        'favourites': favourites,
        'homeItems': homeItems.map((e) => e.toJson()).toList(),
        'folders': folders.map((e) => e.toJson()).toList(),
        'drawerFolders': drawerFolders.map((e) => e.toJson()).toList(),
        'desklets': desklets.map((e) => e.toJson()).toList(),
        'dismissedSuggestions': dismissedSuggestions.toList(),
        if (folderCols != null) 'folderCols': folderCols,
        if (folderRows != null) 'folderRows': folderRows,
        if (folderShape != null) 'folderShape': folderShape,
        if (folderOrderCustom != null) 'folderOrderCustom': folderOrderCustom,
        'wallpapers': wallpapers,
        if (wallpaperLock != null) 'wallpaperLock': wallpaperLock,
        if (wallpaperCurrent != null) 'wallpaperCurrent': wallpaperCurrent,
        if (wallpaperRotationMinutes != null)
          'wallpaperRotationMinutes': wallpaperRotationMinutes,
        'wallpaperInitialized': wallpaperInitialized,
        'deskletsInitialized': deskletsInitialized,
      };

  static LauncherPrefs fromJson(Map<String, dynamic> j) {
    // A prefs file written by a NEWER build. Resetting to defaults is ugly but
    // survivable; throwing here would black-screen the home screen after a
    // downgrade, which is not.
    final v = (j['schemaVersion'] as num?)?.toInt() ?? 0;
    if (v > schemaVersion) return const LauncherPrefs();

    return LauncherPrefs(
      dockSide: j['dockSide'] as String?,
      dockGridButton: j['dockGridButton'] as String?,
      topBar: j['topBar'] as bool?,
      rows: (j['rows'] as num?)?.toInt(),
      cols: (j['cols'] as num?)?.toInt(),
      drawerCols: (j['drawerCols'] as num?)?.toInt(),
      drawerSearchPosition: j['drawerSearchPosition'] as String?,
      drawerScrollStyle: j['drawerScrollStyle'] as String?,
      drawerGrouping: j['drawerGrouping'] as String?,
      workspaceCount: (j['workspaceCount'] as num?)?.toInt(),
      verboseBoot: j['verboseBoot'] as bool?,
      iconSizeDp: (j['iconSizeDp'] as num?)?.toDouble(),
      iconTreatment: j['iconTreatment'] as String?,
      iconPackId: j['iconPackId'] as String?,
      systemIconPack: j['systemIconPack'] as String?,
      cornerRadius: (j['cornerRadius'] as num?)?.toDouble(),
      labelLines: (j['labelLines'] as num?)?.toInt(),
      textScale: (j['textScale'] as num?)?.toDouble(),
      gestures: ((j['gestures'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k as String, v as String)),
      hiddenApps: ((j['hiddenApps'] as List?) ?? const [])
          .map((e) => e as String)
          .toSet(),
      hiddenAppsSearchable: j['hiddenAppsSearchable'] as bool?,
      favourites: ((j['favourites'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      homeItems: ((j['homeItems'] as List?) ?? const [])
          .map((e) => HomeItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      folders: ((j['folders'] as List?) ?? const [])
          .map((e) => AppFolder.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      drawerFolders: ((j['drawerFolders'] as List?) ?? const [])
          .map((e) => AppFolder.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      desklets: ((j['desklets'] as List?) ?? const [])
          .map((e) => Desklet.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      dismissedSuggestions: ((j['dismissedSuggestions'] as List?) ?? const [])
          .map((e) => e as String)
          .toSet(),
      folderCols: (j['folderCols'] as num?)?.toInt(),
      folderRows: (j['folderRows'] as num?)?.toInt(),
      folderShape: j['folderShape'] as String?,
      folderOrderCustom: j['folderOrderCustom'] as bool?,
      wallpapers: ((j['wallpapers'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      wallpaperLock: j['wallpaperLock'] as bool?,
      wallpaperCurrent: j['wallpaperCurrent'] as String?,
      wallpaperRotationMinutes:
          (j['wallpaperRotationMinutes'] as num?)?.toInt(),
      wallpaperInitialized: j['wallpaperInitialized'] as bool? ?? false,
      deskletsInitialized: j['deskletsInitialized'] as bool? ?? false,
    );
  }

  /// The user's shape choice, as the native enum. null = theme decides.
  api.IconTreatment? get treatmentEnum => switch (iconTreatment) {
        'circle' => api.IconTreatment.circle,
        'squircle' => api.IconTreatment.squircle,
        'roundedSquare' => api.IconTreatment.roundedSquare,
        'square' => api.IconTreatment.square,
        'teardrop' => api.IconTreatment.teardrop,
        'original' => api.IconTreatment.original,
        _ => null,
      };

  /// Value equality — this is what makes the `EffectiveTheme` `==` fix pay off.
  ///
  /// `EffectiveTheme` compares `prefs == prefs`, and it is the family key for the
  /// app-list providers. Without this, every new prefs INSTANCE (even one with
  /// identical values, e.g. a re-read from disk) reads as different and re-churns
  /// the app list. The collection fields need DEEP equality, so they go through
  /// `package:collection` rather than reference `==`.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LauncherPrefs &&
        other.dockSide == dockSide &&
        other.dockGridButton == dockGridButton &&
        other.topBar == topBar &&
        other.rows == rows &&
        other.cols == cols &&
        other.drawerCols == drawerCols &&
        other.drawerSearchPosition == drawerSearchPosition &&
        other.drawerScrollStyle == drawerScrollStyle &&
        other.drawerGrouping == drawerGrouping &&
        other.workspaceCount == workspaceCount &&
        other.verboseBoot == verboseBoot &&
        other.iconSizeDp == iconSizeDp &&
        other.iconTreatment == iconTreatment &&
        other.iconPackId == iconPackId &&
        other.systemIconPack == systemIconPack &&
        other.cornerRadius == cornerRadius &&
        other.labelLines == labelLines &&
        other.textScale == textScale &&
        const MapEquality<String, String>().equals(other.gestures, gestures) &&
        const SetEquality<String>().equals(other.hiddenApps, hiddenApps) &&
        other.hiddenAppsSearchable == hiddenAppsSearchable &&
        const ListEquality<String>().equals(other.favourites, favourites) &&
        const ListEquality<HomeItem>().equals(other.homeItems, homeItems) &&
        const ListEquality<AppFolder>().equals(other.folders, folders) &&
        const ListEquality<AppFolder>()
            .equals(other.drawerFolders, drawerFolders) &&
        const ListEquality<Desklet>().equals(other.desklets, desklets) &&
        const SetEquality<String>()
            .equals(other.dismissedSuggestions, dismissedSuggestions) &&
        other.folderCols == folderCols &&
        other.folderRows == folderRows &&
        other.folderShape == folderShape &&
        other.folderOrderCustom == folderOrderCustom &&
        const ListEquality<String>().equals(other.wallpapers, wallpapers) &&
        other.wallpaperLock == wallpaperLock &&
        other.wallpaperCurrent == wallpaperCurrent &&
        other.wallpaperRotationMinutes == wallpaperRotationMinutes &&
        other.wallpaperInitialized == wallpaperInitialized &&
        other.deskletsInitialized == deskletsInitialized;
  }

  @override
  int get hashCode => Object.hashAll([
        dockSide,
        dockGridButton,
        topBar,
        rows,
        cols,
        drawerCols,
        drawerSearchPosition,
        drawerScrollStyle,
        drawerGrouping,
        workspaceCount,
        verboseBoot,
        iconSizeDp,
        iconTreatment,
        iconPackId,
        systemIconPack,
        cornerRadius,
        labelLines,
        textScale,
        const MapEquality<String, String>().hash(gestures),
        const SetEquality<String>().hash(hiddenApps),
        hiddenAppsSearchable,
        const ListEquality<String>().hash(favourites),
        const ListEquality<HomeItem>().hash(homeItems),
        const ListEquality<AppFolder>().hash(folders),
        const ListEquality<AppFolder>().hash(drawerFolders),
        const ListEquality<Desklet>().hash(desklets),
        const SetEquality<String>().hash(dismissedSuggestions),
        folderCols,
        folderRows,
        folderShape,
        // BUG FIX (D2): folderOrderCustom was in operator== but missing here,
        // so two prefs differing only in it compared unequal yet hashed equal.
        // Legal, but the asymmetry is exactly what bites in a Set or a Map key.
        folderOrderCustom,
        const ListEquality<String>().hash(wallpapers),
        wallpaperLock,
        wallpaperCurrent,
        wallpaperRotationMinutes,
        wallpaperInitialized,
        deskletsInitialized,
      ]);
}

/// One slot on a home page. Either an app or a folder, never both.
class HomeItem {
  const HomeItem({
    required this.page,
    required this.index,
    this.componentKey,
    this.folderId,
  });

  final int page;
  final int index;
  final String? componentKey;
  final String? folderId;

  bool get isFolder => folderId != null;

  Map<String, dynamic> toJson() => {
        'page': page,
        'index': index,
        if (componentKey != null) 'componentKey': componentKey,
        if (folderId != null) 'folderId': folderId,
      };

  static HomeItem fromJson(Map<String, dynamic> j) => HomeItem(
        page: (j['page'] as num).toInt(),
        index: (j['index'] as num).toInt(),
        componentKey: j['componentKey'] as String?,
        folderId: j['folderId'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeItem &&
          other.page == page &&
          other.index == index &&
          other.componentKey == componentKey &&
          other.folderId == folderId;

  @override
  int get hashCode => Object.hash(page, index, componentKey, folderId);
}

class AppFolder {
  const AppFolder({
    required this.id,
    required this.name,
    this.members = const [],
  });

  final String id;
  final String name;
  final List<String> members; // componentKeys

  AppFolder copyWith({String? name, List<String>? members}) => AppFolder(
        id: id,
        name: name ?? this.name,
        members: members ?? this.members,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'members': members};

  static AppFolder fromJson(Map<String, dynamic> j) => AppFolder(
        id: j['id'] as String,
        name: j['name'] as String,
        members: ((j['members'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppFolder &&
          other.id == id &&
          other.name == name &&
          const ListEquality<String>().equals(other.members, members);

  @override
  int get hashCode =>
      Object.hash(id, name, const ListEquality<String>().hash(members));
}

/// One desklet placed on the desktop.
///
/// PHASE D2. "Desklet" and not "widget", deliberately: `Widget` already means
/// two things here (Flutter's, and Android's `AppWidget`), and a third meaning
/// in the same codebase guarantees a confusing hour later. Cinnamon calls these
/// desklets, KDE calls them plasmoids, and the Linux vocabulary happens to fit
/// the product.
///
/// ─── WHY col/row/span AND NOT A FLAT SLOT INDEX ─────────────────────────────
///
/// [HomeItem] uses a single `index` because an app occupies exactly one cell.
/// A desklet occupies a RECTANGLE, and a flat index cannot express one: a
/// 2x2 tile starting at index 7 covers 7, 8, and two cells a row below whose
/// indices depend on the column count, which changes per theme. So position is
/// (col, row) and size is (spanX, spanY), and every occupancy test is a
/// rectangle overlap.
///
/// ─── WHY kind IS A STRING ───────────────────────────────────────────────────
///
/// Same contract as `ShellKind.parse`, `brandTreatment` and `BootLineKind`: a
/// kind this build does not recognise must render as ABSENT, never crash and
/// NEVER be silently deleted. A CDN theme can offer a desklet a shipped APK has
/// never heard of, and an older app must round-trip that placement untouched so
/// it reappears after an update. An enum could not do that.
class Desklet {
  const Desklet({
    required this.id,
    required this.kind,
    required this.page,
    this.col = 0,
    this.row = 0,
    this.spanX = 1,
    this.spanY = 1,
    this.config = const {},
  });

  /// Stable across moves and resizes. Not derived from position, because the
  /// position is the thing that changes.
  final String id;

  /// Registry key, e.g. "clock", "monitor", "fastfetch". Unknown values survive
  /// a round trip and simply do not draw.
  final String kind;

  /// Which workspace. Same convention as [HomeItem.page].
  final int page;

  /// Top-left cell on the desktop grid.
  ///
  /// IGNORED ON THE PANE SURFACE (the terminal shell), where desklets are
  /// persistent command output in list order rather than positioned cards.
  /// Precisely the way `dockSide` is already ignored under the Aqua shell: the
  /// record is shared, the renderer is not.
  final int col;
  final int row;

  /// Size in cells, always >= 1. Clamped against the kind's limits AND the grid
  /// on every write; see `DeskletLayout`.
  final int spanX;
  final int spanY;

  /// Per-kind settings. FREE-FORM FROM DAY ONE, and that is a deliberate cost
  /// decision rather than laziness.
  ///
  /// Placements are persisted user data, so adding a typed field later is a
  /// migration and a schema bump; adding a key to an already-free-form map is
  /// nothing. The first two desklets need it immediately anyway (a clock wants
  /// `format` and `showSeconds`, a note is ENTIRELY config), so "add it when
  /// something needs it" resolves to "add it now".
  ///
  /// Validated and CLAMPED ON READ, never on write — the same rule
  /// `SplashSpec.durationMs` and `IconSizing.parseScale` follow. Unknown keys
  /// are ignored and absent keys fall to the kind's default, so a config key
  /// written by a newer build degrades instead of failing to parse.
  final Map<String, Object?> config;

  bool get isPointLike => spanX == 1 && spanY == 1;

  /// Half-open on both axes: a desklet at col 2 with spanX 2 covers 2 and 3,
  /// and [right] is 4. Off-by-one here is an overlap bug that only shows up as
  /// two tiles drawn on top of each other.
  int get right => col + spanX;
  int get bottom => row + spanY;

  bool overlaps(Desklet other) {
    if (other.page != page) return false;
    return col < other.right &&
        other.col < right &&
        row < other.bottom &&
        other.row < bottom;
  }

  Desklet copyWith({
    int? page,
    int? col,
    int? row,
    int? spanX,
    int? spanY,
    Map<String, Object?>? config,
  }) =>
      Desklet(
        id: id,
        kind: kind,
        page: page ?? this.page,
        col: col ?? this.col,
        row: row ?? this.row,
        spanX: spanX ?? this.spanX,
        spanY: spanY ?? this.spanY,
        config: config ?? this.config,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'page': page,
        'col': col,
        'row': row,
        'spanX': spanX,
        'spanY': spanY,
        // Omitted when empty: most desklets never carry config, and writing
        // `"config": {}` on every one of them bloats a file that is read on
        // every theme resolve.
        if (config.isNotEmpty) 'config': config,
      };

  /// Tolerant by design. A missing span or position reads as the safe minimum
  /// rather than throwing, because this parses content that may have been
  /// authored in an admin panel or shipped in a CDN starter desktop, and one
  /// bad field must not take the whole desktop down.
  static Desklet fromJson(Map<String, dynamic> j) => Desklet(
        id: j['id'] as String,
        kind: j['kind'] as String,
        page: (j['page'] as num?)?.toInt() ?? 0,
        col: (j['col'] as num?)?.toInt() ?? 0,
        row: (j['row'] as num?)?.toInt() ?? 0,
        spanX: (j['spanX'] as num?)?.toInt() ?? 1,
        spanY: (j['spanY'] as num?)?.toInt() ?? 1,
        config: ((j['config'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k as String, v as Object?)),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Desklet &&
          other.id == id &&
          other.kind == kind &&
          other.page == page &&
          other.col == col &&
          other.row == row &&
          other.spanX == spanX &&
          other.spanY == spanY &&
          const MapEquality<String, Object?>().equals(other.config, config);

  @override
  int get hashCode => Object.hash(
        id,
        kind,
        page,
        col,
        row,
        spanX,
        spanY,
        const MapEquality<String, Object?>().hash(config),
      );
}
