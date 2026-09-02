library;

import 'package:flutter/widgets.dart';

// ─── SHOW CLAUSES, NOT BARE IMPORTS ─────────────────────────────────────────
//
// `theme_spec.dart` and `dock_metrics.dart` each declare an enum called
// `DockSide`, which `dock_metrics` documents as a known debt and instructs be
// edited in step. Importing both unrestricted here is an ambiguous-import
// error that reads as if neither declaration exists, which is the trap
// `terminal_matches.dart` carries its own note about. One `show` on each side
// costs nothing and cannot be misread.
import '../../engine/effective_theme.dart';
import '../../engine/theme_spec.dart' show AppsSurface, DockSide, ShellKind;
import 'aqua_dock_metrics.dart' show AquaDockMetrics;
import 'dock_metrics.dart' show DockMetrics;

/// How much of the screen the launcher's own dock occupies, as insets.
///
/// ─── THE SUBTRACTION NOTHING WAS DOING ──────────────────────────────────────
///
/// This is the third place the same fault has turned up. `DeskletSurfaceView`
/// is `Positioned.fill` in a box the dock is also positioned in, so a desklet
/// at column 0 sat behind every vertical dock. `AppDrawer` mounted as a page
/// sits under a bottom dock the same way. Both used `MediaQuery.viewPadding`,
/// which describes the SYSTEM's furniture and knows nothing about ours.
///
/// [DockMetrics.reserve] and [AquaDockMetrics.reserve] were both written for
/// exactly this and each had one caller or none. Deriving the band here rather
/// than in each surface is what stops a fourth surface inventing an 89.
///
/// ─── WHY THE SHELL DECIDES WHICH BAND ───────────────────────────────────────
///
/// Not `dockStyle`. That says how a dock SITS (flat, floating, magnified) and a
/// theme may set it on any shell; which dock WIDGET gets mounted is the shell's
/// choice, and the two metrics files describe two different widgets with
/// different geometry. Asking the shell is asking the thing that actually knows.
///
/// Over-reserving is the safe direction and [DockMetrics.reserve] says so: too
/// much leaves a strip of unused desktop, too little puts content back under
/// the dock, which is the bug.
EdgeInsets dockInsets(EffectiveTheme theme) {
  final band = theme.shell == ShellKind.aqua
      ? AquaDockMetrics.reserve
      : DockMetrics.reserve;

  return switch (theme.dock) {
    DockSide.off => EdgeInsets.zero,
    DockSide.bottom => EdgeInsets.only(bottom: band),
    DockSide.left => EdgeInsets.only(left: band),
    DockSide.right => EdgeInsets.only(right: band),
  };
}

/// The same insets, for the DESKTOP, or nothing when this distro has no
/// permanent dock.
///
/// ─── THE ONE PLACE `dockReveal` CHANGES THE ANSWER ──────────────────────────
///
/// 'apps' means the dock exists only while the app list is open, which is what
/// tells Fedora from Ubuntu: upstream GNOME has no dock on the desktop at all,
/// a dash appears with the overview and leaves with it. Reserving a band for it
/// would surrender 89dp of a desktop whose whole argument is that it is empty,
/// permanently, for something that is never there.
///
/// The drawer's version below deliberately does NOT ask, because both values
/// put a dock over that surface: 'apps' means the dock is present precisely
/// when the app list is.
EdgeInsets desktopDockInsets(EffectiveTheme theme) =>
    theme.dockReveal == 'apps' ? EdgeInsets.zero : dockInsets(theme);

/// The same insets, for a drawer, or nothing when the drawer covers the dock
/// rather than sitting under it.
///
/// ─── ONLY A PAGE PAYS ───────────────────────────────────────────────────────
///
/// An overlay drawer is mounted over the whole shell and paints its own wash
/// across everything, dock included, so insetting it would leave a bare band at
/// the bottom of a surface that owns the screen. A workspace-page drawer is a
/// `PageView` child with the shell's chrome stacked on top of it, and that is
/// the case that has to pay.
///
/// ─── AND ONE VALUE OF `dockReveal` THAT DOES CHANGE THE ANSWER ──────────────
///
/// This said `dockReveal` was deliberately not asked, on the grounds that both
/// of its values put a dock over the app list: 'always' obviously, and 'apps'
/// because that value means the dock exists precisely WHILE the app list is
/// open. That was true of two values and false the moment a third arrived.
///
/// 'desktop' is the mirror of 'apps': a dock on every home page and none on the
/// app list, which is what iOS does and what Pocket is. There is no dock over
/// this surface, so there is no band to reserve, and reserving one would leave
/// a strip of dead space along the foot of an App Library.
EdgeInsets drawerDockInsets(EffectiveTheme theme) {
  if (theme.appsSurface != AppsSurface.workspace) return EdgeInsets.zero;
  if (theme.dockReveal == 'desktop') return EdgeInsets.zero;
  return dockInsets(theme);
}
