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
/// ─── SCHEMA 2 ADDED TWO ─────────────────────────────────────────────────────
///
/// `drawerSortMode`, which was simply missed, and `verboseBoot`, which was a
/// real decision with an argument on both sides. Both are documented at their
/// fields. Adding either meant bumping [schemaVersion] and writing a top-up,
/// for the reason spelled out there: this bucket's migration only fires on a
/// first run, so a field promoted without one is a setting silently lost.
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
    this.drawerSortMode,
    this.workspaceCount,
    this.verboseBoot,
    this.hiddenAppsSearchable,
    this.themeMode,
    this.surfaceOpacity,
    this.dockOpacity,
    this.drawerOpacity,
    this.barOpacity,
    this.panelOpacity,
    this.panelBlur,
    this.panelTint,
    this.panelRadius,
    this.badgeStyle,
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

  /// How the list is ordered: alphabetical, by usage, by install date.
  ///
  /// PROMOTED IN SCHEMA 2, and it was an oversight rather than a decision. It
  /// sat in `PrefsSection.drawer` beside `drawerGrouping` and
  /// `drawerScrollStyle`, both of which were already here, and no distro has an
  /// opinion about what order you like your apps in. Someone who sorts by usage
  /// means it everywhere.
  final String? drawerSortMode;

  // ── DESKTOP ───────────────────────────────────────────────────────────────
  final int? workspaceCount;

  // ── BOOT ──────────────────────────────────────────────────────────────────

  /// Play the full `[  OK  ]` log instead of the quick splash.
  ///
  /// PROMOTED IN SCHEMA 2, and this one is a genuine judgement rather than a
  /// missed field. The case against: the boot log is part of the imitation, not
  /// chrome, and wanting Arch to spew dmesg while Ubuntu comes up quietly is a
  /// coherent thing to want.
  ///
  /// The case for won because of what the alternative costs. Per theme, someone
  /// who finds six seconds of systemd tedious has to say so again on every
  /// distro they try, and trying distros is the entire product. A preference
  /// you have to re-state on each new thing you look at reads as a preference
  /// that did not save, which is exactly the complaint this bucket exists to
  /// answer. The per-distro version stays expressible in data: a theme that
  /// ships no `boot` block still gets its family default.
  final bool? verboseBoot;

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

  /// How solid the launcher's surfaces are. See [LauncherPrefs.surfaceOpacity]
  /// for the floor and why it exists.
  final double? surfaceOpacity;

  /// The per-section splits, promoted for the same reason the slider above is:
  /// how see-through you like your dock is a fact about you, not about Ubuntu.
  /// Each is null until deliberately split out and falls back to
  /// [surfaceOpacity], so promoting them changes nothing for anyone who has
  /// never touched them.
  final double? dockOpacity;
  final double? drawerOpacity;
  final double? barOpacity;

  /// Every floating glass surface: sheets, dialogs, the desktop and desklet
  /// menus. Promoted for the same reason the opacities are, and with a sharper
  /// case: blur is a PERFORMANCE setting as much as a taste one, and a person
  /// who turned it off because their Tecno stutters means it off everywhere,
  /// not off on Ubuntu and back on the moment they try Plasma.
  final double? panelOpacity;
  final double? panelBlur;
  final double? panelTint;
  final double? panelRadius;

  /// Badge style. Promoted because "I do not want numbers on my icons" is a
  /// fact about the person, not about Ubuntu, and having to say it again on
  /// every distro is exactly the complaint this bucket exists to answer.
  final String? badgeStyle;

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
        drawerSortMode: p.drawerSortMode,
        workspaceCount: p.workspaceCount,
        verboseBoot: p.verboseBoot,
        hiddenAppsSearchable: p.hiddenAppsSearchable,
        themeMode: p.themeMode,
        surfaceOpacity: p.surfaceOpacity,
        dockOpacity: p.dockOpacity,
        drawerOpacity: p.drawerOpacity,
        barOpacity: p.barOpacity,
        panelOpacity: p.panelOpacity,
        panelBlur: p.panelBlur,
        panelTint: p.panelTint,
        panelRadius: p.panelRadius,
        badgeStyle: p.badgeStyle,
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
      drawerSortMode: drawerSortMode == null,
      workspaceCount: workspaceCount == null,
      verboseBoot: verboseBoot == null,
      hiddenAppsSearchable: hiddenAppsSearchable == null,
      themeMode: themeMode == null,
      surfaceOpacity: surfaceOpacity == null,
      dockOpacity: dockOpacity == null,
      drawerOpacity: drawerOpacity == null,
      barOpacity: barOpacity == null,
      panelOpacity: panelOpacity == null,
      panelBlur: panelBlur == null,
      panelTint: panelTint == null,
      panelRadius: panelRadius == null,
      badgeStyle: badgeStyle == null,
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
      drawerSortMode: drawerSortMode,
      workspaceCount: workspaceCount,
      verboseBoot: verboseBoot,
      hiddenAppsSearchable: hiddenAppsSearchable,
      themeMode: themeMode,
      surfaceOpacity: surfaceOpacity,
      dockOpacity: dockOpacity,
      drawerOpacity: drawerOpacity,
      barOpacity: barOpacity,
      panelOpacity: panelOpacity,
      panelBlur: panelBlur,
      panelTint: panelTint,
      panelRadius: panelRadius,
      badgeStyle: badgeStyle,
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
        if (drawerSortMode != null) 'drawerSortMode': drawerSortMode,
        if (workspaceCount != null) 'workspaceCount': workspaceCount,
        if (verboseBoot != null) 'verboseBoot': verboseBoot,
        if (hiddenAppsSearchable != null)
          'hiddenAppsSearchable': hiddenAppsSearchable,
        if (themeMode != null) 'themeMode': themeMode,
        if (surfaceOpacity != null) 'surfaceOpacity': surfaceOpacity,
        if (dockOpacity != null) 'dockOpacity': dockOpacity,
        if (drawerOpacity != null) 'drawerOpacity': drawerOpacity,
        if (barOpacity != null) 'barOpacity': barOpacity,
        if (panelOpacity != null) 'panelOpacity': panelOpacity,
        if (panelBlur != null) 'panelBlur': panelBlur,
        if (panelTint != null) 'panelTint': panelTint,
        if (panelRadius != null) 'panelRadius': panelRadius,
        if (badgeStyle != null) 'badgeStyle': badgeStyle,
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
        drawerSortMode: j['drawerSortMode'] as String?,
        workspaceCount: (j['workspaceCount'] as num?)?.toInt(),
        verboseBoot: j['verboseBoot'] as bool?,
        hiddenAppsSearchable: j['hiddenAppsSearchable'] as bool?,
        themeMode: j['themeMode'] as String?,
        surfaceOpacity: (j['surfaceOpacity'] as num?)?.toDouble(),
        dockOpacity: (j['dockOpacity'] as num?)?.toDouble(),
        drawerOpacity: (j['drawerOpacity'] as num?)?.toDouble(),
        barOpacity: (j['barOpacity'] as num?)?.toDouble(),
        panelOpacity: (j['panelOpacity'] as num?)?.toDouble(),
        panelBlur: (j['panelBlur'] as num?)?.toDouble(),
        panelTint: (j['panelTint'] as num?)?.toDouble(),
        panelRadius: (j['panelRadius'] as num?)?.toDouble(),
        badgeStyle: j['badgeStyle'] as String?,
      );

  /// Its own version, independent of [LauncherPrefs.schemaVersion]: this bucket
  /// can grow a field without implying anything about the per-theme file.
  ///
  /// ─── 2: WHY GROWING THIS LIST NEEDS A VERSION AT ALL ──────────────────────
  ///
  /// Because the one-time migration in `GlobalPrefsNotifier.build` only runs
  /// when NOTHING has ever been written here. Anyone already past the split has
  /// a stored bucket, so a newly promoted field arrives as null, `applyTo`
  /// clears the per-theme value that field used to hold, and the setting the
  /// user chose is silently gone on the first launch after the update. It would
  /// look exactly like the launcher forgetting a preference for no reason.
  ///
  /// So each bump owns a top-up: see [withV2PromotionsFrom]. A future 3 adds
  /// its own method and the notifier walks the versions in order. The rule is
  /// that promoting a field is never a one-line change to this class alone.
  static const int schemaVersion = 2;

  /// Fill the fields promoted in schema 2 from the active theme's own file.
  ///
  /// Only those two, and only when this bucket has no value for them. A generic
  /// "fill every null from [p]" would be wrong in a way that is hard to spot:
  /// it would resurrect stale per-theme values for fields the user had
  /// deliberately cleared back to the distro default, and the theme file still
  /// holds those, because `PrefsNotifier.edit` leaves the promoted half of the
  /// file untouched rather than rewriting it.
  GlobalPrefs withV2PromotionsFrom(LauncherPrefs p) => GlobalPrefs(
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
        drawerSortMode: drawerSortMode ?? p.drawerSortMode,
        workspaceCount: workspaceCount,
        verboseBoot: verboseBoot ?? p.verboseBoot,
        hiddenAppsSearchable: hiddenAppsSearchable,
        themeMode: themeMode,
        surfaceOpacity: surfaceOpacity,
        dockOpacity: dockOpacity,
        drawerOpacity: drawerOpacity,
        barOpacity: barOpacity,
        panelOpacity: panelOpacity,
        panelBlur: panelBlur,
        panelTint: panelTint,
        panelRadius: panelRadius,
        badgeStyle: badgeStyle,
      );

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
        drawerSortMode,
        workspaceCount,
        verboseBoot,
        hiddenAppsSearchable,
        themeMode,
        surfaceOpacity,
        dockOpacity,
        drawerOpacity,
        barOpacity,
        panelOpacity,
        panelBlur,
        panelTint,
        panelRadius,
        badgeStyle,
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
