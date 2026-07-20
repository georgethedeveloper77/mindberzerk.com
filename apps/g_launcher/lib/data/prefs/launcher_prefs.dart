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
    this.workspaceCount,
    this.verboseBoot,
    this.iconSizeDp,
    this.iconTreatment,
    this.cornerRadius,
    this.labelLines,
    this.textScale,
    this.gestures = const {},
    this.hiddenApps = const {},
    this.favourites = const [],
    this.homeItems = const [],
    this.folders = const [],
    this.drawerFolders = const [],
    this.dismissedSuggestions = const {},
    this.folderCols,
    this.folderRows,
    this.folderShape,
    this.folderOrderCustom,
    this.wallpapers = const [],
    this.wallpaperLock,
    this.wallpaperRotationMinutes,
    this.wallpaperInitialized = false,
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

  LauncherPrefs copyWith({
    String? dockSide,
    String? dockGridButton,
    bool? topBar,
    int? rows,
    int? cols,
    int? drawerCols,
    String? drawerSearchPosition,
    String? drawerScrollStyle,
    int? workspaceCount,
    bool? verboseBoot,
    double? iconSizeDp,
    String? iconTreatment,
    double? cornerRadius,
    int? labelLines,
    double? textScale,
    Map<String, String>? gestures,
    Set<String>? hiddenApps,
    List<String>? favourites,
    List<HomeItem>? homeItems,
    List<AppFolder>? folders,
    List<AppFolder>? drawerFolders,
    Set<String>? dismissedSuggestions,
    int? folderCols,
    int? folderRows,
    String? folderShape,
    bool? folderOrderCustom,
    List<String>? wallpapers,
    bool? wallpaperLock,
    int? wallpaperRotationMinutes,
    bool? wallpaperInitialized,
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
      workspaceCount: workspaceCount ?? this.workspaceCount,
      verboseBoot: verboseBoot ?? this.verboseBoot,
      iconSizeDp: iconSizeDp ?? this.iconSizeDp,
      iconTreatment: iconTreatment ?? this.iconTreatment,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      labelLines: labelLines ?? this.labelLines,
      textScale: textScale ?? this.textScale,
      gestures: gestures ?? this.gestures,
      hiddenApps: hiddenApps ?? this.hiddenApps,
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
      wallpaperRotationMinutes:
          wallpaperRotationMinutes ?? this.wallpaperRotationMinutes,
      wallpaperInitialized: wallpaperInitialized ?? this.wallpaperInitialized,
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
    bool folderCols = false,
    bool folderRows = false,
    bool folderShape = false,
    bool folderOrderCustom = false,
    bool workspaceCount = false,
    bool verboseBoot = false,
    bool iconSizeDp = false,
    bool iconTreatment = false,
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
      workspaceCount: workspaceCount ? null : this.workspaceCount,
      verboseBoot: verboseBoot ? null : this.verboseBoot,
      iconSizeDp: iconSizeDp ? null : this.iconSizeDp,
      iconTreatment: iconTreatment ? null : this.iconTreatment,
      cornerRadius: cornerRadius ? null : this.cornerRadius,
      labelLines: labelLines ? null : this.labelLines,
      textScale: textScale ? null : this.textScale,
      gestures: gestures,
      hiddenApps: hiddenApps,
      favourites: favourites,
      homeItems: homeItems,
      folders: folders,
      drawerFolders: drawerFolders,
      dismissedSuggestions: dismissedSuggestions,
      folderCols: folderCols ? null : this.folderCols,
      folderRows: folderRows ? null : this.folderRows,
      folderShape: folderShape ? null : this.folderShape,
      folderOrderCustom:
          folderOrderCustom ? null : this.folderOrderCustom,
      wallpapers: wallpapers,
      wallpaperLock: wallpaperLock,
      wallpaperRotationMinutes: wallpaperRotationMinutes,
      wallpaperInitialized: wallpaperInitialized,
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
        if (drawerSearchPosition != null)
          'drawerSearchPosition': drawerSearchPosition,
        if (workspaceCount != null) 'workspaceCount': workspaceCount,
        if (verboseBoot != null) 'verboseBoot': verboseBoot,
        if (iconSizeDp != null) 'iconSizeDp': iconSizeDp,
        if (iconTreatment != null) 'iconTreatment': iconTreatment,
        if (cornerRadius != null) 'cornerRadius': cornerRadius,
        if (labelLines != null) 'labelLines': labelLines,
        if (textScale != null) 'textScale': textScale,
        'gestures': gestures,
        'hiddenApps': hiddenApps.toList(),
        'favourites': favourites,
        'homeItems': homeItems.map((e) => e.toJson()).toList(),
        'folders': folders.map((e) => e.toJson()).toList(),
        'drawerFolders': drawerFolders.map((e) => e.toJson()).toList(),
        'dismissedSuggestions': dismissedSuggestions.toList(),
        if (folderCols != null) 'folderCols': folderCols,
        if (folderRows != null) 'folderRows': folderRows,
        if (folderShape != null) 'folderShape': folderShape,
        if (folderOrderCustom != null) 'folderOrderCustom': folderOrderCustom,
        'wallpapers': wallpapers,
        if (wallpaperLock != null) 'wallpaperLock': wallpaperLock,
        if (wallpaperRotationMinutes != null)
          'wallpaperRotationMinutes': wallpaperRotationMinutes,
        'wallpaperInitialized': wallpaperInitialized,
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
      workspaceCount: (j['workspaceCount'] as num?)?.toInt(),
      verboseBoot: j['verboseBoot'] as bool?,
      iconSizeDp: (j['iconSizeDp'] as num?)?.toDouble(),
      iconTreatment: j['iconTreatment'] as String?,
      cornerRadius: (j['cornerRadius'] as num?)?.toDouble(),
      labelLines: (j['labelLines'] as num?)?.toInt(),
      textScale: (j['textScale'] as num?)?.toDouble(),
      gestures: ((j['gestures'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k as String, v as String)),
      hiddenApps: ((j['hiddenApps'] as List?) ?? const [])
          .map((e) => e as String)
          .toSet(),
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
      wallpaperRotationMinutes:
          (j['wallpaperRotationMinutes'] as num?)?.toInt(),
      wallpaperInitialized: j['wallpaperInitialized'] as bool? ?? false,
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
        other.workspaceCount == workspaceCount &&
        other.verboseBoot == verboseBoot &&
        other.iconSizeDp == iconSizeDp &&
        other.iconTreatment == iconTreatment &&
        other.cornerRadius == cornerRadius &&
        other.labelLines == labelLines &&
        other.textScale == textScale &&
        const MapEquality<String, String>().equals(other.gestures, gestures) &&
        const SetEquality<String>().equals(other.hiddenApps, hiddenApps) &&
        const ListEquality<String>().equals(other.favourites, favourites) &&
        const ListEquality<HomeItem>().equals(other.homeItems, homeItems) &&
        const ListEquality<AppFolder>().equals(other.folders, folders) &&
        const ListEquality<AppFolder>()
            .equals(other.drawerFolders, drawerFolders) &&
        const SetEquality<String>()
            .equals(other.dismissedSuggestions, dismissedSuggestions) &&
        other.folderCols == folderCols &&
        other.folderRows == folderRows &&
        other.folderShape == folderShape &&
        other.folderOrderCustom == folderOrderCustom &&
        const ListEquality<String>().equals(other.wallpapers, wallpapers) &&
        other.wallpaperLock == wallpaperLock &&
        other.wallpaperRotationMinutes == wallpaperRotationMinutes &&
        other.wallpaperInitialized == wallpaperInitialized;
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
        workspaceCount,
        verboseBoot,
        iconSizeDp,
        iconTreatment,
        cornerRadius,
        labelLines,
        textScale,
        const MapEquality<String, String>().hash(gestures),
        const SetEquality<String>().hash(hiddenApps),
        const ListEquality<String>().hash(favourites),
        const ListEquality<HomeItem>().hash(homeItems),
        const ListEquality<AppFolder>().hash(folders),
        const ListEquality<AppFolder>().hash(drawerFolders),
        const SetEquality<String>().hash(dismissedSuggestions),
        folderCols,
        folderRows,
        folderShape,
        const ListEquality<String>().hash(wallpapers),
        wallpaperLock,
        wallpaperRotationMinutes,
        wallpaperInitialized,
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
