import 'package:collection/collection.dart';

import 'launcher_prefs.dart';

/// Settings that belong to THE LAUNCHER rather than to a distro.
///
/// ─── WHY THIS EXISTS ────────────────────────────────────────────────────────
///
/// [LauncherPrefs] is stored per theme (`prefs.v1.<themeId>`), and for most of
/// it that is exactly right: Ubuntu's dock is on the left because Ubuntu's dock
/// is on the left, and KDE's is at the bottom for the same kind of reason. Those
/// are properties of the distro being imitated.
///
/// Icon shape is not. Nor is label length, text scale, or how big a folder's
/// grid is. Those are properties of the PERSON. Storing them per theme meant a
/// user who had set circular icons and two-line labels got neither the moment
/// they tried Plasma, then had to set them again, and again for the next distro,
/// and would reasonably conclude the settings did not save.
///
/// So a fixed list of fields is PROMOTED out of the per-theme store into one
/// global bucket. The list is [_promoted] below and it is the only place the
/// split is written down.
///
/// ─── WHAT null MEANS, AND WHY IT IS UNCHANGED ───────────────────────────────
///
/// A promoted field that is null in this bucket means "the user has expressed no
/// preference", which falls through to the distro's own default exactly as a
/// null per-theme field always has. Nothing about the resolver changes: the
/// merge happens on the way OUT of storage, so `EffectiveTheme.resolve` receives
/// a [LauncherPrefs] of the same shape it always did and cannot tell the
/// difference. That is the whole reason this is a storage-layer change rather
/// than a rewrite of every read site.
///
/// ─── THE SHELL CLAMP IS STRUCTURAL, NOT A RULE ──────────────────────────────
///
/// `drawerScrollStyle` and `drawerGrouping` are promoted even though not every
/// distro can honour them: Plasma's Kickoff is a list and the tiling launcher is
/// a prompt, so neither has pages to cube. That needs no clamping code, because
/// neither widget reads those fields. A global preference for cube pages applies
/// wherever there is a paged grid to apply it to and is inert elsewhere, which
/// is the honest behaviour and costs nothing to maintain.
class GlobalPrefs {
  const GlobalPrefs({
    this.iconSizeDp,
    this.iconTreatment,
    this.cornerRadius,
    this.systemIconPack,
    this.labelLines,
    this.textScale,
    this.folderCols,
    this.folderRows,
    this.folderShape,
    this.folderOrderCustom,
    this.drawerSearchPosition,
    this.drawerScrollStyle,
    this.drawerGrouping,
    this.workspaceCount,
    this.hiddenAppsSearchable,
    this.themeMode,
  });

  // ── ICONS ─────────────────────────────────────────────────────────────────
  // Shape, size and corner rounding are the user's taste. `iconPackId` is NOT
  // here: that names theme content shipped with a distro, so it stays per
  // theme. `systemIconPack` is here because it names an APK installed on this
  // phone, which no distro has an opinion about.
  final double? iconSizeDp;
  final String? iconTreatment;
  final double? cornerRadius;
  final String? systemIconPack;

  // ── TYPE ──────────────────────────────────────────────────────────────────
  final int? labelLines;
  final double? textScale;

  // ── FOLDERS ───────────────────────────────────────────────────────────────
  final int? folderCols;
  final int? folderRows;
  final String? folderShape;
  final bool? folderOrderCustom;

  // ── DRAWER BEHAVIOUR ──────────────────────────────────────────────────────
  // Behaviour, not authenticity. The grid's own density (`drawerCols`) and the
  // dock's side stay per theme, because those are the things that make a distro
  // recognisable.
  final String? drawerSearchPosition;
  final String? drawerScrollStyle;
  final String? drawerGrouping;

  // ── DESKTOP ───────────────────────────────────────────────────────────────
  final int? workspaceCount;

  // ── PRIVACY ───────────────────────────────────────────────────────────────
  // Whether a hidden app can be reached by typing its whole name. The hidden
  // SET stays per theme (hiding an app in Ubuntu must not hide it in KDE); this
  // is the rule applied to whichever set is live.
  final bool? hiddenAppsSearchable;

  // ── APPEARANCE ────────────────────────────────────────────────────────────
  // 'system' | 'light' | 'dark'. The most obviously global setting in the list:
  // a user who wants a light phone wants a light phone, whichever desktop they
  // are wearing. Set at setup and changeable in Settings under Appearance.
  final String? themeMode;

  /// Read the promoted fields off a [LauncherPrefs].
  ///
  /// Used for the one-time migration and for splitting an edit.
  factory GlobalPrefs.from(LauncherPrefs p) => GlobalPrefs(
        iconSizeDp: p.iconSizeDp,
        iconTreatment: p.iconTreatment,
        cornerRadius: p.cornerRadius,
        systemIconPack: p.systemIconPack,
        labelLines: p.labelLines,
        textScale: p.textScale,
        folderCols: p.folderCols,
        folderRows: p.folderRows,
        folderShape: p.folderShape,
        folderOrderCustom: p.folderOrderCustom,
        drawerSearchPosition: p.drawerSearchPosition,
        drawerScrollStyle: p.drawerScrollStyle,
        drawerGrouping: p.drawerGrouping,
        workspaceCount: p.workspaceCount,
        hiddenAppsSearchable: p.hiddenAppsSearchable,
        themeMode: p.themeMode,
      );

  /// Overlay these values onto [p], replacing whatever the per-theme store held
  /// for the promoted fields, INCLUDING with null.
  ///
  /// Two steps, and both are necessary. `copyWith` cannot write null, so a
  /// global field the user has never set would leave a stale per-theme value in
  /// place, which is precisely the state this class exists to abolish. So the
  /// nulls are cleared first and the values applied second.
  LauncherPrefs applyTo(LauncherPrefs p) {
    final cleared = p.clearing(
      iconSizeDp: iconSizeDp == null,
      iconTreatment: iconTreatment == null,
      cornerRadius: cornerRadius == null,
      systemIconPack: systemIconPack == null,
      labelLines: labelLines == null,
      textScale: textScale == null,
      folderCols: folderCols == null,
      folderRows: folderRows == null,
      folderShape: folderShape == null,
      folderOrderCustom: folderOrderCustom == null,
      drawerSearchPosition: drawerSearchPosition == null,
      drawerScrollStyle: drawerScrollStyle == null,
      drawerGrouping: drawerGrouping == null,
      workspaceCount: workspaceCount == null,
      hiddenAppsSearchable: hiddenAppsSearchable == null,
      themeMode: themeMode == null,
    );

    return cleared.copyWith(
      iconSizeDp: iconSizeDp,
      iconTreatment: iconTreatment,
      cornerRadius: cornerRadius,
      systemIconPack: systemIconPack,
      labelLines: labelLines,
      textScale: textScale,
      folderCols: folderCols,
      folderRows: folderRows,
      folderShape: folderShape,
      folderOrderCustom: folderOrderCustom,
      drawerSearchPosition: drawerSearchPosition,
      drawerScrollStyle: drawerScrollStyle,
      drawerGrouping: drawerGrouping,
      workspaceCount: workspaceCount,
      hiddenAppsSearchable: hiddenAppsSearchable,
      themeMode: themeMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        if (iconSizeDp != null) 'iconSizeDp': iconSizeDp,
        if (iconTreatment != null) 'iconTreatment': iconTreatment,
        if (cornerRadius != null) 'cornerRadius': cornerRadius,
        if (systemIconPack != null) 'systemIconPack': systemIconPack,
        if (labelLines != null) 'labelLines': labelLines,
        if (textScale != null) 'textScale': textScale,
        if (folderCols != null) 'folderCols': folderCols,
        if (folderRows != null) 'folderRows': folderRows,
        if (folderShape != null) 'folderShape': folderShape,
        if (folderOrderCustom != null) 'folderOrderCustom': folderOrderCustom,
        if (drawerSearchPosition != null)
          'drawerSearchPosition': drawerSearchPosition,
        if (drawerScrollStyle != null) 'drawerScrollStyle': drawerScrollStyle,
        if (drawerGrouping != null) 'drawerGrouping': drawerGrouping,
        if (workspaceCount != null) 'workspaceCount': workspaceCount,
        if (hiddenAppsSearchable != null)
          'hiddenAppsSearchable': hiddenAppsSearchable,
        if (themeMode != null) 'themeMode': themeMode,
      };

  factory GlobalPrefs.fromJson(Map<String, dynamic> j) => GlobalPrefs(
        iconSizeDp: (j['iconSizeDp'] as num?)?.toDouble(),
        iconTreatment: j['iconTreatment'] as String?,
        cornerRadius: (j['cornerRadius'] as num?)?.toDouble(),
        systemIconPack: j['systemIconPack'] as String?,
        labelLines: (j['labelLines'] as num?)?.toInt(),
        textScale: (j['textScale'] as num?)?.toDouble(),
        folderCols: (j['folderCols'] as num?)?.toInt(),
        folderRows: (j['folderRows'] as num?)?.toInt(),
        folderShape: j['folderShape'] as String?,
        folderOrderCustom: j['folderOrderCustom'] as bool?,
        drawerSearchPosition: j['drawerSearchPosition'] as String?,
        drawerScrollStyle: j['drawerScrollStyle'] as String?,
        drawerGrouping: j['drawerGrouping'] as String?,
        workspaceCount: (j['workspaceCount'] as num?)?.toInt(),
        hiddenAppsSearchable: j['hiddenAppsSearchable'] as bool?,
        themeMode: j['themeMode'] as String?,
      );

  /// Its own version, independent of [LauncherPrefs.schemaVersion]: this bucket
  /// can grow a field without implying anything about the per-theme file.
  static const int schemaVersion = 1;

  /// Value equality, and it is load-bearing for the same reason it is on
  /// [LauncherPrefs]: `prefsProvider` rebuilds when this changes, and identity
  /// equality would mean every read looked like a change.
  @override
  bool operator ==(Object other) =>
      other is GlobalPrefs &&
      const DeepCollectionEquality().equals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll([
        iconSizeDp,
        iconTreatment,
        cornerRadius,
        systemIconPack,
        labelLines,
        textScale,
        folderCols,
        folderRows,
        folderShape,
        folderOrderCustom,
        drawerSearchPosition,
        drawerScrollStyle,
        drawerGrouping,
        workspaceCount,
        hiddenAppsSearchable,
        themeMode,
      ]);
}

/// Did any PROMOTED field change between these two?
///
/// This is what routes a write. `PrefsNotifier.edit` hands a mutation function
/// the merged prefs and gets a new object back; it has no idea which field the
/// caller touched, and it does not need to. If the promoted fields differ, the
/// global bucket is written; the rest goes to the theme's own file. One
/// comparison, so a settings row keeps calling `copyWith` exactly as it always
/// has and lands in the right place without knowing there are two places.
bool promotedChanged(LauncherPrefs before, LauncherPrefs after) =>
    GlobalPrefs.from(before) != GlobalPrefs.from(after);
