import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
// legacy.dart is where StateProvider moved in v3; flutter_riverpod.dart is for
// Notifier / NotifierProvider below.

/// Is the Activities drawer open?
///
/// **Also used to live in `gnome_shell.dart`.** Same problem as `shellApps`: the
/// gesture layer reads it, the top bar writes it, the dock writes it, and none
/// of them should have to import a shell to find out whether a drawer is open.
///
/// It stays a `StateProvider` because that is exactly what it is — one bool, no
/// logic. Riverpod 3 moved `StateProvider` to `legacy.dart`; that is a rename,
/// not a deprecation with teeth. A `Notifier<bool>` here would be ceremony.
final activitiesOpenProvider = StateProvider<bool>((ref) => false);

/// Which page the drawer's pager is on.
///
/// ─── WHY THIS IS NOT JUST THE PageController'S BUSINESS ─────────────────────
///
/// It was, and the controller lives in `_DrawerPagerState`, so the page
/// survived exactly as long as that State object did. Anything that remounted
/// the drawer, a rotation, or a parent that swaps the desktop for a spinner
/// while an async provider refreshes, built a fresh controller at its anchor
/// and dumped the user back on page one mid-task.
///
/// Holding it here makes the page a property of the DRAWER rather than of one
/// widget's lifetime, so a remount restores it instead of resetting it. That is
/// worth having on its own merits: losing your place on rotation was never
/// correct either.
///
/// Deliberately NOT reset when the drawer closes. Reopening on the page you
/// left is the lesser surprise, and a reset here would fire on exactly the
/// remounts this exists to survive.
final drawerPageProvider =
    NotifierProvider<DrawerPage, int>(DrawerPage.new);

class DrawerPage extends Notifier<int> {
  @override
  int build() => 0;

  /// Named `setPage` rather than `set` because a bare `set` reads as a setter
  /// declaration at a glance, and per the house rule notifiers expose intent
  /// methods rather than a raw mutator.
  void setPage(int page) {
    if (page == state) return;
    state = page;
  }
}
