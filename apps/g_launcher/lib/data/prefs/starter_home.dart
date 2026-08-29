import '../../engine/theme_spec.dart' show HomeBlock;
import 'home_layout.dart';
import 'launcher_prefs.dart';

/// Lay out a distro's starting desktop ICONS, once.
///
/// [StarterDesktop]'s sibling, and written to the same shape on purpose: pure,
/// applied once per theme, and going through the same writer a user gesture
/// goes through rather than assembling [HomeItem]s by hand.
///
/// ─── THE BUG THIS DOES NOT REPEAT ───────────────────────────────────────────
///
/// `home_grid.dart` used to draw the first N apps whenever `homeItems` was
/// empty, and its own comment records why that was removed: those cells were
/// built with `slot: null` and were not wrapped in `_Draggable`, so they could
/// not be moved, long-pressed or removed. A desktop full of icons that refuse
/// every gesture is worse than an empty one.
///
/// Everything here goes through [HomeLayout.addToHome], which writes real
/// [HomeItem]s into prefs. What lands is indistinguishable from an icon the
/// user dragged there themselves: it drags, it opens a menu, it can be deleted,
/// and deleting all of them is a legitimate arrangement that this never
/// re-stamps because the flag is what says done, not the list being non-empty.
///
/// ─── AND WHY THE ORDER IS ALPHABETICAL ──────────────────────────────────────
///
/// Frecency would be better and is not available. `usage_repository.dart` says
/// so in its own doc: the frequent list is empty until launches accumulate, and
/// the dock therefore falls back to the alphabetical head on a first run. A
/// home seed runs at first use of a theme, which is precisely when usage is
/// empty, so alphabetical is not a compromise here, it is the only thing that
/// exists at the moment this runs.
///
/// The caller passes the list already sorted and filtered, because
/// `shellAppsProvider` has already dropped hidden apps and sorted by label and
/// re-deriving either here would be a second opinion about both.
class StarterHome {
  const StarterHome._();

  /// Returns [prefs] unchanged when there is nothing to do, so the caller can
  /// compare identity and skip the write entirely. Same contract as
  /// [StarterDesktop.apply].
  ///
  /// [exclude] is what the dock is already showing. Without it the first four
  /// icons appear twice on a fresh install, once in the dock and once on the
  /// desktop, because both fall back to the same alphabetical head. On Pocket,
  /// which is an iOS home screen, that duplication would be doubly wrong: a
  /// docked app is not also on the grid there.
  ///
  /// [capacity] is `rows * cols` and is the real ceiling. [HomeBlock.maxFill]
  /// only keeps an absurd authored number out of the loop; this is what stops a
  /// fill of 40 from calling [HomeLayout.addToHome] twenty times for a page
  /// that has been full since the twentieth.
  static LauncherPrefs apply(
    LauncherPrefs prefs,
    HomeBlock block, {
    required List<String> componentKeys,
    required Set<String> exclude,
    required int capacity,
    int page = 0,
  }) {
    if (block.fill <= 0 || capacity <= 0 || componentKeys.isEmpty) return prefs;

    final want = block.fill < capacity ? block.fill : capacity;

    var out = prefs;
    var placed = 0;
    for (final key in componentKeys) {
      if (placed >= want) break;
      if (exclude.contains(key)) continue;

      // `addToHome` refuses a duplicate and refuses a full page, returning the
      // prefs unchanged either way. Counting the RESULT rather than the
      // attempt is what makes both refusals mean the same thing here: a slot
      // that was not taken is a slot the next app can have.
      final next = HomeLayout.addToHome(
        out,
        key,
        page: page,
        capacity: capacity,
      );
      if (identical(next, out)) continue;
      out = next;
      placed++;
    }
    return out;
  }
}
