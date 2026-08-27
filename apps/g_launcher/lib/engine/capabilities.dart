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
enum DrawerWidget {
  /// The full-screen grid. Pages, groups, columns and a movable search bar.
  grid,

  /// KDE's Kickoff: a rail beside a fixed list.
  kickoff,

  /// The tiling prompt, in either shape.
  prompt,

  /// The numbered category menu.
  tools,
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
  DrawerWidget get drawerWidget {
    if (appDrawer == 'tools') return DrawerWidget.tools;
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
        DrawerWidget.grid => '',
      };

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
  Capability get canChooseDrawerGrouping {
    final base = _gridDrawer;
    if (!base.available) return base;
    return drawerGrouping == 'library'
        ? const Capability(false, 'why.libraryFilesByCategory')
        : const Capability(true);
  }

  /// Drawer columns. A list has one column whatever the number says.
  Capability get canChooseDrawerColumns => _gridDrawer;

  /// Where the search bar sits.
  ///
  /// The tool menu is the exception among the non-grid drawers: it has a real
  /// search field and honours the pref, which is why this asks a narrower
  /// question than [_gridDrawer] rather than reusing it.
  Capability get canMoveSearchBar => switch (drawerWidget) {
        DrawerWidget.grid || DrawerWidget.tools => const Capability(true),
        DrawerWidget.kickoff => const Capability(false, 'why.kickoffSearchIsFixed'),
        DrawerWidget.prompt =>
          const Capability(false, 'why.thePromptIsTheSearch'),
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
        ShellKind.tiling || ShellKind.tui =>
          const Capability(false, 'why.noDockOnThisDesktop'),
      };

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
  Capability get hasTopBar =>
      panels.any((p) => p.side == TopBarSide.top)
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

  // `hasAuthoredCategories` was here and is deleted for the same reason. It was
  // written for the folders screen, which I have not read, so it was a getter
  // built against a guess at what that screen needed. It comes back when a
  // caller does.
}
