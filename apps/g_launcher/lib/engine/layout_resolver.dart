/// PHASE 4.
///
/// Merges the theme's default layout with the user's overrides:
///
///     effective = themeDefault  <-  userOverride (when set)
///
/// Store overrides PER THEME. If someone sets the dock to bottom on Ubuntu,
/// then tries KDE, they should get KDE's authentic bottom panel — not a
/// half-remembered preference from another distro. But when they come back to
/// Ubuntu, their bottom dock is still there.
///
/// Overridable: dock side, rows, cols, icon size, drawer style, labels on/off.
library;

import '../data/prefs/launcher_prefs.dart';
import 'theme_spec.dart';

/// The resolved layout scalars: theme defaults with the user's per-theme
/// overrides applied. Pure data, so [LayoutResolver.resolve] can be unit-tested
/// without a device, the same treatment HomeLayout and DockMetrics already get.
class ResolvedLayout {
  const ResolvedLayout({
    required this.dock,
    required this.topBar,
    required this.topBarSide,
    required this.topBarStats,
    required this.panels,
    required this.panelsAuthored,
    required this.workspaceAxis,
    required this.appsSurface,
    required this.desktopIcons,
    required this.panelEdit,
    required this.panelHeight,
    required this.panelSide,
    required this.rows,
    required this.cols,
    required this.drawerCols,
    required this.drawerScrollStyle,
    required this.drawerGrouping,
    required this.kickoffRail,
    required this.tilingLauncher,
    required this.appDrawer,
    required this.homeLayout,
    required this.dockStyle,
    required this.dockReveal,
    required this.iconSizeDp,
    required this.labelLines,
    required this.textScale,
    required this.iconScale,
  });

  final DockSide dock;
  final bool topBar;

  /// Which edge the bar sits on, and whether it carries live readouts. Both
  /// resolve the same way everything else here does: the distro's default,
  /// beaten by the user's per-theme override when they have set one.
  final TopBarSide topBarSide;
  final bool topBarStats;

  /// The distro's panels. Not overridable per user yet: the position and the
  /// modules of a panel are what make a desktop recognisable, and a per-panel
  /// settings surface is its own screen rather than a row. topBarSide and
  /// topBarStats remain the user-facing overrides, and they feed the synthesis
  /// in ThemeLayout when a theme authors no panels of its own.
  final List<PanelSpec> panels;

  /// Did the distro author its panels, or were they synthesised from the
  /// legacy `topBar` trio? Passed straight through from
  /// [ThemeLayout.panelsAuthored]; see that field for why the two were
  /// indistinguishable and what it cost.
  ///
  /// Carried on the resolved object rather than kept private to [resolve]
  /// because it is the same question every future SLOT will ask. A distro that
  /// authored no panels has also, by construction, authored no opinion about
  /// where its bar goes, and a shell reading a synthesised panel as a chosen
  /// one is the failure mode this whole flag exists to close.
  final bool panelsAuthored;

  /// Which way workspaces page. Theme-authored; not a user override, because a
  /// distro that pages the wrong way is not that distro.
  final WorkspaceAxis workspaceAxis;

  /// Where the app list lives, RESOLVED and CLAMPED. See [AppsSurface] and
  /// [LayoutResolver._appsSurface].
  ///
  /// No user override merges in, for the reason [desktopIcons] gives: which
  /// launcher a distro has is what makes Deepin not Ubuntu.
  final AppsSurface appsSurface;

  /// Does the desktop carry app icons? Resolved ONE WAY ONLY: the distro sets
  /// the ceiling and the user may lower it. See [LayoutResolver.resolve].
  final bool desktopIcons;

  /// Theme-authored only. Whether the user MAY edit the panel is not itself
  /// something the user edits.
  final bool panelEdit;

  /// Panel thickness in dp, or null to let the shell use its own default.
  ///
  /// A SCALAR here rather than a field on the resolved [PanelSpec], because
  /// height resolves the way `rows` and `cols` do (user's, else the distro's)
  /// and putting it back inside the panel would mean two places asking the same
  /// question. The shell reads this and falls back to its own constant.
  final double? panelHeight;

  /// Which edge the shell's own panel sits on.
  ///
  /// NON-NULL, unlike [panelHeight], because there is no such thing as a panel
  /// with no edge: something has to be decided, and bottom is what Plasma does.
  final TopBarSide panelSide;  final int rows;
  final int cols;
  final int drawerCols;

  /// How the drawer moves and how its list is grouped, RESOLVED: the user's
  /// choice, else the distro's authored default, else the engine default. Never
  /// null, so no read site carries its own `?? 'pages'` fallback; three of
  /// them did, and a fourth would eventually have disagreed. Unknown values
  /// from a newer build fall through the chain rather than reaching a shell.
  final String drawerScrollStyle;
  final String drawerGrouping;

  /// What the Kickoff rail is made of, RESOLVED: 'tabs' | 'categories'. Never
  /// null, so [KickoffDrawer] carries no fallback of its own.
  ///
  /// No user override merges in. Unlike the two above, this is not a way of
  /// moving through the list, it is WHICH MENU the distro has, and a Mint user
  /// switching it to tabs would be asking for KDE's menu on Mint. Same
  /// direction [desktopIcons] argues for and for the same reason.
  final String kickoffRail;

  /// Which launcher a tiling distro opens, RESOLVED: 'rofi' | 'dmenu'. Never
  /// null, so [TilingLauncher] carries no fallback of its own.
  ///
  /// No user override, and no shell clamp either. See
  /// [ThemeLayout.tilingLauncher] for why this one is named after its widget
  /// rather than clamped like `appsSurface`.
  final String tilingLauncher;

  /// Which drawer this distro opens, RESOLVED: 'grid' | 'tools'. Never null,
  /// so `ShellDrawer` carries no fallback of its own. No user override; see
  /// [ThemeLayout.appDrawer].
  final String appDrawer;

  /// How the desktop arranges its icons, RESOLVED: 'grid' | 'tiled'. Never
  /// null, so `HomeGrid` carries no fallback of its own. No prefs arm; see
  /// [ThemeLayout.homeLayout].
  final String homeLayout;

  /// How the dock sits, RESOLVED: 'flat' | 'floating' | 'magnified'. Never
  /// null. No prefs arm; see [ThemeLayout.dockStyle].
  final String dockStyle;

  /// When the dock exists, RESOLVED: 'always' | 'apps'. Never null. No prefs
  /// arm; see [ThemeLayout.dockReveal].
  final String dockReveal;

  /// The user's EXPLICIT icon-size override, in dp, or the legacy default.
  ///
  /// Being phased out. It is a flat number that knows nothing about the screen,
  /// which is why a 320dp Tecno and a 900dp tablet got the same 52dp icon. New
  /// surfaces should size from their container via `IconSizing` and apply
  /// [iconScale]; this stays until the last caller is converted, so an existing
  /// user's saved preference is not silently dropped.
  final double iconSizeDp;

  final int labelLines;
  final double textScale;

  /// The active theme's per-theme icon multiplier, straight from
  /// `ThemeLayout.iconScale`. No user override merges into it: it describes the
  /// distro's ARTWORK, not a preference, and a user who wants bigger icons has
  /// the grid-columns setting, which changes the cell and therefore the icon.
  final double iconScale;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedLayout &&
          other.dock == dock &&
          other.topBar == topBar &&
          other.topBarSide == topBarSide &&
          other.topBarStats == topBarStats &&
          other.panels.length == panels.length &&
          other.panelsAuthored == panelsAuthored &&
          other.workspaceAxis == workspaceAxis &&
          other.appsSurface == appsSurface &&
          other.desktopIcons == desktopIcons &&
          other.panelEdit == panelEdit &&
          other.panelHeight == panelHeight &&
          other.panelSide == panelSide &&
          other.rows == rows &&
          other.cols == cols &&
          other.drawerCols == drawerCols &&
          other.drawerScrollStyle == drawerScrollStyle &&
          other.drawerGrouping == drawerGrouping &&
          other.kickoffRail == kickoffRail &&
          other.tilingLauncher == tilingLauncher &&
          other.appDrawer == appDrawer &&
          other.homeLayout == homeLayout &&
          other.dockStyle == dockStyle &&
          other.dockReveal == dockReveal &&
          other.iconSizeDp == iconSizeDp &&
          other.labelLines == labelLines &&
          other.textScale == textScale &&
          other.iconScale == iconScale;

  /// ─── hashAll, NOT hash ──────────────────────────────────────────────────
  ///
  /// `Object.hash` takes at most 20 positional arguments and this list was at
  /// 19 before [kickoffRail]. Adding it lands exactly on the ceiling, so the
  /// NEXT field here would have been a compile error at best and a silently
  /// dropped term at worst. `EffectiveTheme` already hit this and moved; this
  /// moves before it has to, since a hash missing a field compares unequal but
  /// hashes the same, which is the quiet kind of wrong.
  @override
  int get hashCode => Object.hashAll([
        dock,
        topBar,
        topBarSide,
        topBarStats,
        panels.length,
        panelsAuthored,
        workspaceAxis,
        appsSurface,
        desktopIcons,
        panelEdit,
        panelHeight,
        panelSide,
        rows,
        cols,
        drawerCols,
        drawerScrollStyle,
        drawerGrouping,
        kickoffRail,
        tilingLauncher,
        appDrawer,
        homeLayout,
        dockStyle,
        dockReveal,
        iconSizeDp,
        labelLines,
        textScale,
        iconScale,
      ]);
}

/// Resolves [ThemeSpec] defaults against [LauncherPrefs] overrides. A null
/// override means "inherit the theme"; a set one wins. This is the ONE place
/// the layout merge lives, so a setting can't silently work in one spot and
/// quietly stop in another.
abstract final class LayoutResolver {
  /// Fallback icon cell size when the user hasn't chosen one.
  ///
  /// DEPRECATED IN SPIRIT. A flat dp number cannot be right on both a 320dp
  /// budget phone and a 900dp tablet, which is precisely why icon size now
  /// derives from the container (`GridMetrics.cellWidthFor` for a grid,
  /// `DockMetrics.slotFor` for a dock) through `IconSizing`. This constant
  /// survives only so a user who already set an explicit size keeps it; nothing
  /// new should read it.
  static const defaultIconSizeDp = 52.0;

  /// TWO lines, so long app names wrap instead of truncating. Mirrors
  /// GridMetrics.defaultLabelLines, and MUST keep mirroring it: the drawer
  /// sizes its cells from GridMetrics and the home grid from here, so a
  /// disagreement makes two grids on the same phone use different row heights
  /// for the same setting. If you change this, change that one to match.
  static const defaultLabelLines = 2;

  static const defaultTextScale = 1.0;

  /// The engine defaults for the drawer, when neither the user nor the distro
  /// has an opinion. 'pages', NOT 'vertical': the `LauncherPrefs` doc once
  /// claimed vertical and every read site said `?? 'pages'`, and the read
  /// sites were what users actually got. Written down here once so the
  /// disagreement cannot recur.
  static const defaultDrawerScrollStyle = 'pages';
  static const defaultDrawerGrouping = 'none';

  /// KDE's own menu, and what every plasma distro drew before the field
  /// existed. A theme that says nothing keeps exactly the rail it had.
  static const defaultKickoffRail = 'tabs';

  /// The centred card, which is what every tiling distro drew before the field
  /// existed. Same contract: a theme that says nothing does not move.
  static const defaultTilingLauncher = 'rofi';

  /// The evenly spaced grid every desktop distro has drawn. A theme that says
  /// nothing does not move.
  static const defaultHomeLayout = 'grid';

  /// MAGNIFIED, because that is what the aqua dock has always drawn and a
  /// theme that says nothing must not move. The two distros that want
  /// something else now say so.
  static const defaultDockStyle = 'magnified';

  /// Part of the desktop, which is what every distro has drawn.
  static const defaultDockReveal = 'always';

  /// Whatever the SHELL would have chosen, which is what every distro got
  /// before a theme could name a drawer. 'grid' is not the name of a widget
  /// here, it is the name of the absence of an override.
  static const defaultAppDrawer = 'grid';

  /// First KNOWN value wins: the user's, else the theme's, else [fallback].
  ///
  /// The theme value arrives pre-validated by `ThemeLayout.fromJson`, but the
  /// USER value can be a string written by a newer build, and an unknown style
  /// must fall through the chain rather than reach a shell that switches on
  /// it. This is the touched-marker rule made executable: a non-null user
  /// value, even one this build cannot render, still means "the user chose",
  /// so it is only skipped for being unknown, never overridden by the theme
  /// when it is known.
  static String _pick(
    String? user,
    String? theme,
    Set<String> known,
    String fallback,
  ) {
    if (user != null && known.contains(user)) return user;
    if (user == null && theme != null && known.contains(theme)) return theme;
    return fallback;
  }

  /// The edge the shell's own panel sits on.
  ///
  /// ─── THE THEME STILL DOES NOT GET A VOTE, AND THE REASON HAS CHANGED ────
  ///
  /// This said the theme could not be consulted because `ThemeSpec._panels`
  /// synthesises a panel for any theme that authored none, so an authored panel
  /// and a synthesised one were indistinguishable by the time they arrived
  /// here, and "the theme's side" would read a GNOME top bar's edge and move
  /// Plasma's panel to it. [ResolvedLayout.panelsAuthored] closes that: the
  /// list can now be asked which it is.
  ///
  /// It is deliberately NOT wired up in the same change, because the obvious
  /// wiring has a second trap underneath the first. `TopBarSide.parse` defaults
  /// to TOP, and `PanelSpec.fromJson` calls it unconditionally, so an authored
  /// panel that omits `side` parses to top rather than to "no opinion". Reading
  /// `panels.first.side` here would therefore move every plasma distro that
  /// authored a panel without naming an edge onto the top of the screen, which
  /// is a regression dressed as a feature.
  ///
  /// The prerequisite is a NULLABLE side on `PanelSpec`, distinguishing "this
  /// panel is on top" from "this panel did not say". That is a separate change
  /// with its own readers to update (`_currentModules` in plasma_shell matches
  /// on `side == bottom`, and would start missing panels that answer null), and
  /// it needs a real theme.json in hand to confirm which of the live distros
  /// actually name an edge.
  ///
  /// Until then: bottom, which is what Plasma does and what this shell has
  /// always drawn.
  /// Which edge the shell's own panel sits on.
  ///
  /// ─── THE THEME WAS NEVER ASKED ──────────────────────────────────────────
  ///
  /// This read `prefs.panelSide` alone and fell through to bottom, so an
  /// authored `panels: [{ side: "top" }]` moved nothing. Garuda authored a top
  /// panel and drew it at the bottom, which is why it and KDE Plasma were
  /// indistinguishable on the device: same edge, same dock, same shell.
  ///
  /// The audit could not see it either. `panels` has a prefs arm so it is
  /// reported rather than fingerprinted, and the report reads the theme.json,
  /// which said `top` all along. Every measurement agreed with the intent and
  /// the device disagreed with both.
  ///
  /// PREFS FIRST, then the theme's first authored panel, then bottom. Same
  /// three-step shape as every other resolved field, and the one it was
  /// missing.
  static TopBarSide _panelSide(LauncherPrefs prefs, ThemeSpec spec) {
    // The PREF wins, and it is a string because that is what a settings row
    // writes. An unrecognised value falls through to the authored side rather
    // than to bottom, so a pref from a newer build degrades to the theme's
    // intent instead of to the default.
    switch (prefs.panelSide) {
      case 'top':
        return TopBarSide.top;
      case 'bottom':
        return TopBarSide.bottom;
      case 'left':
        return TopBarSide.left;
      case 'right':
        return TopBarSide.right;
    }
    // `panels` is non-nullable and `side` is already a TopBarSide, so the
    // theme's own answer needs no parsing. First panel only: the shell draws
    // exactly one and `plasma_shell` places it by this value.
    final panels = spec.layout.panels;
    return panels.isEmpty ? TopBarSide.bottom : panels.first.side;
  }

  /// Where the app list lives, clamped to what the distro's SHELL can render.
  ///
  /// ─── A CLAMP RATHER THAN A SILENT NO-OP ─────────────────────────────────
  ///
  /// [AppsSurface.workspace] is implemented by `WorkspaceCanvas`, which the
  /// Plasma, tiling and Aqua shells all mount. Two shells never reach it:
  ///
  ///   * GNOME inlines its own pager rather than using the shared canvas, so
  ///     the extra page would simply not exist. That inline copy is the same
  ///     divergence that made `workspaceAxis` a GNOME-only field for a while.
  ///   * TUI has no workspaces at all. The terminal IS its own app list: you
  ///     type two letters and press enter, and there is no page to swipe to.
  ///
  /// Without this, a GNOME distro authoring `appsSurface: workspace` would
  /// write a valid value that nothing consumes, which is exactly the failure
  /// mode `kickoffRail`'s doc describes and exactly what happened to
  /// `drawerGrouping` on plasma. Answering `overlay` here means the resolved
  /// value is always the value that will actually be rendered, so a reader
  /// downstream can trust it without asking which shell it is on.
  ///
  /// The right fix for GNOME is to stop inlining its pager. That is a change to
  /// `gnome_shell.dart` and not a line here, and this clamp is what keeps the
  /// gap honest until then.
  static AppsSurface _appsSurface(ThemeSpec spec) =>
      switch (spec.shell) {
        ShellKind.plasma ||
        ShellKind.tiling ||
        ShellKind.aqua =>
          spec.layout.appsSurface,
        ShellKind.gnome || ShellKind.tui => AppsSurface.overlay,
      };

  /// The height the theme put on its bottom panel, if it authored one.
  ///
  /// Bottom, for the same reason the Plasma shell matches on bottom: that is
  /// the panel this scalar describes, and a synthesised TOP bar's height would
  /// be the wrong answer to the question the shell is asking.
  static double? _authoredHeight(ThemeSpec spec) {
    for (final p in spec.layout.panels) {
      if (p.side == TopBarSide.bottom) return p.height;
    }
    return null;
  }

  static ResolvedLayout resolve(ThemeSpec spec, LauncherPrefs prefs) {
    return ResolvedLayout(
      dock: switch (prefs.dockSide) {
        'left' => DockSide.left,
        'bottom' => DockSide.bottom,
        'off' => DockSide.off,
        'right' => DockSide.right,
        _ => spec.layout.dock,
      },
      topBar: prefs.topBar ?? spec.layout.topBar,
      topBarSide: switch (prefs.topBarSide) {
        'top' => TopBarSide.top,
        'bottom' => TopBarSide.bottom,
        'left' => TopBarSide.left,
        'right' => TopBarSide.right,
        // Anything else, including null and a value written by a newer build,
        // inherits the distro. Same contract as `dockSide` directly above.
        _ => spec.layout.topBarSide,
      },
      topBarStats: prefs.topBarStats ?? spec.layout.topBarStats,
      // A user who moves the bar or toggles its readouts is editing the
      // SYNTHESISED panel, so the synthesis is re-run against their choices
      // rather than the theme's. A distro that authored real panels keeps them:
      // overriding one of several panels from two scalars is not expressible,
      // and silently rewriting an authored layout would be worse than ignoring
      // the override.
      // ─── A BUILT PANEL SUPERSEDES BOTH ─────────────────────────────────
      //
      // Two things below produce a panel: a theme that authored one, and the
      // synthesis that turns `topBar` and `topBarSide` into one for a theme
      // that did not. A panel the user assembled by hand beats both, and beats
      // them WHOLESALE rather than merging.
      //
      // Merging was the alternative and it has no honest semantics. "Removed
      // the tray" has to survive the distro later shipping a panel with no tray
      // in it, and there is no correct answer to what the removal then means.
      // A replacement raises no such question: while this is set it IS the
      // panel, and clearing it hands the panel back to the distro intact, which
      // is what Reset in the edit bar does.
      //
      // THE SIDE IS STORED NOW. This said BOTTOM, hardcoded, with a note that
      // a second editable panel would need the side kept alongside the modules.
      // The Edge control is that need arriving, so it is.
      panels: prefs.panelModules != null
          ? [
              PanelSpec(
                // ── THE THEME'S EDGE, EVEN HERE ─────────────────────────
          //
          // This branch fires when the user has rearranged the panel in edit
          // mode, and it rebuilds the panel from THEIR modules. The edge is
          // still a separate decision: reordering the clock should not also
          // move the bar to the bottom, which is what passing prefs alone did
          // once `_panelSide` learned to read the theme.
          side: _panelSide(prefs, spec),
                modules: prefs.panelModules!
                    .map(PanelModule.parse)
                    .whereType<PanelModule>()
                    .toList(),
              ),
            ]
          // ─── THE FLAG, NOT THE SHAPE ────────────────────────────────
          //
          // This asked `panels.length == 1 && panels.first.height == null`,
          // which was a guess at "was this panel synthesised" made from the
          // only evidence available at the time, and it is wrong in the one
          // direction that matters. Those are exactly the properties of the
          // synthesised panel, and ALSO the properties of a real authored
          // panel that happens to be alone and to take the shell default
          // height. Such a distro had its authored edge silently rebound to
          // the user's `topBarSide` pref, which is the control for the
          // SYNTHESISED bar and means nothing on an authored one.
          //
          // `panelsAuthored` answers the question directly, at the only point
          // where it is still answerable. The `length == 1` test stays as a
          // guard on `.first`, not as evidence: synthesis returns either one
          // panel or `const []`, and the empty case must not reach `.first`.
          : !spec.layout.panelsAuthored && spec.layout.panels.length == 1
              ? [
                  PanelSpec(
                    side: switch (prefs.topBarSide) {
                      'top' => TopBarSide.top,
                      'bottom' => TopBarSide.bottom,
                      'left' => TopBarSide.left,
                      'right' => TopBarSide.right,
                      _ => spec.layout.panels.first.side,
                    },
                    modules: spec.layout.panels.first.modules,
                  ),
                ]
              : spec.layout.panels,
      panelsAuthored: spec.layout.panelsAuthored,
      workspaceAxis: spec.layout.workspaceAxis,
      appsSurface: _appsSurface(spec),
      // ─── AND ONLY DOWNWARDS ───────────────────────────────────────────────
      //
      // Every other override on this page is symmetric: a null inherits the
      // distro and a set value replaces it, either direction. This one is not,
      // and deliberately.
      //
      // The distro decides whether a desktop grid EXISTS. A Plasma user who
      // wants a bare desktop is expressing a preference and gets it; a GNOME
      // user switching icons on would be asking for a shell GNOME does not
      // have, and granting it would make the one distro whose whole idea is an
      // empty desktop indistinguishable from the one whose idea is a full one.
      // That is the difference between a theme and a colour scheme.
      //
      // It also keeps the Settings row honest. A greyed row that says Ubuntu
      // keeps a bare desktop is TRUE here, rather than being a control that
      // exists and is arbitrarily withheld.
      desktopIcons: spec.layout.desktopIcons && (prefs.desktopIcons ?? true),
      panelEdit: spec.layout.panelEdit,
      // The user's, else whatever the distro authored on the panel this shell
      // draws, else null and the shell uses its own default.
      panelHeight: prefs.panelHeight ?? _authoredHeight(spec),
      panelSide: _panelSide(prefs, spec),
      rows: prefs.rows ?? spec.layout.rows,
      cols: prefs.cols ?? spec.layout.cols,
      // Drawer defaults to the SAME width as home (a clean 4-wide), not home+1.
      // The user can still bump it in Settings, and the width-responsive
      // GridMetrics path applies in the drawer widget where it is used.
      drawerCols: prefs.drawerCols ?? (prefs.cols ?? spec.layout.cols),
      drawerScrollStyle: _pick(
        prefs.drawerScrollStyle,
        spec.layout.drawerScrollStyle,
        const {'vertical', 'pages', 'cube'},
        defaultDrawerScrollStyle,
      ),
      drawerGrouping: _pick(
        prefs.drawerGrouping,
        spec.layout.drawerGrouping,
        const {'none', 'az', 'library'},
        defaultDrawerGrouping,
      ),
      // No prefs argument: a capability, not a preference. See the field doc.
      kickoffRail: _pick(
        null,
        spec.layout.kickoffRail,
        const {'tabs', 'categories'},
        defaultKickoffRail,
      ),
      // Null prefs arm for the same reason. Which launcher a tiling distro has
      // is not a setting someone forgot to expose.
      tilingLauncher: _pick(
        null,
        spec.layout.tilingLauncher,
        const {'rofi', 'dmenu'},
        defaultTilingLauncher,
      ),
      // No prefs arm. Which menu a distro has is not a setting.
      homeLayout: _pick(
        null,
        spec.layout.homeLayout,
        const {'grid', 'tiled'},
        defaultHomeLayout,
      ),
      dockStyle: _pick(
        null,
        spec.layout.dockStyle,
        const {'flat', 'floating', 'magnified'},
        defaultDockStyle,
      ),
      dockReveal: _pick(
        null,
        spec.layout.dockReveal,
        const {'always', 'apps'},
        defaultDockReveal,
      ),
      appDrawer: _pick(
        null,
        spec.layout.appDrawer,
        // ─── EVERY VALUE, AND THIS SET IS WHY SIX PASSES DID NOTHING ────
        //
        // This read `{'grid', 'tools'}` and was never widened. `ThemeSpec`
        // parsed `card`, `whisker`, `cinnamon`, `zorin`, `query` and `library`
        // correctly, and then `_pick` rejected each one and returned `grid`.
        //
        // It is the worst kind of silent failure this codebase has: the
        // fallback is a WORKING DRAWER, so nothing crashed, nothing logged, and
        // every distro looked plausible while Slingshot, Whisker, Cinnamon's
        // three columns, Zorin's two tiers and Pop's query line had never once
        // been on screen.
        //
        // Adding a drawer therefore touches TWO lists, not one: the parse in
        // `ThemeSpec.fromJson` and this set. A value in the first and not the
        // second is a value that resolves to the default forever.
        const {
          'grid',
          'tools',
          'card',
          'whisker',
          'cinnamon',
          'zorin',
          'query',
          'library',
        },
        defaultAppDrawer,
      ),
      iconSizeDp: prefs.iconSizeDp ?? defaultIconSizeDp,
      labelLines: prefs.labelLines ?? defaultLabelLines,
      textScale: prefs.textScale ?? defaultTextScale,
      iconScale: spec.layout.iconScale,
    );
  }
}
