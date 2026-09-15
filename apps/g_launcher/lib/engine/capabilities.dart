/// Which settings a distro's own shape can actually reach.
///
/// ─── THIRTY LIVE CONTROLS THAT CHANGE NOTHING ───────────────────────────────
///
/// Settings is one screen for fourteen distros, and roughly a third of it is
/// inert on any given one. Arch has thirteen rows that do nothing: it has no
/// dock, no desktop, and dmenu neither pages nor groups nor wraps. Deepin has
/// five, EndeavourOS four, Kali three. Before this file, exactly TWO rows in
/// the whole screen knew to grey themselves.
///
/// That is the failure `LayoutResolver.desktopIcons` argues against at length
/// and the app was committing about thirty times: a control that exists and
/// does nothing teaches its own user that settings are unreliable, and there is
/// no recovering that once learned.
///
/// ─── GREY WITH A REASON, NEVER HIDE ─────────────────────────────────────────
///
/// Every answer here carries a [Capability.why] key. A hidden row makes someone
/// who has read about the feature conclude this build does not have it; a row
/// that says "dmenu is one line" teaches the rule at a glance and tells them
/// which distro to go to for it. `SettingsToggleRow.enabled`'s doc already made
/// this argument; nothing was computing the answer.
///
/// ─── DERIVED FROM WHAT ACTUALLY RENDERS, NOT FROM THE SHELL NAME ────────────
///
/// The tempting implementation is a map from [ShellKind]. It is wrong twice
/// over. Kali is `gnome` and mounts `ToolDrawer`, so its drawer rows are inert
/// for a reason the shell cannot express; Deepin is `aqua` and mounts
/// `AppDrawer`, so its drawer rows work. The question a settings row is really
/// asking is "which WIDGET will render this", so that is what [drawerWidget]
/// answers, by reproducing `shell_drawer.dart`'s own routing.
///
/// Keeping that in step with `ShellDrawer` is a real maintenance cost, and the
/// alternative was every row growing its own copy of the routing. One copy that
/// is named and documented beats twelve that are not.
library;

import 'effective_theme.dart';
import 'theme_spec.dart';

/// Which drawer widget `ShellDrawer` will mount for this distro.
///
/// ─── TEN VALUES, BECAUSE `ShellDrawer` HAS TEN ARMS ─────────────────────────
///
/// This had four, and the shell switch it was copied from has five arms sitting
/// under SEVEN `appDrawer` overrides that are consulted first. Six of those
/// seven had no value here, so a distro authoring `card`, `whisker`,
/// `cinnamon`, `zorin`, `query` or `library` was reported as [grid]: every
/// drawer row in Settings said it was live, and `AppDrawer` was not on screen
/// to receive any of them.
///
/// That is the failure this whole file was written to end, reproduced inside
/// the file itself, and it is the reason the library doc calls keeping this in
/// step "a real maintenance cost" rather than a formality.
enum DrawerWidget {
  /// The full-screen grid. Pages, groups, columns and a movable search bar.
  grid,

  /// KDE's Kickoff: a rail beside a fixed list.
  kickoff,

  /// The tiling prompt, in either shape.
  prompt,

  /// The numbered category menu.
  tools,

  /// elementary's card list.
  card,

  /// Xfce's Whisker menu.
  whisker,

  /// Cinnamon's menu.
  cinnamon,

  /// Zorin's menu.
  zorin,

  /// The query-first menu.
  query,

  /// The category bubbles, reached by `appDrawer: "library"` rather than by
  /// the grouping pref. See `ShellDrawer._Library`.
  library,
}

/// An answer, plus why when the answer is no.
class Capability {
  const Capability(this.available, [this.why]);

  final bool available;

  /// An i18n key naming the reason, or null when [available]. Never a finished
  /// sentence: the copy belongs in en.json like every other string.
  final String? why;
}

extension ThemeCapabilities on EffectiveTheme {
  /// Reproduces `ShellDrawer.build`'s routing. See the library doc for why this
  /// is a copy rather than a call: that widget returns a WIDGET, and a settings
  /// row needs to know which one without building it.
  /// ─── THE OVERRIDES COME FIRST, AND THAT ORDER IS LOAD-BEARING ───────────
  ///
  /// `ShellDrawer.build` tests all seven `appDrawer` values BEFORE it reaches
  /// the shell switch, because a distro's own answer outranks its shell's. This
  /// tested one of them and then fell through to the shell, which is how a
  /// gnome-shell distro authoring `zorin` was reported as a grid.
  ///
  /// A map rather than seven ifs, so a value added to `ShellDrawer` and
  /// forgotten here is a missing key rather than a silent fall-through to the
  /// shell. The fall-through is still the right answer for an UNKNOWN value:
  /// `ThemeLayout.appDrawer` parses those to 'grid' and they land in the switch,
  /// which is what the router does too.
  static const Map<String, DrawerWidget> _overrides = {
    'tools': DrawerWidget.tools,
    'card': DrawerWidget.card,
    'whisker': DrawerWidget.whisker,
    'cinnamon': DrawerWidget.cinnamon,
    'zorin': DrawerWidget.zorin,
    'query': DrawerWidget.query,
    'library': DrawerWidget.library,
  };

  DrawerWidget get drawerWidget {
    final override = _overrides[appDrawer];
    if (override != null) return override;
    return switch (shell) {
      ShellKind.plasma => DrawerWidget.kickoff,
      ShellKind.tiling => DrawerWidget.prompt,
      ShellKind.gnome || ShellKind.aqua || ShellKind.tui => DrawerWidget.grid,
    };
  }

  /// The reason a drawer row is inert, named for the drawer that is actually
  /// there. One place, so twelve rows cannot disagree about what Kali has.
  String get _drawerWhy => switch (drawerWidget) {
        DrawerWidget.kickoff => 'why.kickoffIsAList',
        DrawerWidget.prompt => tilingLauncher == 'dmenu'
            ? 'why.dmenuIsOneLine'
            : 'why.rofiIsARankedList',
        DrawerWidget.tools => 'why.toolMenuIsCategories',
        DrawerWidget.library => 'why.libraryFilesByCategory',
        // ─── ONE KEY FOR FIVE MENUS, ON PURPOSE ───────────────────────────
        //
        // Five separate sentences would each have to name a menu the reader
        // has never heard called that, and all five say the same thing: this
        // distro draws its own menu, so the grid's rows are not describing what
        // is on screen. The distro's name is already at the top of the page.
        DrawerWidget.card ||
        DrawerWidget.whisker ||
        DrawerWidget.cinnamon ||
        DrawerWidget.zorin ||
        DrawerWidget.query =>
          'why.thisDistroDrawsItsOwnMenu',
        DrawerWidget.grid => '',
      };

  /// Strictly `AppDrawer`. Gate a row on this only when the pref behind it has
  /// been PROVEN to reach nowhere else, by grepping the field across `lib/`.
  Capability get _gridDrawer => drawerWidget == DrawerWidget.grid
      ? const Capability(true)
      : Capability(false, _drawerWhy);

  /// Drawer motion: list, pages or cube. `AppDrawer` only.
  ///
  /// Also inert on a distro whose apps are a workspace PAGE rather than an
  /// overlay: a page does not open, close or cube, whatever widget draws it.
  Capability get canChooseDrawerMotion {
    if (appsSurface == AppsSurface.workspace) {
      return const Capability(false, 'why.appsAreAPage');
    }
    return _gridDrawer;
  }

  /// Group A to Z. `AppDrawer` only, and already refused under `library`,
  /// which is the one gate that existed before this file.
  /// ─── LIVE ON EVERY DISTRO MENU, NOT JUST THE GRID ───────────────────────
  ///
  /// The grep says so twice over. `drawer_items.dart` applies `library`
  /// grouping inside the SHARED item provider, so the value reaches whichever
  /// widget `ShellDrawer` mounted rather than only `AppDrawer`; and
  /// `CardDrawer` reads the field directly to seed its own library toggle.
  /// Greying this on elementary, Mint or Zorin would have taken away a row that
  /// works.
  ///
  /// The `az` arm IS `AppDrawer`-only, which is a different statement from the
  /// row being inert. The row's subtitle already carries that caveat, and it is
  /// the same split `apps_section` draws for the index rail.
  Capability get canChooseDrawerGrouping {
    final base = switch (drawerWidget) {
      DrawerWidget.kickoff ||
      DrawerWidget.prompt ||
      DrawerWidget.tools =>
        Capability(false, _drawerWhy),
      _ => const Capability(true),
    };
    if (!base.available) return base;
    return drawerGrouping == 'library'
        ? const Capability(false, 'why.libraryFilesByCategory')
        : const Capability(true);
  }

  /// The alphabet index down the drawer's edge. `AppDrawer` only.
  ///
  /// Asks only whether the widget that draws it is there. Whether it has
  /// anything to index is a question about the LIVE layout and grouping, which
  /// a user can change from the row itself, and a capability that flipped as
  /// the row beside it was tapped would be reporting a setting rather than a
  /// distro. The Settings row carries that half; see `apps_section`.
  /// ─── THE WORKSPACE GATE, WHICH BOTH OF THESE WERE MISSING ──────────────
  ///
  /// [canChooseDrawerMotion] refuses on a distro whose apps are a workspace
  /// PAGE rather than an overlay, and says so: a page does not scroll as a
  /// list, whatever widget draws it. Ubuntu is exactly that distro.
  ///
  /// These two shipped gated on [_gridDrawer] alone, so on Ubuntu the layout
  /// row above them greyed with "the apps are a page" while List shape and
  /// Index rail stayed live underneath it. A user could set both, see the
  /// drawer not change, and have no way to tell which of the three rows was
  /// telling the truth.
  ///
  /// That is worse than either row being wrong on its own. One greyed control
  /// teaches something; a greyed control stacked on two live ones that depend
  /// on it teaches that the page is unreliable.
  ///
  /// Written as a shared getter rather than copied twice, because the next row
  /// that depends on the drawer being a scrollable list will need it too and
  /// copying it a third time is how one of the three gets missed.
  Capability get _scrollableDrawer {
    if (appsSurface == AppsSurface.workspace) {
      return const Capability(false, 'why.appsAreAPage');
    }
    return _gridDrawer;
  }

  Capability get canChooseIndexRail => _scrollableDrawer;

  /// Grid of cells, or list of rows. `AppDrawer` only, same as the index.
  Capability get canChooseListStyle => _scrollableDrawer;

  /// Rows that open for their shortcuts. `AppDrawer` only, same as the two
  /// above, and for the same reason: it is a property of the row, and only one
  /// widget draws rows.
  Capability get canExpandRows => _scrollableDrawer;

  /// Drawer columns. A list has one column whatever the number says.
  ///
  /// `drawerCols` is read by `AppDrawer` and by nothing else that draws a
  /// drawer. `CardDrawer` is the near miss and it settles the question rather
  /// than complicating it: its own comment says the count is FIXED there
  /// "rather than `theme.drawerCols`", so elementary was offering a stepper
  /// that moved a number the screen ignored.
  Capability get canChooseDrawerColumns => _gridDrawer;

  /// Where the search bar sits.
  ///
  /// The tool menu is the exception among the non-grid drawers: it has a real
  /// search field and honours the pref, which is why this asks a narrower
  /// question than [_gridDrawer] rather than reusing it.
  /// ─── SIX MENUS NEVER ASK WHERE THE BAR GOES ─────────────────────────────
  ///
  /// `drawerSearchPosition` is read by three widgets: `AppDrawer`,
  /// `ToolDrawer` and `KickoffDrawer`. `CardDrawer` and `CinnamonDrawer`
  /// mention it only in comments explaining that they do not, and the other
  /// four never name it. So the row was live and doing nothing on every distro
  /// authoring its own menu, which is what this file exists to stop.
  ///
  /// ─── AND KICKOFF WAS NEVER FIXED ────────────────────────────────────────
  ///
  /// This answered `false` with 'why.kickoffSearchIsFixed', and Kickoff has
  /// been placing its search field above or below the rail off the pref the
  /// whole time. So the one row on the whole KDE settings page that claimed a
  /// distro limitation was describing a limitation that did not exist, and KDE
  /// users were told to stop asking for something they already had.
  ///
  /// That reads as the mirror of everything else in this file, and it is the
  /// same mistake: the answer was written from an impression of what Kickoff is
  /// rather than from what `kickoff_drawer.dart` does. A capability asserted
  /// without reading the widget is a guess whichever way it points.
  ///
  /// 'why.kickoffSearchIsFixed' now has no caller. The JSON key stays put; an
  /// unused string costs nothing and deleting it would break any pack or
  /// screenshot still pointing at it.
  Capability get canMoveSearchBar => switch (drawerWidget) {
        DrawerWidget.grid ||
        DrawerWidget.tools ||
        DrawerWidget.kickoff =>
          const Capability(true),
        DrawerWidget.prompt =>
          const Capability(false, 'why.thePromptIsTheSearch'),
        DrawerWidget.card ||
        DrawerWidget.whisker ||
        DrawerWidget.cinnamon ||
        DrawerWidget.zorin ||
        DrawerWidget.query ||
        DrawerWidget.library =>
          const Capability(false, 'why.thisDistroDrawsItsOwnMenu'),
      };

  /// Is there a dock to position or fade?
  ///
  /// Aqua HAS one and refuses to move it, which is a different answer from not
  /// having one, so it gets its own reason. `aqua_shell` documents that at
  /// length: a vertical magnifying dock is not a Mac.
  /// Is there a dock on the DESKTOP to position or fade?
  ///
  /// Asked before the shell, because a distro whose dash lives inside the
  /// overview has no dock on the desktop whatever its shell can draw. Fedora
  /// authors `dock: left` and still has nothing to position: the dash appears
  /// centred in Activities and goes when you leave.
  Capability get _revealedDock => dockReveal == 'apps'
      ? const Capability(false, 'why.theDashIsInActivities')
      : const Capability(true);

  Capability get canPositionDock => !_revealedDock.available
      ? _revealedDock
      : switch (shell) {
          ShellKind.gnome || ShellKind.plasma => const Capability(true),
          ShellKind.aqua => const Capability(false, 'why.theDockHasOneHome'),
          ShellKind.tiling ||
          ShellKind.tui =>
            const Capability(false, 'why.noDockOnThisDesktop'),
        };

  /// Can this distro file its apps into the Library?
  ///
  /// ─── ONLY WHERE THE DISTRO AUTHORS IT, AND THIS IS A REMOVAL ────────────
  ///
  /// Library shipped as a universal option and should not have. It is a
  /// specific desktop's idea: elementary's Applications view and the COSMIC app
  /// library are where category bubbles come from, and both of those distros
  /// author `drawerGrouping: "library"` as their own answer. On Ubuntu it is a
  /// feature from a desktop Ubuntu does not have, offered on a page that is
  /// otherwise careful to say what each distro does and does not do.
  ///
  /// That matters more here than anywhere else on the settings screen, because
  /// distros are the product. A setting that makes Ubuntu look like elementary
  /// is the catalogue arguing with itself.
  ///
  /// ─── READ FROM spec.layout, WHICH IS USUALLY THE WRONG THING TO DO ──────
  ///
  /// `EffectiveTheme` says plainly that a shell must read the RESOLVED value
  /// and never `spec.layout`, and it is right: reading the authored value is
  /// how a user's pref gets ignored.
  ///
  /// This is the exception the rule allows for, because the question is not
  /// "what is the grouping" but "did this distro claim the Library as its own".
  /// Only the authored value can answer that. Resolving first would make the
  /// capability flip the moment the user picked Library, which would let the
  /// option authorise itself.
  ///
  /// So elementary and Zorin keep it, including for a user who switched away
  /// and wants it back. Everyone else never offers it again.
  Capability get canUseLibrary =>
      spec.layout.drawerGrouping == 'library' || appDrawer == 'library'
          ? const Capability(true)
          : const Capability(false, 'why.thisDistroDrawsItsOwnMenu');

  /// Can the dock be a list of names instead of a bar of icons?
  ///
  /// ─── GNOME ONLY, AND THAT IS A FIDELITY CALL ────────────────────────────
  ///
  /// Not a technical limit. `FavouritesList` takes the same `List<DockEntry>`
  /// both dock shells already build, so Aqua could mount it tomorrow. It
  /// should not.
  ///
  /// Aqua's dock magnifies under the pointer and carries a Launchpad slot in
  /// its run, and both of those ARE the emulation: a labelled column down the
  /// left edge is not a thing macOS has ever done, and putting one there would
  /// be the first place in the catalogue where a setting makes a distro stop
  /// looking like what it claims to be. Plasma's launchers live on the panel,
  /// where a dock presentation has nothing to present.
  ///
  /// GNOME is the honest home for it because Ubuntu already keeps a vertical
  /// dock down the left. Widening that strip and writing the names beside the
  /// icons is a variation on an arrangement the distro shipped, not a
  /// contradiction of it.
  Capability get canListDock {
    if (!_revealedDock.available) return _revealedDock;
    if (dock == DockSide.off) {
      return const Capability(false, 'why.noDockOnThisDesktop');
    }
    return switch (shell) {
      ShellKind.gnome => const Capability(true),
      ShellKind.aqua => const Capability(false, 'why.theDockHasOneHome'),
      ShellKind.plasma ||
      ShellKind.tiling ||
      ShellKind.tui =>
        const Capability(false, 'why.noDockOnThisDesktop'),
    };
  }

  /// Is there a dock surface to fade?
  ///
  /// Separate from [canPositionDock] because aqua answers them differently: it
  /// HAS a dock and refuses to move it, so position is greyed and opacity is
  /// not. A revealed dash greys both.
  Capability get canFadeDock {
    if (!_revealedDock.available) return _revealedDock;
    return dock == DockSide.off
        ? const Capability(false, 'why.noDockOnThisDesktop')
        : const Capability(true);
  }

  // `hasDock` was here and is deleted rather than left uncalled.
  //
  // It would have gated Dock opacity, and it could not: aqua's dock EXISTS and
  // refuses to move, so the honest answer was true on every branch that
  // mattered and the only false case was `dock: off`, which the opacity row
  // would have to handle anyway. A capability whose answer is "yes, except when
  // the thing is switched off" is not a capability, it is the switch.
  //
  // The rule for this file: every getter has a caller. An unused one is a
  // question nobody was asking, and this file exists because thirty controls
  // were answering questions nobody could see.

  /// Is there a bar across the top?
  ///
  /// Asked of [panels] rather than of the shell, because `ThemeSpec._panels`
  /// synthesises one for the legacy `topBar: true` and returns `const []` for
  /// false. That is the same test `gnome_shell.panelsOn` and `aqua_shell` use,
  /// so a distro that turns its bar off greys these rows by saying one thing.
  Capability get hasTopBar => panels.any((p) => p.side == TopBarSide.top)
      ? const Capability(true)
      : const Capability(false, 'why.noBarOnThisDesktop');

  /// Icons on the desktop, and therefore a grid to shape.
  ///
  /// The distro sets the ceiling; see [LayoutResolver] for why the user may
  /// only lower it. A distro that never had them cannot be talked into one.
  Capability get hasDesktopGrid => spec.layout.desktopIcons
      ? const Capability(true)
      : const Capability(false, 'why.bareDesktop');

  /// Does anything OPEN the app list?
  ///
  /// On a workspace-surface distro nothing does: you swipe, so a control for
  /// where the button lives is a control for a button that is not there.
  Capability get hasActivitiesButton => switch (appsSurface) {
        AppsSurface.workspace => const Capability(false, 'why.appsAreAPage'),
        AppsSurface.overlay => switch (shell) {
            ShellKind.tui => const Capability(false, 'why.noBarOnThisDesktop'),
            _ => const Capability(true),
          },
      };

  /// Is there a light palette to switch to?
  ///
  /// Several distros are dark by construction. Arch, EndeavourOS and Terminal
  /// author no `paletteLight`, and a light tiling WM is nobody's Arch.
  Capability get hasLightMode => spec.paletteLight == null
      ? const Capability(false, 'why.thisDistroStaysDark')
      : const Capability(true);

  /// Workspaces to count. The terminal has none.
  Capability get hasWorkspaces => shell == ShellKind.tui
      ? const Capability(false, 'why.theTerminalHasNoWorkspaces')
      : const Capability(true);

  /// Is there a wallpaper behind this shell?
  ///
  /// ─── THE TERMINAL PAINTS ITS OWN BACKGROUND ───────────────────────────
  ///
  /// Every other shell runs TRANSPARENT over the system wallpaper, which is
  /// the whole reason `WallpaperController` sets a real one rather than
  /// drawing a picture inside Flutter. The tui shell does not: it fills the
  /// screen with its own terminal background, so a wallpaper set underneath it
  /// is bought, framed, applied and then never seen.
  ///
  /// ─── AND WHY A CAPABILITY RATHER THAN HIDING THE ROW ──────────────────
  ///
  /// The settings row could just be omitted on tui. It would also be omitted
  /// silently, and the next surface that wants to know this fact would have to
  /// rediscover it from the shell name, which is exactly how `drawerGrouping`
  /// came to mean nothing on plasma distros. Asking a capability puts the
  /// reason in one place with a sentence attached, the same as the four above.
  ///
  /// The user's photos, collections and rotation choices are untouched by
  /// this: they are global, and switching to any other distro brings the page
  /// straight back with everything still in it.
  Capability get hasWallpaper => shell == ShellKind.tui
      ? const Capability(false, 'why.theTerminalPaintsItsOwn')
      : const Capability(true);

// `hasAuthoredCategories` was here and is deleted for the same reason. It was
// written for the folders screen, which I have not read, so it was a getter
// built against a guess at what that screen needed. It comes back when a
// caller does.
}
