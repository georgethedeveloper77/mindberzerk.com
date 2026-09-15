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
    required this.drawerIndexRail,
    required this.drawerListStyle,
    required this.dockLayout,
    required this.drawerSearchPosition,
    required this.kickoffRail,
    required this.tilingLauncher,
    required this.appDrawer,
    required this.homeLayout,
    required this.dockStyle,
    required this.dockHover,
    required this.dockPress,
    required this.dockEntrance,
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

  /// The drawer's alphabet index, RESOLVED: 'off' | 'plain' | 'arc'.
  ///
  /// Resolves from the user and the engine only. There is no distro arm: see
  /// [LauncherPrefs.drawerIndexRail] for why a field the admin cannot publish
  /// is worse than a field the admin does not have.
  ///
  /// Meaningful only when the layout is the list AND the grouping is 'az',
  /// because an index needs sections to point at. That pair is enforced in
  /// Settings and checked again at the read site, rather than being resolved
  /// away here: a resolver that silently answered 'off' on a paged drawer
  /// would make the Settings row lie about what it had saved.
  final String drawerIndexRail;

  /// The vertical drawer's shape, RESOLVED: 'grid' | 'rows'.
  ///
  /// Meaningful only when the layout is the list. A page of rows is not a
  /// shape the pager can size, so this is inert on every other scroll style
  /// and `AppDrawer` gates on both.
  final String drawerListStyle;

  /// The dock's presentation, RESOLVED: 'bar' | 'list'.
  ///
  /// No distro arm, same as the two above it. A distro states WHERE its dock
  /// is and whether it floats; whether the user wants names beside the icons is
  /// a reach preference, and no theme.json has a way to say it.
  final String dockLayout;

  /// Where the drawer's search bar sits, RESOLVED: 'top' | 'bottom' | 'off'.
  /// Never null, so `AppDrawer` carries no fallback of its own.
  ///
  /// It carried one, and that fallback was the whole bug: the read site was
  /// `theme.prefs.drawerSearchPosition ?? 'bottom'`, so a distro could not pin
  /// its own position no matter what it authored. See
  /// [ThemeLayout.drawerSearchPosition] for what that cost Deepin.
  final String drawerSearchPosition;

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

  /// The three dock animations, RESOLVED. See [ThemeLayout.dockHover].
  ///
  /// Each has a prefs arm, unlike [dockStyle]: how a dock sits is part of what
  /// makes a distro that distro, and how it animates is taste.
  final String dockHover;
  final String dockPress;
  final String dockEntrance;

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
          other.drawerIndexRail == drawerIndexRail &&
          other.drawerListStyle == drawerListStyle &&
          other.dockLayout == dockLayout &&
          other.drawerSearchPosition == drawerSearchPosition &&
          other.kickoffRail == kickoffRail &&
          other.tilingLauncher == tilingLauncher &&
          other.appDrawer == appDrawer &&
          other.homeLayout == homeLayout &&
          other.dockStyle == dockStyle &&
          other.dockHover == dockHover &&
          other.dockPress == dockPress &&
          other.dockEntrance == dockEntrance &&
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
        drawerIndexRail,
        drawerListStyle,
        dockLayout,
        drawerSearchPosition,
        kickoffRail,
        tilingLauncher,
        appDrawer,
        homeLayout,
        dockStyle,
        dockHover,
        dockPress,
        dockEntrance,
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

  /// The index is ON where it applies at all.
  ///
  /// It only applies under `vertical` + `az`, which is already a state a user
  /// chose on purpose, and a letter index is the thing that makes that state
  /// worth choosing. Defaulting to 'off' would mean the feature ships switched
  /// off for everyone who already wanted exactly what it improves.
  static const defaultDrawerIndexRail = 'arc';

  /// The grid, because that is what every existing drawer already looks like.
  ///
  /// The opposite call to [defaultDrawerIndexRail], and for the opposite
  /// reason: the index adds a control to a screen that was missing one, while
  /// rows REDRAW a screen the user has already arranged. Restyling fifteen
  /// distros on upgrade is not a default, it is a redesign nobody asked for.
  static const defaultDrawerListStyle = 'grid';

  /// The bar. Every distro in the catalogue emulates a desktop that has one,
  /// and a list is a phone idiom borrowed onto them rather than anything Ubuntu
  /// or Fedora does. Opt in, never arrive in.
  static const defaultDockLayout = 'bar';

  /// Thumb-reachable, and what every distro drew before the field existed. A
  /// theme that says nothing keeps exactly the bar it had.
  static const defaultDrawerSearchPosition = 'bottom';

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
  ///
  /// It carries a corner radius as well as a swell, which is why `dockHover`
  /// took the swell and left this alone rather than replacing it.
  static const defaultDockStyle = 'magnified';

  /// MAGNIFY, for the reason the old dock-style default gave: it is what the
  /// aqua dock has always drawn, and a theme that says nothing must not move.
  ///
  /// It is also harmless on the docks that cannot do it. `GnomeDock` has never
  /// honoured magnification and does not start now; a hover mode it does not
  /// implement is a value it ignores, the same way it already ignores
  /// `dockStyle: magnified`.
  static const defaultDockHover = 'magnify';

  /// The safe one, and what every dock in the app already does on a tap:
  /// `PressPop` scales down and back.
  static const defaultDockPress = 'sink';

  /// NOTHING, deliberately, unlike the other two.
  ///
  /// Hover and press have always-on defaults because the dock already did
  /// something in both cases and removing it would be a change. An entrance
  /// animation is new: no dock has ever slid, expanded or blurred in, so a
  /// default of anything else would animate every distro on first paint on the
  /// strength of a field nobody authored.
  static const defaultDockEntrance = 'none';

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
  /// Takes the RESOLVED layout, not the spec.
  ///
  /// It read `spec.layout` and was called from `resolve`, which by then had
  /// already picked a preset. So a distro whose macOS-like layout puts its bar
  /// on top would have had its panel side answered from the Zorin layout it was
  /// not using: a plausible answer, from the wrong layout, which is the failure
  /// shape this whole file's allow-list notes keep describing.
  static TopBarSide _panelSide(LauncherPrefs prefs, ThemeLayout base) {
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
    final panels = base.panels;
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
  /// [base], because a preset may move the app surface even though the SHELL
  /// it is being matched against cannot change.
  static AppsSurface _appsSurface(ThemeSpec spec, ThemeLayout base) =>
      switch (spec.shell) {
        ShellKind.plasma ||
        ShellKind.tiling ||
        ShellKind.aqua =>
          base.appsSurface,
        ShellKind.gnome || ShellKind.tui => AppsSurface.overlay,
      };

  /// The height the theme put on its bottom panel, if it authored one.
  ///
  /// Bottom, for the same reason the Plasma shell matches on bottom: that is
  /// the panel this scalar describes, and a synthesised TOP bar's height would
  /// be the wrong answer to the question the shell is asking.
  static double? _authoredHeight(ThemeLayout base) {
    for (final p in base.panels) {
      if (p.side == TopBarSide.bottom) return p.height;
    }
    return null;
  }

  static ResolvedLayout resolve(ThemeSpec spec, LauncherPrefs prefs) {
    // ─── THE PRESET IS RESOLVED ONCE, HERE, AND THEN FORGOTTEN ───────────
    //
    // `layoutFor` returns a complete [ThemeLayout] that was merged at parse, so
    // everything below is the same theme-default-then-user-override merge this
    // function has always performed. Nothing in [ResolvedLayout] changes, no
    // shell learns that presets exist, and a distro that authors none gets
    // `spec.layout` byte for byte.
    //
    // Read through this local, never `spec.layout`. A single missed site would
    // mix one preset's panels with another's grid, and the result would be a
    // plausible-looking layout that no card in the picker describes.
    final base = spec.layoutFor(prefs.layoutPreset);

    return ResolvedLayout(
      dock: switch (prefs.dockSide) {
        'left' => DockSide.left,
        'bottom' => DockSide.bottom,
        'off' => DockSide.off,
        'right' => DockSide.right,
        _ => base.dock,
      },
      topBar: prefs.topBar ?? base.topBar,
      topBarSide: switch (prefs.topBarSide) {
        'top' => TopBarSide.top,
        'bottom' => TopBarSide.bottom,
        'left' => TopBarSide.left,
        'right' => TopBarSide.right,
        // Anything else, including null and a value written by a newer build,
        // inherits the distro. Same contract as `dockSide` directly above.
        _ => base.topBarSide,
      },
      topBarStats: prefs.topBarStats ?? base.topBarStats,
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
          side: _panelSide(prefs, base),
                // `PanelItem.parseAll`, not `PanelModule.parse`: the stored
                // strings can read `app:com.example.files`, and parsing to the
                // kind alone would drop the package and render a button that
                // launches nothing. Unrecognised entries are still dropped
                // rather than fatal.
                //
                // ── AND IT EXPANDS `tray` FOR THE SAME REASON THE THEME DOES
                //
                // Edit mode writes the panel it rendered, so a list saved after
                // the expansion landed holds the three modules already and this
                // is a no-op on it. A list saved BEFORE it still says `tray`,
                // and running it through the same function is what stops an
                // early adopter's saved panel being the one panel in the app
                // whose tray cannot be tapped. The side is the resolved one, so
                // a saved panel moved to the top edge collapses back to the
                // Quick Settings button rather than duplicating the status bar.
                items: PanelItem.parseAll(
                  prefs.panelModules!,
                  side: _panelSide(prefs, base),
                ),
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
          : !base.panelsAuthored && base.panels.length == 1
              ? [
                  PanelSpec(
                    side: switch (prefs.topBarSide) {
                      'top' => TopBarSide.top,
                      'bottom' => TopBarSide.bottom,
                      'left' => TopBarSide.left,
                      'right' => TopBarSide.right,
                      _ => base.panels.first.side,
                    },
                    items: base.panels.first.items,
                  ),
                ]
              : base.panels,
      panelsAuthored: base.panelsAuthored,
      workspaceAxis: base.workspaceAxis,
      appsSurface: _appsSurface(spec, base),
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
      desktopIcons: base.desktopIcons && (prefs.desktopIcons ?? true),
      panelEdit: base.panelEdit,
      // The user's, else whatever the distro authored on the panel this shell
      // draws, else null and the shell uses its own default.
      panelHeight: prefs.panelHeight ?? _authoredHeight(base),
      panelSide: _panelSide(prefs, base),
      rows: prefs.rows ?? base.rows,
      cols: prefs.cols ?? base.cols,
      // Drawer defaults to the SAME width as home (a clean 4-wide), not home+1.
      // The user can still bump it in Settings, and the width-responsive
      // GridMetrics path applies in the drawer widget where it is used.
      drawerCols: prefs.drawerCols ?? (prefs.cols ?? base.cols),
      // ─── THE ALLOW-LIST IS THE DANGEROUS HALF OF ADDING A STYLE ────────
      //
      // A value missing from this set is dropped here, silently, and the
      // resolver hands back something plausible instead. So a distro could
      // author `cylinder`, the pack could publish, the device could install it,
      // and the drawer would slide with nothing anywhere reporting a problem.
      // That is the exact failure shape `drawerGrouping` and `chromeFamily`
      // both hit before.
      //
      // `vertical` is not a transition: it selects a different widget entirely,
      // and `app_drawer` branches on it before `DrawerPager` is reached. It
      // lives in the same field because that is the question a user is
      // answering, which is "how does my drawer move", and splitting it into
      // two fields would cost a prefs migration to express a distinction
      // nobody sees.
      //
      // Keep this set, `DrawerTransition.parse` and the Settings picker edited
      // together. Two of the three fail loudly; this one does not.
      drawerScrollStyle: _pick(
        prefs.drawerScrollStyle,
        base.drawerScrollStyle,
        const {
          'vertical',
          'pages',
          'cube',
          'cylinder',
          'sphere',
          'depth',
          'stack',
        },
        defaultDrawerScrollStyle,
      ),
      drawerGrouping: _pick(
        prefs.drawerGrouping,
        base.drawerGrouping,
        const {'none', 'az', 'library'},
        defaultDrawerGrouping,
      ),
      // Null theme arm, like `kickoffRail` and `tilingLauncher` above, but for
      // the opposite reason: those are capabilities a user should not vote on,
      // this is a preference no distro can currently express. Keep this set and
      // `IndexRail.parse` edited together.
      drawerIndexRail: _pick(
        prefs.drawerIndexRail,
        null,
        const {'off', 'plain', 'arc'},
        defaultDrawerIndexRail,
      ),
      drawerListStyle: _pick(
        prefs.drawerListStyle,
        null,
        const {'grid', 'rows'},
        defaultDrawerListStyle,
      ),
      dockLayout: _pick(
        prefs.dockLayout,
        null,
        const {'bar', 'list'},
        defaultDockLayout,
      ),
      // A PREFS ARM, unlike the four below it. Where the search bar sits is a
      // reach preference on a phone, so a user who has moved it keeps it on
      // every distro they visit; the distro only answers for someone who never
      // touched it. That is also why this cannot carry an `exclusive` feature
      // row: all-access Settings reproduces it.
      drawerSearchPosition: _pick(
        prefs.drawerSearchPosition,
        base.drawerSearchPosition,
        const {'top', 'bottom', 'off'},
        defaultDrawerSearchPosition,
      ),
      // No prefs argument: a capability, not a preference. See the field doc.
      kickoffRail: _pick(
        null,
        base.kickoffRail,
        const {'tabs', 'categories'},
        defaultKickoffRail,
      ),
      // Null prefs arm for the same reason. Which launcher a tiling distro has
      // is not a setting someone forgot to expose.
      tilingLauncher: _pick(
        null,
        base.tilingLauncher,
        const {'rofi', 'dmenu'},
        defaultTilingLauncher,
      ),
      // No prefs arm. Which menu a distro has is not a setting.
      homeLayout: _pick(
        null,
        base.homeLayout,
        const {'grid', 'tiled'},
        defaultHomeLayout,
      ),
      // ─── `magnified` STAYS, AND SEEDS THE NEW FIELD ──────────────────
      //
      // The tidy version of this split rewrote it to `floating`, on the grounds
      // that magnification is a RESPONSE and the other two are ways of SITTING.
      // That is true and it is also not the whole job this value does:
      // `AquaDockStyle.magnified` picks a corner radius of 0.28 where floating
      // picks 0.42, so rewriting it would have quietly rounded Deepin's dock.
      //
      // So the split is additive. This field is untouched and every published
      // pack resolves exactly as before; `dockHover` below reads it as its
      // default, and only the SWELL moves to the new field.
      dockStyle: _pick(
        null,
        base.dockStyle,
        const {'flat', 'floating', 'magnified'},
        defaultDockStyle,
      ),
      dockHover: _pick(
        prefs.dockHover,
        base.dockHover ?? (base.dockStyle == 'magnified' ? 'magnify' : null),
        // THE SECOND LIST, and the failure `dockReveal` documents below: a
        // value this set omits resolves to the default forever behind a dock
        // that looks like it is working. Kept in the same order as the parse in
        // `theme_spec.dart` so the two can be read side by side.
        const {'none', 'magnify', 'lift', 'tilt', 'part', 'focus', 'arc'},
        defaultDockHover,
      ),
      dockPress: _pick(
        prefs.dockPress,
        base.dockPress,
        const {
          'sink',
          'bounce',
          'jelly',
          'pop',
          'flip',
          'swing',
          'pulse',
          'ripple',
          'wave',
          'launch',
        },
        defaultDockPress,
      ),
      dockEntrance: _pick(
        prefs.dockEntrance,
        base.dockEntrance,
        const {'none', 'slide', 'expand', 'blur', 'stagger', 'gloss'},
        defaultDockEntrance,
      ),
      dockReveal: _pick(
        null,
        base.dockReveal,
        // THE SECOND LIST. `ThemeSpec.fromJson` parses these and this set
        // admits them, and a value in one and not the other resolves to the
        // default forever behind a working dock. That is the `appDrawer` story
        // below, six passes long.
        const {'always', 'apps', 'desktop'},
        defaultDockReveal,
      ),
      appDrawer: _pick(
        null,
        base.appDrawer,
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
      iconScale: base.iconScale,
    );
  }
}
